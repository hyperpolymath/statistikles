# SPDX-License-Identifier: MPL-2.0
# Structured observability tests — correlation ids, structured logging, and
# the (pluggable, no-op-safe) VeriSimDB audit-trail wiring.
#
# No live VeriSimDB backend is required anywhere in this file:
# audit_persistence_enabled() defaults to false, so record_audit! only ever
# constructs a record in this suite — it never attempts a network call. Log
# capture uses Test.collect_test_logs/with_logger, the same pattern the
# standard library's own logging tests use, so no HTTP/LLM is needed either.

using Logging

@testset "Observability" begin

    # ── Correlation / tool-call identifiers ──────────────────────────────────
    @testset "new_correlation_id" begin
        a = Statistikles.new_correlation_id()
        b = Statistikles.new_correlation_id()
        @test a isa String
        @test a != b                      # globally unique per call
        @test length(a) == 36             # canonical UUID string length
    end

    @testset "tool_call_identifier" begin
        # Well-formed tool_call: reuse the LLM-assigned id.
        @test Statistikles.tool_call_identifier(Dict{String,Any}("id" => "call_abc")) == "call_abc"
        # Missing / empty / malformed id: mint a fresh one rather than error.
        minted = Statistikles.tool_call_identifier(Dict{String,Any}())
        @test minted isa String && !isempty(minted)
        minted2 = Statistikles.tool_call_identifier(Dict{String,Any}("id" => ""))
        @test minted2 isa String && !isempty(minted2)
        @test Statistikles.tool_call_identifier("not-a-dict") isa String
    end

    # ── Argument hashing: order-independent, never raw ───────────────────────
    @testset "hash_arguments" begin
        a1 = Dict{String,Any}("data" => [1.0, 2.0, 3.0], "alpha" => 0.05)
        a2 = Dict{String,Any}("alpha" => 0.05, "data" => [1.0, 2.0, 3.0])  # different insertion order
        a3 = Dict{String,Any}("data" => [1.0, 2.0, 4.0], "alpha" => 0.05)  # different value

        h1 = Statistikles.hash_arguments(a1)
        h2 = Statistikles.hash_arguments(a2)
        h3 = Statistikles.hash_arguments(a3)

        @test h1 isa String
        @test h1 == h2               # order-independent
        @test h1 != h3               # different arguments -> different hash
        @test !occursin("1.0", h1)   # never a serialization of the raw values
        @test !occursin("data", h1)
    end

    # ── Result shape summaries: shape only, never raw values ─────────────────
    @testset "summarize_result" begin
        dict_result = Dict{String,Any}("mean" => 42.7333, "std" => 5.5, "n" => 8)
        s = Statistikles.summarize_result(dict_result)
        @test s["type"] == "Dict"
        @test s["n_keys"] == 3
        @test Set(s["keys"]) == Set(["mean", "std", "n"])
        @test !(42.7333 in values(s))   # no raw value leaked into the summary

        vec_result = [1.0, 2.0, 3.0, 4.0]
        sv = Statistikles.summarize_result(vec_result)
        @test sv["type"] == "Vector"
        @test sv["length"] == 4

        scalar_result = 3.14159
        ss = Statistikles.summarize_result(scalar_result)
        @test ss["type"] == "Float64"
    end

    # ── Audit record construction: shape tested, no network dependency ───────
    @testset "build_audit_record" begin
        args = Dict{String,Any}("data" => [1.0, 2.0, 3.0])
        result = Dict{String,Any}("mean" => 2.0, "n" => 3)
        rec = Statistikles.build_audit_record("turn-1", "call-1", "descriptive_statistics",
                                              args, result; duration_s=0.0123)
        @test rec["turn_id"] == "turn-1"
        @test rec["tool_call_id"] == "call-1"
        @test rec["tool"] == "descriptive_statistics"
        @test rec["arg_hash"] == Statistikles.hash_arguments(args)
        @test rec["success"] == true
        @test rec["result_summary"]["type"] == "Dict"
        @test rec["duration_s"] == 0.0123
        @test haskey(rec, "timestamp")

        # An error-shaped result is marked unsuccessful.
        err_result = Dict{String,Any}("error" => "boom")
        rec_err = Statistikles.build_audit_record("turn-2", "call-2", "bogus_tool", args, err_result)
        @test rec_err["success"] == false
        @test !haskey(rec_err, "duration_s")   # optional field omitted when not supplied
    end

    # ── audit_persistence_enabled: off by default, parses truthy/falsy forms ─
    @testset "audit_persistence_enabled" begin
        @test Statistikles.audit_persistence_enabled() == false  # unset -> off by default

        for truthy in ["true", "TRUE", "1", "yes", "on", " On "]
            withenv("STATISTIKLES_AUDIT_PERSIST" => truthy) do
                @test Statistikles.audit_persistence_enabled() == true
            end
        end
        for falsy in ["false", "0", "no", "off", ""]
            withenv("STATISTIKLES_AUDIT_PERSIST" => falsy) do
                @test Statistikles.audit_persistence_enabled() == false
            end
        end
    end

    # ── record_audit!: no-op-safe by default, never touches the network ──────
    @testset "record_audit! is no-op-safe by default" begin
        args = Dict{String,Any}("data" => [1.0, 2.0])
        result = Dict{String,Any}("mean" => 1.5)
        # Persistence is off by default in this process's ENV; this must
        # return the constructed record without attempting any HTTP call —
        # no timeout, no exception, no dependency on a live VeriSimDB.
        rec = Statistikles.record_audit!("turn-3", "call-3", "descriptive_statistics",
                                         args, result; duration_s=0.001)
        @test rec["turn_id"] == "turn-3"
        @test rec["success"] == true
    end

    # ── configure_logging! / level parsing ────────────────────────────────────
    @testset "log level parsing" begin
        @test Statistikles._parse_log_level("debug") == Logging.Debug
        @test Statistikles._parse_log_level("INFO") == Logging.Info
        @test Statistikles._parse_log_level("Warn") == Logging.Warn
        @test Statistikles._parse_log_level("warning") == Logging.Warn
        @test Statistikles._parse_log_level("ERROR") == Logging.Error
        @test Statistikles._parse_log_level("nonsense") == Logging.Info  # safe fallback
        @test Statistikles._parse_log_level("") == Logging.Info
    end

    @testset "configure_logging! honours STATISTIKLES_LOG_LEVEL" begin
        withenv("STATISTIKLES_LOG_LEVEL" => "Debug") do
            logger = Statistikles.configure_logging!()
            @test logger isa Logging.ConsoleLogger
            @test Logging.min_enabled_level(logger) == Logging.Debug
        end
        # Restore Info-level behavior for the rest of the suite.
        withenv("STATISTIKLES_LOG_LEVEL" => nothing) do
            logger = Statistikles.configure_logging!()
            @test Logging.min_enabled_level(logger) == Logging.Info
        end
    end

    # ── Structured log records: correlation id + tool metadata captured ──────
    @testset "log_tool_call emits structured records" begin
        logs, _ = Test.collect_test_logs() do
            Statistikles.log_tool_call("turn-abc", "call-xyz", "descriptive_statistics",
                Dict{String,Any}("data" => [1.0, 2.0, 3.0]),
                Dict{String,Any}("mean" => 2.0, "n" => 3), 0.0421)
        end
        @test length(logs) == 1
        rec = logs[1]
        @test rec.level == Logging.Info
        @test rec.message == "tool_call"
        kv = Dict(rec.kwargs)
        @test kv[:correlation_id] == "turn-abc"
        @test kv[:tool_call_id] == "call-xyz"
        @test kv[:tool] == "descriptive_statistics"
        @test kv[:success] == true
        @test kv[:result_summary]["type"] == "Dict"
        @test kv[:duration_ms] isa Real
        @test kv[:arg_hash] isa String
        @test !occursin("1.0", kv[:arg_hash])  # never the raw argument values

        # An error-shaped result logs at Warn, not Info.
        logs2, _ = Test.collect_test_logs() do
            Statistikles.log_tool_call("turn-err", "call-err", "bogus_tool",
                Dict{String,Any}(), Dict{String,Any}("error" => "boom"), 0.001)
        end
        @test length(logs2) == 1
        @test logs2[1].level == Logging.Warn
        @test Dict(logs2[1].kwargs)[:success] == false
    end

    # ── End-to-end: process_tool_calls threads the correlation id through ────
    @testset "process_tool_calls: correlation id threads into log records" begin
        messages = Any[Dict{String,Any}("role" => "user", "content" => "describe")]
        resp = Dict{String,Any}("choices" => [Dict{String,Any}(
            "message" => Dict{String,Any}(
                "tool_calls" => [Dict{String,Any}(
                    "id" => "call_obs_1",
                    "function" => Dict{String,Any}(
                        "name" => "descriptive_statistics",
                        "arguments" => "{\"data\":[2,4,4,4,5,5,7,9]}")
                )]
            )
        )])

        logs, pr = Test.collect_test_logs() do
            Statistikles.process_tool_calls(resp, messages; correlation_id="fixed-turn-id")
        end

        @test pr.correlation_id == "fixed-turn-id"
        tool_logs = [l for l in logs if l.message == "tool_call"]
        @test !isempty(tool_logs)
        kv = Dict(tool_logs[1].kwargs)
        @test kv[:correlation_id] == "fixed-turn-id"
        @test kv[:tool_call_id] == "call_obs_1"
        @test kv[:tool] == "descriptive_statistics"

        # Two independent calls without an explicit correlation id get distinct ids.
        messages2 = Any[Dict{String,Any}("role" => "user", "content" => "describe")]
        pr_a = Statistikles.process_tool_calls(resp, messages2)
        messages3 = Any[Dict{String,Any}("role" => "user", "content" => "describe")]
        pr_b = Statistikles.process_tool_calls(resp, messages3)
        @test pr_a.correlation_id != pr_b.correlation_id
    end

end
