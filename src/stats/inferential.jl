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
    m1, m2 = mean(group1), mean(group2)
    s1, s2 = var(group1), var(group2)

    # Welch-Satterthwaite Degrees of Freedom calculation.
    se = sqrt(s1 / n1 + s2 / n2)
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
        "effect_size_interpretation" => effect_interp
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
    if ms_within == 0.0
        f_stat = ss_between == 0.0 ? 0.0 : Inf
        p_value = ss_between == 0.0 ? 1.0 : 0.0
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
        "test_type" => "One-way ANOVA (independent groups)"
    )
end
