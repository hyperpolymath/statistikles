# SPDX-License-Identifier: PMPL-1.0-or-later
# Advanced estimation — James-Stein estimator. Symbolic computation only.

function james_stein_estimator(observations::Vector{Float64},
                               grand_mean::Union{Float64,Nothing}=nothing)
    n = length(observations)
    if isnothing(grand_mean)
        grand_mean = mean(observations)
    end
    variance = var(observations)
    variance == 0 && return Dict{String,Any}("error" => "Zero variance in observations")

    shrinkage = max(0.0, 1 - (n - 3) / (n * variance))
    estimates = shrinkage * grand_mean .+ (1 - shrinkage) * observations

    return Dict{String,Any}(
        "estimates" => estimates, "shrinkage_factor" => shrinkage,
        "grand_mean" => grand_mean, "original_mean" => mean(observations),
        "improvement" => "Reduces total squared error compared to MLE",
        "note" => "James-Stein dominates MLE for p >= 3 dimensions"
    )
end
