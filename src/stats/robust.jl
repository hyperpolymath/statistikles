# SPDX-License-Identifier: MPL-2.0

# Robust Statistics — Resilient Estimation and Outlier Detection.
#
# This module implements algorithms that are insensitive to outliers 
# and violations of distributional assumptions.

"""
    mahalanobis_distance(X::Matrix{Float64}) -> Vector{Float64}

MAHALANOBIS DISTANCE: Measures how many standard deviations a point is 
from the mean of a distribution, accounting for covariance.
"""
function mahalanobis_distance(X::Matrix{Float64})
    n, p = size(X)
    mu = mean(X, dims=1)
    # Use robust covariance if possible, but OLS here for kernel speed
    S = cov(X)
    S_inv = inv(S)
    
    distances = zeros(n)
    for i in 1:n
        diff = X[i, :] .- mu[:]
        distances[i] = sqrt(diff' * S_inv * diff)
    end
    
    return distances
end

"""
    huber_m_estimator(data::Vector{Float64}; c=1.345, max_iter=100, tol=1e-6) -> Float64

HUBER M-ESTIMATOR: Robust location estimate that blends mean and median.
- `c`: Tuning constant (standard is 1.345 for 95% efficiency).
"""
function huber_m_estimator(data::Vector{Float64}; c::Float64=1.345, max_iter::Int=100, tol::Float64=1e-6)
    mu = median(data)
    sigma = mad(data, normalize=true)
    
    for _ in 1:max_iter
        # Weights: w(z) = 1 if |z| < c, else c/|z|
        z = (data .- mu) ./ sigma
        w = [abs(zi) < c ? 1.0 : c / abs(zi) for zi in z]
        
        mu_new = sum(w .* data) / sum(w)
        if abs(mu_new - mu) < tol
            return mu_new
        end
        mu = mu_new
    end
    
    return mu
end

"""
    ransac_regression(X::Matrix{Float64}, y::Vector{Float64}; n_iters=100, threshold=1.0) -> Dict

RANSAC (Random Sample Consensus): Fits a regression model while 
ignoring outliers through iterative sampling of "inliers".
"""
function ransac_regression(X::Matrix{Float64}, y::Vector{Float64}; n_iters::Int=100, threshold::Float64=1.0)
    n, p = size(X)
    best_model = nothing
    best_inliers = Int[]
    
    for _ in 1:n_iters
        # Sample minimum points for a model
        idx = sample(1:n, p + 1; replace=false)
        X_sub, y_sub = X[idx, :], y[idx]
        
        # Fit model
        beta = hcat(ones(p+1), X_sub) \ y_sub
        
        # Find inliers
        y_pred = hcat(ones(n), X) * beta
        residuals = abs.(y .- y_pred)
        inliers = findall(<(threshold), residuals)
        
        if length(inliers) > length(best_inliers)
            best_inliers = inliers
            best_model = beta
        end
    end
    
    return Dict{String, Any}(
        "coefficients" => best_model,
        "n_inliers" => length(best_inliers),
        "inlier_indices" => best_inliers,
        "test_type" => "RANSAC Robust Regression"
    )
end
