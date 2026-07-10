# SPDX-License-Identifier: MPL-2.0
# Neural-boundary guardrail tests.
#
# The flagship guarantee — "no number is ever produced by the LLM" — is only
# real if it is enforced and tested. These tests exercise the three guardrail
# primitives, the malformed-tool-call recovery path in process_tool_calls, and
# the executor's clamps and unknown-sub-type guards. No HTTP / live LLM needed:
# LLM responses are constructed as plain Dicts.

@testset "Neural-Boundary Guardrail" begin

    # ── collect_numbers: recursive numeric harvest ───────────────────────────
    @testset "collect_numbers" begin
        nested = Dict{String,Any}(
            "mean"   => 5.0,
            "counts" => [1, 2, 3],
            "nested" => Dict{String,Any}(
                "p_value" => 0.05,
                "flag"    => true,     # Bool: a flag, not a statistic
                "label"   => "large",  # String: no harvestable number
            ),
            "tuple"  => (2.5, 3.5),
        )
        nums = Statistikles.collect_numbers(nested)
        @test 5.0 in nums
        @test 0.05 in nums
        @test 2.5 in nums && 3.5 in nums
        @test all(x -> x in nums, [1.0, 2.0, 3.0])
        # mean + 3 counts + p_value + 2 tuple entries = 7 (bool/string ignored)
        @test length(nums) == 7
        # Booleans and strings are never harvested
        @test isempty(Statistikles.collect_numbers(Dict("flag" => true, "name" => "x")))
        @test isempty(Statistikles.collect_numbers("just prose, no numbers here"))
    end

    # ── extract_numeric_tokens: literals in prose ────────────────────────────
    @testset "extract_numeric_tokens" begin
        toks = Statistikles.extract_numeric_tokens(
            "The mean is 42.73, p = 0.05, effect 35% and 1.5e-3, df = 12")
        @test "42.73" in toks
        @test "0.05" in toks
        @test "35%" in toks
        @test "1.5e-3" in toks
        @test "12" in toks
        @test isempty(Statistikles.extract_numeric_tokens("no digits at all"))
    end

    # ── validate_numeric_provenance ──────────────────────────────────────────
    @testset "validate_numeric_provenance: CLEAN fixture" begin
        # Every number in the prose traces back to a tool result — including a
        # rounded mean (42.73 from 42.7333…), a rounded p-value (0.05 from
        # 0.0512), a percent variant (35% from 0.35), and a structural count (3).
        tool_results = Any[Dict{String,Any}(
            "mean"       => 42.7333333,
            "std"        => 5.5,
            "p_value"    => 0.0512,
            "proportion" => 0.35,
        )]
        clean = "The mean is 42.73 with SD 5.5. The p-value is 0.05, so about " *
                "35% of cases. With 3 groups the result holds."
        ok, orphans = Statistikles.validate_numeric_provenance(clean, tool_results, Float64[])
        @test ok
        @test isempty(orphans)

        # user-supplied numbers are legitimate provenance too
        ok_u, _ = Statistikles.validate_numeric_provenance(
            "You supplied 88 observations.", Any[], [88.0])
        @test ok_u

        # small structural integers (0..12) never require a source
        ok_s, _ = Statistikles.validate_numeric_provenance(
            "There are 7 groups and 12 items.", Any[], Float64[])
        @test ok_s
    end

    @testset "validate_numeric_provenance: INJECTED FABRICATION" begin
        tool_results = Any[Dict{String,Any}(
            "mean"       => 42.7333333,
            "std"        => 5.5,
            "p_value"    => 0.0512,
            "proportion" => 0.35,
        )]
        # 42.73 is legitimate; r = 0.87 and t = 3.14159 are fabricated mollocks.
        fabricated = "The mean is 42.73 but the correlation was r = 0.87 and t = 3.14159."
        ok, orphans = Statistikles.validate_numeric_provenance(fabricated, tool_results, Float64[])
        @test !ok
        @test "0.87" in orphans
        @test "3.14159" in orphans
        @test !("42.73" in orphans)   # the one real number is not flagged
    end

    # ── process_tool_calls: recovery from malformed tool calls (NO HTTP) ──────
    @testset "process_tool_calls: malformed tool_call recovery" begin
        # (i) tool_call missing the "function" key entirely
        messages = Any[Dict{String,Any}("role" => "user", "content" => "hi")]
        resp = Dict{String,Any}("choices" => [Dict{String,Any}(
            "message" => Dict{String,Any}(
                "tool_calls" => [Dict{String,Any}("id" => "call_1", "type" => "function")]
            )
        )])
        pr = Statistikles.process_tool_calls(resp, messages)
        @test pr.tool_calls_made
        @test length(pr.tool_results) == 1
        @test haskey(pr.tool_results[1], "error")
        # a clean role:"tool" error message was appended so the model can recover
        tool_msgs = [m for m in messages if get(m, "role", "") == "tool"]
        @test !isempty(tool_msgs)
        @test occursin("error", tool_msgs[end]["content"])

        # (ii) function present but "arguments" is not valid JSON
        messages2 = Any[Dict{String,Any}("role" => "user", "content" => "hi")]
        resp2 = Dict{String,Any}("choices" => [Dict{String,Any}(
            "message" => Dict{String,Any}(
                "tool_calls" => [Dict{String,Any}(
                    "id" => "call_2",
                    "function" => Dict{String,Any}(
                        "name" => "descriptive_statistics",
                        "arguments" => "{not valid json")
                )]
            )
        )])
        pr2 = Statistikles.process_tool_calls(resp2, messages2)
        @test pr2.tool_calls_made
        @test haskey(pr2.tool_results[1], "error")
        @test occursin("Malformed", pr2.tool_results[1]["error"])

        # (iii) a well-formed tool_call runs the symbolic function for real
        messages3 = Any[Dict{String,Any}("role" => "user", "content" => "describe")]
        resp3 = Dict{String,Any}("choices" => [Dict{String,Any}(
            "message" => Dict{String,Any}(
                "tool_calls" => [Dict{String,Any}(
                    "id" => "call_3",
                    "function" => Dict{String,Any}(
                        "name" => "descriptive_statistics",
                        "arguments" => "{\"data\":[2,4,4,4,5,5,7,9]}")
                )]
            )
        )])
        pr3 = Statistikles.process_tool_calls(resp3, messages3)
        @test pr3.tool_calls_made
        @test haskey(pr3.tool_results[1], "mean")
        @test pr3.tool_results[1]["mean"] == 5.0

        # a response with no tool calls makes none
        resp0 = Dict{String,Any}("choices" => [Dict{String,Any}(
            "message" => Dict{String,Any}("content" => "Just prose."))])
        pr0 = Statistikles.process_tool_calls(resp0, Any[])
        @test pr0.tool_calls_made == false
        @test isempty(pr0.tool_results)
    end

    # ── executor: clamps on caller-supplied sizes ────────────────────────────
    @testset "executor clamps" begin
        # n_reps clamp (bootstrap)
        over = Statistikles.execute_tool("bootstrap",
            Dict{String,Any}("data" => [1.0, 2, 3, 4, 5], "n_reps" => 200_000))
        @test haskey(over, "error") && occursin("n_reps", over["error"])
        under = Statistikles.execute_tool("bootstrap",
            Dict{String,Any}("data" => [1.0, 2, 3, 4, 5], "n_reps" => 50))
        @test !haskey(under, "error")

        # n_permutations clamp (permanova) — returns early, before permuting
        dm = [[0.0, 1.0, 2.0], [1.0, 0.0, 1.0], [2.0, 1.0, 0.0]]
        perm = Statistikles.execute_tool("permanova",
            Dict{String,Any}("distance_matrix" => dm,
                             "group_labels" => ["a", "a", "b"],
                             "n_permutations" => 200_000))
        @test haskey(perm, "error") && occursin("n_permutations", perm["error"])

        # component-count clamp k ≤ 20 (bayesian_em, ica, topic_modeling)
        em = Statistikles.execute_tool("bayesian_em",
            Dict{String,Any}("data" => collect(1.0:20.0), "k" => 25))
        @test haskey(em, "error") && occursin("component count", em["error"])
        ica = Statistikles.execute_tool("signal_processing",
            Dict{String,Any}("type" => "ica", "x" => [[1.0, 2, 3], [4.0, 5, 6]], "k" => 25))
        @test haskey(ica, "error") && occursin("component count", ica["error"])
        nmf = Statistikles.execute_tool("nlp_symbolic",
            Dict{String,Any}("type" => "topic_modeling",
                             "x" => [[1.0, 2, 3], [4.0, 5, 6]], "k" => 25))
        @test haskey(nmf, "error") && occursin("component count", nmf["error"])
    end

    # ── executor: unknown sub-type dispatch guards ───────────────────────────
    @testset "executor unknown sub-type guards" begin
        for (tool, args, needle) in [
            ("t_test",             Dict{String,Any}("type" => "bogus", "group1" => [1.0, 2, 3]), "t_test"),
            ("time_series",        Dict{String,Any}("type" => "bogus", "data" => [1.0, 2, 3]),    "time_series"),
            ("information_theory", Dict{String,Any}("type" => "bogus", "data" => [1.0, 2, 3]),    "information_theory"),
            ("survival_analysis",  Dict{String,Any}("type" => "bogus", "times" => [1.0], "events" => [true]), "survival_analysis"),
            ("robust_stats",       Dict{String,Any}("type" => "bogus", "data" => [1.0, 2, 3]),    "robust_stats"),
            ("causal_inference",   Dict{String,Any}("type" => "bogus"),                            "causal_inference"),
            ("spatial_stats",      Dict{String,Any}("type" => "bogus"),                            "spatial_stats"),
            ("advanced_modeling",  Dict{String,Any}("type" => "bogus"),                            "advanced_modeling"),
            ("algebraic_stats",    Dict{String,Any}("type" => "bogus"),                            "algebraic_stats"),
            ("nonparametric_test", Dict{String,Any}("type" => "bogus", "group1" => [1.0], "group2" => [2.0]), "nonparametric_test"),
            ("measurement_analysis", Dict{String,Any}("type" => "bogus"),                          "measurement_analysis"),
            ("inter_rater_reliability", Dict{String,Any}("type" => "bogus"),                       "inter_rater_reliability"),
            ("sampling_design",    Dict{String,Any}("type" => "bogus"),                            "sampling_design"),
        ]
            r = Statistikles.execute_tool(tool, args)
            @test haskey(r, "error")
            @test occursin("Unknown type", r["error"])
            @test occursin(needle, r["error"])
        end

        # unknown top-level tool
        u = Statistikles.execute_tool("nonexistent_tool", Dict{String,Any}())
        @test haskey(u, "error") && occursin("Unknown tool", u["error"])
    end

end
