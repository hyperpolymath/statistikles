# SPDX-License-Identifier: MPL-2.0

# Inferential Statistics — Deterministic Hypothesis Testing.
#
# This module implements formal statistical tests. 
# INVARIANT: All p-values and test statistics are computed via 
# symbolic execution, preventing neural hallucinations of 
# statistical significance.

"""
    t_test_independent(group1, group2; alpha=0.05) -> Dict

WELCH'S T-TEST: Compares the means of two independent samples.
- ASSUMPTIONS: Does NOT assume equal variances (Welch-Satterthwaite approximation).
- EFFECT SIZE: Computes Cohen's d to quantify the magnitude of the difference.
- OUTPUT: Returns T-statistic, Degrees of Freedom, and 2-tailed p-value.
"""
function t_test_independent(group1::Vector{Float64}, group2::Vector{Float64};
                           alpha::Float64=0.05)
    n1, n2 = length(group1), length(group2)

    # DEGENERATE GUARD: below n=2 per group, the Welch-Satterthwaite df
    # formula divides by (n-1) == 0.
    if n1 < 2 || n2 < 2
        return Dict{String,Any}(
            "t_stat" => nothing, "df" => nothing, "p_value" => nothing,
            "significant" => false, "cohens_d" => nothing,
            "effect_size_interpretation" => nothing,
            "note" => "t-test requires at least 2 observations per group"
        )
    end

    m1, m2 = mean(group1), mean(group2)
    s1, s2 = var(group1), var(group2)

    # Welch-Satterthwaite Degrees of Freedom calculation.
    se = sqrt(s1 / n1 + s2 / n2)

    # DEGENERATE GUARD: se == 0 only when both groups have zero variance,
    # which makes t_stat an Inf (differing means) or NaN (equal means).
    if se == 0.0
        return Dict{String,Any}(
            "t_stat" => nothing, "df" => nothing, "p_value" => nothing,
            "significant" => false, "cohens_d" => 0.0,
            "effect_size_interpretation" => "negligible",
            "note" => "t-statistic undefined: zero variance in both groups"
        )
    end

    t_stat = (m1 - m2) / se
    df = (s1 / n1 + s2 / n2)^2 / ((s1 / n1)^2 / (n1 - 1) + (s2 / n2)^2 / (n2 - 1))

    # P-VALUE: Evaluated against the T-Distribution.
    p_two = 2 * (1 - cdf(TDist(df), abs(t_stat)))

    # EFFECT SIZE: Cohen's d using the pooled standard deviation.
    s_pooled = sqrt(((n1 - 1) * s1 + (n2 - 1) * s2) / (n1 + n2 - 2))
    cohens_d = s_pooled == 0 ? 0.0 : (m1 - m2) / s_pooled
    ad = abs(cohens_d)
    effect_interp = ad < 0.2 ? "negligible" :
                    ad < 0.5 ? "small" :
                    ad < 0.8 ? "medium" : "large"

    return Dict{String,Any}(
        "t_stat" => t_stat,
        "df" => df,
        "p_value" => p_two,
        "significant" => p_two < alpha,
        "cohens_d" => cohens_d,
        "effect_size_interpretation" => effect_interp,
        "note" => nothing
    )
end

"""
    one_way_anova(groups; alpha=0.05) -> Dict

ONE-WAY ANOVA: Tests whether k independent group means are equal.
- DECOMPOSITION: Partitions total variance into between-group and
  within-group sums of squares.
- EFFECT SIZE: Reports eta squared (SSB / SST).
- OUTPUT: F-statistic, (df_between, df_within), and p-value from the
  F-distribution.

Used directly, via the `one_way_anova` executor tool, and internally by
`levenes_test` (which runs ANOVA on absolute deviations from group medians).
"""
function one_way_anova(groups::Vector{Vector{Float64}}; alpha::Float64=0.05)
    k = length(groups)
    k < 2 && return Dict{String,Any}("error" => "Need at least 2 groups")
    any(length(g) < 2 for g in groups) &&
        return Dict{String,Any}("error" => "Each group needs at least 2 observations")

    ns = length.(groups)
    N = sum(ns)
    group_means = mean.(groups)
    grand_mean = sum(sum.(groups)) / N

    ss_between = sum(ns .* (group_means .- grand_mean) .^ 2)
    ss_within = sum(sum((g .- m) .^ 2) for (g, m) in zip(groups, group_means))
    df_between = k - 1
    df_within = N - k

    ms_between = ss_between / df_between
    ms_within = ss_within / df_within

    # Degenerate case: zero within-group variance.
    # DEGENERATE GUARD: with nonzero between-group variance the F-ratio is
    # mathematically infinite — report `nothing` (JSON null) with a note
    # rather than leaking Inf; p_value stays the legitimate, finite 0.0.
    note = nothing
    if ms_within == 0.0
        if ss_between == 0.0
            f_stat = 0.0
            p_value = 1.0
        else
            f_stat = nothing
            p_value = 0.0
            note = "F statistic undefined (infinite): zero within-group variance with nonzero between-group variance"
        end
    else
        f_stat = ms_between / ms_within
        p_value = 1 - cdf(FDist(df_between, df_within), f_stat)
    end

    return Dict{String,Any}(
        "F_statistic" => f_stat,
        "df_between" => df_between,
        "df_within" => df_within,
        "ss_between" => ss_between,
        "ss_within" => ss_within,
        "eta_squared" => ss_between + ss_within == 0.0 ? 0.0 :
                         ss_between / (ss_between + ss_within),
        "group_means" => group_means,
        "grand_mean" => grand_mean,
        "p_value" => p_value,
        "significant" => p_value < alpha,
        "test_type" => "One-way ANOVA (independent groups)",
        "note" => note
    )
