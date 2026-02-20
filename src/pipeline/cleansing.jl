# SPDX-License-Identifier: PMPL-1.0-or-later
# Data cleansing — third stage of the Data Quality Pathway.
#
# Raw Input → Detection → Validation → [CLEANSING] → Normalization → Analysis
#
# Techniques: outlier detection, missing value handling, deduplication,
# encoding normalization, type coercion.

"""
    detect_outliers(data::Vector{Float64}; method="iqr") -> Dict

Detect outliers using IQR, Z-score, or modified Z-score methods.
"""
function detect_outliers(data::Vector{Float64}; method::String="iqr",
                         threshold::Float64=1.5)
    n = length(data)

    if method == "iqr"
        q1 = quantile(data, 0.25)
        q3 = quantile(data, 0.75)
        iqr_val = q3 - q1
        lower = q1 - threshold * iqr_val
        upper = q3 + threshold * iqr_val
        outlier_mask = (data .< lower) .| (data .> upper)
    elseif method == "zscore"
        z_threshold = threshold > 1 ? threshold : 3.0
        z = (data .- mean(data)) ./ std(data)
        outlier_mask = abs.(z) .> z_threshold
        lower = mean(data) - z_threshold * std(data)
        upper = mean(data) + z_threshold * std(data)
    elseif method == "modified_zscore"
        med = median(data)
        mad_val = median(abs.(data .- med))
        modified_z = 0.6745 .* (data .- med) ./ (mad_val > 0 ? mad_val : 1.0)
        z_threshold = threshold > 1 ? threshold : 3.5
        outlier_mask = abs.(modified_z) .> z_threshold
        lower = med - z_threshold * mad_val / 0.6745
        upper = med + z_threshold * mad_val / 0.6745
    else
        return Dict{String,Any}("error" => "Unknown method: $method")
    end

    outlier_indices = findall(outlier_mask)
    outlier_values = data[outlier_indices]

    return Dict{String,Any}(
        "method" => method,
        "n_outliers" => length(outlier_indices),
        "outlier_indices" => outlier_indices,
        "outlier_values" => outlier_values,
        "bounds" => (lower, upper),
        "pct_outliers" => length(outlier_indices) / n * 100,
        "recommendation" => length(outlier_indices) == 0 ? "No outliers detected" :
            length(outlier_indices) / n < 0.05 ? "Few outliers — inspect individually" :
            "Many outliers — check data collection or consider robust methods"
    )
end

"""
    handle_missing(data::Vector{Union{Float64,Missing}}; strategy="listwise") -> Dict

Handle missing values with various strategies.
"""
function handle_missing(data::Vector{Union{Float64,Missing}};
                        strategy::String="listwise")
    n_original = length(data)
    n_missing = count(ismissing, data)

    if strategy == "listwise"
        clean = collect(skipmissing(data))
        return Dict{String,Any}(
            "strategy" => "listwise deletion",
            "data" => clean,
            "n_original" => n_original,
            "n_removed" => n_missing,
            "n_remaining" => length(clean)
        )
    elseif strategy == "mean"
        clean_vals = collect(skipmissing(data))
        m = mean(clean_vals)
        filled = [ismissing(x) ? m : Float64(x) for x in data]
        return Dict{String,Any}(
            "strategy" => "mean imputation",
            "data" => filled,
            "imputed_value" => m,
            "n_imputed" => n_missing,
            "warning" => "Mean imputation reduces variance and can bias standard errors"
        )
    elseif strategy == "median"
        clean_vals = collect(skipmissing(data))
        med = median(clean_vals)
        filled = [ismissing(x) ? med : Float64(x) for x in data]
        return Dict{String,Any}(
            "strategy" => "median imputation",
            "data" => filled,
            "imputed_value" => med,
            "n_imputed" => n_missing,
            "warning" => "Median imputation is more robust than mean but still reduces variance"
        )
    end

    return Dict{String,Any}("error" => "Unknown strategy: $strategy")
end

"""
    deduplicate(data::Vector; keep="first") -> Dict

Remove duplicate entries from data.
"""
function deduplicate(data::Vector; keep::String="first")
    n_original = length(data)
    seen = Set()
    result = eltype(data)[]

    if keep == "first"
        for val in data
            if !(val in seen)
                push!(seen, val)
                push!(result, val)
            end
        end
    elseif keep == "last"
        for val in reverse(data)
            if !(val in seen)
                push!(seen, val)
                pushfirst!(result, val)
            end
        end
    end

    return Dict{String,Any}(
        "data" => result,
        "n_original" => n_original,
        "n_unique" => length(result),
        "n_duplicates_removed" => n_original - length(result)
    )
end
