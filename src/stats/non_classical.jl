# SPDX-License-Identifier: MPL-2.0

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
    tropical_mean(data::Vector{Float64}) -> Float64

TROPICAL MEAN (min-plus): The minimum value (identity of tropical addition).
"""
function tropical_mean(data::Vector{Float64})
    return minimum(data)
end

"""
    tropical_matrix_multiply(A::Matrix{Float64}, B::Matrix{Float64}) -> Matrix{Float64}

TROPICAL MATRIX MULTIPLICATION: (A ⊗ B)ᵢⱼ = min_k(Aᵢₖ + Bₖⱼ)
Used for shortest-path problems and scheduling.
"""
function tropical_matrix_multiply(A::Matrix{Float64}, B::Matrix{Float64})
    m, n = size(A)
    n2, p = size(B)
    @assert n == n2 "Inner dimensions must match"
    C = fill(Inf, m, p)
    for i in 1:m, j in 1:p
        for k in 1:n
            C[i, j] = min(C[i, j], A[i, k] + B[k, j])
        end
    end
    return C
end

"""
    tropical_eigenvalue(A::Matrix{Float64}) -> Float64

TROPICAL EIGENVALUE: min cycle mean of the directed graph represented by A.
"""
function tropical_eigenvalue(A::Matrix{Float64})
    n = size(A, 1)
    @assert size(A, 1) == size(A, 2) "Matrix must be square"
    # Karp's algorithm for minimum cycle mean
    d = fill(Inf, n + 1, n)
    d[1, 1] = 0.0
    for k in 1:n
        for i in 1:n, j in 1:n
            if d[k, i] < Inf && A[i, j] < Inf
                d[k + 1, j] = min(d[k + 1, j], d[k, i] + A[i, j])
            end
        end
    end
    λ = Inf
    for j in 1:n
        if d[n + 1, j] < Inf
            max_ratio = -Inf
            for k in 1:n
                if d[k, j] < Inf
                    max_ratio = max(max_ratio, (d[n + 1, j] - d[k, j]) / (n + 1 - k))
                end
            end
            λ = min(λ, max_ratio)
        end
    end
    return λ
end

"""
    bell_test_chsh(correlations::Vector{Float64}) -> Float64

BELL TEST (CHSH): Tests the CHSH inequality for quantum entanglement.
S = E(0,0) - E(0,1) + E(1,0) + E(1,1). Classical bound: |S| ≤ 2.
"""
function bell_test_chsh(correlations::Vector{Float64})
    # S = E(0,0) - E(0,1) + E(1,0) + E(1,1)
    @assert length(correlations) == 4
    S = correlations[1] - correlations[2] + correlations[3] + correlations[4]
    return S
end
