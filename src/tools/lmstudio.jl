# SPDX-License-Identifier: MPL-2.0
# LM Studio server interface.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  HARD NOTICE: NEURAL-SYMBOLIC BOUNDARY                                │
# │                                                                        │
# │  This module handles communication with the LLM (neural component).   │
# │  The LLM's role is EXCLUSIVELY:                                       │
# │  1. Parsing natural language input                                     │
# │  2. Deciding which statistical tool to invoke                          │
# │  3. Interpreting symbolic results in plain language                    │
# │                                                                        │
# │  The LLM NEVER computes statistics. If you see a number in the        │
# │  LLM's response that didn't come from a tool call, it is a            │
# │  MOLLOCK — a plausible-sounding fabrication. Trust only tool results.  │
# └─────────────────────────────────────────────────────────────────────────┘

# Configuration — override via environment variables
const BASE_URL = get(ENV, "STATISTIKLES_LM_URL", "http://localhost:1234/v1")
const API_KEY = get(ENV, "STATISTIKLES_API_KEY", "lm-studio")
const MODEL = get(ENV, "STATISTIKLES_MODEL", "lmstudio-community/qwen2.5-7b-instruct")

const HEADERS = [
    "Content-Type" => "application/json",
    "Accept" => "application/json",
    "Authorization" => "Bearer $API_KEY"
]

"""
    call_lm_studio(messages, tools; stream) -> Dict

Send a chat completion request to LM Studio.
Uses untyped Dict to avoid Julia method dispatch issues with JSON-parsed dicts.
"""
function call_lm_studio(messages, tools=nothing; stream::Bool=false)
    payload = Dict{String,Any}(
        "model" => MODEL,
        "messages" => messages,
        "temperature" => 0.7,
        "max_tokens" => 4000
    )

    if !isnothing(tools)
        payload["tools"] = tools
    end

    if stream
        payload["stream"] = true
    end

    body = Vector{UInt8}(JSON3.write(payload))

    try
        resp = HTTP.request("POST", "$BASE_URL/chat/completions", HEADERS, body;
                           status_exception=false,
                           connect_timeout=10, readtimeout=120, retry=false)
        if resp.status == 200
            return JSON3.read(String(resp.body), Dict{String,Any})
        else
            return Dict{String,Any}("error" => "HTTP $(resp.status): $(String(resp.body))")
        end
    catch e
        return Dict{String,Any}("error" => "Connection failed: $(string(e))")
    end
end

"""
    process_tool_calls(response, messages; tools=nothing, max_rounds=5,
                       correlation_id=new_correlation_id())
        -> (final, tool_results, tool_calls_made, correlation_id)

Drive the symbolic tool-call loop. For each round the assistant requests tool
calls, execute the (verified Julia) functions, feed the results back, and ask
the model again — up to `max_rounds` (bounded to guard against loops) until a
reply carries no more tool calls.

Returns a NamedTuple:
  * `final`           — the last LLM response Dict (the interpretive reply, or a
                        transport-error Dict if the follow-up call failed).
  * `tool_results`    — every symbolic result produced this turn, in order, as
                        native Julia Dicts (fuel for the numeric guardrail).
  * `tool_calls_made` — whether any tool call was executed at all.
  * `correlation_id`  — the per-chat-turn id every tool call in this run was
                        logged and audited under (caller-supplied, or a fresh
                        one minted when omitted).

Each individual tool call is wrapped in try/catch: a malformed `tool_call`
(missing keys, non-JSON `arguments`) yields a clean `Dict("error"=>...)` tool
message so the model can recover instead of the session throwing. The `tools`
parameter is forwarded on the follow-up call so the model can chain tools.

Every tool call is timed and emits one structured log record
(`log_tool_call`) plus an audit-trail record (`record_audit!`, pluggable and
no-op-safe unless `STATISTIKLES_AUDIT_PERSIST=true`) — see
`tools/observability.jl`. Neither logs nor persists raw arguments/results.
"""
function process_tool_calls(response, messages; tools=nothing, max_rounds::Int=5,
                            correlation_id::AbstractString=new_correlation_id())
    tool_results = Any[]
    tool_calls_made = false
    current = response

    for _ in 1:max_rounds
        (haskey(current, "choices") && !isempty(current["choices"])) || break
        message = current["choices"][1]["message"]

        has_calls = haskey(message, "tool_calls") &&
                    !isnothing(message["tool_calls"]) &&
                    !isempty(message["tool_calls"])
        has_calls || break

        tool_calls_made = true

        # Record the assistant's tool-call request in the transcript.
        push!(messages, Dict{String,Any}(
            "role" => "assistant",
            "tool_calls" => message["tool_calls"]
        ))

        # Execute each tool call (symbolic computation). A bad call must never
        # crash the turn — it becomes an error result the model can react to.
        for tool_call in message["tool_calls"]
            result = nothing
            fn_name = "unknown"
            args = Dict{String,Any}()
            tc_id = tool_call_identifier(tool_call)
            t0 = time()
            try
                fn_name = tool_call["function"]["name"]
                args = JSON3.read(tool_call["function"]["arguments"], Dict{String,Any})
                result = execute_tool(fn_name, args)
            catch e
                result = Dict{String,Any}("error" => "Malformed tool call: $(string(e))")
            end
            duration_s = time() - t0
            push!(tool_results, result)

            log_tool_call(correlation_id, tc_id, fn_name, args, result, duration_s)
            record_audit!(correlation_id, tc_id, fn_name, args, result; duration_s=duration_s)

            tool_msg = Dict{String,Any}(
                "role" => "tool",
                "content" => JSON3.write(result)
            )
            if tool_call isa AbstractDict && haskey(tool_call, "id")
                tool_msg["tool_call_id"] = tool_call["id"]
            end
            push!(messages, tool_msg)
        end

        # Interpret results — forward `tools` so the model may chain further.
        current = call_lm_studio(messages, tools)
        haskey(current, "error") && break
    end

    return (final = current, tool_results = tool_results, tool_calls_made = tool_calls_made,
            correlation_id = correlation_id)
end
