# SPDX-License-Identifier: MPL-2.0
# Structured observability: correlation ids, structured logging, and the
# VeriSimDB audit-trail wiring for the tool-execution runtime path.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  WHY THIS EXISTS                                                        │
# │                                                                         │
# │  Every tool call is where neural (LLM-chosen) meets symbolic (Julia-    │
# │  computed) — the exact boundary the guardrail enforces. That boundary   │
# │  is only auditable if it is OBSERVED: which tool ran, for which chat    │
# │  turn, with which (hashed, never-raw) arguments, producing what shape   │
# │  of result, in how long. This module supplies that instrumentation and  │
# │  wires it to the (optional, pluggable) VeriSimDB persistence layer.     │
# │                                                                         │
# │  Two hard rules:                                                       │
# │   1. Never log or persist raw argument/result VALUES — only hashes and  │
# │      shape summaries. Real data may be user data.                      │
# │   2. Never make the test suite depend on a live VeriSimDB backend —     │
# │      persistence is opt-in via STATISTIKLES_AUDIT_PERSIST.             │
# └─────────────────────────────────────────────────────────────────────────┘

# ── Logging setup ────────────────────────────────────────────────────────────

# Map a case-insensitive level name to a Logging level. Anything unrecognized
# (including an empty/unset ENV var) falls back to Info — a typo should never
# silently drop the process into Debug-volume output.
function _parse_log_level(s::AbstractString)
    key = uppercase(strip(s))
    key == "DEBUG"   && return Logging.Debug
    key == "INFO"    && return Logging.Info
    key == "WARN"    && return Logging.Warn
    key == "WARNING" && return Logging.Warn
    key == "ERROR"   && return Logging.Error
    return Logging.Info
end

"""
    configure_logging!() -> Logging.AbstractLogger

Install a stderr-backed `ConsoleLogger` whose minimum level is controlled by
the `STATISTIKLES_LOG_LEVEL` environment variable (default `"Info"`; accepts
`Debug`/`Info`/`Warn`/`Warning`/`Error`, case-insensitively). Called
automatically when the package loads (see `__init__`); safe to call again to
pick up a changed environment variable mid-session.

Human-facing REPL output (the banner, prompts, and the assistant's answers)
is always written with `println` to stdout and never routed through this
logger — the two streams stay separate so log lines never interleave with a
conversation.
"""
function configure_logging!()
    level = _parse_log_level(get(ENV, "STATISTIKLES_LOG_LEVEL", "Info"))
    logger = Logging.ConsoleLogger(stderr, level)
    Logging.global_logger(logger)
    return logger
end

# ── Correlation / tool-call identifiers ──────────────────────────────────────

"""
    new_correlation_id() -> String

Generate a fresh, globally-unique identifier (UUID v4) suitable for use as a
per-chat-turn correlation id or a per-tool-call id.
"""
new_correlation_id() = string(uuid4())

"""
    tool_call_identifier(tool_call) -> String

Return the id the LLM assigned to a tool call (`tool_call["id"]`) when
present and non-empty, otherwise mint a fresh one. Tool calls arriving from a
malformed/partial LLM response must still get a usable id for logging and
audit purposes.
"""
function tool_call_identifier(tool_call)
    if tool_call isa AbstractDict
        id = get(tool_call, "id", nothing)
        (id isa AbstractString && !isempty(id)) && return String(id)
    end
    return new_correlation_id()
end

# ── Argument hashing (never log/persist raw arguments) ───────────────────────

"""
    hash_arguments(args) -> String

A stable, order-independent, non-reversible digest of a tool-call argument
collection (typically a `Dict`) — for logging and audit records that must
never carry raw arguments (which may contain user data). Identical
arguments, regardless of key insertion order, hash identically (Julia's
`AbstractDict` hash combines per-pair hashes with `xor`, so it is
order-independent by construction).
"""
hash_arguments(args) = string(hash(args); base=16)

# ── Result shape summaries (never log/persist raw result values) ────────────

"""
    summarize_result(result) -> Dict{String,Any}

A shape-only summary of a tool result — type, and (for `Dict`s) sorted key
names and count, or (for vectors/arrays) length/size — never the actual
values. Used for log records and audit entries so observability never
becomes a second channel for raw data to leak through.
"""
function summarize_result(result)
    if result isa AbstractDict
        ks = sort!(String[string(k) for k in keys(result)])
        return Dict{String,Any}("type" => "Dict", "n_keys" => length(result), "keys" => ks)
    elseif result isa AbstractVector
        return Dict{String,Any}("type" => "Vector", "length" => length(result))
    elseif result isa AbstractArray
        return Dict{String,Any}("type" => "Array", "size" => collect(size(result)))
    else
        return Dict{String,Any}("type" => string(typeof(result)))
    end
