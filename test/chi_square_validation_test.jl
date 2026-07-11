# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# chi_square_validation_test.jl — Dedicated correctness review of the three
# functions PR #41 merged with only smoke-test coverage: `chi_square_test`
# and `chi_square_goodness_of_fit` (src/stats/inferential.jl), and the
# completed `frequency_table` (src/stats/descriptive.jl). All three produce
# numbers end users see verbatim, so this file checks the mathematics
# against ground truth computed by a SECOND, independent implementation
# rather than the library's own output.
#
# Ground truth was derived locally (2026-07-11, WSL Debian) with:
#   - R 4.5.0's `chisq.test` (stats package, base R)
#   - SciPy 1.15.3's `scipy.stats.chi2_contingency` / `chisquare`
# Both implementations agreed to >= 12 significant figures on every case
# below; only the constants (not the derivation scripts) are committed.
#
# BUGS FOUND AND FIXED during this review (see src/stats/inferential.jl):
#   1. `chi_square_test` / `chi_square_goodness_of_fit` used `1 - cdf(...)`
#      for the upper-tail p-value, which underflows to exactly 0.0 for
#      large chi-squared statistics (verified: cdf saturates to 1.0 in
#      Float64 well before the true tail probability reaches zero).
#      Switched to `ccdf(...)`, which stays numerically accurate into the
#      1e-22 range and beyond.
#   2. `chi_square_test` had no guard for r<2 or c<2 columns/rows or a
#      zero-observation table: `Chisq(0)` throws an uncaught `DomainError`
#      (verified interactively), and `Cramér's V`'s `min(r,c)-1` divides by
#      zero for a 1-row/1-column table. Both are now `ArgumentError`s.
#   3. `chi_square_test` silently treated any table with a fully zero row
#      or column as if that category didn't exist (via an `expected > 0`
#      skip), while still charging its degree of freedom to `df` — an
#      undefined comparison presented as a normal result. R's own
#      `chisq.test` hits the same input and leaks `NaN`/`NA`; this function
#      now returns `nothing` + a `"note"` explaining why, never a number.
#   4. `chi_square_goodness_of_fit` had no guard for k<2 categories (same
#      `Chisq(0)` crash as above), no length/sum-to-1 validation on a
#      caller-supplied `expected_proportions`, and no guard for a
#      caller-supplied zero proportion (`(O-0)^2/0` is `Inf` or `NaN`).
#   5. Neither function warned when expected cell counts fall below 5
#      (Cochran's rule of thumb) — both now set a non-fatal `"warning"`.
#   6. Added an optional, explicitly-off-by-default Yates' continuity
#      correction for 2x2 tables (`yates_correction=true`), verified
#      against R's `chisq.test(..., correct=TRUE)`.
#
# `frequency_table` (src/stats/descriptive.jl) was reviewed and found
# mathematically correct as-is: category counts, relative/cumulative
# frequencies, and mode selection all check out against a hand count.
# No production code change was needed there; it's still covered below.

using Test
using Statistikles

