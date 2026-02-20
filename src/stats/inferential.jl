# SPDX-License-Identifier: PMPL-1.0-or-later
# Inferential tests — t-tests, ANOVA, chi-square
# All computations are deterministic Julia code, never neural inference.

"""
    t_test_independent(group1, group2; alpha=0.05) -> Dict

Welch's independent samples t-test (does not assume equal variances).
Includes Cohen's d effect size.
"""
function t_test_independent(group1::Vector{Float64}, group2::Vector{Float64};
                           alpha::Float64=0.05)
    n1, n2 = length(group1), length(group2)
    m1, m2 = mean(group1), mean(group2)
    s1, s2 = var(group1), var(group2)

    se = sqrt(s1 / n1 + s2 / n2)
    t_stat = (m1 - m2) / se
    df = (s1 / n1 + s2 / n2)^2 / ((s1 / n1)^2 / (n1 - 1) + (s2 / n2)^2 / (n2 - 1))

    p_two = 2 * (1 - cdf(TDist(df), abs(t_stat)))
    pooled_sd = sqrt(((n1 - 1) * s1 + (n2 - 1) * s2) / (n1 + n2 - 2))
    d = (m1 - m2) / pooled_sd

    d_interp = abs(d) >= 0.8 ? "Large" : abs(d) >= 0.5 ? "Medium" :
               abs(d) >= 0.2 ? "Small" : "Negligible"

    return Dict{String,Any}(
        "t_statistic" => t_stat, "df" => df,
        "p_value_two_tailed" => p_two,
        "p_value_one_tailed" => 1 - cdf(TDist(df), abs(t_stat)),
        "significant" => p_two < alpha,
        "mean_difference" => m1 - m2, "se_difference" => se,
        "ci_95_difference" => (m1 - m2 - quantile(TDist(df), 0.975) * se,
                               m1 - m2 + quantile(TDist(df), 0.975) * se),
        "cohens_d" => d, "effect_size_interpretation" => d_interp,
        "group1_stats" => Dict("n" => n1, "mean" => m1, "sd" => sqrt(s1)),
        "group2_stats" => Dict("n" => n2, "mean" => m2, "sd" => sqrt(s2)),
        "test_type" => "Welch's independent samples t-test"
    )
end

"""
    t_test_paired(pre, post; alpha=0.05) -> Dict

Paired samples t-test with Cohen's d.
"""
function t_test_paired(pre::Vector{Float64}, post::Vector{Float64}; alpha::Float64=0.05)
    length(pre) != length(post) && return Dict{String,Any}("error" => "Vectors must have same length")
    diffs = post .- pre
    n = length(diffs)
    m_diff = mean(diffs)
    s_diff = std(diffs)
    se = s_diff / sqrt(n)
    t_stat = m_diff / se
    df = n - 1
    p_two = 2 * (1 - cdf(TDist(df), abs(t_stat)))

    return Dict{String,Any}(
        "t_statistic" => t_stat, "df" => df, "p_value" => p_two,
        "significant" => p_two < alpha,
        "mean_difference" => m_diff, "se_difference" => se,
        "ci_95" => (m_diff - quantile(TDist(df), 0.975) * se,
                    m_diff + quantile(TDist(df), 0.975) * se),
        "cohens_d" => m_diff / s_diff,
        "test_type" => "Paired samples t-test"
    )
end

"""
    t_test_one_sample(data, mu0; alpha=0.05) -> Dict

One-sample t-test with Cohen's d.
"""
function t_test_one_sample(data::Vector{Float64}, mu0::Float64=0.0; alpha::Float64=0.05)
    n = length(data)
    m = mean(data)
    s = std(data)
    se = s / sqrt(n)
    t_stat = (m - mu0) / se
    df = n - 1
    p_two = 2 * (1 - cdf(TDist(df), abs(t_stat)))

    return Dict{String,Any}(
        "t_statistic" => t_stat, "df" => df, "p_value" => p_two,
        "significant" => p_two < alpha,
        "sample_mean" => m, "hypothesized_mean" => mu0, "se" => se,
        "ci_95" => (m - quantile(TDist(df), 0.975) * se,
                    m + quantile(TDist(df), 0.975) * se),
        "cohens_d" => (m - mu0) / s,
        "test_type" => "One-sample t-test"
    )
