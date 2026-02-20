# SPDX-License-Identifier: PMPL-1.0-or-later
# Correlation and regression — symbolic computation only.

function pearson_correlation(x::Vector{Float64}, y::Vector{Float64}; alpha::Float64=0.05)
    n = length(x)
    n != length(y) && return Dict{String,Any}("error" => "Vectors must have same length")
    r = cor(x, y)
    t_stat = r * sqrt((n - 2) / (1 - r^2))
    p_value = 2 * (1 - cdf(TDist(n - 2), abs(t_stat)))
    z = atanh(r)
    se_z = 1 / sqrt(n - 3)
    ci = (tanh(z - 1.96 * se_z), tanh(z + 1.96 * se_z))
    r_interp = abs(r) >= 0.7 ? "Strong" : abs(r) >= 0.4 ? "Moderate" :
               abs(r) >= 0.2 ? "Weak" : "Negligible"

    return Dict{String,Any}(
        "r" => r, "r_squared" => r^2, "t_statistic" => t_stat,
        "df" => n - 2, "p_value" => p_value, "significant" => p_value < alpha,
        "ci_95" => ci, "interpretation" => r_interp,
        "direction" => r > 0 ? "Positive" : "Negative", "n" => n,
        "coefficient_of_determination" => "$(round(r^2 * 100, digits=1))% of variance explained"
    )
end

function spearman_correlation(x::Vector{Float64}, y::Vector{Float64}; alpha::Float64=0.05)
    n = length(x)
    rx = ordinalrank(x)
    ry = ordinalrank(y)
    rho = cor(Float64.(rx), Float64.(ry))
    t_stat = rho * sqrt((n - 2) / (1 - rho^2))
    p_value = 2 * (1 - cdf(TDist(n - 2), abs(t_stat)))

    return Dict{String,Any}(
        "rho" => rho, "t_statistic" => t_stat, "df" => n - 2,
        "p_value" => p_value, "significant" => p_value < alpha,
        "n" => n, "test_type" => "Spearman rank correlation"
    )
end

function simple_linear_regression(x::Vector{Float64}, y::Vector{Float64})
    n = length(x)
    n != length(y) && return Dict{String,Any}("error" => "Vectors must have same length")
    xm, ym = mean(x), mean(y)
    SS_xy = sum((x .- xm) .* (y .- ym))
    SS_xx = sum((x .- xm) .^ 2)
    b1 = SS_xy / SS_xx
    b0 = ym - b1 * xm
    y_pred = b0 .+ b1 .* x
    residuals = y .- y_pred
    SSR = sum((y_pred .- ym) .^ 2)
    SSE = sum(residuals .^ 2)
    SST = sum((y .- ym) .^ 2)
    r_sq = SSR / SST
    adj_r_sq = 1 - (1 - r_sq) * (n - 1) / (n - 2)
    MSE = SSE / (n - 2)
    se_b1 = sqrt(MSE / SS_xx)
    se_b0 = sqrt(MSE * (1 / n + xm^2 / SS_xx))
    t_b1 = b1 / se_b1
    t_b0 = b0 / se_b0
    p_b1 = 2 * (1 - cdf(TDist(n - 2), abs(t_b1)))
    p_b0 = 2 * (1 - cdf(TDist(n - 2), abs(t_b0)))
    F_stat = (SSR / 1) / (SSE / (n - 2))
    p_F = 1 - cdf(FDist(1, n - 2), F_stat)

    return Dict{String,Any}(
        "intercept" => Dict("estimate" => b0, "se" => se_b0, "t" => t_b0, "p" => p_b0),
        "slope" => Dict("estimate" => b1, "se" => se_b1, "t" => t_b1, "p" => p_b1),
        "r_squared" => r_sq, "adj_r_squared" => adj_r_sq,
        "F_statistic" => F_stat, "F_p_value" => p_F,
        "residual_se" => sqrt(MSE),
        "SS_regression" => SSR, "SS_error" => SSE, "SS_total" => SST,
        "n" => n,
        "equation" => "y = $(round(b0, digits=4)) + $(round(b1, digits=4))x",
        "interpretation" => "For each unit increase in x, y changes by $(round(b1, digits=4))"
    )
end

function multiple_regression(X::Matrix{Float64}, y::Vector{Float64};
                            var_names::Union{Vector{String},Nothing}=nothing)
    n, p = size(X)
    X_aug = hcat(ones(n), X)
    k = p + 1
    XtX = X_aug' * X_aug
    beta = XtX \ (X_aug' * y)
    y_pred = X_aug * beta
    ym = mean(y)
    SSR = sum((y_pred .- ym) .^ 2)
    SSE = sum((y .- y_pred) .^ 2)
    SST = sum((y .- ym) .^ 2)
    r_sq = SSR / SST
    adj_r_sq = 1 - (1 - r_sq) * (n - 1) / (n - k)
    MSE = SSE / (n - k)
    F_stat = (SSR / p) / MSE
    p_F = 1 - cdf(FDist(p, n - k), F_stat)
    var_beta = MSE * inv(XtX)
    se_beta = sqrt.(diag(var_beta))
    t_stats = beta ./ se_beta
    p_values = [2 * (1 - cdf(TDist(n - k), abs(t))) for t in t_stats]

    vifs = Float64[]
    for j in 1:p
        other = setdiff(1:p, j)
        if !isempty(other)
            X_o = hcat(ones(n), X[:, other])
            bj = X_o \ X[:, j]
            pj = X_o * bj
            r2j = 1 - sum((X[:, j] .- pj) .^ 2) / sum((X[:, j] .- mean(X[:, j])) .^ 2)
            push!(vifs, 1 / (1 - r2j))
        else
            push!(vifs, 1.0)
        end
    end

    if isnothing(var_names)
        var_names = ["X$i" for i in 1:p]
    end

    coefficients = [Dict("variable" => "intercept", "estimate" => beta[1],
                         "se" => se_beta[1], "t" => t_stats[1], "p" => p_values[1])]
    for i in 1:p
        push!(coefficients, Dict("variable" => var_names[i], "estimate" => beta[i+1],
                                 "se" => se_beta[i+1], "t" => t_stats[i+1],
                                 "p" => p_values[i+1], "VIF" => vifs[i]))
    end

    mc_warn = any(v -> v > 10, vifs) ? "WARNING: VIF > 10 — multicollinearity present" :
              any(v -> v > 5, vifs) ? "CAUTION: VIF > 5 — moderate multicollinearity" :
              "No multicollinearity concerns"

    return Dict{String,Any}(
        "coefficients" => coefficients,
        "r_squared" => r_sq, "adj_r_squared" => adj_r_sq,
        "F_statistic" => F_stat, "F_p_value" => p_F,
        "residual_se" => sqrt(MSE), "n" => n, "p_predictors" => p,
        "multicollinearity" => mc_warn, "VIFs" => vifs
    )
end
