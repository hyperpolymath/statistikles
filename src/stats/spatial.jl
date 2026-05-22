# SPDX-License-Identifier: MPL-2.0

# Spatial Statistics — Geographic Correlation and Regression.
#
# This module implements measures of spatial dependency and local modeling.

"""
    morans_i(x::Vector{Float64}, W::Matrix{Float64}) -> Dict

MORAN'S I: Measures global spatial autocorrelation.
- `x`: Variable of interest.
- `W`: Spatial weights matrix (contiguity or distance-based).
"""
function morans_i(x::Vector{Float64}, W::Matrix{Float64})
    n = length(x)
    @assert size(W) == (n, n)
    
    z = x .- mean(x)
    S0 = sum(W)
    
    numerator = n * sum(W .* (z * z'))
    denominator = S0 * sum(z .^ 2)
    
    I = numerator / denominator
    
    # Expected value under null: E(I) = -1 / (n - 1)
    ei = -1 / (n - 1)
    
    return Dict{String, Any}(
        "morans_i" => I,
        "expected_i" => ei,
        "test_type" => "Global Moran's I"
    )
end

"""
    gwr_basic(y::Vector{Float64}, X::Matrix{Float64}, coords::Matrix{Float64}; bw=1.0) -> Dict

GEOGRAPHICALLY WEIGHTED REGRESSION: Fits local models for each location.
- `coords`: [n x 2] matrix of Lat/Lon or X/Y coordinates.
- `bw`: Bandwidth for the kernel.
"""
function gwr_basic(y::Vector{Float64}, X::Matrix{Float64}, coords::Matrix{Float64}; bw::Float64=1.0)
    n, p = size(X)
    X_aug = hcat(ones(n), X)
    local_betas = zeros(n, p + 1)
    
    for i in 1:n
        # Compute weights based on distance to point i
        dists = [sqrt(sum((coords[i, :] .- coords[j, :]).^2)) for j in 1:n]
        # Gaussian kernel: w = exp(-0.5 * (d/bw)^2)
        w = exp.(-0.5 .* (dists ./ bw).^2)
        W = Diagonal(w)
        
        # Local WLS: beta = (Xt W X) \ Xt W y
        beta = (X_aug' * W * X_aug) \ (X_aug' * W * y)
        local_betas[i, :] = beta
    end
    
    return Dict{String, Any}(
        "local_coefficients" => local_betas,
        "test_type" => "Geographically Weighted Regression (Fixed Bandwidth)"
    )
end
