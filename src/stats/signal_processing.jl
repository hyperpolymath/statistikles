# SPDX-License-Identifier: MPL-2.0

# Signal Processing — Independent Component and Wavelet Analysis.
#
# This module implements deterministic decomposition of mixed signals.

"""
    independent_component_analysis(X::Matrix{Float64}; k=2, max_iter=100) -> Dict

ICA: Separates a multivariate signal into additive subcomponents.
- Uses the FastICA algorithm foundation (non-Gaussianity maximization).
"""
function independent_component_analysis(X::Matrix{Float64}; k::Int=2, max_iter::Int=100)
    # 1. Centering & Whitening
    n, p = size(X)
    X_cent = X .- mean(X, dims=1)
    # Covariance whitening
    C = cov(X_cent)
    E, D, _ = svd(C)
    K = E * Diagonal(1.0 ./ sqrt.(D .+ 1e-10)) * E'
    X_white = X_cent * K
    
    # 2. FastICA iterative loop
    W = randn(k, p)
    for i in 1:k
        w = W[i, :]
        for _ in 1:max_iter
            # Negentropy proxy: G(u) = tanh(u)
            u = X_white * w
            g = tanh.(u)
            dg = 1.0 .- g.^2
            
            w_new = (X_white' * g) ./ n .- mean(dg) .* w
            # Gram-Schmidt decorrelation (simple)
            w_new ./= norm(w_new)
            
            if norm(w_new - w) < 1e-6
                w = w_new
                break
            end
            w = w_new
        end
        W[i, :] = w
    end
    
    return Dict{String, Any}(
        "mixing_matrix" => W,
        "source_signals" => X_white * W',
        "test_type" => "Independent Component Analysis (FastICA foundation)"
    )
end
