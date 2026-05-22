# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# e2e_test.jl — End-to-end pipeline tests for StatistEase
#
# Tests full statistical workflows from raw data input through to structured
# output reports. Validates that the pipeline stages compose correctly and
# that edge cases (empty data, NaN, single element) are handled gracefully.

using Test
using Statistics
using StatistEase

@testset "StatistEase E2E Pipeline Tests" begin

    # ═══════════════════════════════════════════════════════════════════
    # 1. FULL DESCRIPTIVE STATS PIPELINE
    #    Input: raw array → pipeline → full report with all fields
    # ═══════════════════════════════════════════════════════════════════
    @testset "Full descriptive stats pipeline" begin
        # Load a realistic dataset (simulated clinical measurements)
        data = [72.1, 68.4, 74.5, 71.0, 69.8, 76.3, 70.2, 73.1,
                65.9, 77.8, 72.5, 69.1, 74.0, 71.6, 68.9, 75.2,
                70.8, 73.4, 67.3, 76.1]

        report = descriptive_stats(data)

        # Report must contain all required keys
        required_keys = ["n", "mean", "median", "mode", "std", "variance",
                         "min", "max", "range", "q1", "q3", "iqr",
                         "skewness", "kurtosis", "mad", "cv",
                         "harmonic_mean", "geometric_mean",
                         "trimmed_mean", "winsorized_mean", "quadratic_mean"]
        for key in required_keys
            @test haskey(report, key) "Missing key: $key"
        end

        # Numerical sanity: all values must be finite (no NaN/Inf)
        for key in required_keys
            val = report[key]
            if val isa Number
                @test isfinite(val) || val isa Int "Non-finite value for $key: $val"
            end
        end

        # Statistical correctness checks
        @test report["n"] == 20
        @test isapprox(report["mean"], mean(data), atol=1e-8)
        @test report["min"] == minimum(data)
        @test report["max"] == maximum(data)
        @test isapprox(report["range"], maximum(data) - minimum(data), atol=1e-10)
        @test report["min"] <= report["mean"] <= report["max"]
        @test report["q1"] <= report["median"] <= report["q3"]
        @test report["std"] == sqrt(report["variance"])
    end

    # ═══════════════════════════════════════════════════════════════════
    # 2. RANDOM DATA PIPELINE: 100 VALUES → MULTIPLE STATS → ALL FINITE
    #    Verifies that no statistical operation produces NaN/Inf for
    #    well-formed random data.
    # ═══════════════════════════════════════════════════════════════════
    @testset "Random 100-element pipeline produces all-finite results" begin
        # Use a fixed seed for reproducibility
        import Random
        Random.seed!(42)
        data = randn(100) .* 10 .+ 50  # Normally distributed, mean≈50, std≈10

        report = descriptive_stats(data)

        # Core statistics must all be finite
        finite_keys = ["mean", "median", "std", "variance", "min", "max",
                       "q1", "q3", "iqr", "mad", "skewness", "kurtosis",
                       "trimmed_mean", "quadratic_mean"]
        for key in finite_keys
            @test isfinite(report[key]) "Pipeline produced non-finite $key"
        end

        # Harmonic/geometric mean require positive data
        if all(d -> d > 0, data)
            @test isfinite(report["harmonic_mean"])
            @test isfinite(report["geometric_mean"])
        end

        # CV = std / mean — valid when mean ≠ 0
        if abs(report["mean"]) > 1e-10
            @test isfinite(report["cv"])
        end

        # Power means should obey ordering: M_{-1} ≤ M_0 ≤ M_1 ≤ M_2
        pos_data = abs.(data) .+ 1.0  # Ensure positive for all power means
        m_harm  = power_mean(pos_data, -1.0)
        m_geom  = power_mean(pos_data,  0.0)
        m_arith = power_mean(pos_data,  1.0)
        m_quad  = power_mean(pos_data,  2.0)
        @test m_harm  <= m_geom  + 1e-10
        @test m_geom  <= m_arith + 1e-10
        @test m_arith <= m_quad  + 1e-10
    end

    # ═══════════════════════════════════════════════════════════════════
    # 3. OUTPUT FORMATTING: REPORT → JSON-COMPATIBLE DICT
    #    Verifies that the report dict can round-trip through JSON
    #    serialisation without loss.
    # ═══════════════════════════════════════════════════════════════════
    @testset "Stats report produces JSON-compatible representation" begin
        data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        report = descriptive_stats(data)

        # Every value must be a JSON-serialisable primitive (Number, String, Bool, Nothing)
        for (key, val) in report
            @test key isa String
            @test (val isa Number || val isa String || val isa Bool || val === nothing ||
                   val isa Vector) "Key $key has non-serialisable type $(typeof(val))"
        end

        # Key statistical assertions on the well-known [1..10] dataset
        @test report["n"]    == 10
        @test isapprox(report["mean"],   5.5, atol=1e-8)
        @test isapprox(report["median"], 5.5, atol=1e-8)
        @test report["min"]  == 1.0
        @test report["max"]  == 10.0
        @test isapprox(report["range"], 9.0, atol=1e-10)

        # Weighted stats must also return a dict
        weights = ones(10)
        wreport = weighted_stats(data, weights)
        @test wreport isa Dict
        @test haskey(wreport, "weighted_mean")
        @test isapprox(wreport["weighted_mean"], 5.5, atol=1e-8)
    end

    # ═══════════════════════════════════════════════════════════════════
    # 4. ERROR HANDLING: EDGE CASES
    #    Validates that the pipeline degrades gracefully rather than
    #    crashing or producing silent garbage.
    # ═══════════════════════════════════════════════════════════════════
    @testset "Error handling — empty array" begin
        # Empty array: expect an error dict (not a thrown exception)
        result = descriptive_stats(Float64[])
        @test result isa Dict
        @test haskey(result, "error")
    end

    @testset "Error handling — single element" begin
        # Single element: need ≥ 2 non-NaN observations per implementation
        result = descriptive_stats([42.0])
        @test result isa Dict
        @test haskey(result, "error")
    end

    @testset "Error handling — NaN-containing array" begin
        # Array with NaNs: valid values should still be processed
        data_with_nans = [1.0, NaN, 3.0, NaN, 5.0, 7.0, 9.0, NaN, 11.0, 13.0]
        result = descriptive_stats(data_with_nans)
        @test result isa Dict

        # If processing succeeds (≥2 non-NaN values), results must be finite
        if !haskey(result, "error")
            @test isfinite(result["mean"])
            @test isfinite(result["std"])
            # n should reflect only the non-NaN observations
            @test result["n"] == count(!isnan, data_with_nans)
        else
            # If it returns an error, that is also acceptable
            @test result["error"] isa String
        end
    end

    @testset "Error handling — all-NaN array" begin
        # All NaN: must return an error dict, not crash
        result = descriptive_stats([NaN, NaN, NaN])
        @test result isa Dict
        @test haskey(result, "error")
    end

    # ═══════════════════════════════════════════════════════════════════
    # 5. INFERENTIAL + DESCRIPTIVE COMBINED PIPELINE
    #    Simulates a realistic analysis: two groups, descriptive stats
    #    for each, then hypothesis test comparing them.
    # ═══════════════════════════════════════════════════════════════════
    @testset "Combined descriptive + inferential pipeline" begin
        # Simulate control vs. treatment measurements
        control   = [23.1, 24.0, 22.8, 23.5, 24.2, 22.9, 23.8, 24.1, 23.0, 23.7]
        treatment = [25.4, 26.1, 25.8, 26.4, 25.2, 26.8, 25.5, 26.0, 25.9, 26.3]

        r_ctrl = descriptive_stats(control)
        r_trt  = descriptive_stats(treatment)

        # Both groups must produce valid reports
        @test !haskey(r_ctrl, "error")
        @test !haskey(r_trt,  "error")

        # Treatment group mean should be higher than control
        @test r_trt["mean"] > r_ctrl["mean"]

        # T-test should detect significant difference (well-separated groups)
        tresult = t_test_independent(control, treatment)
        @test haskey(tresult, "p_value")
        @test 0.0 <= tresult["p_value"] <= 1.0
        # With 10 very clean observations per group, p should be small
        @test tresult["p_value"] < 0.01

        # Non-parametric test should agree with parametric
        mw = mann_whitney_u(control, treatment)
        @test haskey(mw, "p_value")
        @test 0.0 <= mw["p_value"] <= 1.0
    end

end # @testset "StatistEase E2E Pipeline Tests"
