# SPDX-License-Identifier: PMPL-1.0-or-later
# Sampling design calculations — symbolic computation only.

function design_effect(icc::Float64, cluster_size::Int)
    deff = 1 + (cluster_size - 1) * icc
    return Dict{String,Any}(
        "design_effect" => deff, "ICC" => icc, "cluster_size" => cluster_size,
        "effective_n_multiplier" => 1 / deff,
        "interpretation" => "Multiply simple random sample size by $(round(deff, digits=2)) to account for clustering",
        "example" => "If SRS needs n=100, cluster design needs n=$(ceil(Int, 100 * deff))"
    )
end

function margin_of_error(; n::Int=100, proportion::Float64=0.5,
                           confidence::Float64=0.95,
                           population::Union{Int,Nothing}=nothing)
    z = quantile(Normal(), (1 + confidence) / 2)
    moe = z * sqrt(proportion * (1 - proportion) / n)
    if !isnothing(population) && n / population > 0.05
        fpc = sqrt((population - n) / (population - 1))
        moe_fpc = moe * fpc
    else
        fpc = 1.0
        moe_fpc = moe
    end

    return Dict{String,Any}(
        "margin_of_error" => moe, "margin_of_error_fpc" => moe_fpc,
        "confidence_level" => confidence, "n" => n, "proportion" => proportion,
        "fpc_applied" => fpc < 1.0,
        "ci" => (proportion - moe_fpc, proportion + moe_fpc),
        "interpretation" => "+/-$(round(moe_fpc * 100, digits=1)) percentage points"
    )
end

function missing_data_analysis(data::Matrix{Union{Float64,Missing}})
    n, k = size(data)
    var_missing = [count(ismissing, data[:, j]) for j in 1:k]
    var_pct = var_missing ./ n .* 100
    case_missing = [count(ismissing, data[i, :]) for i in 1:n]
    total_missing = sum(var_missing)
    total_cells = n * k
    overall_pct = total_missing / total_cells * 100

    mechanism_hint = overall_pct < 5 ? "Low missingness — likely minimal impact" :
                     all(var_pct .< 20) ? "Moderate — consider multiple imputation" :
                     "High — investigate mechanism (MCAR/MAR/MNAR)"

    return Dict{String,Any}(
        "total_missing" => total_missing, "total_cells" => total_cells,
        "overall_pct" => overall_pct,
        "variable_missing" => var_missing, "variable_pct" => var_pct,
        "n_complete_cases" => count(==(0), case_missing),
        "mechanism_hint" => mechanism_hint
    )
end
