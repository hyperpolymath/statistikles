# SPDX-License-Identifier: MPL-2.0

# Representations — Compositional and Interval Data Analysis.
#
# This module implements Aitchison geometry for simplex data and 
# interval arithmetic foundations.

"""
    centered_log_ratio(x::Vector{Float64}) -> Vector{Float64}

CLR TRANSFORM: Maps compositional data from the simplex to Euclidean space.
- `x`: Input composition (must sum to constant, e.g., 1.0).
"""
function centered_log_ratio(x::Vector{Float64})
    @assert all(x .> 0) "Compositional data must be positive"
    g = exp(mean(log.(x))) # Geometric mean
    return log.(x ./ g)
end

"""
    interval_overlap_test(a::Tuple{Float64, Float64}, b::Tuple{Float64, Float64}) -> Dict

INTERVAL HYPOTHESIS: Tests whether two intervals overlap or if one is 
contained within another.
"""
function interval_overlap_test(a::Tuple{Float64, Float64}, b::Tuple{Float64, Float64})
    overlap = max(0.0, min(a[2], b[2]) - max(a[1], b[1]))
    contained = (a[1] >= b[1] && a[2] <= b[2]) || (b[1] >= a[1] && b[2] <= a[2])
    
    return Dict{String, Any}(
        "overlap_width" => overlap,
        "is_contained" => contained,
        "is_disjoint" => overlap == 0.0,
        "test_type" => "Interval Relationship Test"
    )
end
