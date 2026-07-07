# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# property_test.jl — Hand-written property-based tests for StatistEase
#
# Each test exercises a mathematical invariant that must hold for ALL valid
# inputs, validated against 100 randomly-generated datasets. Properties are
# chosen from fundamental statistical identities, not implementation details.
#
# Julia does not have a QuickCheck equivalent in stdlib, so we use explicit
# random loops with @test assertions. Each loop runs 100 independent trials.

using Test
using Statistics
using StatistEase
import Random

# ── Helpers ──────────────────────────────────────────────────────────────────

"""
    rand_array(; min_len=2, max_len=50, scale=10.0) -> Vector{Float64}

Generate a random array of Float64 with length uniform in [min_len, max_len]
and values drawn from N(0, scale).
"""
function rand_array(; min_len=2, max_len=50, scale=10.0)
    n = rand(min_len:max_len)
    randn(n) .* scale
end

"""
    rand_positive_array(; min_len=2, max_len=50) -> Vector{Float64}

Like rand_array but all elements are strictly positive (for harmonic/geometric
mean properties).
"""
function rand_positive_array(; min_len=2, max_len=50)
    abs.(rand_array(; min_len=min_len, max_len=max_len)) .+ 0.01
end

# ── Property Tests ────────────────────────────────────────────────────────────

