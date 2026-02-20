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
