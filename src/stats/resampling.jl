# SPDX-License-Identifier: MPL-2.0

# Resampling Methods — Bootstrapping and Jackknife.
#
# This module provides auditable empirical confidence intervals.

"""
    bootstrap_ci(data::Vector{Float64}, stat_fn::Function; n_reps=1000, alpha=0.05) -> Dict

BOOTSTRAPPING: Generates empirical CI for any provided statistic.
- `stat_fn`: Function to compute the statistic (e.g., mean, median).
- `n_reps`: Number of bootstrap replicates.
"""
function bootstrap_ci(data::Vector{Float64}, stat_fn::Function; n_reps::Int=1000, alpha::Float64=0.05)
    n = length(data)
    reps = zeros(n_reps)
    
    for i in 1:n_reps
        resample = sample(data, n; replace=true)
        reps[i] = stat_fn(resample)
    end
    
    sorted_reps = sort(reps)
    lower_idx = max(1, floor(Int, (alpha / 2) * n_reps))
    upper_idx = min(n_reps, ceil(Int, (1 - alpha / 2) * n_reps))
    
    return Dict{String, Any}(
        "observed_stat" => stat_fn(data),
        "ci_lower" => sorted_reps[lower_idx],
        "ci_upper" => sorted_reps[upper_idx],
        "n_reps" => n_reps,
        "alpha" => alpha,
        "test_type" => "Bootstrap Confidence Interval"
    )
end