@testset "StatistEase Property-Based Tests" begin

    # Set a fixed seed so failing trials are reproducible
    Random.seed!(2026)

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 1: Mean of constant array equals that constant
    #   ∀ x ∈ ℝ, n ≥ 2 : mean([x, x, …, x]) = x
    # ═══════════════════════════════════════════════════════════════════
    @testset "Mean of constant array == constant" begin
        for _ in 1:100
            x = randn()
            n = rand(2:50)
            data = fill(x, n)
            r = descriptive_stats(data)
            @test !haskey(r, "error")
            @test isapprox(r["mean"], x, atol=1e-10)
            @test isapprox(r["median"], x, atol=1e-10)
        end
    end

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 2: Variance of constant array equals zero
    #   ∀ x ∈ ℝ, n ≥ 2 : variance([x, x, …, x]) = 0
    # ═══════════════════════════════════════════════════════════════════
    @testset "Variance of constant array == 0" begin
        for _ in 1:100
            x = randn()
            n = rand(2:50)
            data = fill(x, n)
            r = descriptive_stats(data)
            @test !haskey(r, "error")
            # Julia's var() uses Bessel correction (n-1 denominator) but with a
            # constant array every deviation is 0, so variance = 0 regardless.
            @test isapprox(r["variance"], 0.0, atol=1e-10)
            @test isapprox(r["std"],      0.0, atol=1e-10)
        end
    end

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 3: Sorting does not change mean or std
    #   mean(sort(x)) = mean(x) and std(sort(x)) = std(x)
    # ═══════════════════════════════════════════════════════════════════
    @testset "Sort does not change mean or std" begin
        for _ in 1:100
            data = rand_array()
            r_orig   = descriptive_stats(data)
            r_sorted = descriptive_stats(sort(data))
            @test !haskey(r_orig,   "error")
            @test !haskey(r_sorted, "error")
            @test isapprox(r_orig["mean"], r_sorted["mean"], atol=1e-10)
            @test isapprox(r_orig["std"],  r_sorted["std"],  atol=1e-10)
            @test isapprox(r_orig["variance"], r_sorted["variance"], atol=1e-10)
        end
    end

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 4: Weighted average satisfies pooling identity
    #   mean(vcat(a, b)) = (n_a * mean(a) + n_b * mean(b)) / (n_a + n_b)
    # ═══════════════════════════════════════════════════════════════════
    @testset "Concatenated arrays satisfy weighted average identity" begin
        for _ in 1:100
            a = rand_array(min_len=2, max_len=25)
            b = rand_array(min_len=2, max_len=25)
            combined = vcat(a, b)

            n_a = length(a)
            n_b = length(b)
            n_total = n_a + n_b

            r_comb = descriptive_stats(combined)
            @test !haskey(r_comb, "error")

            expected_mean = (n_a * mean(a) + n_b * mean(b)) / n_total
            @test isapprox(r_comb["mean"], expected_mean, atol=1e-8)
        end
    end

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 5: min ≤ mean ≤ max for any non-empty array
    #   This is a fundamental constraint that no rounding error should break.
    # ═══════════════════════════════════════════════════════════════════
    @testset "min <= mean <= max for any non-empty array" begin
        for _ in 1:100
            data = rand_array()
            r = descriptive_stats(data)
            @test !haskey(r, "error")
            @test r["min"] <= r["mean"] + 1e-10
            @test r["mean"] <= r["max"] + 1e-10
        end
    end

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 6: IQR = Q3 - Q1
    #   This is definitional but must hold in the implementation.
    # ═══════════════════════════════════════════════════════════════════
    @testset "IQR == Q3 - Q1" begin
        for _ in 1:100
            data = rand_array()
            r = descriptive_stats(data)
            @test !haskey(r, "error")
            @test isapprox(r["iqr"], r["q3"] - r["q1"], atol=1e-10)
        end
    end

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 7: Quadratic mean ≥ arithmetic mean (QM-AM inequality)
    #   For any array of positive numbers, QM ≥ AM ≥ GM ≥ HM.
    # ═══════════════════════════════════════════════════════════════════
    @testset "Quadratic mean >= arithmetic mean (QM-AM inequality)" begin
        for _ in 1:100
            data = rand_positive_array()  # Must be positive for GM/HM
            r = descriptive_stats(data)
            @test !haskey(r, "error")
            # QM ≥ AM
            @test r["quadratic_mean"] >= r["mean"] - 1e-10
            # AM ≥ HM (only if harmonic_mean is finite and positive)
            if isfinite(r["harmonic_mean"]) && r["harmonic_mean"] > 0
                @test r["mean"] >= r["harmonic_mean"] - 1e-10
            end
        end
    end

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 8: Power mean ordering M_p ≤ M_q for p ≤ q
    #   Tests the power_mean function directly with positive data.
    # ═══════════════════════════════════════════════════════════════════
    @testset "Power mean ordering: M_{-1} <= M_0 <= M_1 <= M_2" begin
        for _ in 1:100
            data = rand_positive_array()
            m_minus1 = power_mean(data, -1.0)  # harmonic
            m_zero   = power_mean(data,  0.0)  # geometric
            m_one    = power_mean(data,  1.0)  # arithmetic
            m_two    = power_mean(data,  2.0)  # quadratic

            @test isfinite(m_minus1) && isfinite(m_zero) && isfinite(m_one) && isfinite(m_two)
            @test m_minus1 <= m_zero  + 1e-10
            @test m_zero   <= m_one   + 1e-10
            @test m_one    <= m_two   + 1e-10
        end
    end

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 9: Scale invariance of CV (coefficient of variation)
    #   CV(k * x) = CV(x) for any positive scalar k.
    # ═══════════════════════════════════════════════════════════════════
    @testset "CV is scale-invariant" begin
        for _ in 1:100
            data = rand_positive_array()  # Positive data ensures positive mean
            k = rand() * 10 + 0.1        # Positive scalar in (0.1, 10.1)
            r_orig   = descriptive_stats(data)
            r_scaled = descriptive_stats(data .* k)
            @test !haskey(r_orig,   "error")
            @test !haskey(r_scaled, "error")
            # CV = std/mean — scaling both by k cancels out
            if abs(r_orig["mean"]) > 1e-10 && abs(r_scaled["mean"]) > 1e-10
                @test isapprox(r_orig["cv"], r_scaled["cv"], atol=1e-8)
            end
        end
    end

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 10: Weighted stats with uniform weights == unweighted stats
    #   weighted_stats(x, ones(n)) should equal descriptive_stats(x) for mean.
    # ═══════════════════════════════════════════════════════════════════
    @testset "Uniform-weighted stats agree with unweighted mean" begin
        for _ in 1:100
            data = rand_array()
            n = length(data)
            weights = ones(n)

            r_unweighted = descriptive_stats(data)
            r_weighted   = weighted_stats(data, weights)

            @test !haskey(r_unweighted, "error")
            @test r_weighted isa Dict
            @test haskey(r_weighted, "weighted_mean")

            @test isapprox(r_weighted["weighted_mean"], r_unweighted["mean"], atol=1e-8)
        end
    end

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 11: Pearson correlation is in [-1, 1]
    # ═══════════════════════════════════════════════════════════════════
    @testset "Pearson correlation is always in [-1, 1]" begin
        for _ in 1:100
            n = rand(5:50)
            x = randn(n)
            y = randn(n)
            r = pearson_correlation(x, y)
            @test r isa Dict || r isa Number
            corr_val = r isa Dict ? r["r"] : r
            @test -1.0 - 1e-10 <= corr_val <= 1.0 + 1e-10
        end
    end

    # ═══════════════════════════════════════════════════════════════════
    # PROPERTY 12: p-values are always in [0, 1]
    #   Applies to t-test and Mann-Whitney U.
    # ═══════════════════════════════════════════════════════════════════
    @testset "p-values are always in [0, 1]" begin
        for _ in 1:100
            n1 = rand(5:25)
            n2 = rand(5:25)
            g1 = randn(n1)
            g2 = randn(n2)

            t_result = t_test_independent(g1, g2)
            @test haskey(t_result, "p_value")
            @test 0.0 <= t_result["p_value"] <= 1.0

            mw_result = mann_whitney_u(g1, g2)
            @test haskey(mw_result, "p_value")
            @test 0.0 <= mw_result["p_value"] <= 1.0
        end
    end

end # @testset "StatistEase Property-Based Tests"
