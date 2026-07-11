# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# degenerate_input_test.jl — Degenerate-input guards + @assert -> ArgumentError
#
# Exercises the compute core at the boundary: n=1/2/3 vectors, constant
# vectors, and zero-variance two-group cases. Two invariants are checked:
#
#   1. No NaN/Inf ever leaks into a returned Dict (this would violate the
#      finiteness + JSON-serialisability contract). Degenerate fields must
#      come back as `nothing` (JSON null), not NaN/Inf.
#   2. Validation that used to be a disable-able `@assert` now throws a
#      real, catchable `ArgumentError`.

using Test
using Statistics
using Statistikles

# ── Helper: recursive "no NaN/Inf, JSON-serialisable" walk ──────────────────
# Generalises the flat walk in e2e_test.jl (§3 "Stats report produces
# JSON-compatible representation") to nested Dict/Vector/Matrix structures,
# since e.g. multiple_regression nests a Dict inside "coefficients".
function assert_finite_and_serialisable(val, path::String="root")
    if val isa Dict
        for (k, v) in val
            @test k isa String
            assert_finite_and_serialisable(v, "$path.$k")
        end
    elseif val isa AbstractArray
        for (i, v) in enumerate(val)
            assert_finite_and_serialisable(v, "$path[$i]")
        end
    elseif val isa AbstractFloat
        @test isfinite(val)
    elseif val isa Number || val isa String || val isa Bool || val === nothing || val isa Symbol
        # OK: JSON-serialisable primitive, nothing further to check.
        @test true
    else
        @test false  # non-serialisable / unexpected type at $path
    end
end

