# SPDX-License-Identifier: PMPL-1.0-or-later
using StatistEase
using Test
using Statistics
using Random
using DataFrames

Random.seed!(42)

@testset "StatistEase.jl" begin
    
    @testset "Descriptive Statistics" begin
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        stats = descriptive_stats(data)
        @test stats["mean"] == 3.0
        @test stats["n"] == 5
        @test stats["harmonic_mean"] ≈ 2.18978102189781
        @test stats["geometric_mean"] ≈ 2.605171084697352
        @test stats["skewness"] ≈ 0.0
    end

    @testset "Inferential Statistics" begin
        g1 = [1.0, 2.0, 3.0]
        g2 = [10.0, 11.0, 12.0]
        tt = t_test_independent(g1, g2)
        @test tt["p_value"] < 0.01
        @test tt["significant"] == true
    end

    @testset "Correlation and Regression" begin
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        y = [2.1, 3.9, 6.1, 8.2, 10.1]
        corr = pearson_correlation(x, y)
        @test corr["r"] > 0.99
        
        reg = simple_linear_regression(x, y)
        @test reg["slope"] ≈ 2.0 atol=0.1
        
        # Logistic Regression
        X = [1.0; 2.0; 10.0; 11.0;;]
        y_log = [0.0, 0.0, 1.0, 1.0]
        log_reg = logistic_regression(X, y_log)
        @test length(log_reg["coefficients"]) == 2
    end

    @testset "Estimation" begin
        data = randn(100) .+ 5.0
        fit = mle_fit(data, "normal")
        @test fit["mu"] ≈ 5.0 atol=0.5
    end

    @testset "Complexity" begin
        # Test sorting complexity (should be O(n log n))
        res = estimate_complexity(sort, n -> rand(n), n_range=[100, 200, 400])
        @test haskey(res, "complexity_class")
        @test res["empirical_exponent"] > 0.1
    end

    @testset "Corrections" begin
        p_vals = [0.01, 0.04, 0.05, 0.1]
        adj = adjust_p_values(p_vals, method="bonferroni")
        @test adj["adjusted"] == [0.04, 0.16, 0.2, 0.4]
        
        adj_holm = adjust_p_values(p_vals, method="holm")
        @test adj_holm["adjusted"][1] == 0.04 # 0.01 * 4
    end

    @testset "Path Analysis (SEM)" begin
        # Simulate simple mediation model: X -> M -> Y
        n = 100
        X = randn(n)
        M = 0.5 .* X .+ randn(n) .* 0.1
        Y = 0.7 .* M .+ randn(n) .* 0.1
        
        df = DataFrame(X=X, M=M, Y=Y)
        spec = [:M => [:X], :Y => [:M]]
        
        res = path_analysis(df, spec)
        @test haskey(res, "path_coefficients")
        @test res["path_coefficients"]["X -> M"] ≈ 0.5 atol=0.1
        @test res["path_coefficients"]["M -> Y"] ≈ 0.7 atol=0.1
        @test haskey(res, "fit_indices")
    end

    @testset "Multivariate (PCA)" begin
        X = [1.0 2.0; 2.0 1.0; 1.1 2.1; 1.9 0.9]
        res = pca(X)
        @test res["n_components"] == 2
        @test res["explained_variance_ratio"][1] > 0.8
    end

    @testset "Resampling (Bootstrap)" begin
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        res = bootstrap_ci(data, mean, n_reps=100)
        @test res["ci_lower"] < 3.0
        @test res["ci_upper"] > 3.0
    end

    @testset "Time Series" begin
        data = [1.0, 2.0, 3.0, 4.0, 5.0]
        ma = moving_average(data, 2)
        @test isnan(ma[1])
        @test ma[2] == 1.5
        
        acf = autocorrelation(data, 1)
        @test acf[1] ≈ 1.0
    end

    @testset "Information Theory" begin
        data = ["A", "A", "B", "B"]
        ent = shannon_entropy(data)
        @test ent ≈ 1.0 # 1 bit
        
        p = [0.5, 0.5]
        q = [0.1, 0.9]
        kl = kl_divergence(p, q)
        @test kl > 0
    end

    @testset "Survival Analysis" begin
        times = [1.0, 2.0, 3.0]
        events = [true, false, true]
        res = kaplan_meier(times, events)
        @test res["survival_probabilities"][1] ≈ 0.666 atol=0.01
    end

    @testset "Meta-Analysis" begin
        es = [0.5, 0.6, 0.4]
        vars = [0.01, 0.01, 0.01]
        res = meta_analysis(es, vars, model="fixed")
        @test res["combined_effect"] ≈ 0.5
    end

    @testset "Non-parametric (Expanded)" begin
        # Friedman test
        data = [1.0 2.0 3.0; 1.1 2.1 3.1; 0.9 1.9 2.9]
        res = friedman_test(data)
        @test res["df"] == 2
        @test haskey(res, "Q_statistic")

        # Cochran's Q
        binary_data = [1 0 1; 1 1 1; 0 0 1; 1 0 1]
        res_q = cochrans_q(binary_data)
        @test haskey(res_q, "Q_statistic")

        # Mann-Whitney U (with ties)
        g1 = [1.0, 2.0, 3.0, 4.0, 5.0]
        g2 = [3.0, 4.0, 5.0, 6.0, 7.0]
        mw = mann_whitney_u(g1, g2)
        @test haskey(mw, "U_statistic")
        @test haskey(mw, "tie_correction")
        @test mw["n1"] == 5
        @test mw["n2"] == 5
        @test 0.0 <= mw["p_value"] <= 1.0

        # Mann-Whitney with known ties
        g1_tied = [1.0, 2.0, 2.0, 3.0]
        g2_tied = [2.0, 3.0, 3.0, 4.0]
        mw_tied = mann_whitney_u(g1_tied, g2_tied)
        @test mw_tied["tie_correction"] > 0  # Should detect ties

        # Wilcoxon signed-rank (paired)
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        y = [1.5, 2.5, 2.8, 4.2, 5.1]
        ws = wilcoxon_signed_rank(x, y)
        @test haskey(ws, "W_statistic")
        @test haskey(ws, "tie_correction")
        @test ws["n_nonzero"] == 5
        @test 0.0 <= ws["p_value"] <= 1.0

        # Wilcoxon with identical pairs (all zeros)
        ws_zero = wilcoxon_signed_rank([1.0, 2.0], [1.0, 2.0])
        @test ws_zero["n_nonzero"] == 0
        @test ws_zero["p_value"] == 1.0

        # Kruskal-Wallis
        kw = kruskal_wallis([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]])
        @test haskey(kw, "H_statistic")
        @test haskey(kw, "tie_correction")
        @test kw["k_groups"] == 3
        @test kw["N_total"] == 9
        @test kw["df"] == 2
        @test 0.0 <= kw["p_value"] <= 1.0

        # KW with ties
        kw_tied = kruskal_wallis([[1.0, 1.0, 2.0], [2.0, 3.0, 3.0]])
        @test kw_tied["tie_correction"] > 0

        # PERMANOVA (single-factor)
        D = [0.0 1.0 2.0 3.0; 1.0 0.0 1.5 2.5; 2.0 1.5 0.0 1.0; 3.0 2.5 1.0 0.0]
        labels = ["A", "A", "B", "B"]
        perm = permanova(D, labels; n_permutations=99)
        @test haskey(perm, "pseudo_F")
        @test haskey(perm, "partial_R2")
        @test perm["n_groups"] == 2
        @test perm["N_total"] == 4
        @test 0.0 <= perm["p_value"] <= 1.0

        # PERMANOVA multi-factor (like adonis2 ~ group + run)
        D2 = [0.0 1.0 2.0 3.0; 1.0 0.0 1.5 2.5; 2.0 1.5 0.0 1.0; 3.0 2.5 1.0 0.0]
        group = ["A", "A", "B", "B"]
        run = ["R1", "R2", "R1", "R2"]
        pm = permanova_multi(D2, [("group", group), ("run", run)]; n_permutations=99)
        @test haskey(pm, "factors")
        @test length(pm["factors"]) == 2
        @test pm["factors"][1]["factor"] == "group"
        @test pm["factors"][2]["factor"] == "run"
        @test 0.0 <= pm["R2_total"] <= 1.0
    end

    @testset "Robust Statistics" begin
        data = [1.0, 2.0, 3.0, 100.0] # 100 is an outlier
        h_est = huber_m_estimator(data)
        @test h_est < mean(data) # Huber should be closer to median
        
        X = [1.0 2.0; 2.0 1.0; 1.1 2.1]
        dist = mahalanobis_distance(X)
        @test length(dist) == 3
    end

    @testset "Causal Inference (Econometrics)" begin
        y = [1.0, 2.0, 3.0, 4.0]
        treat = [0, 0, 1, 1]
        post = [0, 1, 0, 1]
        res = difference_in_differences(y, treat, post)
        @test haskey(res, "did_estimate")
    end

    @testset "Spatial Statistics" begin
        x = [1.0, 2.0, 3.0]
        W = [0.0 1.0 0.0; 1.0 0.0 1.0; 0.0 1.0 0.0]
        res = morans_i(x, W)
        @test haskey(res, "morans_i")
    end

    @testset "Machine Learning" begin
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        y = [1.1, 3.9, 9.2, 16.1, 24.9] # Quadratic
        res = spline_regression(x, y, n_knots=1)
        @test length(res["coefficients"]) > 2
    end

    @testset "Algebraic Statistics" begin
        @test padic_valuation(20, 2) == 2 # 2^2 * 5
        res = mcnemar_test(10, 5)
        @test haskey(res, "p_value")
    end

    @testset "Compositional & Intervals" begin
        data = [0.2, 0.3, 0.5]
        clr = centered_log_ratio(data)
        @test sum(clr) ≈ 0.0 atol=1e-10
        
        res = interval_overlap_test((1.0, 5.0), (4.0, 10.0))
        @test res["overlap_width"] == 1.0
    end

    @testset "Non-Classical Probability" begin
        v1 = [1.0, 5.0]
        v2 = [2.0, 0.0]
        @test tropical_dot_product(v1, v2) == 3.0 # min(1+2, 5+0)
        
        bell = bell_test_chsh([0.5, 0.5, 0.5, 0.5])
        @test bell == 1.0
    end

    @testset "Structured & Dynamic" begin
        adj = [0 1 1; 1 0 0; 1 0 0]
        cent = degree_centrality(adj)
        @test cent[1] == 1.0
        
        # Long sequence for stable Hurst
        hurst = hurst_exponent(collect(1.0:100.0) .+ randn(100) .* 0.1)
        @test !isnan(hurst)
    end

    @testset "Unconventional Frameworks" begin
        feat = [1, 1, 2, 2, 3]
        target = [1, 2] # Indices 1 and 2
        res = rough_set_approximations(feat, target)
        # Class 1 (indices 1,2) is subset of target indices [1,2]
        @test length(res["lower_approximation"]) >= 2
    end

    @testset "PRE Suite" begin
        # Perfect association
        matrix = [10 0; 0 10]
        res = calculate_PRE_suite(matrix)
        @test res["Lambda"]["value"] == 1.0
        @test res["Tau"]["value"] == 1.0
        @test res["Gamma"]["value"] == 1.0
        @test res["Cramer's V"]["value"] == 1.0
        @test res["Theil's U"]["value"] ≈ 1.0 atol=1e-5
        
        # No association
        matrix_null = [5 5; 5 5]
        res_null = calculate_PRE_suite(matrix_null)
        @test res_null["Lambda"]["value"] == 0.0
        @test res_null["Tau"]["value"] == 0.0
        @test res_null["Cramer's V"]["value"] == 0.0
    end

end
