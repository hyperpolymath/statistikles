# SPDX-License-Identifier: MPL-2.0
# Reference validation (advanced surface) — ground truth for tools that,
# before this file, had only `isa Dict`/`haskey` smoke tests.
#
# Every expected value below is either an exact closed-form result of the
# module's own textbook formula applied by hand to an engineered input
# (H statistics, product-limit survival probabilities, inverse-variance
# meta-analysis weights, an orthogonal-design OLS fit), or cross-checked
# with a second, independent implementation run LOCALLY (Python 3.13.5 +
# NumPy / `fractions.Fraction`) — never copied from this library's own
# output. Python is used only to derive the numeric literals below; none
# of it enters the repository (governance bans Python in repo code).
#
# chi_square / goodness_of_fit are intentionally OUT OF SCOPE here — they
# already have reference coverage in reference_validation_test.jl and are
# being extended separately by test/chi-square-validation.

@testset "Reference Validation — Advanced Modules (ground truth)" begin

    @testset "Kruskal-Wallis H test vs reference" begin
        # 3 groups of 2, values 1..6 with NO ties ⇒ midranks are exactly
        # 1,2,3,4,5,6. Rank sums: R1=1+2=3, R2=3+4=7, R3=5+6=11, N=6, k=3.
        # H = (12/(N(N+1)))·Σ(Rᵢ²/nᵢ) - 3(N+1)
        #   = (12/42)·(9/2 + 49/2 + 121/2) - 21 = (2/7)·(179/2) - 21
        #   = 179/7 - 147/7 = 32/7  (Kruskal & Wallis 1952, eq. for H;
        #   same formula the implementation uses — verified exact by hand
        #   since there are no ties, so tie_correction = 0 and H is exact).
        groups = [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0]]
        r = kruskal_wallis(groups)
        @test isapprox(r["H_statistic"], 32 / 7; atol = 1e-9)
        @test isapprox(r["H_uncorrected"], 32 / 7; atol = 1e-9)
        @test r["tie_correction"] == 0.0
        @test r["df"] == 2
        @test r["k_groups"] == 3
        @test r["N_total"] == 6
        # H ~ χ²(df=2) asymptotically; df=2 chi-square has the closed-form
        # survival function P(χ²₂ > x) = e^(-x/2) (same identity already
        # used for chi_square_test's df=2 case in reference_validation_test.jl,
        # independent of the library's own Distributions.cdf call path).
        @test isapprox(r["p_value"], exp(-16 / 7); atol = 1e-9)
        @test r["significant"] == false
        # eta_squared_H = (H - k + 1)/(N - k) = (32/7 - 2)/3 = 6/7
        @test isapprox(r["eta_squared_H"], 6 / 7; atol = 1e-9)
        @test r["group_medians"] == [1.5, 3.5, 5.5]
    end

    @testset "Multiple linear regression vs reference (orthogonal design)" begin
        # Orthogonal 2-predictor design: X1 = [-1,-1,-1,1,1,1] (Σ=0, ΣX1²=6),
        # X2 = [-1,0,1,-1,0,1] (Σ=0, ΣX2²=4), X1·X2 = 0, both ⊥ the intercept
        # column. This makes XᵀX exactly diagonal = diag(6,6,4), so the
        # normal-equation solution reduces to independent weighted sums —
        # hand-computable exactly, no matrix inversion needed:
        #   intercept = ȳ,  β1 = (X1·y)/6,  β2 = (X2·y)/4
        X = [-1.0 -1.0; -1.0 0.0; -1.0 1.0; 1.0 -1.0; 1.0 0.0; 1.0 1.0]
        y = [3.0, 8.0, 13.0, 16.0, 20.0, 24.0]
        r = multiple_regression(X, y; var_names = ["Var1", "Var2"])
        # ȳ = Σy/6 = (3+8+13+16+20+24)/6 = 84/6 = 14.
        @test isapprox(r["coefficients"]["Intercept"], 14.0; atol = 1e-9)
        @test isapprox(r["coefficients"]["Var1"], 6.0; atol = 1e-9)
        @test isapprox(r["coefficients"]["Var2"], 4.5; atol = 1e-9)
        # Residuals by hand: ŷ = 14 + 6·X1 + 4.5·X2 ⇒ residuals
        # [-0.5, 0, 0.5, 0.5, 0, -0.5] ⇒ SS_res = 6·0.25 = 1.0 exactly.
        # SS_tot = Σ(y-14)² = 121+36+1+4+36+100 = 298 ⇒ R² = 1 - 1/298 = 297/298.
        @test isapprox(r["r_squared"], 297 / 298; atol = 1e-9)
        # adj R² = 1 - (1-R²)(n-1)/df_resid = 1 - (1/298)(5/3) = 889/894
        @test isapprox(r["adj_r_squared"], 889 / 894; atol = 1e-9)
        @test r["n"] == 6
        @test r["p"] == 2
        @test r["note"] === nothing
        # sigma² = SS_res/df_resid = 1/3; (XᵀX)⁻¹ diagonal = [1/6, 1/6, 1/4]
        # (exact, since XᵀX is diagonal by construction) ⇒
        # SE_intercept = SE_Var1 = √(1/18), SE_Var2 = √(1/12).
        @test isapprox(r["std_errors"]["Intercept"], sqrt(1 / 18); atol = 1e-9)
        @test isapprox(r["std_errors"]["Var1"], sqrt(1 / 18); atol = 1e-9)
        @test isapprox(r["std_errors"]["Var2"], sqrt(1 / 12); atol = 1e-9)
        t0 = 14.0 / sqrt(1 / 18)
        t1 = 6.0 / sqrt(1 / 18)
        t2 = 4.5 / sqrt(1 / 12)
        @test isapprox(r["t_stats"]["Intercept"], t0; atol = 1e-6)
        @test isapprox(r["t_stats"]["Var1"], t1; atol = 1e-6)
        @test isapprox(r["t_stats"]["Var2"], t2; atol = 1e-6)
        # Two-sided p-value from Student's t, df=3, via the CLOSED FORM for
        # odd degrees of freedom (standard reduction of ∫ds/(a²+s²)²; see
        # e.g. Gradshteyn & Ryzhik 2.103): for ν=3, a=√3,
        #   F(t) = 1/2 + atan(t/√3)/π + √3·t / (π(3+t²))
        #   two-sided p = 1 - 2·atan(|t|/√3)/π - 2√3|t| / (π(3+t²))
        # Cross-checked against the well-known df=3, α=0.05 two-tailed
        # critical value t=3.182446305 (standard t-table): this formula
        # gives p≈0.05 at that t, confirming the derivation — entirely
        # independent of the library's own Distributions.cdf(TDist(...)) call.
        t3_pvalue(t) = 1 - (2 / π) * atan(abs(t) / sqrt(3)) -
                       (2 * sqrt(3) * abs(t)) / (π * (3 + t^2))
        @test isapprox(t3_pvalue(3.182446305), 0.05; atol = 1e-6)  # formula self-check
        @test isapprox(r["p_values"]["Intercept"], t3_pvalue(t0); atol = 1e-8)
        @test isapprox(r["p_values"]["Var1"], t3_pvalue(t1); atol = 1e-8)
        @test isapprox(r["p_values"]["Var2"], t3_pvalue(t2); atol = 1e-8)
    end

    @testset "Logistic regression vs reference (saturated binary predictor)" begin
        # Classic exact-MLE special case (Hosmer & Lemeshow, "Applied
        # Logistic Regression", 3rd ed., §1.2): when the single covariate
        # is dichotomous, the model is SATURATED (2 parameters, 2 cells),
        # so the MLE reproduces the empirical log-odds in each cell exactly:
        #   x=0 group (n=4): 1 success ⇒ p0 = 1/4 ⇒ β0 = logit(1/4) = -ln(3)
        #   x=1 group (n=4): 3 successes ⇒ p1 = 3/4 ⇒
        #     β1 = logit(3/4) - logit(1/4) = ln(3) - (-ln(3)) = 2·ln(3)
        # Cross-checked with an independent Newton/IRLS solve in Python
        # 3.13.5 + NumPy, run locally (not committed): converged to
        # β = [-1.09861229, 2.19722458], matching -ln(3), 2·ln(3) to 8dp.
        X = reshape([0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0], 8, 1)
        y = [0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0]
        r = logistic_regression(X, y)
        @test isapprox(r["coefficients"][1], -log(3.0); atol = 1e-6)
        @test isapprox(r["coefficients"][2], 2 * log(3.0); atol = 1e-6)
    end

    @testset "Kaplan-Meier survival estimate vs reference" begin
        # Product-limit estimator (Kaplan & Meier 1958). Hand-computed with
        # one censored observation inside a tied time group:
        #   t=1: 1 event, at risk 5  ⇒ S = 1·(1-1/5)      = 0.8
        #   t=2: 1 event + 1 censored (tie group), at risk 4
        #        ⇒ S = 0.8·(1-1/4)  = 0.6
        #   t=3: 1 event, at risk 2  ⇒ S = 0.6·(1-1/2)    = 0.3
        #   t=4: 1 event, at risk 1  ⇒ S = 0.3·(1-1/1)    = 0.0
        times = [1.0, 2.0, 2.0, 3.0, 4.0]
        events = [true, true, false, true, true]
        r = kaplan_meier(times, events)
        @test r["times"] == [1.0, 2.0, 3.0, 4.0]
        @test isapprox(r["survival_probabilities"], [0.8, 0.6, 0.3, 0.0]; atol = 1e-12)
    end

    @testset "Meta-analysis: fixed-effects vs reference" begin
        # 3 studies, variances chosen for clean inverse-variance weights:
        # w = 1/var = [20, 50, 100], Σw = 170.
        # combined = Σ(w·es)/Σw = (20·0.3 + 50·0.6 + 100·0.9)/170
        #          = (6 + 30 + 90)/170 = 126/170 = 63/85
        # se = √(1/Σw) = √(1/170)
        # (standard inverse-variance fixed-effect model; constants
        # cross-checked with Python 3.13.5 `fractions.Fraction` exact
        # rational arithmetic, run locally, not committed.)
        es = [0.3, 0.6, 0.9]
        vars = [0.05, 0.02, 0.01]
        r = meta_analysis(es, vars; model = "fixed")
        @test isapprox(r["combined_effect"], 63 / 85; atol = 1e-9)
        @test isapprox(r["std_error"], sqrt(1 / 170); atol = 1e-9)
        @test r["model"] == "Fixed-Effects"
        @test r["k_studies"] == 3
    end

    @testset "Meta-analysis: random-effects (DerSimonian-Laird) vs reference" begin
        # Same 3 studies, DerSimonian & Laird (1986) random-effects model.
        # Q = Σw(es - fixed)² = 126/17 (df = k-1 = 2)
        # τ² = max(0, (Q-df)/(Σw - Σw²/Σw)) = max(0, (126/17-2)/(1600/17))
        #    = (92/17)/(1600/17) = 92/1600 = 23/400 = 0.0575
        # w* = 1/(var+τ²); combined* = Σ(w*·es)/Σw* = 10737/16655
        # I² = max(0, (Q-df)/max(Q,ε)) = (92/17)/(126/17) = 92/126 = 46/63
        # (exact rational values cross-checked with Python 3.13.5
        # `fractions.Fraction`, run locally, not committed.)
        es = [0.3, 0.6, 0.9]
        vars = [0.05, 0.02, 0.01]
        r = meta_analysis(es, vars; model = "random")
        @test isapprox(r["Q_stat"], 126 / 17; atol = 1e-9)
        @test isapprox(r["tau_squared"], 23 / 400; atol = 1e-9)
        @test isapprox(r["combined_effect"], 10737 / 16655; atol = 1e-9)
        @test isapprox(r["I_squared"], 46 / 63; atol = 1e-9)
        @test r["model"] == "Random-Effects (DerSimonian-Laird)"
        @test r["k_studies"] == 3
    end

end
