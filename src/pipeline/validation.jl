# SPDX-License-Identifier: MPL-2.0
# Data validation — second stage of the Data Quality Pathway.
#
# Raw Input → Detection → [VALIDATION] → Cleansing → Normalization → Analysis

"""
    validate_data(data::Vector{Float64}; constraints=nothing) -> Dict

Validate numeric data against constraints and flag issues.
"""
function validate_data(data::Vector{Float64};
                       min_val::Union{Float64,Nothing}=nothing,
                       max_val::Union{Float64,Nothing}=nothing,
                       required_n::Union{Int,Nothing}=nothing,
                       no_duplicates::Bool=false)
    issues = String[]
    warnings = String[]
    n = length(data)

    # Sample size
    if !isnothing(required_n) && n < required_n
        push!(issues, "Insufficient sample size: got $n, need $required_n")
    end
    if n < 3
        push!(issues, "Too few observations for meaningful analysis")
    elseif n < 30
        push!(warnings, "Small sample (n=$n) — consider non-parametric methods")
    end

    # Range checks
    if !isnothing(min_val)
        below = count(x -> x < min_val, data)
        below > 0 && push!(issues, "$below values below minimum ($min_val)")
    end
    if !isnothing(max_val)
        above = count(x -> x > max_val, data)
        above > 0 && push!(issues, "$above values above maximum ($max_val)")
    end

    # Duplicates
    if no_duplicates && length(unique(data)) < n
        push!(warnings, "$(n - length(unique(data))) duplicate values found")
    end

    # Variance
    if var(data) == 0
        push!(issues, "Zero variance — all values identical")
    elseif var(data) < 1e-10
        push!(warnings, "Near-zero variance — data may lack variability")
    end

    # Infinity / NaN
    n_inf = count(isinf, data)
    n_nan = count(isnan, data)
    n_inf > 0 && push!(issues, "$n_inf infinite values")
    n_nan > 0 && push!(issues, "$n_nan NaN values")

    return Dict{String,Any}(
        "valid" => isempty(issues),
        "n" => n,
        "issues" => issues,
        "warnings" => warnings,
        "summary" => isempty(issues) && isempty(warnings) ?
            "Data passes validation" :
            isempty(issues) ? "Data valid with warnings" : "Data has validation issues"
    )
end

"""
    validate_matrix(data::Matrix{Float64}; min_rows, min_cols) -> Dict

Validate a data matrix (e.g., item responses, contingency table).
"""
function validate_matrix(data::Matrix{Float64};
                         min_rows::Int=2, min_cols::Int=2)
    n, k = size(data)
    issues = String[]
    warnings = String[]

    n < min_rows && push!(issues, "Too few rows: got $n, need >= $min_rows")
    k < min_cols && push!(issues, "Too few columns: got $k, need >= $min_cols")

    n_nan = count(isnan, data)
    n_nan > 0 && push!(issues, "$n_nan NaN values in matrix")

    # Check for zero-variance columns
    zero_var_cols = [j for j in 1:k if var(data[:, j]) == 0]
    !isempty(zero_var_cols) && push!(warnings,
        "Zero variance in column(s): $(join(zero_var_cols, ", "))")

    return Dict{String,Any}(
        "valid" => isempty(issues),
        "rows" => n, "cols" => k,
        "issues" => issues, "warnings" => warnings
    )
end
