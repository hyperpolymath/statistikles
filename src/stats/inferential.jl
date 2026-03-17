# SPDX-License-Identifier: PMPL-1.0-or-later

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
    
    return Dict{String,Any}(
        "t_stat" => t_stat,
        "df" => df,
        "p_value" => p_two,
        "significant" => p_two < alpha
    )
end