@testset "Chi-Square Dedicated Validation" begin

    # ═══════════════════════════════════════════════════════════════════
    # 1. CHI-SQUARE TEST OF INDEPENDENCE — 3x3 ground truth
    # ═══════════════════════════════════════════════════════════════════
    @testset "Independence (3x3) vs R chisq.test / SciPy chi2_contingency" begin
        # obs <- matrix(c(10,20,30, 6,9,17, 8,15,20), nrow=3, byrow=TRUE)
        # R:     chisq.test(obs, correct=FALSE)
        #        X-squared = 0.515205667618567, df = 4, p-value = 0.972003923728684
        # SciPy: scipy.stats.chi2_contingency(obs, correction=False)
        #        chi2 = 0.5152056676185671, dof = 4, p = 0.9720039237286836
        # (R and SciPy agree to 12 significant figures; SciPy's extra ULP is
        # float64 rounding noise, well inside the tolerance below.)
        observed = [10 20 30; 6 9 17; 8 15 20]
        r = Statistikles.chi_square_test(observed)

        @test isapprox(r["chi_squared"], 0.515205667618567; atol = 1e-9)
        @test r["df"] == 4
        @test isapprox(r["p_value"], 0.972003923728684; atol = 1e-9)
        @test r["significant"] == false
        @test r["n"] == 135

        # Cramér's V = sqrt(chi2 / (n * (min(r,c)-1))) = sqrt(0.515205667618567 / (135*2))
        expected_cramers_v = sqrt(0.515205667618567 / (135 * 2))
        @test isapprox(r["cramers_v"], expected_cramers_v; atol = 1e-9)

        @test r["note"] === nothing
        @test r["warning"] === nothing  # all expected counts are well above 5
    end

    @testset "Independence (2x2, uncorrected) vs R / SciPy" begin
        # obs2 <- matrix(c(8,12,15,5), nrow=2, byrow=TRUE)
        # R:     chisq.test(obs2, correct=FALSE)
        #        X-squared = 5.012787723785166, df = 1, p-value = 0.0251607592004087
        # SciPy: chi2_contingency(obs2, correction=False) agrees to 12 s.f.
        observed = [8 12; 15 5]
        r = Statistikles.chi_square_test(observed)
        @test isapprox(r["chi_squared"], 5.012787723785166; atol = 1e-9)
        @test r["df"] == 1
        @test isapprox(r["p_value"], 0.0251607592004087; atol = 1e-9)
        @test r["significant"] == true  # p < 0.05
    end

    @testset "Independence (2x2, Yates-corrected) vs R chisq.test(correct=TRUE)" begin
        # R: chisq.test(obs2, correct=TRUE)
        #    X-squared = 3.682864450127878, df = 1, p-value = 0.0549743287216943
        observed = [8 12; 15 5]
        r = Statistikles.chi_square_test(observed; yates_correction = true)
        @test isapprox(r["chi_squared"], 3.682864450127878; atol = 1e-9)
        @test r["df"] == 1
        @test isapprox(r["p_value"], 0.0549743287216943; atol = 1e-9)
        @test r["significant"] == false  # p > 0.05 (correction pulls it back from significance)
        @test occursin("Yates", r["test_type"])
    end

    @testset "yates_correction rejected on a non-2x2 table" begin
        observed = [10 20 30; 6 9 17; 8 15 20]
        @test_throws ArgumentError Statistikles.chi_square_test(observed; yates_correction = true)
    end

    # ═══════════════════════════════════════════════════════════════════
    # 2. CHI-SQUARE GOODNESS-OF-FIT — non-uniform expected proportions
    # ═══════════════════════════════════════════════════════════════════
    @testset "Goodness-of-fit (non-uniform) vs R chisq.test(p=...) / SciPy chisquare" begin
        # observed_gof <- c(18, 22, 15, 25, 20); props <- c(.15,.25,.10,.30,.20)
        # R:     chisq.test(observed_gof, p=props)
        #        X-squared = 4.293333333333333, df = 4, p-value = 0.367760644428913
        # SciPy: scipy.stats.chisquare(observed_gof, f_exp=n*props)
        #        statistic = 4.293333333333333, pvalue = 0.36776064442891276
        observed = [18, 22, 15, 25, 20]
        props = [0.15, 0.25, 0.10, 0.30, 0.20]
        r = Statistikles.chi_square_goodness_of_fit(observed, props)

        @test isapprox(r["chi_squared"], 4.293333333333333; atol = 1e-9)
        @test r["df"] == 4
        @test isapprox(r["p_value"], 0.367760644428913; atol = 1e-9)
        @test r["significant"] == false
        @test isapprox(r["expected"], [15.0, 25.0, 10.0, 30.0, 20.0]; atol = 1e-12)
        @test r["n"] == 100
        @test r["note"] === nothing
        @test r["warning"] === nothing  # min expected = 10, above the Cochran threshold
    end

    @testset "Goodness-of-fit (uniform default) closed-form cross-check" begin
        # k=3 uniform categories, n=30 -> expected=10 each. Deviations
        # [+5,0,-5] -> chi2 = (25+0+25)/10 = 5.0 exactly, df=2.
        # df=2 has a closed-form chi-square survival function independent
        # of the library's own Distributions.cdf call path:
        #   P(chi^2_2 > x) = exp(-x/2)
        observed = [15, 10, 5]
        r = Statistikles.chi_square_goodness_of_fit(observed)
        @test r["chi_squared"] == 5.0
        @test r["df"] == 2
        @test isapprox(r["p_value"], exp(-2.5); atol = 1e-12)
    end

    # ═══════════════════════════════════════════════════════════════════
    # 3. DEGENERATE-INPUT HANDLING — clean errors, no NaN/Inf leaks
    # ═══════════════════════════════════════════════════════════════════
    @testset "chi_square_test: 1-row table throws ArgumentError (was: DomainError)" begin
        @test_throws ArgumentError Statistikles.chi_square_test(reshape([10, 20, 30], 1, 3))
    end

    @testset "chi_square_test: negative counts throw ArgumentError" begin
        @test_throws ArgumentError Statistikles.chi_square_test([10 -5; 3 8])
    end

    @testset "chi_square_test: all-zero table throws ArgumentError" begin
        @test_throws ArgumentError Statistikles.chi_square_test([0 0; 0 0])
    end

    @testset "chi_square_test: zero row total -> nothing + note, not NaN" begin
        observed = [0 0 0; 6 9 17; 8 15 20]
        r = Statistikles.chi_square_test(observed)
        @test r["chi_squared"] === nothing
        @test r["df"] === nothing
        @test r["p_value"] === nothing
        @test r["cramers_v"] === nothing
        @test r["significant"] == false
        @test r["note"] !== nothing
        @test occursin("zero total", r["note"])
        assert_finite_and_serialisable(r)
    end

    @testset "chi_square_test: zero column total -> nothing + note, not NaN" begin
        observed = [0 20 30; 0 9 17; 0 15 20]
        r = Statistikles.chi_square_test(observed)
        @test r["chi_squared"] === nothing
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "chi_square_goodness_of_fit: k=1 category throws ArgumentError" begin
        @test_throws ArgumentError Statistikles.chi_square_goodness_of_fit([42])
    end

    @testset "chi_square_goodness_of_fit: mismatched proportions length throws ArgumentError" begin
        @test_throws ArgumentError Statistikles.chi_square_goodness_of_fit([10, 20, 30], [0.5, 0.5])
    end

    @testset "chi_square_goodness_of_fit: proportions not summing to 1 throws ArgumentError" begin
        @test_throws ArgumentError Statistikles.chi_square_goodness_of_fit([10, 20, 30], [0.5, 0.5, 0.5])
    end

    @testset "chi_square_goodness_of_fit: negative counts throw ArgumentError" begin
        @test_throws ArgumentError Statistikles.chi_square_goodness_of_fit([10, -5, 30])
    end

    @testset "chi_square_goodness_of_fit: zero-observation table throws ArgumentError" begin
        @test_throws ArgumentError Statistikles.chi_square_goodness_of_fit([0, 0, 0])
    end

    @testset "chi_square_goodness_of_fit: zero expected proportion -> nothing + note, not Inf" begin
        # Category 3 is assigned zero probability but was observed anyway:
        # (O-E)^2/E = (5-0)^2/0 = Inf under the naive formula.
        observed = [10, 15, 5]
        props = [0.5, 0.5, 0.0]
        r = Statistikles.chi_square_goodness_of_fit(observed, props)
        @test r["chi_squared"] === nothing
        @test r["note"] !== nothing
        assert_finite_and_serialisable(r)
    end

    @testset "chi_square_test: low expected counts trigger a warning, not an error" begin
        # Small counts spread over a 3x2 table so several expected cells
        # fall below 5, but the table itself is still well-formed.
        observed = [2 1; 1 2; 3 1]
        r = Statistikles.chi_square_test(observed)
        @test r["chi_squared"] !== nothing  # statistic is still returned
        @test r["warning"] !== nothing
        @test occursin("below 5", r["warning"])
        assert_finite_and_serialisable(r)
    end

    # ═══════════════════════════════════════════════════════════════════
    # 4. JSON-SERIALISABLE FINITENESS on a normal case (both functions)
    # ═══════════════════════════════════════════════════════════════════
    @testset "chi_square_test: normal case is fully finite + JSON-serialisable" begin
        r = Statistikles.chi_square_test([10 20 30; 6 9 17; 8 15 20])
        assert_finite_and_serialisable(r)
    end

    @testset "chi_square_goodness_of_fit: normal case is fully finite + JSON-serialisable" begin
        r = Statistikles.chi_square_goodness_of_fit([18, 22, 15, 25, 20],
                                                      [0.15, 0.25, 0.10, 0.30, 0.20])
        assert_finite_and_serialisable(r)
    end

    # ═══════════════════════════════════════════════════════════════════
    # 5. FREQUENCY_TABLE — reviewed, found correct; covered here too
    # ═══════════════════════════════════════════════════════════════════
    @testset "frequency_table: hand-counted ground truth" begin
        data = ["x", "y", "x", "x", "z", "y", "x"]
        # Hand count: x×4, y×2, z×1, n=7; categories sort alphabetically.
        r = Statistikles.frequency_table(data)
        @test r["categories"] == ["x", "y", "z"]
        @test r["frequencies"] == [4, 2, 1]
        @test isapprox(r["relative_frequencies"], [400 / 7, 200 / 7, 100 / 7]; atol = 1e-9)
        @test r["cumulative_frequencies"] == [4, 6, 7]
        @test isapprox(r["cumulative_relative_frequencies"], [400 / 7, 600 / 7, 100.0]; atol = 1e-9)
        @test r["n"] == 7
        @test r["n_categories"] == 3
        @test r["mode"] == "x"
        assert_finite_and_serialisable(r)
    end

    @testset "frequency_table: empty input returns a clean error, not a crash" begin
        r = Statistikles.frequency_table(String[])
        @test haskey(r, "error")
        assert_finite_and_serialisable(r)
    end

    # ═══════════════════════════════════════════════════════════════════
    # 6. EXECUTOR DISPATCH — chi_square tool still matches the direct call
    #    (guards against the fix above breaking the router's Matrix{Int}
    #    coercion path in src/tools/executor.jl)
    # ═══════════════════════════════════════════════════════════════════
    @testset "Executor dispatch: chi_square independence unaffected by the guards" begin
        observed_rows = [[10, 20, 30], [6, 9, 17], [8, 15, 20]]
        direct = Statistikles.chi_square_test([10 20 30; 6 9 17; 8 15 20])
        via_tool = Statistikles.execute_tool("chi_square",
            Dict{String,Any}("type" => "independence", "observed" => observed_rows))
        @test isapprox(via_tool["chi_squared"], direct["chi_squared"]; atol = 1e-12)
        @test isapprox(via_tool["p_value"], direct["p_value"]; atol = 1e-12)
    end

    @testset "Executor dispatch: chi_square goodness-of-fit unaffected by the guards" begin
        direct = Statistikles.chi_square_goodness_of_fit([18, 22, 15, 25, 20],
                                                           [0.15, 0.25, 0.10, 0.30, 0.20])
        via_tool = Statistikles.execute_tool("chi_square",
            Dict{String,Any}("type" => "goodness_of_fit", "observed" => [18, 22, 15, 25, 20],
                              "expected_proportions" => [0.15, 0.25, 0.10, 0.30, 0.20]))
        @test isapprox(via_tool["chi_squared"], direct["chi_squared"]; atol = 1e-12)
        @test isapprox(via_tool["p_value"], direct["p_value"]; atol = 1e-12)
    end

end
