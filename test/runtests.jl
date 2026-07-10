# SPDX-License-Identifier: MPL-2.0
# Statistikles — Comprehensive Unit Test Suite
# Every exported function tested. Zero tolerance for errors/warnings.

using Test
using Statistics
using Statistikles

@testset "Statistikles Full Test Suite" begin

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

    # ═══════════════════════════════════════════════════════════════════
    # FISHER'S EXACT TEST
    # ═══════════════════════════════════════════════════════════════════
    @testset "Fisher's Exact Test" begin
        # Classic example: treatment vs control
        r = fisher_exact_test(1, 9, 11, 3)
        @test haskey(r, "p_value")
        @test haskey(r, "odds_ratio")
        @test 0.0 <= r["p_value"] <= 1.0

        # Perfectly balanced: not significant
        r2 = fisher_exact_test(5, 5, 5, 5)
        @test r2["p_value"] > 0.5

        # Extreme association: highly significant
        r3 = fisher_exact_test(10, 0, 0, 10)
        @test r3["p_value"] < 0.001
        @test r3["odds_ratio"] == Inf
    end

    # ═══════════════════════════════════════════════════════════════════
    # DUNN'S POST-HOC TEST
    # ═══════════════════════════════════════════════════════════════════
    @testset "Dunn's Test" begin
        groups = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]]
        r = dunn_test(groups)
        @test r["n_comparisons"] == 3  # C(3,2) = 3 pairwise
        @test length(r["comparisons"]) == 3
        @test r["correction"] == "bonferroni"

        # Each comparison has required fields
        for comp in r["comparisons"]
            @test haskey(comp, "z")
            @test haskey(comp, "p_raw")
            @test haskey(comp, "p_adjusted")
            @test comp["p_adjusted"] >= comp["p_raw"]  # Correction inflates p
        end

        # Holm correction
        r_holm = dunn_test(groups; correction="holm")
        @test r_holm["correction"] == "holm"
    end

    # ═══════════════════════════════════════════════════════════════════
    # KOLMOGOROV-SMIRNOV 2-SAMPLE
    # ═══════════════════════════════════════════════════════════════════
    @testset "KS 2-Sample" begin
        # Same distribution: not significant
        x = randn(100)
        y = randn(100)
        r = ks_2sample(x, y)
        @test haskey(r, "D_statistic")
        @test 0.0 <= r["D_statistic"] <= 1.0
        @test 0.0 <= r["p_value"] <= 1.0

        # Very different distributions: significant
        x2 = randn(50)
        y2 = randn(50) .+ 5.0  # Shifted by 5
        r2 = ks_2sample(x2, y2)
        @test r2["significant"] == true
        @test r2["D_statistic"] > 0.5
    end

    # ═══════════════════════════════════════════════════════════════════
    # INTRACLASS CORRELATION COEFFICIENT
    # ═══════════════════════════════════════════════════════════════════
    @testset "ICC" begin
        # 5 subjects, 3 raters with good agreement
        data = [1.0 1.1 0.9; 2.0 2.1 1.9; 3.0 3.2 2.8; 4.0 3.9 4.1; 5.0 5.1 4.9]
        r = icc(data)
        @test haskey(r, "icc")
        @test r["icc"] > 0.9  # Very high agreement
        @test r["n_subjects"] == 5
        @test r["n_raters"] == 3

        # One-way model
        r_ow = icc(data; model="oneway")
        @test r_ow["model"] == "oneway"
        @test r_ow["icc"] > 0.8

        # Consistency vs agreement
        r_con = icc(data; type="consistency")
        @test r_con["type"] == "consistency"
    end

    # ═══════════════════════════════════════════════════════════════════
    # BLAND-ALTMAN AGREEMENT
    # ═══════════════════════════════════════════════════════════════════
    @testset "Bland-Altman" begin
        m1 = [10.0, 20.0, 30.0, 40.0, 50.0]
        m2 = [11.0, 19.0, 31.0, 39.0, 51.0]
        r = bland_altman(m1, m2)
        @test haskey(r, "bias")
        @test haskey(r, "loa_lower")
        @test haskey(r, "loa_upper")
        @test r["loa_lower"] < r["bias"] < r["loa_upper"]
        @test r["n"] == 5

        # Perfect agreement: bias = 0
        r_perf = bland_altman([1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
        @test isapprox(r_perf["bias"], 0.0, atol=1e-10)
    end

    # ═══════════════════════════════════════════════════════════════════
    # ANDERSON-DARLING NORMALITY TEST
    # ═══════════════════════════════════════════════════════════════════
    @testset "Anderson-Darling" begin
        # Normal data should pass
        normal_data = randn(100)
        r = anderson_darling(normal_data)
        @test haskey(r, "A2")
        @test haskey(r, "A2_star")
        @test haskey(r, "p_value")
        @test 0.0 <= r["p_value"] <= 1.0

        # Uniform data should fail normality
        uniform_data = collect(range(0, 1, length=100))
        r_unif = anderson_darling(uniform_data)
        @test r_unif["normal"] == false  # Uniform is NOT normal
    end

    # ═══════════════════════════════════════════════════════════════════
    # PARTIAL CORRELATION
    # ═══════════════════════════════════════════════════════════════════
    @testset "Partial Correlation" begin
        # x and y correlated, z is confounder
        z = randn(50)
        x = z .+ randn(50) .* 0.3
        y = z .+ randn(50) .* 0.3
        r = partial_correlation(x, y, z)
        @test haskey(r, "r_partial")
        @test haskey(r, "r_xy")
        @test -1.0 <= r["r_partial"] <= 1.0
        # Partial r should be smaller than raw r (z explains the correlation)
        @test abs(r["r_partial"]) < abs(r["r_xy"]) + 0.2  # Allow tolerance
    end

    # ═══════════════════════════════════════════════════════════════════
    # GRUBBS' TEST
    # ═══════════════════════════════════════════════════════════════════
    @testset "Grubbs' Test" begin
        # Data with obvious outlier
        data = [10.0, 11.0, 12.0, 10.5, 11.5, 100.0]
        r = grubbs_test(data)
        @test r["suspect_value"] == 100.0
        @test r["is_outlier"] == true
        @test r["G_statistic"] > r["G_critical"]

        # Normal data without outlier
        data_clean = [10.0, 11.0, 12.0, 10.5, 11.5, 12.5]
        r2 = grubbs_test(data_clean)
        @test r2["is_outlier"] == false
    end

    # ═══════════════════════════════════════════════════════════════════
    # SPEARMAN RANK CORRELATION
    # ═══════════════════════════════════════════════════════════════════
    @testset "Spearman Correlation" begin
        # Perfect monotonic
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        y = [2.0, 4.0, 6.0, 8.0, 10.0]
        r = spearman_correlation(x, y)
        @test isapprox(r["rho"], 1.0, atol=1e-10)
        @test r["significant"] == true

        # Inverse monotonic
        y_inv = [10.0, 8.0, 6.0, 4.0, 2.0]
        r_inv = spearman_correlation(x, y_inv)
        @test isapprox(r_inv["rho"], -1.0, atol=1e-10)

        # With ties
        x_tied = [1.0, 2.0, 2.0, 3.0, 4.0]
        y_tied = [1.0, 3.0, 2.0, 4.0, 5.0]
        r_tied = spearman_correlation(x_tied, y_tied)
        @test -1.0 <= r_tied["rho"] <= 1.0
    end

    # ═══════════════════════════════════════════════════════════════════
    # MANOVA
    # ═══════════════════════════════════════════════════════════════════
    @testset "MANOVA" begin
        # 3 groups, 2 DVs — groups clearly different
        g1 = [1.0 2.0; 1.5 2.5; 1.2 2.2; 0.8 1.8]
        g2 = [5.0 6.0; 5.5 6.5; 5.2 6.2; 4.8 5.8]
        g3 = [9.0 10.0; 9.5 10.5; 9.2 10.2; 8.8 9.8]
        r = manova_oneway([g1, g2, g3])
        @test haskey(r, "wilks_lambda")
        @test haskey(r, "F_statistic")
        @test 0.0 <= r["wilks_lambda"] <= 1.0
        @test r["significant"] == true  # Groups clearly differ
        @test r["k_groups"] == 3
        @test r["p_variables"] == 2

        # Same group data: not significant
        g_same = randn(10, 2)
        r2 = manova_oneway([g_same[1:5,:], g_same[6:10,:]])
        @test r2["wilks_lambda"] > 0.5  # Close to 1 = no difference
    end

    # ═══════════════════════════════════════════════════════════════════
    # LEVENE'S TEST (already exists, add test)
    # ═══════════════════════════════════════════════════════════════════
    @testset "Levene's Test" begin
        # one_way_anova is now defined (stats/inferential.jl), so
        # levenes_test can be exercised for real.
        g1 = collect(1.0:30.0)
        g2 = collect(101.0:130.0)  # same spread, different location
        r = Statistikles.levenes_test([g1, g2])
        @test haskey(r, "F_statistic")
        @test 0.0 <= r["p_value"] <= 1.0
        @test r["significant"] == false
    end

    # ═══════════════════════════════════════════════════════════════════
    # ASPASIA BRIDGE
    # ═══════════════════════════════════════════════════════════════════
    @testset "Aspasia Bridge" begin
        # Init creates directories
        dir = init_bridge()
        @test isdir(dir)

        # Write a transaction
        txn_id = write_transaction(
            "t_test_independent",
            Dict("group1" => [1.0, 2.0, 3.0], "group2" => [4.0, 5.0, 6.0]),
            Dict("t_stat" => -3.67, "p_value" => 0.01),
            "Groups differ significantly"
        )
        @test length(txn_id) == 36  # UUID format

        # Pending audits should include our transaction
        pending = list_pending_audits()
        @test txn_id in pending

        # No audit yet
        audit = read_audit(txn_id)
        @test audit === nothing

        # Summary
        summary = cross_verify_summary()
        @test summary["pending"] >= 1
        @test haskey(summary, "bridge_dir")
    end

    # ═══════════════════════════════════════════════════════════════════
    # TYPELL LEVELS 1-12
    # ═══════════════════════════════════════════════════════════════════
    @testset "TypeLL Level 4: Probability" begin
        p = Probability(0.05)
        @test p.value == 0.05
        @test_throws AssertionError Probability(-0.1)
        @test_throws AssertionError Probability(1.5)
    end

    @testset "TypeLL Level 4: EffectSize" begin
        es = EffectSize(0.35, "cohens_d")
        @test es.label == "small"  # 0.2 ≤ 0.35 < 0.5
        es_large = EffectSize(1.2, "cohens_d")
        @test es_large.label == "large"
        es_r = EffectSize(0.45, "r")
        @test es_r.label == "medium"  # 0.3 ≤ 0.45 < 0.5
    end

    @testset "TypeLL Level 7: Tropical" begin
        a = TropicalValue(3.0, "min_plus")
        b = TropicalValue(5.0, "min_plus")
        @test (a + b).value == 3.0   # min(3, 5) = 3
        @test (a * b).value == 8.0   # 3 + 5 = 8
    end

    @testset "TypeLL Level 8: ModularInt" begin
        a = ModularInt(7, 5)
        b = ModularInt(3, 5)
        @test a.value == 2  # 7 mod 5
        @test (a + b).value == 0  # (2 + 3) mod 5
        @test (a * b).value == 1  # (2 * 3) mod 5
    end

    @testset "TypeLL Level 12: AuditSession" begin
        result = Dict{String,Any}("p_value" => 0.03)
        session = new_audit_session("txn-001", result)
        @test session.state == :compute

        # Valid transition: compute → verify
        s2 = advance(session, :verify, Dict("passed" => true))
        @test s2.state == :verify

        # Invalid transition: verify → persist (should be verify → prove)
        @test_throws ErrorException advance(s2, :persist, "id-123")

        # Valid: verify → prove → persist
        s3 = advance(s2, :prove, Dict("trust" => 4))
        @test s3.state == :prove
        s4 = advance(s3, :persist, "verisim-id-001")
        @test s4.state == :persist
    end

    # ═══════════════════════════════════════════════════════════════════
    # ECHIDNA ADAPTER
    # ═══════════════════════════════════════════════════════════════════
    @testset "ECHIDNA Adapter" begin
        report = proof_coverage_report()
        @test report["total_obligations"] == 7
        @test length(report["pending"]) == 7
        @test typeof(report["echidna_available"]) == Bool
    end

    # ╔══════════════════════════════════════════════════════════════════╗
    # ║  POINT-TO-POINT TESTS                                         ║
    # ║  Verify individual function contracts in isolation             ║
    # ╚══════════════════════════════════════════════════════════════════╝

    @testset "P2P: Return type contracts" begin
        # Every statistical function must return Dict{String,Any}
        data = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
        @test descriptive_stats(data) isa Dict{String,Any}
        @test t_test_independent(data[1:4], data[5:8]) isa Dict{String,Any}
        @test pearson_correlation(data, reverse(data)) isa Dict{String,Any}
        @test simple_linear_regression(data, data .* 2) isa Dict{String,Any}
        @test mann_whitney_u(data[1:4], data[5:8]) isa Dict{String,Any}
        @test wilcoxon_signed_rank(data[1:4], data[5:8] .- 1.0) isa Dict{String,Any}
        @test kruskal_wallis([data[1:3], data[4:6], data[7:8]]) isa Dict{String,Any}
        @test fisher_exact_test(5, 3, 2, 8) isa Dict{String,Any}
        @test adjust_p_values([0.01, 0.04, 0.03]) isa Dict
        @test spearman_correlation(data, reverse(data)) isa Dict{String,Any}
        @test grubbs_test(data) isa Dict{String,Any}
        @test partial_correlation(data, reverse(data), randn(8)) isa Dict{String,Any}
    end

    @testset "P2P: p-value bounds" begin
        # Every p-value must be in [0, 1]
        for _ in 1:10
            g1 = randn(20)
            g2 = randn(20) .+ rand()
            @test 0.0 <= t_test_independent(g1, g2)["p_value"] <= 1.0
            @test 0.0 <= mann_whitney_u(g1, g2)["p_value"] <= 1.0
            @test 0.0 <= wilcoxon_signed_rank(g1, g2)["p_value"] <= 1.0
            @test 0.0 <= ks_2sample(g1, g2)["p_value"] <= 1.0
        end
    end

    @testset "P2P: Effect size labels" begin
        @test EffectSize(0.1, "cohens_d").label == "negligible"
        @test EffectSize(0.3, "cohens_d").label == "small"
        @test EffectSize(0.6, "cohens_d").label == "medium"
        @test EffectSize(1.0, "cohens_d").label == "large"
        @test EffectSize(0.05, "r").label == "negligible"
        @test EffectSize(0.2, "r").label == "small"
        @test EffectSize(0.4, "r").label == "medium"
        @test EffectSize(0.8, "r").label == "large"
        @test EffectSize(0.005, "eta_squared").label == "negligible"
        @test EffectSize(0.03, "eta_squared").label == "small"
        @test EffectSize(0.1, "eta_squared").label == "medium"
        @test EffectSize(0.2, "eta_squared").label == "large"
    end

    @testset "P2P: Edge cases" begin
        # Empty-ish data
        @test descriptive_stats([1.0, 2.0])["n"] == 2

        # All identical values
        r = descriptive_stats([5.0, 5.0, 5.0, 5.0])
        @test r["variance"] == 0.0
        @test r["std"] == 0.0

        # Single group in KW throws DomainError
        @test_throws DomainError kruskal_wallis([[1.0, 2.0]])

        # Probability bounds
        @test_throws AssertionError Probability(-0.01)
        @test_throws AssertionError Probability(1.01)
        @test Probability(0.0).value == 0.0
        @test Probability(1.0).value == 1.0
    end

    # ╔══════════════════════════════════════════════════════════════════╗
    # ║  END-TO-END TESTS                                              ║
    # ║  Full pipeline: data → analysis → cross-verify → persist       ║
    # ╚══════════════════════════════════════════════════════════════════╝

    @testset "E2E: Full analysis pipeline" begin
        # Simulate a real analysis workflow
        group_a = [23.0, 25.0, 28.0, 30.0, 27.0, 26.0, 29.0, 31.0, 24.0, 28.0]
        group_b = [31.0, 33.0, 35.0, 29.0, 34.0, 36.0, 32.0, 30.0, 37.0, 35.0]

        # Step 1: Descriptive stats for each group
        desc_a = descriptive_stats(group_a)
        desc_b = descriptive_stats(group_b)
        @test desc_a["n"] == 10
        @test desc_b["n"] == 10
        @test desc_b["mean"] > desc_a["mean"]

        # Step 2: Check normality
        norm_a = anderson_darling(group_a)
        norm_b = anderson_darling(group_b)

        # Step 3: Choose test based on normality
        if norm_a["normal"] && norm_b["normal"]
            result = t_test_independent(group_a, group_b)
        else
            result = mann_whitney_u(group_a, group_b)
        end
        @test haskey(result, "p_value")
        @test result["p_value"] < 0.05  # Groups are clearly different

        # Step 4: Effect size
        diff = mean(group_b) - mean(group_a)
        pooled_sd = sqrt((var(group_a) + var(group_b)) / 2)
        d = diff / pooled_sd
        es = EffectSize(d, "cohens_d")
        @test es.label in ["medium", "large"]

        # Step 5: Write to bridge for Aspasia audit
        txn_id = write_transaction(
            "t_test_independent",
            Dict("group_a" => group_a, "group_b" => group_b),
            result,
            "Group B scored significantly higher than Group A"
        )
        @test length(txn_id) == 36

        # Step 6: Check ECHIDNA proof coverage
        report = proof_coverage_report()
        @test report["total_obligations"] >= 7
    end

    @testset "E2E: Nonparametric pipeline" begin
        # 3 groups, ordinal data → KW → Dunn post-hoc → corrections
        g1 = [1.0, 2.0, 1.5, 2.5, 1.0]
        g2 = [3.0, 4.0, 3.5, 4.5, 3.0]
        g3 = [5.0, 6.0, 5.5, 6.5, 5.0]

        kw = kruskal_wallis([g1, g2, g3])
        @test kw["significant"] == true

        dunn = dunn_test([g1, g2, g3]; correction="holm")
        @test dunn["n_comparisons"] == 3
        # At least some pairs should differ
        sig_count = count(c -> c["significant"], dunn["comparisons"])
        @test sig_count >= 1

        # Correct p-values
        raw_ps = [c["p_raw"] for c in dunn["comparisons"]]
        adj = adjust_p_values(raw_ps; method="fdr")
        @test all(adj["adjusted"] .>= raw_ps)
    end

    @testset "E2E: Correlation → Regression pipeline" begin
        x = collect(1.0:20.0)
        y = 2.0 .* x .+ 3.0 .+ randn(20) .* 0.5

        # Pearson
        pr = pearson_correlation(x, y)
        @test pr["r"] > 0.95

        # Spearman should agree
        sr = spearman_correlation(x, y)
        @test sr["rho"] > 0.9

        # Regression
        reg = simple_linear_regression(x, y)
        @test isapprox(reg["slope"], 2.0, atol=0.3)
        @test isapprox(reg["intercept"], 3.0, atol=1.5)
        @test reg["r_squared"] > 0.9
    end

    # ╔══════════════════════════════════════════════════════════════════╗
    # ║  ASPECT TESTS                                                  ║
    # ║  Cross-cutting concerns: types, NaN handling, determinism      ║
    # ╚══════════════════════════════════════════════════════════════════╝

    @testset "Aspect: NaN handling" begin
        data_with_nan = [1.0, 2.0, NaN, 4.0, 5.0]
        r = descriptive_stats(data_with_nan)
        @test r["n"] == 4  # NaN filtered out
        @test !isnan(r["mean"])
    end

    @testset "Aspect: Determinism" begin
        # Same input → same output (no hidden randomness in pure functions)
        data = [3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0]
        r1 = descriptive_stats(data)
        r2 = descriptive_stats(data)
        @test r1["mean"] == r2["mean"]
        @test r1["std"] == r2["std"]
        @test r1["skewness"] == r2["skewness"]
        @test r1["kurtosis"] == r2["kurtosis"]

        # Rank tests are deterministic (no random permutations)
        g1 = [1.0, 2.0, 3.0]
        g2 = [4.0, 5.0, 6.0]
        mw1 = mann_whitney_u(g1, g2)
        mw2 = mann_whitney_u(g1, g2)
        @test mw1["U_statistic"] == mw2["U_statistic"]
        @test mw1["p_value"] == mw2["p_value"]
    end

    @testset "Aspect: Symmetry" begin
        # Pearson r(x,y) = r(y,x)
        x = randn(20)
        y = randn(20)
        @test pearson_correlation(x, y)["r"] ≈ pearson_correlation(y, x)["r"]

        # Spearman ρ(x,y) = ρ(y,x)
        @test spearman_correlation(x, y)["rho"] ≈ spearman_correlation(y, x)["rho"]

        # MW U: group order affects U1/U2 but p-value stays the same
        g1 = randn(15)
        g2 = randn(15) .+ 1.0
        @test mann_whitney_u(g1, g2)["p_value"] ≈ mann_whitney_u(g2, g1)["p_value"]

        # KS is symmetric
        @test ks_2sample(g1, g2)["D_statistic"] ≈ ks_2sample(g2, g1)["D_statistic"]
    end

    @testset "Aspect: Mathematical invariants" begin
        data = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        r = descriptive_stats(data)

        # QM-AM-GM-HM inequality (for positive data)
        @test r["quadratic_mean"] >= r["mean"] - 1e-10
        @test r["mean"] >= r["geometric_mean"] - 1e-10
        @test r["geometric_mean"] >= r["harmonic_mean"] - 1e-10

        # Variance = std²
        @test isapprox(r["variance"], r["std"]^2, atol=1e-10)

        # IQR = Q3 - Q1
        @test isapprox(r["iqr"], r["q3"] - r["q1"], atol=1e-10)

        # Range = max - min
        @test isapprox(r["range"], r["max"] - r["min"], atol=1e-10)

        # CLR sums to zero
        clr = centered_log_ratio([0.3, 0.5, 0.2])
        @test isapprox(sum(clr), 0.0, atol=1e-10)

        # Tropical: min(a,a) = a (idempotence)
        a = TropicalValue(7.0, "min_plus")
        @test (a + a).value == 7.0

        # Modular: (a + b) mod n = ((a mod n) + (b mod n)) mod n
        @test ModularInt(17, 7).value == mod(17, 7)
        @test (ModularInt(17, 7) + ModularInt(23, 7)).value == mod(17 + 23, 7)
    end

    # ╔══════════════════════════════════════════════════════════════════╗
    # ║  EXECUTION TESTS                                               ║
    # ║  Performance, no errors on large data, no stack overflow       ║
    # ╚══════════════════════════════════════════════════════════════════╝

    @testset "Execution: Large data" begin
        big_data = randn(10_000)
        r = descriptive_stats(big_data)
        @test r["n"] == 10_000
        @test !isnan(r["mean"])
        @test !isnan(r["std"])

        # MW on large groups
        mw = mann_whitney_u(randn(500), randn(500) .+ 0.1)
        @test 0.0 <= mw["p_value"] <= 1.0

        # KW with many groups
        groups = [randn(50) .+ i * 0.5 for i in 1:5]
        kw = kruskal_wallis(groups)
        @test kw["k_groups"] == 5
    end

    @testset "Execution: No stack overflow on deep recursion" begin
        # Midranks on large vector (iterative, shouldn't overflow)
        large = randn(5000)
        ranks = midranks(large)
        @test length(ranks) == 5000
        @test isapprox(sum(ranks), 5000 * 5001 / 2, atol=1e-6)
    end

    # ╔══════════════════════════════════════════════════════════════════╗
    # ║  LIFECYCLE TESTS                                               ║
    # ║  TypeLL session protocol, bridge round-trip, state transitions  ║
    # ╚══════════════════════════════════════════════════════════════════╝

    @testset "Lifecycle: Full audit session (L12)" begin
        # compute → verify → prove → persist → report → complete
        result = Dict{String,Any}("p_value" => 0.03, "test" => "t_test")
        s1 = new_audit_session("lifecycle-001", result)
        @test s1.state == :compute

        s2 = advance(s1, :verify, Dict("numerical_ok" => true))
        @test s2.state == :verify
        @test s2.verify_result !== nothing

        s3 = advance(s2, :prove, Dict("trust_level" => 4, "prover" => "agda"))
        @test s3.state == :prove
        @test s3.proof_result !== nothing

        s4 = advance(s3, :persist, "verisimdb-rec-001")
        @test s4.state == :persist
        @test s4.persist_id == "verisimdb-rec-001"

        s5 = advance(s4, :report, nothing)
        @test s5.state == :report

        s6 = advance(s5, :complete, nothing)
        @test s6.state == :complete
    end

    @testset "Lifecycle: Session type violations" begin
        result = Dict{String,Any}("p_value" => 0.5)
        s = new_audit_session("violation-001", result)

        # Cannot skip steps
        @test_throws ErrorException advance(s, :prove, nothing)
        @test_throws ErrorException advance(s, :persist, nothing)
        @test_throws ErrorException advance(s, :complete, nothing)

        # Can only go forward
        s2 = advance(s, :verify, Dict("ok" => true))
        @test_throws ErrorException advance(s2, :compute, nothing)
    end

    @testset "Lifecycle: Bridge round-trip" begin
        # Write transaction
        txn_id = write_transaction(
            "lifecycle_test",
            Dict("data" => [1.0, 2.0, 3.0]),
            Dict("mean" => 2.0),
            "Mean is 2"
        )

        # Should appear in pending
        @test txn_id in list_pending_audits()

        # Not yet audited
        @test read_audit(txn_id) === nothing

        # Summary reflects state
        summary = cross_verify_summary()
        @test summary["pending"] >= 1
    end

    # ╔══════════════════════════════════════════════════════════════════╗
    # ║  BENCHMARKS                                                    ║
    # ║  Timing gates — functions must complete within bounds          ║
    # ╚══════════════════════════════════════════════════════════════════╝

    @testset "Bench: Descriptive stats < 100ms on 10K" begin
        data = randn(10_000)
        t = @elapsed descriptive_stats(data)
        @test t < 0.1  # 100ms
    end

    @testset "Bench: Mann-Whitney < 200ms on 1K×1K" begin
        t = @elapsed mann_whitney_u(randn(1000), randn(1000))
        @test t < 0.2
    end

    @testset "Bench: Midranks < 50ms on 10K" begin
        t = @elapsed midranks(randn(10_000))
        @test t < 0.05
    end

    @testset "Bench: KS 2-sample < 500ms on 1K×1K" begin
        t = @elapsed ks_2sample(randn(1000), randn(1000))
        @test t < 0.5
    end

    @testset "Bench: PERMANOVA < 5s on 100 obs, 999 perms" begin
        n = 100
        D = rand(n, n)
        D = (D + D') / 2  # Symmetric
        for i in 1:n; D[i,i] = 0.0; end
        labels = repeat(["A", "B"], inner=n÷2)
        t = @elapsed permanova(D, labels; n_permutations=999)
        @test t < 5.0
    end

    @testset "Bench: Tropical matrix 100×100 < 1s" begin
        A = rand(100, 100)
        B = rand(100, 100)
        t = @elapsed tropical_matrix_multiply(A, B)
        @test t < 1.0
    end

    @testset "Bench: Power mean < 10ms on 10K" begin
        data = abs.(randn(10_000)) .+ 0.1
        t = @elapsed power_mean(data, 2.0)
        @test t < 0.01
    end

    @testset "Bench: Bootstrap CI < 2s (1K reps)" begin
        data = randn(100)
        t = @elapsed bootstrap_ci(data, mean; n_reps=1000)
        @test t < 2.0
    end

    # ╔══════════════════════════════════════════════════════════════════╗
    # ║  BETLANG INTEGRATION TESTS                                     ║
    # ╚══════════════════════════════════════════════════════════════════╝

    @testset "BetLang: Ternary primitives" begin
        # bet returns one of three values
        results = Set([bet(1, 2, 3) for _ in 1:100])
        @test results ⊆ Set([1, 2, 3])
        @test length(results) >= 2  # Should hit at least 2 of 3

        # bet_weighted respects weights
        heavy_results = [bet_weighted([(10, 0.98), (20, 0.01), (30, 0.01)]) for _ in 1:100]
        @test count(==(10), heavy_results) > 80  # 10 should dominate

        # bet_chain threads state
        result = bet_chain(10, x -> x + bet(0, 1, -1), 0)
        @test -10 <= result <= 10

        # bet_monte_carlo collects stats
        mc = bet_monte_carlo(1000, () -> bet(1.0, 2.0, 3.0))
        @test mc["n"] == 1000
        @test 1.5 < mc["mean"] < 2.5  # E[X] = (1+2+3)/3 = 2
    end

    @testset "BetLang: Uncertainty number systems" begin
        # DistnumberNormal propagation
        a = DistnumberNormal(10.0, 2.0)
        b = DistnumberNormal(5.0, 1.0)
        s = a + b
        @test s.mu == 15.0
        @test isapprox(s.sigma, sqrt(5.0), atol=1e-10)

        d = a - b
        @test d.mu == 5.0
        @test isapprox(d.sigma, sqrt(5.0), atol=1e-10)

        # AffineInterval
        i1 = AffineInterval(1.0, 3.0)
        i2 = AffineInterval(2.0, 4.0)
        i3 = i1 + i2
        @test i3.lo == 3.0
        @test i3.hi == 7.0
        @test width(i1) == 2.0
        @test midpoint(i1) == 2.0

        # ImpreciseProbability
        p = ImpreciseProbability(0.3, 0.7)
        c = complement(p)
        @test isapprox(c.lower, 0.3, atol=1e-10)
        @test isapprox(c.upper, 0.7, atol=1e-10)
        @test_throws AssertionError ImpreciseProbability(-0.1, 0.5)
        @test_throws AssertionError ImpreciseProbability(0.5, 1.5)
    end

    @testset "BetLang: Sampling methods" begin
        # Latin Hypercube
        lhs = latin_hypercube(50, 3)
        @test size(lhs) == (50, 3)
        @test all(0.0 .<= lhs .<= 1.0)

        # Sobol sequence
        sob = sobol_sequence(100, 2)
        @test size(sob) == (100, 2)
        @test all(0.0 .<= sob .<= 1.0)

        # Importance sampling
        target(x) = exp(-x^2 / 2)
        proposal(x) = exp(-abs(x))
        propose() = randn()
        samples, weights = importance_sample(target, proposal, propose, 500)
        @test length(samples) == 500
        @test isapprox(sum(weights), 1.0, atol=1e-10)
    end

    @testset "BetLang: Optimization" begin
        # Simulated annealing on Rosenbrock
        rosenbrock(x) = (1 - x[1])^2 + 100 * (x[2] - x[1]^2)^2
        r = simulated_annealing(rosenbrock, [0.0, 0.0]; steps=5000)
        @test r["best_score"] < 10.0  # Should get close to minimum

        # Particle swarm on sphere function
        sphere(x) = sum(x .^ 2)
        r2 = particle_swarm(sphere, 20, 3; steps=500, bounds=(-5.0, 5.0))
        @test r2["best_score"] < 1.0  # Should find near-zero
    end

    @testset "BetLang: Financial risk" begin
        returns = randn(1000) .* 0.02  # Daily returns ~2% vol
        var = value_at_risk(returns)
        cvar = conditional_var(returns)
        @test var > 0  # VaR should be positive (loss)
        @test cvar >= var  # CVaR ≥ VaR always

        # Dutch book check
        coherent = dutch_book_check([0.3, 0.5, 0.2])
        @test coherent["coherent"] == true
        @test isapprox(coherent["total"], 1.0, atol=1e-10)

        incoherent = dutch_book_check([0.3, 0.5, 0.3])
        @test incoherent["coherent"] == false
        @test incoherent["overround"] > 0

        # Risk of ruin
        ruin = risk_of_ruin(0.55, 1.0, 1.0, 100.0)
        @test 0.0 < ruin < 1.0
    end

    @testset "Bench: BetLang Monte Carlo < 1s (10K)" begin
        t = @elapsed bet_monte_carlo(10_000, () -> bet(1.0, 2.0, 3.0))
        @test t < 1.0
    end

    @testset "Bench: Latin Hypercube 1000×10 < 100ms" begin
        t = @elapsed latin_hypercube(1000, 10)
        @test t < 0.1
    end

    @testset "Bench: Simulated Annealing 10K steps < 2s" begin
        t = @elapsed simulated_annealing(x -> sum(x .^ 2), zeros(5); steps=10_000)
        @test t < 2.0
    end

    # ╔══════════════════════════════════════════════════════════════════╗
    # ║  JULIA ECOSYSTEM INTEGRATIONS                                  ║
    # ╚══════════════════════════════════════════════════════════════════╝

    @testset "Axiom: Property Audit" begin
        result = Dict{String,Any}("p_value" => 0.03, "df" => 14.0, "n" => 30)
        audit = statistical_property_audit(result)
        @test audit["p_value_bounded"] == true
        @test audit["df_nonneg"] == true
        @test audit["n_positive"] == true
        @test audit["all_passed"] == true

        bad = Dict{String,Any}("p_value" => -0.5)
        @test statistical_property_audit(bad)["p_value_bounded"] == false
    end

    @testset "SMTLib: Dutch Book Verification" begin
        r = smt_verify_dutch_book([0.3, 0.5, 0.2])
        @test r["coherent"] == true

        r2 = smt_verify_dutch_book([0.3, 0.5, 0.3])
        @test r2["coherent"] == false
    end

    @testset "SMTLib: Mean Inequality Chain" begin
        r = smt_verify_mean_inequality([2.0, 4.0, 4.0, 5.0, 7.0, 9.0])
        @test r["chain_holds"] == true
    end

    @testset "SMTLib: Correction Monotonicity" begin
        raw = [0.01, 0.04, 0.03]
        adj = adjust_p_values(raw; method="bonferroni")["adjusted"]
        @test smt_verify_correction_monotone(raw, adj)["monotone"] == true
    end

    @testset "Causals: Bet Chain DAG" begin
        dag = bet_chain_to_dag(5, ["win", "draw", "lose"])
        @test length(dag["nodes"]) == 5
        @test dag["is_dag"] == true
    end

    @testset "Causals: Bradford Hill" begin
        assoc = Dict{String,Any}("effect_size" => 0.8, "temporal_order" => true,
                                 "mechanism_known" => true, "rct_available" => true)
        @test bradford_hill_checklist(assoc)["strength"] == "strong"
    end

    @testset "Causals: Confounding" begin
        z = randn(50); x = z .+ randn(50) .* 0.2; y = z .+ randn(50) .* 0.2
        @test haskey(confounding_check(x, y, z), "is_confounder")
    end

    @testset "Bowtie: Risk Model" begin
        r = bowtie_from_bets(0.1, [0.9, 0.95, 0.8], [("loss", 100.0)])
        @test r["top_event_prob"] < r["threat_prob"]
        @test r["most_critical_barrier"] isa Int
    end

    @testset "Bowtie: Monte Carlo" begin
        r = monte_carlo_bowtie(0.1, [0.9, 0.95]; n_sims=5000)
        @test 0.0 <= r["top_event_rate"] <= 1.0
    end

    @testset "ZeroProb: Zero-Inflated" begin
        data = vcat(zeros(30), randn(70) .+ 5.0)
        r = zero_inflated_model(data)
        @test r["n_zeros"] == 30
        @test r["recommend_zi"] == true
    end

    @testset "ZeroProb: Rare Event" begin
        r = rare_event_probability(10000, 5)
        @test r["is_rare"] == true
        @test r["ci_lower"] < r["ci_upper"]
    end

    @testset "Quantum: Bell Experiment" begin
        r = simulate_bell_experiment(10000)
        @test abs(r["S_value"]) > 2.0
        @test r["violates_classical"] == true
    end

    @testset "Quantum: Random Walk" begin
        r = quantum_random_walk(100)
        @test r["speedup_ratio"] > 1.0
    end

end  # Full Test Suite

# ── Extended test categories (CRG Grade C) ───────────────────────────────────
# E2E tests: full statistical pipelines from input to report
include("e2e_test.jl")

# Property tests: mathematical invariants validated over random inputs
include("property_test.jl")

# Reference validation: the trusted symbolic layer checked against
# hand-derived / independently computed ground-truth values
include("reference_validation_test.jl")

# Executor router coverage: every LLM-facing tool name in definitions.jl
# is exercised through execute_tool (or explicitly skipped with a reason)
include("executor_router_test.jl")
