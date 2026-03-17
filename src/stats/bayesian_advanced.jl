# SPDX-License-Identifier: PMPL-1.0-or-later

# Advanced Bayesian and Mixture Modeling — Iterative Solvers.
#
# This module implements the EM algorithm and MCMC foundations.

"""
    expectation_maximization_normal(data::Vector{Float64}, k::Int; max_iter=100) -> Dict

EM ALGORITHM: Fits a Gaussian Mixture Model (GMM).
- `k`: Number of components.
"""
function expectation_maximization_normal(data::Vector{Float64}, k::Int; max_iter::Int=100)
    n = length(data)
    # Initialize parameters
    mu = sample(data, k; replace=false)
    sigma = fill(std(data), k)
    pi_weights = fill(1/k, k)
    
    responsibilities = zeros(n, k)
    
    for _ in 1:max_iter
        # E-step
        for j in 1:k
            responsibilities[:, j] = pi_weights[j] .* pdf.(Normal(mu[j], sigma[j]), data)
        end
        responsibilities ./= sum(responsibilities, dims=2)
        
        # M-step
        N_j = sum(responsibilities, dims=1)
        for j in 1:k
            mu[j] = sum(responsibilities[:, j] .* data) / N_j[j]
            sigma[j] = sqrt(sum(responsibilities[:, j] .* (data .- mu[j]).^2) / N_j[j])
            pi_weights[j] = N_j[j] / n
        end
    end
    
    return Dict{String, Any}(
        "means" => mu,
        "std_devs" => sigma,
        "weights" => pi_weights,
        "test_type" => "EM Algorithm (Gaussian Mixture)"
    )
end
