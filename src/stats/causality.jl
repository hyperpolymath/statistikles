# SPDX-License-Identifier: PMPL-1.0-or-later
# Causal inference — Granger causality. Symbolic computation only.

function granger_causality_test(x::Vector{Float64}, y::Vector{Float64}, lag::Int=1)
    n = length(x)
    n != length(y) && return Dict{String,Any}("error" => "Series must have same length")
    n <= 2 * lag + 1 && return Dict{String,Any}("error" => "Series too short for lag=$lag")

    # Create lagged matrices
    Y_lag = zeros(n - lag, lag)
    X_lag = zeros(n - lag, lag)
    for i in 1:lag
        Y_lag[:, i] = y[i:n-lag+i-1]
        X_lag[:, i] = x[i:n-lag+i-1]
    end
    y_test = y[lag+1:end]

    # Restricted model: Y on Y_lag only
    Y_aug_r = hcat(ones(n - lag), Y_lag)
    beta_r = Y_aug_r \ y_test
    resid_r = y_test .- Y_aug_r * beta_r
    RSS_r = sum(resid_r .^ 2)

    # Unrestricted model: Y on Y_lag + X_lag
    Y_aug_u = hcat(ones(n - lag), Y_lag, X_lag)
    beta_u = Y_aug_u \ y_test
    resid_u = y_test .- Y_aug_u * beta_u
    RSS_u = sum(resid_u .^ 2)

    df1 = lag
    df2 = n - lag - 2 * lag - 1
    df2 = max(df2, 1)
    F_stat = ((RSS_r - RSS_u) / df1) / (RSS_u / df2)
    p_value = 1 - cdf(FDist(df1, df2), max(F_stat, 0.0))

    return Dict{String,Any}(
        "F_statistic" => F_stat, "p_value" => p_value, "lag" => lag,
        "reject_null" => p_value < 0.05,
        "interpretation" => p_value < 0.05 ? "X Granger-causes Y" : "No Granger causality detected",
        "RSS_restricted" => RSS_r, "RSS_unrestricted" => RSS_u
    )
end

"""
    instrumental_variables(y, x, z) -> Dict

2SLS (Two-Stage Least Squares): Estimates causal effects when regressors 
are correlated with error terms.
- `y`: Dependent variable.
- `x`: Endogenous regressor.
- `z`: Instrument (correlated with x but not with y's error).
"""
function instrumental_variables(y::Vector{Float64}, x::Vector{Float64}, z::Vector{Float64})
    n = length(y)
    Z = hcat(ones(n), z)
    X = hcat(ones(n), x)
    
    # Stage 1: Regress x on z to get x_hat
    beta1 = (Z' * Z) \ (Z' * x)
    x_hat = Z * beta1
    
    # Stage 2: Regress y on x_hat
    X_hat = hcat(ones(n), x_hat)
    beta2 = (X_hat' * X_hat) \ (X_hat' * y)
    
    return Dict{String, Any}(
        "coefficients" => beta2,
        "test_type" => "2SLS Instrumental Variables"
    )
end

"""
    difference_in_differences(y, treat, post) -> Dict

DiD: Estimates causal effect by comparing changes over time between groups.
- `y`: Outcome.
- `treat`: Boolean (1 if treatment group).
-Post`: Boolean (1 if after treatment).
"""
function difference_in_differences(y::Vector{Float64}, treat::Vector{Int}, post::Vector{Int})
    n = length(y)
    # Interaction term
    inter = treat .* post
    
    X = hcat(ones(n), treat, post, inter)
    beta = X \ y
    
    return Dict{String, Any}(
        "did_estimate" => beta[4],
        "coefficients" => beta,
        "test_type" => "Difference-in-Differences"
    )
end

"""
    regression_discontinuity(y, x, threshold) -> Dict

RDD: Estimates causal effect at a sharp cutoff.
"""
function regression_discontinuity(y::Vector{Float64}, x::Vector{Float64}, threshold::Float64)
    # D = 1 if x >= threshold
    D = [xi >= threshold ? 1.0 : 0.0 for xi in x]
    # Center x at threshold
    x_centered = x .- threshold
    
    X = hcat(ones(length(y)), x_centered, D, x_centered .* D)
    beta = X \ y
    
    return Dict{String, Any}(
        "treatment_effect" => beta[3],
        "coefficients" => beta,
        "test_type" => "Sharp Regression Discontinuity"
    )
end
