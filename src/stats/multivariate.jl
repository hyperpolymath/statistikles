# SPDX-License-Identifier: PMPL-1.0-or-later

# Multivariate Analysis — PCA and Exploratory Factor Analysis.
#
# This module implements deterministic dimensionality reduction algorithms.

"""
    pca(X::Matrix{Float64}; n_components=nothing) -> Dict

PRINCIPAL COMPONENT ANALYSIS: Computes orthogonal transformations.
- `components`: The principal axes (eigenvectors).
- `explained_variance`: Variance explained by each component.
- `cumulative_variance`: Running total of explained variance.
"""
function pca(X::Matrix{Float64}; n_components::Union{Int, Nothing}=nothing)
    n, p = size(X)
    # Center the data
    X_centered = X .- mean(X, dims=1)
    
    # SVD decomposition
    U, S, V = svd(X_centered)
    
    # Variance explained
    variances = (S.^2) ./ (n - 1)
    total_var = sum(variances)
    explained_var_ratio = variances ./ total_var
    cum_var_ratio = cumsum(explained_var_ratio)
    
    k = isnothing(n_components) ? p : min(n_components, p)
    
    return Dict{String, Any}(
        "components" => V[:, 1:k],
        "explained_variance_ratio" => explained_var_ratio[1:k],
        "cumulative_variance_ratio" => cum_var_ratio[1:k],
        "n_components" => k,
        "test_type" => "Principal Component Analysis"
    )
end