@testset "Degenerate Input Guards" begin

    # ═══════════════════════════════════════════════════════════════════
    # DESCRIPTIVE STATS — skewness n>=3, kurtosis n>=4, mean-zero cv,
    # zero/negative harmonic & geometric means, reciprocal cancellation
    # ═══════════════════════════════════════════════════════════════════
    @testset "descriptive_stats: n=2 (below skewness/kurtosis minimum)" begin
        r = descriptive_stats([1.0, 3.0])
        @test r["n"] == 2
        @test r["skewness"] === nothing
        @test r["kurtosis"] === nothing
        @test r["skewness_note"] !== nothing
        @test r["kurtosis_note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "descriptive_stats: n=3 (skewness OK, kurtosis still undefined)" begin
        r = descriptive_stats([1.0, 2.0, 4.0])
        @test r["n"] == 3
        @test r["skewness"] !== nothing
        @test r["kurtosis"] === nothing
        assert_finite_and_serialisable(r)
    end

    @testset "descriptive_stats: n=4 (both skewness and kurtosis defined)" begin
        r = descriptive_stats([1.0, 2.0, 4.0, 7.0])
        @test r["n"] == 4
        @test r["skewness"] !== nothing
        @test r["kurtosis"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "descriptive_stats: constant vector (zero variance)" begin
        r = descriptive_stats(fill(5.0, 6))
        @test r["variance"] == 0.0
        @test r["skewness"] == 0.0  # existing convention: 0.0, not NaN
        @test r["kurtosis"] == 0.0
        assert_finite_and_serialisable(r)
    end

    @testset "descriptive_stats: data containing zero (harmonic/geometric undefined)" begin
        r = descriptive_stats([0.0, 1.0, 2.0, 3.0])
        @test r["harmonic_mean"] === nothing
        @test r["harmonic_mean_note"] !== nothing
        @test r["geometric_mean"] === nothing  # 0.0 is also non-positive
        assert_finite_and_serialisable(r)
    end

    @testset "descriptive_stats: negative value (geometric undefined only)" begin
        r = descriptive_stats([-1.0, 1.0, 2.0, 3.0])
        @test r["geometric_mean"] === nothing
        @test r["geometric_mean_note"] !== nothing
        @test r["harmonic_mean"] !== nothing  # no exact zero, reciprocals don't cancel
        assert_finite_and_serialisable(r)
    end

    @testset "descriptive_stats: reciprocals cancel to zero (harmonic mean undefined)" begin
        # sum(1/x) = -0.5 - 1.0 + 1.0 + 0.5 = 0.0 exactly -> would leak Inf
        r = descriptive_stats([-2.0, -1.0, 1.0, 2.0])
        @test r["harmonic_mean"] === nothing
        @test r["harmonic_mean_note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "descriptive_stats: mean-zero data (cv undefined)" begin
        r = descriptive_stats([-2.0, -1.0, 1.0, 2.0])
        @test r["mean"] == 0.0
        @test r["cv"] === nothing
        @test r["cv_note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "descriptive_stats: n=1 still returns the pre-existing error dict" begin
        r = descriptive_stats([42.0])
        @test haskey(r, "error")
    end

    @testset "weighted_stats: mismatched lengths throw ArgumentError" begin
        @test_throws ArgumentError weighted_stats([1.0, 2.0], [1.0])
    end

    # ═══════════════════════════════════════════════════════════════════
    # CORRELATIONS — n=0/1, zero-variance, perfect correlation
    # ═══════════════════════════════════════════════════════════════════
    @testset "pearson_correlation: n=0/1 return null fields, not NaN" begin
        for data in (Float64[], [1.0])
            r = pearson_correlation(data, data)
            @test r["r"] === nothing
            @test r["note"] !== nothing
            assert_finite_and_serialisable(r)
        end
    end

    @testset "pearson_correlation: constant x (zero denominator)" begin
        r = pearson_correlation(fill(3.0, 5), [1.0, 2.0, 3.0, 4.0, 5.0])
        @test r["r"] === nothing
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "pearson_correlation: perfect correlation (r²=1) nulls the t-test" begin
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        r = pearson_correlation(x, 2.0 .* x)
        @test isapprox(r["r"], 1.0, atol=1e-10)
        @test r["t_stat"] === nothing
        @test r["p_value"] === nothing
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "pearson_correlation: mismatched lengths throw ArgumentError" begin
        @test_throws ArgumentError pearson_correlation([1.0, 2.0], [1.0])
    end

    @testset "spearman_correlation: n=0/1 no longer crash" begin
        for data in (Float64[], [1.0])
            r = spearman_correlation(data, data)
            @test r["rho"] === nothing
            @test r["note"] !== nothing
            assert_finite_and_serialisable(r)
        end
    end

    @testset "spearman_correlation: mismatched lengths throw ArgumentError" begin
        @test_throws ArgumentError spearman_correlation([1.0, 2.0], [1.0])
    end

    @testset "partial_correlation: n<4 returns null fields" begin
        r = partial_correlation([1.0, 2.0, 3.0], [2.0, 3.0, 4.0], [1.0, 1.0, 2.0])
        @test r["r_partial"] === nothing
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "partial_correlation: constant x, n>=4 (zero variance, not the n<4 path)" begin
        # Statistics.cor() returns NaN (not an error) on a zero-variance
        # vector; this must not leak into r_xy/r_xz/r_yz.
        r = partial_correlation(fill(2.0, 5), [1.0, 2.0, 3.0, 4.0, 5.0], [2.0, 1.0, 4.0, 3.0, 5.0])
        @test r["r_xy"] === nothing
        @test r["r_xz"] === nothing
        @test r["r_partial"] === nothing
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "partial_correlation: mismatched lengths throw ArgumentError" begin
        @test_throws ArgumentError partial_correlation(
            [1.0, 2.0, 3.0, 4.0], [1.0, 2.0], [1.0, 2.0, 3.0, 4.0])
    end

    # ═══════════════════════════════════════════════════════════════════
    # REGRESSION — zero-variance x/y, insufficient residual df
    # ═══════════════════════════════════════════════════════════════════
    @testset "simple_linear_regression: constant x (undefined slope)" begin
        r = simple_linear_regression(fill(2.0, 5), [1.0, 2.0, 3.0, 4.0, 5.0])
        @test r["slope"] === nothing
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "simple_linear_regression: constant y (undefined R²)" begin
        r = simple_linear_regression([1.0, 2.0, 3.0, 4.0, 5.0], fill(7.0, 5))
        @test r["r_squared"] === nothing
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "simple_linear_regression: mismatched lengths throw ArgumentError" begin
        @test_throws ArgumentError simple_linear_regression([1.0, 2.0], [1.0])
    end

    @testset "multiple_regression: constant y (undefined R² and standard errors)" begin
        X = [1.0 2.0; 2.0 1.0; 3.0 4.0; 4.0 3.0; 5.0 5.0]
        y = fill(9.0, 5)
        r = multiple_regression(X, y)
        @test r["r_squared"] === nothing
        @test all(v === nothing for v in values(r["std_errors"]))
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "multiple_regression: insufficient residual df (n <= p + 1)" begin
        X = [1.0 1.0; 2.0 4.0; 3.0 2.0]  # n=3, p=2 => df_resid = 0
        y = [3.0, 5.0, 7.0]
        r = multiple_regression(X, y)
        @test all(v === nothing for v in values(r["std_errors"]))
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "multiple_regression: mismatched y length throws ArgumentError" begin
        X = [1.0 2.0; 2.0 1.0; 3.0 4.0]
        @test_throws ArgumentError multiple_regression(X, [1.0, 2.0])
    end

    # ═══════════════════════════════════════════════════════════════════
    # T-TESTS & ANOVA — n<2 per group, zero-variance groups
    # ═══════════════════════════════════════════════════════════════════
    @testset "t_test_independent: n<2 per group returns null fields" begin
        r = t_test_independent([1.0], [2.0, 3.0, 4.0])
        @test r["t_stat"] === nothing
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "t_test_independent: zero-variance groups, unequal means" begin
        r = t_test_independent(fill(1.0, 5), fill(2.0, 5))
        @test r["t_stat"] === nothing
        @test r["cohens_d"] == 0.0
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "t_test_independent: zero-variance groups, equal means" begin
        r = t_test_independent(fill(1.0, 5), fill(1.0, 5))
        @test r["t_stat"] === nothing
        assert_finite_and_serialisable(r)
    end

    @testset "one_way_anova: perfect separation, zero within-group variance" begin
        r = one_way_anova([fill(1.0, 4), fill(5.0, 4)])
        @test r["F_statistic"] === nothing
        @test r["p_value"] == 0.0
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "one_way_anova: identical constant groups (ms_within==0 and ss_between==0)" begin
        r = one_way_anova([fill(3.0, 4), fill(3.0, 4)])
        @test r["F_statistic"] == 0.0
        @test r["p_value"] == 1.0
        @test r["note"] === nothing
        assert_finite_and_serialisable(r)
    end

    # ═══════════════════════════════════════════════════════════════════
    # NORMALITY TEST — duplicated skewness/kurtosis formula (assumptions.jl),
    # reachable via the executor tool layer.
    # ═══════════════════════════════════════════════════════════════════
    @testset "test_normality: n<4 returns null fields, not a crash" begin
        r = Statistikles.test_normality([1.0, 2.0, 3.0])
        @test r["skewness"] === nothing
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "test_normality: constant data (zero variance)" begin
        r = Statistikles.test_normality(fill(4.0, 10))
        @test r["skewness"] === nothing
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    # ═══════════════════════════════════════════════════════════════════
    # CONVERTED @assert -> ArgumentError SITES (full grep sweep of src/)
    # ═══════════════════════════════════════════════════════════════════
    @testset "Converted validations throw ArgumentError, not AssertionError" begin
        @test_throws ArgumentError kl_divergence([0.5, 0.5], [1.0])
        @test_throws ArgumentError centered_log_ratio([0.5, -0.1, 0.6])
        @test_throws ArgumentError centered_log_ratio([0.5, 0.0, 0.5])
        @test_throws ArgumentError Probability(-0.1)
        @test_throws ArgumentError Probability(1.5)
        @test_throws ArgumentError ImpreciseProbability(-0.1, 0.5)
        @test_throws ArgumentError ImpreciseProbability(0.5, 1.5)
        @test_throws ArgumentError (ModularInt(1, 5) + ModularInt(1, 7))
        @test_throws ArgumentError (ModularInt(1, 5) * ModularInt(1, 7))
        @test_throws ArgumentError tropical_matrix_multiply([1.0 2.0; 3.0 4.0], [1.0 2.0 3.0])
        @test_throws ArgumentError tropical_eigenvalue([1.0 2.0 3.0; 4.0 5.0 6.0])
        @test_throws ArgumentError bell_test_chsh([1.0, 2.0, 3.0])
        @test_throws ArgumentError stuart_maxwell_test([1 2 3; 4 5 6])
        @test_throws ArgumentError permanova([0.0 1.0; 1.0 0.0], ["A", "B", "C"])
        @test_throws ArgumentError permanova(
            [0.0 1.0 2.0; 1.0 0.0 1.0; 2.0 1.0 0.0], ["A", "A", "A"])
        @test_throws ArgumentError permanova_multi(
            [0.0 1.0; 1.0 0.0], Tuple{String,Vector}[("group", ["A", "B", "C"])])
        @test_throws ArgumentError bland_altman([1.0, 2.0], [1.0])
        @test_throws ArgumentError morans_i(
            [1.0, 2.0], [1.0 2.0 3.0; 4.0 5.0 6.0; 7.0 8.0 9.0])
        @test_throws ArgumentError kaplan_meier([1.0, 2.0], [true])
        @test_throws ArgumentError log_rank_test(
            [1.0, 2.0, 3.0], [true, false, true], ["A", "B", "C"])
        @test_throws ArgumentError meta_analysis([0.5, 0.3], [0.1])
        @test_throws ArgumentError smt_verify_correction_monotone([0.1, 0.2], [0.1])
    end

end # @testset "Degenerate Input Guards"