end

"""
    chi_square_test(observed::Matrix{Int}; alpha=0.05, yates_correction=false) -> Dict

CHI-SQUARE TEST OF INDEPENDENCE: Tests whether two categorical variables are
independent in an r×c contingency table of observed frequencies.
- EXPECTED COUNTS: `E_ij = row_sum_i * col_sum_j / n`.
- STATISTIC: Pearson `χ² = Σ (O_ij - E_ij)² / E_ij`, `df = (r-1)(c-1)`.
- P-VALUE: upper-tail `ccdf(Chisq(df), χ²)` (numerically stable for large χ²,
  unlike `1 - cdf(...)` which underflows to exactly 0.0 in the far tail).
- EFFECT SIZE: Reports Cramér's V = `√(χ² / (n·(min(r,c)-1)))`.
- YATES' CONTINUITY CORRECTION: optional (`yates_correction=true`), valid only
  for 2×2 tables: `χ² = Σ (max(0, |O-E| - 0.5))² / E`. The `max(0, ...)` clamp
  matters whenever every cell's `|O-E| < 0.5` (near-independence tables): without
  it the unclamped formula can *inflate* χ² instead of correcting it downward.
  Off by default to preserve the standard (uncorrected) Pearson statistic;
  matches R's `chisq.test(correct=TRUE)` and SciPy's
  `chi2_contingency(correction=True)`.
- DEGENERATE GUARDS: throws `ArgumentError` for a malformed table (fewer than
  2 rows/columns, negative counts, zero total observations — none of these
  describe a valid r×c contingency table). Returns `nothing`+`"note"` (never
  NaN/Inf) when the table shape is valid but a row or column sums to zero,
  since the independence test is statistically undefined there (this is the
  behaviour R's own `chisq.test` silently leaks as NaN/NA for the same input).
  Emits a non-fatal `"warning"` when any expected count is below 5 (Cochran's
  rule of thumb — the χ² approximation may be unreliable, but the statistic
  is still returned).
"""
function chi_square_test(observed::Matrix{Int}; alpha::Float64=0.05,
                          yates_correction::Bool=false)
    r, c = size(observed)
    require_at_least(r, 2, "observed rows")
    require_at_least(c, 2, "observed columns")
    require_nonnegative(observed, "observed")
    if yates_correction && (r != 2 || c != 2)
        throw(ArgumentError("yates_correction is only defined for 2×2 tables, got $(r)×$(c)"))
    end

    n = sum(observed)
    require_at_least(n, 1, "sum(observed)")

    row_sums = vec(sum(observed, dims=2))
    col_sums = vec(sum(observed, dims=1))

    # DEGENERATE GUARD: a row or column that sums to zero means that category
    # was never observed at all. The expected-count formula still evaluates
    # to a clean 0 for every cell in it (0 * col_sum / n = 0), but the
    # resulting χ² would silently omit that category's contribution while
    # still charging its degree of freedom — an undefined comparison, not a
    # legitimate result. R's `chisq.test` hits the same condition and leaks
    # `NaN`/`NA`; we return `nothing` + a note instead of fabricating a number.
    if any(==(0), row_sums) || any(==(0), col_sums)
        return Dict{String,Any}(
            "chi_squared" => nothing, "df" => nothing, "p_value" => nothing,
            "significant" => false, "cramers_v" => nothing,
            "n" => n, "test_type" => "Chi-square test of independence",
            "note" => "test undefined: a row or column has zero total observations",
            "warning" => nothing
        )
    end

    expected = [row_sums[i] * col_sums[j] / n for i in 1:r, j in 1:c]

    chi2 = if yates_correction
        # Clamp each cell's correction to a minimum of 0: without
        # `max(0.0, ...)`, a cell with |O-E| < 0.5 would square a *negative*
        # number, inflating χ² instead of correcting it downward (e.g.
        # observed=[10 10; 10 11] has |O-E|=0.2439 in every cell and must
        # yield χ²=0.0, not 0.0256 — see test/chi_square_validation_test.jl).
        sum((max(0.0, abs(observed[i, j] - expected[i, j]) - 0.5))^2 / expected[i, j]
            for i in 1:r, j in 1:c)
    else
        sum((observed[i, j] - expected[i, j])^2 / expected[i, j] for i in 1:r, j in 1:c)
    end
    df = (r - 1) * (c - 1)
    p_value = ccdf(Chisq(df), chi2)

    min_expected = minimum(expected)
    n_low = count(<(5), expected)
    warning = min_expected < 5 ?
        "$n_low of $(r*c) expected cell counts are below 5; the χ² approximation may be unreliable (Cochran's rule of thumb)" :
        nothing

    return Dict{String,Any}(
        "chi_squared" => chi2,
        "df" => df,
        "p_value" => p_value,
        "significant" => p_value < alpha,
        "cramers_v" => sqrt(chi2 / (n * (min(r, c) - 1))),
        "n" => n,
        "test_type" => yates_correction ?
            "Chi-square test of independence (Yates-corrected)" :
            "Chi-square test of independence",
        "note" => nothing,
        "warning" => warning
    )
