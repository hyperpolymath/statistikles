# SPDX-License-Identifier: MPL-2.0

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

"""
    manova_oneway(groups::Vector{Matrix{Float64}}; alpha=0.05) -> Dict

ONE-WAY MANOVA (Multivariate Analysis of Variance).
Tests whether the multivariate means of k groups differ.
Uses Wilks' Lambda with F-approximation.

Each group is a Matrix where rows = observations, columns = dependent variables.
"""
function manova_oneway(groups::Vector{Matrix{Float64}}; alpha::Float64=0.05)
    k = length(groups)
    p = size(groups[1], 2)  # Number of dependent variables
    ns = [size(g, 1) for g in groups]
    N = sum(ns)

    # Grand mean
    all_data = vcat(groups...)
    grand_mean = mean(all_data, dims=1)

    # Between-groups SSCP matrix (H)
    H = zeros(p, p)
    for (i, g) in enumerate(groups)
        group_mean = mean(g, dims=1)
        diff = group_mean .- grand_mean
        H .+= ns[i] .* (diff' * diff)
    end

    # Within-groups SSCP matrix (E)
    E = zeros(p, p)
    for g in groups
        group_mean = mean(g, dims=1)
        centered = g .- group_mean
        E .+= centered' * centered
    end

    # Wilks' Lambda = det(E) / det(E + H)
    E_H = E + H
    det_E = det(E)
    det_EH = det(E_H)
    wilks_lambda = det_EH > 0 ? det_E / det_EH : 0.0

    # Rao's F-approximation for Wilks' Lambda
    df_h = k - 1  # Hypothesis df
    df_e = N - k  # Error df
    s = min(p, df_h)

    # F-approximation (Rao 1951)
    t = sqrt((p^2 * df_h^2 - 4) / (p^2 + df_h^2 - 5))
    t = isnan(t) || t <= 0 ? 1.0 : t

    lambda_1t = wilks_lambda > 0 ? wilks_lambda^(1.0 / t) : 0.0
    df1 = p * df_h
    df2 = (df_e - (p - df_h + 1) / 2) * t - (p * df_h - 2) / 2

    F_stat = df2 > 0 && lambda_1t < 1.0 ? ((1.0 - lambda_1t) / lambda_1t) * (df2 / df1) : 0.0
    p_value = df1 > 0 && df2 > 0 ? 1 - cdf(FDist(df1, df2), F_stat) : 1.0

    # Partial eta-squared
    eta_sq = 1 - wilks_lambda

    return Dict{String,Any}(
        "wilks_lambda" => wilks_lambda,
        "F_statistic" => F_stat,
        "df1" => df1,
        "df2" => df2,
        "p_value" => p_value,
        "significant" => p_value < alpha,
        "partial_eta_squared" => eta_sq,
        "k_groups" => k,
        "p_variables" => p,
        "N_total" => N,
        "test_type" => "One-way MANOVA (Wilks' Lambda with Rao F-approximation)"
    )
end
