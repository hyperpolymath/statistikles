# SPDX-License-Identifier: PMPL-1.0-or-later
# Descriptive statistics — all computations are symbolic, never neural.

"""
    descriptive_stats(data::Vector{Float64}) -> Dict

Comprehensive descriptive statistics. Every number is computed by Julia,
not estimated by an LLM. This is a core principle of StatistEase.
"""
function descriptive_stats(data::Vector{Float64})
    n = length(data)
    n < 2 && return Dict{String,Any}("error" => "Need at least 2 observations")

    sorted = sort(data)
    q1 = quantile(data, 0.25)
    q3 = quantile(data, 0.75)
    iqr_val = q3 - q1
    m = mean(data)
    s = std(data)
    se = s / sqrt(n)

    z_scores = (data .- m) ./ s
    skew = n > 2 ? (n / ((n - 1) * (n - 2))) * sum(z_scores .^ 3) : NaN
    kurt = n > 3 ? ((n * (n + 1)) / ((n - 1) * (n - 2) * (n - 3))) * sum(z_scores .^ 4) -
                   (3 * (n - 1)^2) / ((n - 2) * (n - 3)) : NaN

    ci_95 = (m - 1.96 * se, m + 1.96 * se)

    return Dict{String,Any}(
        "n" => n,
        "mean" => m,
        "median" => median(data),
        "mode" => mode(data),
        "std" => s,
        "variance" => var(data),
        "se_mean" => se,
        "ci_95" => ci_95,
        "min" => minimum(data),
        "max" => maximum(data),
        "range" => maximum(data) - minimum(data),
        "q1" => q1,
        "q3" => q3,
        "iqr" => iqr_val,
        "skewness" => skew,
        "kurtosis" => kurt,
        "cv" => abs(m) > 0 ? s / abs(m) * 100 : NaN,
        "outlier_fences" => (q1 - 1.5 * iqr_val, q3 + 1.5 * iqr_val),
        "normality_hint" => abs(skew) < 2 && abs(kurt) < 7 ?
                            "Approximately normal" : "Possibly non-normal"
    )
end

"""
    frequency_table(data::Vector{String}) -> Dict

Frequency table for categorical data.
"""
function frequency_table(data::Vector{String})
    counts = countmap(data)
    n = length(data)
    sorted_keys = sort(collect(keys(counts)), by=k -> counts[k], rev=true)

    rows = Dict{String,Any}[]
    cumulative = 0
    for k in sorted_keys
        c = counts[k]
        cumulative += c
        push!(rows, Dict{String,Any}(
            "category" => k,
            "frequency" => c,
            "relative_freq" => c / n,
            "percent" => round(c / n * 100, digits=2),
            "cumulative_freq" => cumulative,
            "cumulative_percent" => round(cumulative / n * 100, digits=2)
        ))
    end

    return Dict{String,Any}(
        "table" => rows,
        "n" => n,
        "n_categories" => length(counts),
        "modal_category" => sorted_keys[1]
    )
end
