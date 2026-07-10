# SPDX-License-Identifier: MPL-2.0
# Reference validation — the trusted symbolic layer checked against ground truth.
#
# The no-mollocks guarantee only holds if the Julia layer itself is correct.
# Every expected value below is hand-derived or independently computed
# (regularized incomplete beta / Lanczos lgamma, cross-checked analytically),
# NOT copied from this library's own output. If one of these fails, the
# symbolic layer is producing wrong-but-deterministic numbers — the exact
# failure mode the project exists to prevent.

@testset "Reference Validation (ground truth)" begin

    @testset "Descriptive: exact moments" begin
        data = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        r = descriptive_stats(data)
        @test r["mean"] == 5.0
        @test r["median"] == 4.5
        # Σ(x-5)² = 32, sample variance = 32/7
        @test isapprox(r["variance"], 32 / 7; atol = 1e-12)
        @test isapprox(r["std"], sqrt(32 / 7); atol = 1e-12)
    end

    @testset "Welch t-test vs reference" begin
        g1 = [1.0, 2.0, 3.0, 4.0, 5.0]   # m=3,   s²=2.5
        g2 = [2.0, 4.0, 6.0, 8.0, 10.0]  # m=6,   s²=10
        r = t_test_independent(g1, g2)
        # t = -3/√(0.5+2) = -1.897366596...; Welch-Satterthwaite df = 6.25/1.0625
        @test isapprox(r["t_stat"], -1.897366596101028; atol = 1e-9)
        @test isapprox(r["df"], 5.882352941176471; atol = 1e-9)
        # p = 2·P(T_df > |t|) — reference via regularized incomplete beta
        @test isapprox(r["p_value"], 0.107531194931; atol = 1e-6)
        @test r["significant"] == false
        # Cohen's d with pooled SD: s_pooled = √((4·2.5 + 4·10)/8) = √6.25 = 2.5
        # d = (3 - 6) / 2.5 = -1.2  (a "large" effect)
        @test isapprox(r["cohens_d"], -1.2; atol = 1e-12)
        @test r["effect_size_interpretation"] == "large"
    end

    @testset "Pearson correlation vs reference" begin
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        y = [1.0, 2.0, 3.0, 4.0, 6.0]
        r = pearson_correlation(x, y)
        # r = 12/√148, r² = 36/37, t = r·√(3/(1-r²)) = 6√3 exactly
        @test isapprox(r["r"], 12 / sqrt(148); atol = 1e-12)
        @test isapprox(r["r_squared"], 36 / 37; atol = 1e-12)
        @test isapprox(r["t_stat"], 6 * sqrt(3.0); atol = 1e-9)
        @test r["df"] == 3
        @test isapprox(r["p_value"], 0.00190127466020; atol = 1e-6)
        @test r["significant"] == true
    end

    @testset "Simple linear regression: exact coefficients" begin
        x = [1.0, 2.0, 3.0, 4.0, 5.0]
        y = [2.0, 4.0, 5.0, 4.0, 5.0]
        r = simple_linear_regression(x, y)
        # slope = 6/10, intercept = 4 - 0.6·3, r² = 1 - 2.4/6 (all exact)
        @test isapprox(r["slope"], 0.6; atol = 1e-12)
        @test isapprox(r["intercept"], 2.2; atol = 1e-12)
        @test isapprox(r["r_squared"], 0.6; atol = 1e-12)
    end

    @testset "One-way ANOVA vs reference" begin
        groups = [[1.0, 2.0, 3.0], [2.0, 3.0, 4.0], [3.0, 4.0, 5.0]]
        r = one_way_anova(groups)
        # SSB = 3(1+0+1) = 6, SSW = 2+2+2 = 6, F = (6/2)/(6/6) = 3
        # p = (1 + 2F/6)^(-3) = 0.125 exactly (closed form for d1=2)
        @test isapprox(r["F_statistic"], 3.0; atol = 1e-12)
        @test r["df_between"] == 2
        @test r["df_within"] == 6
        @test isapprox(r["eta_squared"], 0.5; atol = 1e-12)
        @test isapprox(r["p_value"], 0.125; atol = 1e-9)
        @test r["significant"] == false

        # Identical groups: no between-group variance at all
        same = [[1.0, 2.0], [1.0, 2.0]]
        r0 = one_way_anova(same)
        @test isapprox(r0["F_statistic"], 0.0; atol = 1e-12)
        @test r0["p_value"] == 1.0 || r0["p_value"] > 0.99
    end

    @testset "Mann-Whitney U vs reference" begin
        g1 = [1.0, 2.0, 3.0]
        g2 = [4.0, 5.0, 6.0]
        r = mann_whitney_u(g1, g2)
        # Complete separation: U = 0; z = (4.5-0.5)/√(9·7/12) = 1.745743...
        @test r["U_statistic"] == 0.0
        @test isapprox(r["z"], 1.745743121887939; atol = 1e-9)
        @test isapprox(r["p_value"], 0.0808555; atol = 1e-5)
        @test isapprox(r["rank_biserial_r"], 1.0; atol = 1e-12)
    end

    @testset "Levene's test (via one_way_anova)" begin
        # Groups with identical spread: |deviations from median| are the
        # same in every group, so between-group SS is 0 and F is 0.
        groups = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]]
        r = Statistikles.levenes_test(groups)
        @test isapprox(r["F_statistic"], 0.0; atol = 1e-12)
        @test r["significant"] == false
    end

    @testset "Executor dispatch: anova tool" begin
        direct = one_way_anova([[1.0, 2.0, 3.0], [2.0, 3.0, 4.0], [3.0, 4.0, 5.0]])
        via_tool = Statistikles.execute_tool("anova",
            Dict{String,Any}("groups" => [[1.0, 2.0, 3.0], [2.0, 3.0, 4.0], [3.0, 4.0, 5.0]]))
        @test isapprox(via_tool["F_statistic"], direct["F_statistic"]; atol = 1e-12)
        @test isapprox(via_tool["p_value"], direct["p_value"]; atol = 1e-12)
    end

end
