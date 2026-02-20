# SPDX-License-Identifier: PMPL-1.0-or-later
# Statistical assumptions testing — symbolic computation only.

function test_normality(data::Vector{Float64})
    n = length(data)
    sorted = sort(data)
    m = mean(data)
    s = std(data)
    z_scores = (data .- m) ./ s
    skew = (n / ((n - 1) * (n - 2))) * sum(z_scores .^ 3)
    kurt = ((n * (n + 1)) / ((n - 1) * (n - 2) * (n - 3))) * sum(z_scores .^ 4) -
           (3 * (n - 1)^2) / ((n - 2) * (n - 3))
    JB = (n / 6) * (skew^2 + kurt^2 / 4)
    p_JB = 1 - cdf(Chisq(2), JB)
    ecdf_vals = (1:n) ./ n
    theoretical = cdf.(Normal(m, s), sorted)
    KS = maximum(abs.(ecdf_vals .- theoretical))

    return Dict{String,Any}(
        "skewness" => skew, "kurtosis" => kurt,
        "jarque_bera" => JB, "JB_p_value" => p_JB,
        "KS_statistic" => KS, "n" => n,
        "normal_skew" => abs(skew) < 2, "normal_kurtosis" => abs(kurt) < 7,
        "overall_assessment" => (abs(skew) < 2 && abs(kurt) < 7 && p_JB > 0.05) ?
            "Data appears approximately normal" :
            "Data may violate normality assumption",
        "recommendations" => n < 30 ?
            "Small sample — consider non-parametric alternatives" :
            "Large sample — parametric tests may be robust to mild violations"
    )
end

function levenes_test(groups::Vector{Vector{Float64}}; alpha::Float64=0.05)
    medians = median.(groups)
    deviations = [abs.(g .- m) for (g, m) in zip(groups, medians)]
    result = one_way_anova(deviations; alpha=alpha)

    return Dict{String,Any}(
        "F_statistic" => result["F_statistic"],
        "p_value" => result["p_value"],
        "significant" => result["significant"],
        "interpretation" => result["significant"] ?
            "Variances are significantly different — assumption violated" :
            "No significant difference in variances — assumption met",
        "group_variances" => var.(groups),
        "variance_ratio" => maximum(var.(groups)) / minimum(var.(groups)),
        "rule_of_thumb" => maximum(var.(groups)) / minimum(var.(groups)) < 4 ?
            "Variance ratio < 4:1 — generally acceptable" :
            "Variance ratio >= 4:1 — consider Welch's correction or transformation"
    )
end
