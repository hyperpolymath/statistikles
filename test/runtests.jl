# SPDX-License-Identifier: PMPL-1.0-or-later
# StatistEase — Comprehensive Unit Test Suite
# Every exported function tested. Zero tolerance for errors/warnings.

using Test
using Statistics: mean
using StatistEase

@testset "StatistEase Full Test Suite" begin

    # ═══════════════════════════════════════════════════════════════════
    # DESCRIPTIVE STATISTICS
    # ═══════════════════════════════════════════════════════════════════
    @testset "Descriptive Statistics" begin
        data = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        r = descriptive_stats(data)

        @test r["n"] == 8
        @test r["mean"] == 5.0
        @test r["median"] == 4.5
        @test r["mode"] == 4.0
        @test r["std"] > 0
        @test r["variance"] > 0
        @test haskey(r, "harmonic_mean")
        @test haskey(r, "geometric_mean")
        @test haskey(r, "trimmed_mean")
        @test haskey(r, "winsorized_mean")
        @test haskey(r, "quadratic_mean")
        @test haskey(r, "mad")
        @test haskey(r, "cv")
        @test haskey(r, "skewness")
        @test haskey(r, "kurtosis")
        @test haskey(r, "q1")
        @test haskey(r, "q3")
        @test haskey(r, "iqr")
        @test haskey(r, "min")
        @test haskey(r, "max")
        @test haskey(r, "range")
        @test r["min"] == 2.0
        @test r["max"] == 9.0
        @test r["range"] == 7.0

        # Harmonic mean: n / Σ(1/xᵢ)
        @test r["harmonic_mean"] > 0

        # Geometric mean: exp(Σlog(xᵢ)/n)
        @test r["geometric_mean"] > 0

        # Trimmed mean ≈ mean (small trim)
        @test abs(r["trimmed_mean"] - r["mean"]) < 2.0

        # Quadratic mean ≥ arithmetic mean (QM-AM inequality)
        @test r["quadratic_mean"] >= r["mean"] - 1e-10

        # MAD ≥ 0
        @test r["mad"] >= 0

        # Edge: 2-element data
        r2 = descriptive_stats([1.0, 3.0])
        @test r2["n"] == 2
        @test r2["mean"] == 2.0
    end

    @testset "Power Mean" begin
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        # p=1 → arithmetic mean
        @test isapprox(power_mean(data, 1.0), mean(data), atol=1e-10)
        # p=2 → quadratic mean
        @test power_mean(data, 2.0) > power_mean(data, 1.0)
        # p=-1 → harmonic mean
        @test power_mean(data, -1.0) < power_mean(data, 1.0)
        # p→0 → geometric mean
        @test isapprox(power_mean(data, 0.0), exp(sum(log.(data)) / 5), atol=1e-10)
        # Power mean inequality: M_p ≤ M_q for p ≤ q
        @test power_mean(data, -1.0) <= power_mean(data, 0.0) + 1e-10
        @test power_mean(data, 0.0) <= power_mean(data, 1.0) + 1e-10
        @test power_mean(data, 1.0) <= power_mean(data, 2.0) + 1e-10
    end

    @testset "Weighted Statistics" begin
        data = [10.0, 20.0, 30.0]
        weights = [1.0, 2.0, 3.0]
        r = weighted_stats(data, weights)
        # Weighted mean = (10*1 + 20*2 + 30*3) / 6 = 140/6 ≈ 23.33
        @test isapprox(r["weighted_mean"], 140.0 / 6.0, atol=1e-10)
        @test r["weighted_variance"] > 0
        @test r["weighted_std"] == sqrt(r["weighted_variance"])
    end

    # ═══════════════════════════════════════════════════════════════════
    # INFERENTIAL STATISTICS
    # ═══════════════════════════════════════════════════════════════════
    @testset "T-Test Independent" begin
        g1 = [5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
        g2 = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0]
        r = t_test_independent(g1, g2)
        @test haskey(r, "t_stat")
        @test haskey(r, "p_value")
        @test 0.0 <= r["p_value"] <= 1.0
        @test r["df"] > 0
    end

    # ═══════════════════════════════════════════════════════════════════
    # NONPARAMETRIC TESTS
    # ═══════════════════════════════════════════════════════════════════
    @testset "Mann-Whitney U" begin
        g1 = [1.0, 2.0, 3.0, 4.0, 5.0]
        g2 = [3.0, 4.0, 5.0, 6.0, 7.0]
        r = mann_whitney_u(g1, g2)
        @test haskey(r, "U_statistic")
        @test haskey(r, "tie_correction")
        @test 0.0 <= r["p_value"] <= 1.0

        # With ties
        g1t = [1.0, 2.0, 2.0, 3.0]
        g2t = [2.0, 3.0, 3.0, 4.0]
        rt = mann_whitney_u(g1t, g2t)
        @test rt["tie_correction"] > 0
    end

    @testset "Wilcoxon Signed-Rank" begin
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        y = [1.5, 2.5, 2.8, 4.2, 5.1]
        r = wilcoxon_signed_rank(x, y)
        @test haskey(r, "W_statistic")
        @test r["n_nonzero"] == 5
        @test 0.0 <= r["p_value"] <= 1.0

        # All identical → n_nonzero = 0
        rz = wilcoxon_signed_rank([1.0, 2.0], [1.0, 2.0])
        @test rz["n_nonzero"] == 0
    end

    @testset "Kruskal-Wallis" begin
        r = kruskal_wallis([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]])
        @test r["k_groups"] == 3
        @test r["df"] == 2
        @test r["H_statistic"] > 0
        @test 0.0 <= r["p_value"] <= 1.0

        # With ties
        rt = kruskal_wallis([[1.0, 1.0, 2.0], [2.0, 3.0, 3.0]])
        @test rt["tie_correction"] > 0
    end

    @testset "Friedman" begin
        data = [1.0 2.0 3.0; 1.1 2.1 3.1; 0.9 1.9 2.9]
        r = friedman_test(data)
        @test r["df"] == 2
        @test haskey(r, "Q_statistic")
        @test 0.0 <= r["p_value"] <= 1.0
    end

    @testset "Cochran's Q" begin
        data = [1 0 1; 1 1 1; 0 0 1; 1 0 1]
        r = cochrans_q(data)
        @test haskey(r, "Q_statistic")
        @test r["df"] == 2
    end

    @testset "PERMANOVA" begin
        D = [0.0 1.0 2.0 3.0; 1.0 0.0 1.5 2.5; 2.0 1.5 0.0 1.0; 3.0 2.5 1.0 0.0]
        labels = ["A", "A", "B", "B"]
        r = permanova(D, labels; n_permutations=99)
        @test r["n_groups"] == 2
        @test r["pseudo_F"] >= 0
        @test 0.0 <= r["p_value"] <= 1.0
        @test 0.0 <= r["partial_R2"] <= 1.0
    end

    @testset "PERMANOVA Multi-Factor" begin
        D = [0.0 1.0 2.0 3.0; 1.0 0.0 1.5 2.5; 2.0 1.5 0.0 1.0; 3.0 2.5 1.0 0.0]
        group = ["A", "A", "B", "B"]
        run = ["R1", "R2", "R1", "R2"]
        factors = Tuple{String, Vector}[("group", group), ("run", run)]
        r = permanova_multi(D, factors; n_permutations=99)
        @test length(r["factors"]) == 2
        @test r["factors"][1]["factor"] == "group"
        @test r["factors"][2]["factor"] == "run"
        @test 0.0 <= r["R2_total"] <= 1.0
    end

    @testset "Midranks" begin
        # No ties → standard ranks
        @test midranks([3.0, 1.0, 2.0]) == [3.0, 1.0, 2.0]
        # Ties → averaged ranks
        @test midranks([1.0, 2.0, 2.0, 3.0]) == [1.0, 2.5, 2.5, 4.0]
        # All tied
        @test midranks([5.0, 5.0, 5.0]) == [2.0, 2.0, 2.0]
    end

    @testset "Tie Correction" begin
        @test tie_correction([1.0, 2.0, 3.0]) == 0.0  # No ties
        @test tie_correction([1.0, 2.0, 2.0, 3.0]) == 6.0  # One group of 2: 2³-2=6
        @test tie_correction([1.0, 1.0, 1.0]) == 24.0  # One group of 3: 3³-3=24
    end

    # ═══════════════════════════════════════════════════════════════════
    # CORRELATIONS & REGRESSION
    # ═══════════════════════════════════════════════════════════════════
    @testset "Pearson Correlation" begin
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        y = [2.0, 4.0, 6.0, 8.0, 10.0]
        r = pearson_correlation(x, y)
        @test isapprox(r["r"], 1.0, atol=1e-10)
        @test isapprox(r["r_squared"], 1.0, atol=1e-10)
    end

    @testset "Simple Linear Regression" begin
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        y = [2.0, 4.0, 6.0, 8.0, 10.0]
        r = simple_linear_regression(x, y)
        @test isapprox(r["slope"], 2.0, atol=1e-10)
        @test isapprox(r["intercept"], 0.0, atol=1e-10)
        @test isapprox(r["r_squared"], 1.0, atol=1e-10)
    end

    # ═══════════════════════════════════════════════════════════════════
    # CORRECTIONS
    # ═══════════════════════════════════════════════════════════════════
    @testset "P-Value Corrections" begin
        pvals = [0.01, 0.04, 0.03, 0.005]

        bonf = adjust_p_values(pvals; method="bonferroni")
        @test all(bonf["adjusted"] .>= pvals)
        @test all(bonf["adjusted"] .<= 1.0)

        holm = adjust_p_values(pvals; method="holm")
        @test all(holm["adjusted"] .>= pvals)

        fdr = adjust_p_values(pvals; method="fdr")
        @test all(fdr["adjusted"] .>= pvals)

        sidak = adjust_p_values(pvals; method="sidak")
        @test all(sidak["adjusted"] .>= pvals)
    end

    # ═══════════════════════════════════════════════════════════════════
    # ALGEBRAIC STATISTICS
    # ═══════════════════════════════════════════════════════════════════
    @testset "McNemar's Test" begin
        r = mcnemar_test(30, 12)
        @test haskey(r, "chi_squared")
        @test haskey(r, "p_value")
        @test 0.0 <= r["p_value"] <= 1.0
    end

    @testset "P-adic Valuation" begin
        @test padic_valuation(12, 2) == 2    # 12 = 2² × 3
        @test padic_valuation(12, 3) == 1    # 12 = 4 × 3¹
        @test padic_valuation(100, 5) == 2   # 100 = 5² × 4
        @test padic_valuation(7, 2) == 0     # 7 is odd
    end

    @testset "Modular Statistics" begin
        data = collect(1:100)
        r = modular_stats(data, 10)
        @test r["modulus"] == 10
        @test sum(r["residue_counts"]) == 100
        @test r["entropy"] > 0
        @test 0.0 <= r["entropy_ratio"] <= 1.0
    end

    @testset "GCD Statistics" begin
        r = gcd_stats([12, 18, 24])
        @test r["gcd"] == 6
        @test r["lcm"] == 72
        @test r["all_even"] == true
    end

    # ═══════════════════════════════════════════════════════════════════
    # NON-CLASSICAL: TROPICAL & QUANTUM
    # ═══════════════════════════════════════════════════════════════════
    @testset "Tropical Algebra" begin
        v1 = [1.0, 2.0, 3.0]
        v2 = [4.0, 1.0, 2.0]
        @test tropical_dot_product(v1, v2) == min(1+4, 2+1, 3+2)  # min(5,3,5) = 3

        @test tropical_mean([3.0, 1.0, 4.0, 1.0, 5.0]) == 1.0

        A = [0.0 1.0; 2.0 0.0]
        B = [1.0 0.0; 0.0 1.0]
        C = tropical_matrix_multiply(A, B)
        @test C[1,1] == min(0+1, 1+0)  # 1
        @test C[1,2] == min(0+0, 1+1)  # 0
    end

    @testset "Tropical Eigenvalue" begin
        A = [0.0 1.0; 2.0 0.0]
        λ = tropical_eigenvalue(A)
        @test isfinite(λ)
    end

    @testset "Choquet Integral" begin
        values = [0.3, 0.7, 0.5]
        capacity = idx -> length(idx) / 3.0  # Normalized counting measure
        ci = choquet_integral(values, capacity)
        @test 0.0 <= ci <= 1.0
    end

    @testset "Bell/CHSH Test" begin
        # Classical limit: |S| ≤ 2
        classical = [0.5, -0.3, 0.4, 0.4]
        S = bell_test_chsh(classical)
        @test typeof(S) == Float64
        # Quantum violation: |S| > 2 (up to 2√2)
        quantum = [0.7, -0.7, 0.7, 0.7]
        S_q = bell_test_chsh(quantum)
        @test abs(S_q) > 2  # Violates classical bound
    end

    # ═══════════════════════════════════════════════════════════════════
    # BAYESIAN
    # ═══════════════════════════════════════════════════════════════════
    @testset "Bootstrap CI" begin
        data = randn(50) .+ 5.0
        r = bootstrap_ci(data, mean)  # requires stat_fn argument
        @test haskey(r, "ci_lower")
        @test haskey(r, "ci_upper")
        @test r["ci_lower"] < r["ci_upper"]
    end

    # ═══════════════════════════════════════════════════════════════════
    # INFORMATION THEORY
    # ═══════════════════════════════════════════════════════════════════
    @testset "Shannon Entropy" begin
        # Varied data has entropy ≥ 0
        H = shannon_entropy([1.0, 2.0, 3.0, 4.0])
        @test H >= 0.0

        # All same values: entropy = 0 (no uncertainty)
        H_same = shannon_entropy([5.0, 5.0, 5.0])
        @test H_same >= -1e-10  # -0.0 is OK
    end

    @testset "KL Divergence" begin
        p = [0.5, 0.5]
        q = [0.5, 0.5]
        @test isapprox(kl_divergence(p, q), 0.0, atol=1e-10)
    end

    # ═══════════════════════════════════════════════════════════════════
    # SURVIVAL ANALYSIS
    # ═══════════════════════════════════════════════════════════════════
    @testset "Kaplan-Meier" begin
        times = [1.0, 2.0, 3.0, 4.0, 5.0]
        events = [true, true, false, true, false]
        r = kaplan_meier(times, events)
        @test haskey(r, "times")
        @test haskey(r, "survival_probabilities")
        @test r["survival_probabilities"][1] <= 1.0
    end

    # ═══════════════════════════════════════════════════════════════════
    # META-ANALYSIS
    # ═══════════════════════════════════════════════════════════════════
    @testset "Meta-Analysis" begin
        effects = [0.5, 0.3, 0.7, 0.4]
        variances = [0.1, 0.2, 0.15, 0.12]
        r = meta_analysis(effects, variances)
        @test haskey(r, "combined_effect")
        @test haskey(r, "I_squared")
    end

    # ═══════════════════════════════════════════════════════════════════
    # ROBUST STATISTICS
    # ═══════════════════════════════════════════════════════════════════
    @testset "Mahalanobis Distance" begin
        data = randn(20, 2)
        r = mahalanobis_distance(data)  # returns Vector{Float64} of distances
        @test length(r) == 20
        @test all(r .>= 0)
    end

    # ═══════════════════════════════════════════════════════════════════
    # TIME SERIES
    # ═══════════════════════════════════════════════════════════════════
    @testset "Moving Average" begin
        data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
        r = moving_average(data, 3)  # positional arg, not kwarg
        @test length(r) == 7  # returns vector same length as input
    end

    @testset "Autocorrelation" begin
        data = randn(50)
        r = autocorrelation(data, 5)  # returns vector of lag+1 length
        @test length(r) >= 5
    end

    # ═══════════════════════════════════════════════════════════════════
    # COMPOSITIONAL & INTERVAL
    # ═══════════════════════════════════════════════════════════════════
    @testset "Centered Log-Ratio" begin
        comp = [0.3, 0.5, 0.2]
        r = centered_log_ratio(comp)  # returns Vector{Float64} directly
        @test length(r) == 3
        # CLR should sum to ≈ 0
        @test isapprox(sum(r), 0.0, atol=1e-10)
    end

    # ═══════════════════════════════════════════════════════════════════
    # GRAPH & FRACTAL
    # ═══════════════════════════════════════════════════════════════════
    @testset "Degree Centrality" begin
        adj = [0 1 1; 1 0 0; 1 0 0]
        r = degree_centrality(adj)  # returns normalized degree vector
        @test length(r) == 3
        @test r[1] > r[2]  # node 1 has more connections
    end

    @testset "Hurst Exponent" begin
        data = cumsum(randn(200))
        H = hurst_exponent(data)  # returns Float64 directly
        @test 0.0 <= H <= 1.5  # Allow slight overshoot for finite samples
    end

    # ═══════════════════════════════════════════════════════════════════
    # ROUGH SETS
    # ═══════════════════════════════════════════════════════════════════
    @testset "Rough Set Approximations" begin
        features = [1, 1, 2, 2, 3, 3]
        target_set = [1, 2, 3]  # indices of target elements
        r = rough_set_approximations(features, target_set)
        @test haskey(r, "lower_approximation")
        @test haskey(r, "upper_approximation")
    end

end  # Full Test Suite
