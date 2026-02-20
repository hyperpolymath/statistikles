# SPDX-License-Identifier: PMPL-1.0-or-later
# Data normalization — fourth stage of the Data Quality Pathway.
#
# Raw Input → Detection → Validation → Cleansing → [NORMALIZATION] → Analysis
#
# Transforms data for statistical suitability. Includes:
# - Z-score standardization
# - Min-max scaling
# - Log transformation
# - Database normalization concepts (1NF→BCNF for tabular data)

"""
    normalize_zscore(data::Vector{Float64}) -> Dict

Z-score standardization: (x - mean) / sd.
Transforms to mean=0, sd=1.
"""
function normalize_zscore(data::Vector{Float64})
    m = mean(data)
    s = std(data)
    s == 0 && return Dict{String,Any}("error" => "Cannot z-score with zero variance")
    normalized = (data .- m) ./ s

    return Dict{String,Any}(
        "data" => normalized,
        "method" => "z-score standardization",
        "original_mean" => m, "original_sd" => s,
        "new_mean" => mean(normalized), "new_sd" => std(normalized),
        "interpretation" => "Values now represent standard deviations from the mean"
    )
end

"""
    normalize_minmax(data::Vector{Float64}; range=(0.0, 1.0)) -> Dict

Min-max scaling to a specified range.
"""
function normalize_minmax(data::Vector{Float64}; target_range::Tuple{Float64,Float64}=(0.0, 1.0))
    lo, hi = minimum(data), maximum(data)
    hi == lo && return Dict{String,Any}("error" => "Cannot min-max with zero range")
    a, b = target_range
    normalized = a .+ (data .- lo) ./ (hi - lo) .* (b - a)

    return Dict{String,Any}(
        "data" => normalized,
        "method" => "min-max scaling",
        "original_range" => (lo, hi),
        "target_range" => target_range,
        "new_min" => minimum(normalized),
        "new_max" => maximum(normalized)
    )
end

"""
    normalize_log(data::Vector{Float64}; base=:natural) -> Dict

Log transformation for positively skewed data.
"""
function normalize_log(data::Vector{Float64}; base::Symbol=:natural)
    any(x -> x <= 0, data) && return Dict{String,Any}(
        "error" => "Cannot log-transform non-positive values. Consider adding a constant."
    )

    transformed = if base == :natural
        log.(data)
    elseif base == :log10
        log10.(data)
    elseif base == :log2
        log2.(data)
    else
        log.(data)
    end

    # Check if transformation helped
    orig_skew = skewness_calc(data)
    new_skew = skewness_calc(transformed)

    return Dict{String,Any}(
        "data" => transformed,
        "method" => "log transformation ($(base))",
        "original_skewness" => orig_skew,
        "new_skewness" => new_skew,
        "improvement" => abs(new_skew) < abs(orig_skew) ?
            "Skewness reduced — transformation helped" :
            "Skewness not reduced — consider other transformations"
    )
end

# Internal helper
function skewness_calc(data::Vector{Float64})
    n = length(data)
    m = mean(data)
    s = std(data)
    s == 0 && return 0.0
    return (n / ((n - 1) * (n - 2))) * sum(((data .- m) ./ s) .^ 3)
end

"""
    check_tabular_normalization(df::DataFrame) -> Dict

Check tabular data against database normalization principles (1NF→3NF).
Identifies potential violations relevant to statistical analysis.
"""
function check_tabular_normalization(df::DataFrame)
    n, k = size(df)
    issues = String[]
    recommendations = String[]

    # 1NF: Atomic values (no lists/arrays in cells)
    for col in names(df)
        if any(row -> row isa AbstractVector || row isa AbstractArray, skipmissing(df[!, col]))
            push!(issues, "1NF violation: column '$col' contains non-atomic values")
        end
    end

    # Check for repeating groups (multiple columns with same prefix + number)
    col_names = string.(names(df))
    for name in col_names
        m = match(r"^(.+?)(\d+)$", name)
        if !isnothing(m)
            prefix = m.captures[1]
            similar = filter(c -> startswith(c, prefix) && match(r"\d+$", c) !== nothing, col_names)
            if length(similar) > 2
                push!(issues, "1NF warning: repeating group detected ('$(prefix)*' columns) — consider long format")
                break
            end
        end
    end

    # 2NF: Check for partial dependencies (simplified)
    if k > 3
        push!(recommendations, "Consider whether all columns depend on the full key, not just part of it")
    end

    # 3NF: Check for transitive dependencies (simplified heuristic)
    numeric_cols = [col for col in names(df) if eltype(df[!, col]) <: Union{Number, Missing}]
    for i in 1:length(numeric_cols), j in (i+1):length(numeric_cols)
        c1, c2 = numeric_cols[i], numeric_cols[j]
        clean = dropmissing(df[:, [c1, c2]])
        if nrow(clean) > 5
            r = cor(Float64.(clean[!, 1]), Float64.(clean[!, 2]))
            if abs(r) > 0.99
                push!(issues, "3NF warning: '$c1' and '$c2' are near-perfectly correlated (r=$(round(r, digits=3))) — possible transitive dependency")
            end
        end
    end

    nf_level = isempty(issues) ? "Appears normalized (3NF)" :
               any(contains("1NF"), issues) ? "Below 1NF" :
               any(contains("3NF"), issues) ? "1NF-2NF (3NF violations)" : "1NF-2NF"

    return Dict{String,Any}(
        "normalization_level" => nf_level,
        "n_rows" => n, "n_cols" => k,
        "issues" => issues,
        "recommendations" => recommendations,
        "note" => "Database normalization principles help identify data structure issues that can affect statistical analysis"
    )
end
