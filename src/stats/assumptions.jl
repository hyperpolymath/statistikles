# SPDX-License-Identifier: MPL-2.0
# Statistical assumptions testing — symbolic computation only.

function test_normality(data::Vector{Float64})
    n = length(data)

    # DEGENERATE GUARD: the Jarque-Bera statistic needs both skewness
    # (n >= 3) and kurtosis (n >= 4); below that the moment formulas
    # divide by zero.
    if n < 4
        return Dict{String,Any}(
            "skewness" => nothing, "kurtosis" => nothing,
            "jarque_bera" => nothing, "JB_p_value" => nothing,
            "KS_statistic" => nothing, "n" => n,
            "normal_skew" => nothing, "normal_kurtosis" => nothing,
            "overall_assessment" => nothing,
            "recommendations" => "Insufficient data (need at least 4 observations) to assess normality",
            "note" => "Skewness/kurtosis-based normality test requires at least 4 observations"
        )
    end

    sorted = sort(data)
    m = mean(data)
    s = std(data)

    # DEGENERATE GUARD: zero variance makes z-scores 0/0 and the Jarque-Bera
    # inputs undefined.
    if s == 0.0
        return Dict{String,Any}(
            "skewness" => nothing, "kurtosis" => nothing,
            "jarque_bera" => nothing, "JB_p_value" => nothing,
            "KS_statistic" => 0.0, "n" => n,
            "normal_skew" => nothing, "normal_kurtosis" => nothing,
            "overall_assessment" => "Data is constant; normality is not meaningfully defined",
            "recommendations" => n < 30 ?
                "Small sample — consider non-parametric alternatives" :
                "Large sample — parametric tests may be robust to mild violations",
            "note" => "Skewness/kurtosis undefined: zero variance in data"
        )
    end

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
            "Large sample — parametric tests may be robust to mild violations",
        "note" => nothing
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

"""
    anderson_darling(data::Vector{Float64}) -> Dict

ANDERSON-DARLING TEST for normality. More powerful than KS test, especially
in the tails. Uses Stephens' (1986) modified statistic with approximate p-value.
"""
function anderson_darling(data::Vector{Float64})
    n = length(data)
    sorted = sort(data)
    m = mean(data)
    s = std(data)

    # Standardize
    z = (sorted .- m) ./ s

    # Compute CDF values
    Φ = cdf.(Normal(), z)

    # A² statistic: -n - (1/n) Σᵢ (2i-1)[ln Φᵢ + ln(1-Φₙ₊₁₋ᵢ)]
    S = sum((2i - 1) * (log(max(Φ[i], 1e-15)) + log(max(1 - Φ[n + 1 - i], 1e-15))) for i in 1:n)
    A2 = -n - S / n

    # Stephens modification for estimated parameters
    A2_star = A2 * (1 + 0.75 / n + 2.25 / n^2)

    # Approximate p-value (D'Agostino & Stephens, 1986)
    p_value = if A2_star < 0.2
        1.0 - exp(-13.436 + 101.14 * A2_star - 223.73 * A2_star^2)
    elseif A2_star < 0.34
        1.0 - exp(-8.318 + 42.796 * A2_star - 59.938 * A2_star^2)
    elseif A2_star < 0.6
        exp(0.9177 - 4.279 * A2_star - 1.38 * A2_star^2)
    elseif A2_star < 10.0
        exp(1.2937 - 5.709 * A2_star + 0.0186 * A2_star^2)
    else
        0.0  # Extremely non-normal
    end
    p_value = clamp(p_value, 0.0, 1.0)

    return Dict{String,Any}(
        "A2" => A2,
        "A2_star" => A2_star,
        "p_value" => p_value,
        "normal" => p_value > 0.05,
        "n" => n,
        "test_type" => "Anderson-Darling normality test (Stephens modification)"
    )
end