end

_is_error_result(result) = result isa AbstractDict && haskey(result, "error")

# ── Structured tool-call logging ─────────────────────────────────────────────

"""
    log_tool_call(correlation_id, tool_call_id, tool_name, args, result, duration_s)

Emit the single structured log record for one completed tool call — `@info`
on success, `@warn` when the result carries an `"error"` key. Carries the
per-chat-turn `correlation_id`, the per-tool-call id, the tool name, an
argument hash (never raw arguments), a result shape summary (never raw
values), and duration in milliseconds. This is the sole diagnostic
breadcrumb for tool execution — it replaces the previous ad-hoc
`println("[symbolic] executing: ...")`.
"""
function log_tool_call(correlation_id::AbstractString, tool_call_id::AbstractString,
                       tool_name::AbstractString, args, result, duration_s::Real)
    duration_ms = round(duration_s * 1000; digits=2)
    summary = summarize_result(result)
    ahash = hash_arguments(args)
    if _is_error_result(result)
        @warn "tool_call" correlation_id=correlation_id tool_call_id=tool_call_id tool=tool_name arg_hash=ahash duration_ms=duration_ms result_summary=summary success=false
    else
        @info "tool_call" correlation_id=correlation_id tool_call_id=tool_call_id tool=tool_name arg_hash=ahash duration_ms=duration_ms result_summary=summary success=true
    end
    return nothing
end

# ── VeriSimDB audit-trail wiring (pluggable, no-op-safe by default) ─────────

"""
    audit_persistence_enabled() -> Bool

Whether audit records should actually be persisted to VeriSimDB (a network
call). Defaults to `false` — audit-record *construction* is always exercised
and tested, but nothing in the test suite or a default run depends on a live
VeriSimDB backend being reachable. Opt in with
`STATISTIKLES_AUDIT_PERSIST=true` (also accepts `1`/`yes`/`on`,
case-insensitively).
"""
function audit_persistence_enabled()
    v = lowercase(strip(get(ENV, "STATISTIKLES_AUDIT_PERSIST", "false")))
    return v in ("1", "true", "yes", "on")
end

"""
    build_audit_record(turn_id, tool_call_id, tool_name, args, result;
                       duration_s=nothing) -> Dict{String,Any}

Construct (without persisting) the audit-trail record for one tool
invocation: turn id, tool-call id, tool name, an argument hash (never raw
arguments), and result provenance — a shape summary plus a success flag
(never raw result values) — with a timestamp. This is the record
`record_audit!` persists via `store_result` (audit modality) when
persistence is enabled.
"""
function build_audit_record(turn_id::AbstractString, tool_call_id::AbstractString,
                            tool_name::AbstractString, args, result;
                            duration_s::Union{Real,Nothing}=nothing)
    record = Dict{String,Any}(
        "turn_id"        => String(turn_id),
        "tool_call_id"   => String(tool_call_id),
        "tool"           => String(tool_name),
        "arg_hash"       => hash_arguments(args),
        "result_summary" => summarize_result(result),
        "success"        => !_is_error_result(result),
        "timestamp"      => string(now()),
    )
    duration_s === nothing || (record["duration_s"] = Float64(duration_s))
    return record
end

"""
    record_audit!(turn_id, tool_call_id, tool_name, args, result; duration_s=nothing)
        -> Dict{String,Any}

Build the audit record for one tool call and, only when
`audit_persistence_enabled()`, persist it via `store_result` (VeriSimDB,
`"audit"` modality). Always returns the constructed record — even when
persistence is disabled, or enabled but the backend is unreachable
(persistence failures are caught and logged, never thrown) — so callers and
tests can inspect the record's shape without a live backend.
"""
function record_audit!(turn_id::AbstractString, tool_call_id::AbstractString,
                       tool_name::AbstractString, args, result;
                       duration_s::Union{Real,Nothing}=nothing)
    record = build_audit_record(turn_id, tool_call_id, tool_name, args, result; duration_s=duration_s)
    if audit_persistence_enabled()
        try
            store_result("tool_audit", record, record["arg_hash"]; modality="audit")
        catch e
            @warn "audit_persistence_failed" turn_id=turn_id tool=tool_name exception=(e, catch_backtrace())
        end
    end
    return record
end
