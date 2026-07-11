# SPDX-License-Identifier: MPL-2.0
# Executor router coverage — every registered LLM-facing tool exercised.
#
# execute_tool(name, args) is the precise layer the LLM drives: a bare string
# tool name plus a loosely-typed argument Dict gets coerced into typed Julia
# calls. Before this file, that string→function mapping and argument
# coercion was exercised for exactly one tool ("anova"). This file
# programmatically enumerates every tool registered in tools/definitions.jl
# (parsed via get_tools(), never hand-copied) and calls execute_tool for
# each with a table of minimal valid arguments, asserting a clean
# (non-"error") Dict comes back. A small set of high-traffic tools are
# additionally cross-checked against their direct Julia function call — the
# same pattern already used for "anova" in reference_validation_test.jl.
#
# If a tool is ever added to get_tools() without a corresponding entry here
# (either in ARG_TABLE or SKIP_LIST), the "every registered tool" testset
# below fails. That is the point: coverage cannot silently rot.

@testset "Executor Router Coverage" begin

    # ── Minimal valid arguments per registered tool name ──────────────────
    # Keep each entry the smallest input that exercises the tool's primary
    # code path without tripping degenerate-input guards.
    ARG_TABLE = Dict{String,Dict{String,Any}}(
        "descriptive_statistics" => Dict{String,Any}(
            "data" => [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]),
        "frequency_analysis" => Dict{String,Any}(
            "data" => ["a", "b", "a", "c", "b", "a"]),
        "t_test" => Dict{String,Any}(
            "type" => "independent",
            "group1" => [1.0, 2.0, 3.0, 4.0, 5.0],
            "group2" => [2.0, 4.0, 6.0, 8.0, 10.0]),
        "anova" => Dict{String,Any}(
            "groups" => [[1.0, 2.0, 3.0], [2.0, 3.0, 4.0], [3.0, 4.0, 5.0]]),
        "chi_square" => Dict{String,Any}(
            "type" => "independence",
            "observed" => [[10, 20], [30, 40]]),
        "correlation" => Dict{String,Any}(
            "x" => [1.0, 2.0, 3.0, 4.0, 5.0],
            "y" => [1.0, 2.0, 3.0, 4.0, 6.0]),
        "regression" => Dict{String,Any}(
            "x" => [1.0, 2.0, 3.0, 4.0, 5.0],
            "y" => [2.0, 4.0, 5.0, 4.0, 5.0]),
        "nonparametric_test" => Dict{String,Any}(
            "type" => "mann_whitney",
            "group1" => [1.0, 2.0, 3.0],
            "group2" => [4.0, 5.0, 6.0]),
        "permanova" => Dict{String,Any}(
            "distance_matrix" => [[0.0, 1.0, 2.0, 3.0],
                                   [1.0, 0.0, 1.5, 2.5],
                                   [2.0, 1.5, 0.0, 1.0],
                                   [3.0, 2.5, 1.0, 0.0]],
            "group_labels" => ["A", "A", "B", "B"],
            "n_permutations" => 49),
        "effect_size_calculator" => Dict{String,Any}(
            "cohens_d" => 0.5, "n1" => 20, "n2" => 20),
        "power_analysis" => Dict{String,Any}(
            "effect_size" => 0.5, "n" => 30),
        "sample_size_calculator" => Dict{String,Any}(
            "design" => "means", "effect_size" => 0.5),
        "test_assumptions" => Dict{String,Any}(
            "type" => "normality",
            "data" => collect(1.0:15.0)),
        "bayesian_analysis" => Dict{String,Any}(
            "prior" => [0.5, 0.5],
            "likelihood" => [[0.8, 0.2], [0.3, 0.7]],
            "data_index" => 1),
        "bayes_factor" => Dict{String,Any}(
            "r_squared_full" => 0.6, "r_squared_reduced" => 0.4,
            "n" => 50, "p_full" => 3, "p_reduced" => 1),
        "credible_intervals" => Dict{String,Any}(
            "samples" => collect(1.0:100.0)),
        "fuzzy_logic_analysis" => Dict{String,Any}(
            "value" => 0.5, "center" => 0.5, "width" => 0.2, "operation" => "membership"),
        "dempster_shafer" => Dict{String,Any}(
            "evidence1" => Dict("A" => 0.6, "B" => 0.4),
            "evidence2" => Dict("A" => 0.5, "B" => 0.5)),
        "granger_causality" => Dict{String,Any}(
            "series_x" => [1.0i + 0.1 * cos(i) for i in 1:20],
            "series_y" => [2.0i + 0.1 * sin(i) for i in 1:20],
            "lag" => 1),
        "james_stein" => Dict{String,Any}(
            "observations" => [1.0, 2.5, 3.0, 4.5, 5.0, 2.0]),
        "diagnostic_metrics" => Dict{String,Any}(
            "true_positive" => 50, "false_negative" => 10,
            "true_negative" => 80, "false_positive" => 5),
        "reliability_analysis" => Dict{String,Any}(
            "items" => [[3.0, 4.0, 5.0], [4.0, 4.0, 4.0], [2.0, 3.0, 3.0],
                        [5.0, 5.0, 4.0], [3.0, 4.0, 4.0], [4.0, 3.0, 5.0]]),
        "measurement_analysis" => Dict{String,Any}(
            "type" => "sem", "reliability" => 0.8, "sd" => 10.0),
        "validity_assessment" => Dict{String,Any}(
            "n_essential" => 8, "n_total" => 10),
        "criterion_validity_test" => Dict{String,Any}(
            "predictor" => [1.0, 2.0, 3.0, 4.0, 5.0],
            "criterion" => [2.0, 4.0, 5.0, 4.0, 6.0]),
        "inter_rater_reliability" => Dict{String,Any}(
            "type" => "cohens_kappa",
            "rater1" => [1, 0, 1, 1, 0, 1],
            "rater2" => [1, 0, 0, 1, 0, 1]),
        "qualitative_analysis" => Dict{String,Any}(
            "themes_per_interview" => [5, 3, 2, 1, 1, 0, 1]),
        "calculate_pre" => Dict{String,Any}(
            "observed" => [1.0, 2.0, 3.0, 4.0, 5.0],
            "predicted" => [1.1, 2.1, 2.9, 4.2, 4.8]),
        "sampling_design" => Dict{String,Any}(
            "type" => "margin_of_error", "n" => 100,
            "proportion" => 0.5, "confidence" => 0.95),
    )

    # ── Skip-list: tools genuinely needing external services/files ────────
    # Keep this EMPTY unless a tool truly cannot be exercised in-process.
    # A broken/undefined dispatch target is a bug to fix, not a skip
    # reason — the whole point of this file is to catch exactly that.
    SKIP_LIST = Dict{String,String}()

    registered_tools = [t["function"]["name"] for t in Statistikles.get_tools()]

    @testset "Registry coverage: every tool has a table entry or skip reason" begin
        @test !isempty(registered_tools)
        for name in registered_tools
            @test haskey(ARG_TABLE, name) || haskey(SKIP_LIST, name)
        end
        # The skip-list is an escape hatch, not a dumping ground.
        @test length(SKIP_LIST) <= 3
        for (name, reason) in SKIP_LIST
            @test !isempty(reason)
        end
    end

    @testset "execute_tool succeeds for every non-skipped registered tool" begin
        for name in registered_tools
            haskey(SKIP_LIST, name) && continue
            @test haskey(ARG_TABLE, name)
            !haskey(ARG_TABLE, name) && continue  # can't call without args
            result = Statistikles.execute_tool(name, ARG_TABLE[name])
            @test result isa Dict
            @test !haskey(result, "error")
        end
    end

    # ── Cross-checks: router output vs. direct Julia function call ────────
    # For high-traffic tools, confirm execute_tool's argument coercion
    # doesn't silently change the numbers — the same pattern as the
    # "anova" cross-check in reference_validation_test.jl.
    @testset "Cross-check: t_test router vs. direct call" begin
        g1, g2 = [1.0, 2.0, 3.0, 4.0, 5.0], [2.0, 4.0, 6.0, 8.0, 10.0]
        direct = t_test_independent(g1, g2)
        via_tool = Statistikles.execute_tool("t_test",
            Dict{String,Any}("type" => "independent", "group1" => g1, "group2" => g2))
        @test isapprox(via_tool["t_stat"], direct["t_stat"]; atol = 1e-12)
        @test isapprox(via_tool["p_value"], direct["p_value"]; atol = 1e-12)
        @test isapprox(via_tool["cohens_d"], direct["cohens_d"]; atol = 1e-12)
    end

    @testset "Cross-check: descriptive_statistics router vs. direct call" begin
        data = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        direct = descriptive_stats(data)
        via_tool = Statistikles.execute_tool("descriptive_statistics",
            Dict{String,Any}("data" => data))
        @test isapprox(via_tool["mean"], direct["mean"]; atol = 1e-12)
        @test isapprox(via_tool["variance"], direct["variance"]; atol = 1e-12)
        @test isapprox(via_tool["skewness"], direct["skewness"]; atol = 1e-12)
    end

    @testset "Cross-check: correlation router vs. direct call" begin
        x, y = [1.0, 2.0, 3.0, 4.0, 5.0], [1.0, 2.0, 3.0, 4.0, 6.0]
        direct = pearson_correlation(x, y)
        via_tool = Statistikles.execute_tool("correlation",
            Dict{String,Any}("x" => x, "y" => y, "method" => "pearson"))
        @test isapprox(via_tool["r"], direct["r"]; atol = 1e-12)
        @test isapprox(via_tool["p_value"], direct["p_value"]; atol = 1e-12)
    end

    @testset "Cross-check: regression router vs. direct call" begin
        x, y = [1.0, 2.0, 3.0, 4.0, 5.0], [2.0, 4.0, 5.0, 4.0, 5.0]
        direct = simple_linear_regression(x, y)
        via_tool = Statistikles.execute_tool("regression",
            Dict{String,Any}("x" => x, "y" => y))
        @test isapprox(via_tool["slope"], direct["slope"]; atol = 1e-12)
        @test isapprox(via_tool["intercept"], direct["intercept"]; atol = 1e-12)
        @test isapprox(via_tool["r_squared"], direct["r_squared"]; atol = 1e-12)
    end

    @testset "Cross-check: mann_whitney router vs. direct call" begin
        g1, g2 = [1.0, 2.0, 3.0], [4.0, 5.0, 6.0]
        direct = mann_whitney_u(g1, g2)
        via_tool = Statistikles.execute_tool("nonparametric_test",
            Dict{String,Any}("type" => "mann_whitney", "group1" => g1, "group2" => g2))
        @test isapprox(via_tool["U_statistic"], direct["U_statistic"]; atol = 1e-12)
        @test isapprox(via_tool["p_value"], direct["p_value"]; atol = 1e-12)
    end

end