end

"""
    one_way_anova(groups; alpha=0.05) -> Dict

One-way ANOVA with eta-squared and omega-squared effect sizes.
"""
function one_way_anova(groups::Vector{Vector{Float64}}; alpha::Float64=0.05)
    k = length(groups)
    ns = length.(groups)
    N = sum(ns)
    means = mean.(groups)
    grand_mean = mean(vcat(groups...))

    SSB = sum(ns .* (means .- grand_mean) .^ 2)
    SSW = sum(sum((g .- m) .^ 2) for (g, m) in zip(groups, means))
    SST = SSB + SSW
    df_b = k - 1
    df_w = N - k
    MSB = SSB / df_b
    MSW = SSW / df_w
    F_stat = MSB / MSW
    p_value = 1 - cdf(FDist(df_b, df_w), F_stat)
    eta_sq = SSB / SST
    omega_sq = (SSB - df_b * MSW) / (SST + MSW)

    eta_interp = eta_sq >= 0.14 ? "Large" : eta_sq >= 0.06 ? "Medium" :
                 eta_sq >= 0.01 ? "Small" : "Negligible"

    return Dict{String,Any}(
        "F_statistic" => F_stat, "p_value" => p_value,
        "significant" => p_value < alpha,
        "df_between" => df_b, "df_within" => df_w,
        "SS_between" => SSB, "SS_within" => SSW, "SS_total" => SST,
        "MS_between" => MSB, "MS_within" => MSW,
        "eta_squared" => eta_sq, "omega_squared" => omega_sq,
        "effect_size_interpretation" => eta_interp,
        "group_means" => means, "grand_mean" => grand_mean,
        "k_groups" => k, "N_total" => N
    )
end

"""
    chi_square_test(observed; alpha=0.05) -> Dict

Chi-square test of independence with Cramer's V.
"""
function chi_square_test(observed::Matrix{Int}; alpha::Float64=0.05)
    rows, cols = size(observed)
    row_totals = sum(observed, dims=2)
    col_totals = sum(observed, dims=1)
    N = sum(observed)
    expected = (row_totals * col_totals) / N
    chi2 = sum((observed .- expected) .^ 2 ./ expected)
    df = (rows - 1) * (cols - 1)
    p_value = 1 - cdf(Chisq(df), chi2)
    cramers_v = sqrt(chi2 / (N * (min(rows, cols) - 1)))

    v_interp = cramers_v >= 0.5 ? "Large" : cramers_v >= 0.3 ? "Medium" :
               cramers_v >= 0.1 ? "Small" : "Negligible"

    return Dict{String,Any}(
        "chi_square" => chi2, "df" => df, "p_value" => p_value,
        "significant" => p_value < alpha,
        "expected_frequencies" => expected,
        "standardized_residuals" => (observed .- expected) ./ sqrt.(expected),
        "phi" => sqrt(chi2 / N), "cramers_v" => cramers_v,
        "effect_size_interpretation" => v_interp, "n" => N,
        "min_expected" => minimum(expected),
        "assumption_met" => minimum(expected) >= 5 ?
            "Expected frequencies adequate" : "WARNING: Some expected frequencies < 5"
    )
end

"""
    chi_square_goodness_of_fit(observed, expected_proportions; alpha) -> Dict
"""
function chi_square_goodness_of_fit(observed::Vector{Int},
                                    expected_proportions::Union{Vector{Float64},Nothing}=nothing;
                                    alpha::Float64=0.05)
    k = length(observed)
    N = sum(observed)
    if isnothing(expected_proportions)
        expected_proportions = fill(1.0 / k, k)
    end
    expected = expected_proportions .* N
    chi2 = sum((observed .- expected) .^ 2 ./ expected)
    df = k - 1
    p_value = 1 - cdf(Chisq(df), chi2)

    return Dict{String,Any}(
        "chi_square" => chi2, "df" => df, "p_value" => p_value,
        "significant" => p_value < alpha,
        "observed" => observed, "expected" => expected, "n" => N
    )
end