end

"""
    chi_square_goodness_of_fit(observed, expected_proportions=nothing; alpha=0.05) -> Dict

CHI-SQUARE GOODNESS-OF-FIT: Tests whether observed category counts match an
expected distribution. Defaults to a uniform distribution across categories
when `expected_proportions` is not supplied.
- STATISTIC: `χ² = Σ (O_i - E_i)² / E_i` where `E_i = n * p_i`, `df = k - 1`.
- P-VALUE: upper-tail `ccdf(Chisq(df), χ²)` (see `chi_square_test` docstring).
- DEGENERATE GUARDS: throws `ArgumentError` for fewer than 2 categories,
  negative counts, `expected_proportions` of mismatched length or not
  summing to 1 (±1e-9), or zero total observations. Returns `nothing`+`"note"`
  (never NaN/Inf) if any expected count is exactly zero (only reachable via a
  caller-supplied zero proportion — the default uniform split cannot produce
  this). Emits a non-fatal `"warning"` when any expected count is below 5.
"""
function chi_square_goodness_of_fit(observed::Vector{Int},
                                    expected_proportions::Union{Vector{Float64},Nothing}=nothing;
                                    alpha::Float64=0.05)
    k = length(observed)
    require_at_least(k, 2, "observed categories")
    require_nonnegative(observed, "observed")

    props = if isnothing(expected_proportions)
        fill(1.0 / k, k)
    else
        require_equal_length(observed, expected_proportions, "observed", "expected_proportions")
        require_nonnegative(expected_proportions, "expected_proportions")
        isapprox(sum(expected_proportions), 1.0; atol=1e-9) || throw(ArgumentError(
            "expected_proportions must sum to 1, got $(sum(expected_proportions))"))
        expected_proportions
    end

    n = sum(observed)
    require_at_least(n, 1, "sum(observed)")

    expected = n .* props

    # DEGENERATE GUARD: only reachable when a caller supplies a 0.0
    # proportion for some category. (observed - 0)^2 / 0 is Inf (if that
    # category was nonetheless observed) or NaN (0/0, if it wasn't) —
    # either way, an undefined comparison, not a legitimate statistic.
    if any(==(0.0), expected)
        return Dict{String,Any}(
            "chi_squared" => nothing, "df" => nothing, "p_value" => nothing,
            "significant" => false, "expected" => expected,
            "n" => n, "test_type" => "Chi-square goodness-of-fit",
            "note" => "test undefined: expected_proportions assigns zero probability to an observed category",
            "warning" => nothing
        )
    end

    chi2 = sum((observed .- expected) .^ 2 ./ expected)
    df = k - 1
    p_value = ccdf(Chisq(df), chi2)

    min_expected = minimum(expected)
    n_low = count(<(5), expected)
    warning = min_expected < 5 ?
        "$n_low of $k expected cell counts are below 5; the χ² approximation may be unreliable (Cochran's rule of thumb)" :
        nothing

    return Dict{String,Any}(
        "chi_squared" => chi2,
        "df" => df,
        "p_value" => p_value,
        "significant" => p_value < alpha,
        "expected" => expected,
        "n" => n,
        "test_type" => "Chi-square goodness-of-fit",
        "note" => nothing,
        "warning" => warning
    )
end
