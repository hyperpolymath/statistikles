# SPDX-License-Identifier: PMPL-1.0-or-later

# Non-Classical Probability — Choquet and Tropical Analysis.
#
# This module implements measures for non-additive and min-plus algebras.

"""
    choquet_integral(values::Vector{Float64}, capacity::Function) -> Float64

CHOQUET INTEGRAL: Integrates a function with respect to a non-additive 
measure (capacity). Used in decision-making under uncertainty.
- `capacity`: A function that takes a set of indices and returns a measure.
"""
function choquet_integral(values::Vector{Float64}, capacity::Function)
    n = length(values)
    idx = sortperm(values)
    sorted_v = values[idx]
    
    integral = sorted_v[1] * capacity(idx)
    for i in 2:n
        integral += (sorted_v[i] - sorted_v[i-1]) * capacity(idx[i:n])
    end
    return integral
end

"""
    tropical_addition(a, b) -> min(a, b)
    tropical_multiplication(a, b) -> a + b

TROPICAL ALGEBRA: Foundation for scheduling and optimization statistics.
"""
function tropical_dot_product(v1::Vector{Float64}, v2::Vector{Float64})
    # multiplication becomes addition, addition becomes minimum
    return minimum(v1 .+ v2)
end

"""
    bell_test_chsh(counts::Dict{String, Int}) -> Float64

BELL TEST (CHSH): Tests the CHSH inequality for quantum entanglement.
Expects counts for (a,b) settings in {0,1}x{0,1}.
"""
function bell_test_chsh(correlations::Vector{Float64})
    # S = E(0,0) - E(0,1) + E(1,0) + E(1,1)
    @assert length(correlations) == 4
    S = correlations[1] - correlations[2] + correlations[3] + correlations[4]
    return S
end
