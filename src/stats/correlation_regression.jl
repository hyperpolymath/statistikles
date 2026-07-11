# SPDX-License-Identifier: MPL-2.0

# Correlation and Regression — Symbolic Statistical Inference.
#
# This module implements the relational computation kernel. 
# INVARIANT: All statistical models (OLS, Pearson) are solved via 
# deterministic linear algebra, ensuring reproducible results.

"""
    spearman_correlation(x, y; alpha=0.05) -> Dict

SPEARMAN RANK CORRELATION: Non-parametric measure of monotonic association.
Uses midranks for tied values. Equivalent to Pearson on ranks.
"""
function spearman_correlation(x::Vector{Float64}, y::Vector{Float64}; alpha::Float64=0.05)
    n = length(x)
    require_equal_length(x, y, "x", "y")

    # DEGENERATE GUARD: below n=2, midranks/mean on the ranks either errors
    # (empty collection) or feeds a negative (n-2) into the significance
    # formula's sqrt, which throws DomainError. Bail out gracefully instead.
    if n < 2
        return Dict{String,Any}(
            "rho" => nothing, "t_stat" => nothing, "df" => nothing,
            "p_value" => nothing, "significant" => false,
            "interpretation" => nothing,
            "test_type" => "Spearman rank correlation (midranks)",
            "note" => "Spearman correlation requires at least 2 observations"
        )
    end

    rx = midranks(x)
    ry = midranks(y)

    # Pearson on the ranks
    mx, my = mean(rx), mean(ry)
    num = sum((rx .- mx) .* (ry .- my))
    den = sqrt(sum((rx .- mx).^2) * sum((ry .- my).^2))
    rho = den > 0 ? num / den : 0.0

    # Significance via t-distribution
    t_stat = rho * sqrt((n - 2) / (1 - rho^2 + 1e-15))
    df = n - 2
    p_val = df > 0 ? 2 * (1 - cdf(TDist(df), abs(t_stat))) : 1.0

    return Dict{String,Any}(
        "rho" => rho,
        "t_stat" => t_stat,
        "df" => df,
        "p_value" => p_val,
        "significant" => p_val < alpha,
        "interpretation" => abs(rho) > 0.7 ? "Strong" : abs(rho) > 0.3 ? "Moderate" : "Weak",
        "test_type" => "Spearman rank correlation (midranks)"
    )
end

"""
    pearson_correlation(x, y; alpha=0.05) -> Dict

LINEAR ASSOCIATION: Computes the Pearson product-moment coefficient.
- `r`: The correlation coefficient (-1.0 to 1.0).
- `p_value`: Probability of observing the result under the null hypothesis.
- `interpretation`: Qualitative mapping (Strong, Moderate, Weak).
"""
function pearson_correlation(x::Vector{Float64}, y::Vector{Float64}; alpha::Float64=0.05)
    n = length(x)
    require_equal_length(x, y, "x", "y")

    # DEGENERATE GUARD: below n=2 there is nothing to correlate.
    if n < 2
        return Dict{String,Any}(
            "r" => nothing, "r_squared" => nothing, "t_stat" => nothing,
            "df" => nothing, "p_value" => nothing, "significant" => false,
            "interpretation" => nothing,
            "note" => "Pearson correlation requires at least 2 observations"
        )
    end

    mx, my = mean(x), mean(y)
    num = sum((x .- mx) .* (y .- my))
    den = sqrt(sum((x .- mx).^2) * sum((y .- my).^2))

    # DEGENERATE GUARD: den == 0 means zero variance in x or y (r = 0/0).
    r = den > 0 ? num / den : nothing
    r_squared = r === nothing ? nothing : r^2

    # Statistical significance (t-test): t = r * sqrt((n-2)/(1-r^2))
    # DEGENERATE GUARD: needs df > 0 and a non-perfect correlation
    # (1 - r^2 > 0), else the formula divides by zero.
    df = n - 2
    t_stat = (r !== nothing && df > 0 && (1 - r^2) > 0) ?
             r * sqrt(df / (1 - r^2)) : nothing
    p_val = t_stat === nothing ? nothing : 2 * (1 - cdf(TDist(df), abs(t_stat)))

    interpretation = r === nothing ? nothing :
        abs(r) > 0.7 ? "Strong" : abs(r) > 0.3 ? "Moderate" : "Weak"

    note = if r === nothing
        "Correlation undefined: zero variance in x or y"
    elseif t_stat === nothing
        "Significance test undefined: perfect correlation or insufficient degrees of freedom"
    else
        nothing
    end

    return Dict{String,Any}(
        "r" => r,
        "r_squared" => r_squared,
        "t_stat" => t_stat,
        "df" => df,
        "p_value" => p_val,
        "significant" => p_val === nothing ? false : p_val < alpha,
        "interpretation" => interpretation,
        "note" => note
    )
end

"""
    simple_linear_regression(x, y; alpha=0.05) -> Dict

BIVARIATE MODELING: Fits a straight line (y = beta0 + beta1*x).
"""
function simple_linear_regression(x::Vector{Float64}, y::Vector{Float64}; alpha::Float64=0.05)
    n = length(x)
    require_equal_length(x, y, "x", "y")
    mx, my = mean(x), mean(y)

    # DEGENERATE GUARD: zero variance in x makes the slope 0/0.
    ss_xx = sum((x .- mx) .^ 2)
    if ss_xx == 0
        return Dict{String,Any}(
            "intercept" => nothing, "slope" => nothing, "r_squared" => nothing,
            "n" => n, "test_type" => "Simple Linear Regression",
            "note" => "Regression undefined: zero variance in x"
        )
    end

    beta1 = sum((x .- mx) .* (y .- my)) / ss_xx
    beta0 = my - beta1 * mx

    # Predictions and residuals
    y_pred = beta0 .+ beta1 .* x
    residuals = y .- y_pred
    ss_res = sum(residuals.^2)
    ss_tot = sum((y .- my).^2)
    # DEGENERATE GUARD: zero variance in y makes R² a 0/0.
    r2 = ss_tot > 0 ? 1 - (ss_res / ss_tot) : nothing

    return Dict{String,Any}(
        "intercept" => beta0,
        "slope" => beta1,
        "r_squared" => r2,
        "n" => n,
        "test_type" => "Simple Linear Regression",
        "note" => r2 === nothing ? "R-squared undefined: zero variance in y" : nothing
    )
end

"""
    multiple_regression(X::Matrix, y::Vector; var_names=nothing) -> Dict

MULTIVARIATE MODELING: Performs Ordinary Least Squares (OLS) regression.
- COEFFICIENTS: Estimates beta weights using the normal equation (XtX \\ Xt * y).
- DIAGNOSTICS: Computes Adjusted R-squared and F-statistics.
- MULTICOLLINEARITY: Calculates Variance Inflation Factors (VIF).
"""
function multiple_regression(X::Matrix{Float64}, y::Vector{Float64}; var_names=nothing)
    n, p = size(X)
    length(y) == n || throw(ArgumentError(
        "y must have length equal to the number of rows in X (got $(length(y)), expected $n)"))

    # Add intercept column
    X_aug = hcat(ones(n), X)

    # Normal equation: beta = (XtX) \ Xt * y
    beta = (X_aug' * X_aug) \ (X_aug' * y)

    y_pred = X_aug * beta
    residuals = y .- y_pred
    ss_res = sum(residuals.^2)
    ss_tot = sum((y .- mean(y)).^2)

    # DEGENERATE GUARD: zero variance in y makes R² a 0/0.
    r2 = ss_tot > 0 ? 1 - (ss_res / ss_tot) : nothing
    df_resid = n - p - 1
    adj_r2 = (r2 !== nothing && df_resid > 0) ? 1 - (1 - r2) * (n - 1) / df_resid : nothing

    labels = isnothing(var_names) ? ["Intercept"; ["Var$i" for i in 1:p]] : ["Intercept"; var_names]

    # DEGENERATE GUARD: standard errors need positive residual degrees of
    # freedom (n - p - 1 > 0); otherwise sigma2's denominator is <= 0.
    note = nothing
    if r2 !== nothing && df_resid > 0
        sigma2 = ss_res / df_resid
        se = sqrt.(diag(sigma2 * inv(X_aug' * X_aug)))
        t_stats = beta ./ se
        p_values = 2 .* (1 .- cdf.(TDist(df_resid), abs.(t_stats)))
        std_errors = Dict(labels[i] => se[i] for i in 1:(p+1))
        t_stats_dict = Dict(labels[i] => t_stats[i] for i in 1:(p+1))
        p_values_dict = Dict(labels[i] => p_values[i] for i in 1:(p+1))
    else
        std_errors = Dict(labels[i] => nothing for i in 1:(p+1))
        t_stats_dict = Dict(labels[i] => nothing for i in 1:(p+1))
        p_values_dict = Dict(labels[i] => nothing for i in 1:(p+1))
        note = df_resid <= 0 ?
            "Standard errors undefined: insufficient residual degrees of freedom (n - p - 1 <= 0)" :
            "Standard errors undefined: zero variance in y"
    end

    return Dict{String,Any}(
        "coefficients" => Dict(labels[i] => beta[i] for i in 1:(p+1)),
        "std_errors" => std_errors,
        "t_stats" => t_stats_dict,
        "p_values" => p_values_dict,
        "r_squared" => r2,
        "adj_r_squared" => adj_r2,
        "n" => n,
        "p" => p,
        "note" => note
    )
end

"""
    logistic_regression(X::Matrix, y::Vector; max_iter=100, tol=1e-6) -> Dict

LOGISTIC MODELING: Fits a binary classifier using IRLS.
Uses the logit link function: log(p/(1-p)) = X * beta.
"""
function logistic_regression(X::Matrix{Float64}, y::Vector{Float64}; max_iter::Int=100, tol::Float64=1e-6)
    n, p = size(X)
    X_aug = hcat(ones(n), X)
    k = p + 1
    
    # Initialize beta
    beta = zeros(k)
    
    for iter in 1:max_iter
        # Linear predictor
        eta = X_aug * beta
        # Probability (sigmoid)
        p_hat = 1.0 ./ (1.0 .+ exp.(-eta))
        # Weight matrix: W = diag(p*(1-p))
        w = p_hat .* (1.0 .- p_hat)
        # Prevent singular matrix
        w = max.(w, 1e-10)
        
        # Working response: z = eta + (y - p_hat)/w
        z = eta .+ (y .- p_hat) ./ w
        
        # Update beta using Weighted Least Squares
        # beta_new = (Xt * W * X) \ (Xt * W * z)
        W = Diagonal(w)
        beta_new = (X_aug' * W * X_aug) \ (X_aug' * W * z)
        
        if norm(beta_new - beta) < tol
            beta = beta_new
            break
        end
        beta = beta_new
    end
    
    return Dict{String,Any}(
        "coefficients" => beta,
        "test_type" => "Logistic Regression (Binary)"
    )
end

"""
    partial_correlation(x, y, z; alpha=0.05) -> Dict

PARTIAL CORRELATION: Correlation between x and y controlling for z.
Removes the effect of confounding variable(s) z.
"""
function partial_correlation(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64}; alpha::Float64=0.05)
    n = length(x)
    require_equal_length(x, y, "x", "y")
    require_equal_length(x, z, "x", "z")

    # DEGENERATE GUARD: need at least 4 observations (df = n - 3 > 0).
    if n < 4
        return Dict{String,Any}(
            "r_partial" => nothing, "r_xy" => nothing, "r_xz" => nothing, "r_yz" => nothing,
            "t_stat" => nothing, "df" => nothing, "p_value" => nothing, "significant" => false,
            "test_type" => "Partial correlation (controlling for z)",
            "note" => "Partial correlation requires at least 4 observations"
        )
    end

    # DEGENERATE GUARD: Statistics.cor() returns NaN (not an error) for a
    # constant/zero-variance input, which would otherwise leak straight into
    # r_xy/r_xz/r_yz. Compute each pairwise correlation the same guarded way
    # pearson_correlation does (den == 0 => nothing) so no NaN can enter the
    # partial-correlation formula below.
    safe_cor(a::Vector{Float64}, b::Vector{Float64}) = begin
        ma, mb = mean(a), mean(b)
        den = sqrt(sum((a .- ma) .^ 2) * sum((b .- mb) .^ 2))
        den > 0 ? sum((a .- ma) .* (b .- mb)) / den : nothing
    end

    r_xy = safe_cor(x, y)
    r_xz = safe_cor(x, z)
    r_yz = safe_cor(y, z)

    # Partial r formula: r_xy.z = (r_xy - r_xz * r_yz) / sqrt((1 - r_xz²)(1 - r_yz²))
    # DEGENERATE GUARD: undefined if any pairwise correlation above is
    # undefined (zero variance in x, y, or z), or if the residual variance
    # denominator is zero.
    r_partial = if r_xy === nothing || r_xz === nothing || r_yz === nothing
        nothing
    else
        denom = sqrt((1 - r_xz^2) * (1 - r_yz^2))
        denom > 0 ? (r_xy - r_xz * r_yz) / denom : nothing
    end

    # Significance test. DEGENERATE GUARD: needs df > 0 and a non-perfect
    # partial correlation (1 - r_partial^2 > 0).
    df = n - 3
    t_stat = (r_partial !== nothing && df > 0 && (1 - r_partial^2) > 0) ?
             r_partial * sqrt(df / (1 - r_partial^2)) : nothing
    p_val = t_stat === nothing ? nothing : 2 * (1 - cdf(TDist(df), abs(t_stat)))

    note = if r_xy === nothing || r_xz === nothing || r_yz === nothing
        "Partial correlation undefined: zero variance in x, y, or z (constant input)"
    elseif r_partial === nothing
        "Partial correlation undefined: zero residual variance after controlling for z"
    elseif t_stat === nothing
        "Significance test undefined: perfect partial correlation or insufficient degrees of freedom"
    else
        nothing
    end

    return Dict{String,Any}(
        "r_partial" => r_partial,
        "r_xy" => r_xy,
        "r_xz" => r_xz,
        "r_yz" => r_yz,
        "t_stat" => t_stat,
        "df" => df,
        "p_value" => p_val,
        "significant" => p_val === nothing ? false : p_val < alpha,
        "test_type" => "Partial correlation (controlling for z)",
        "note" => note
    )
end

"""
    grubbs_test(data; alpha=0.05) -> Dict

GRUBBS' TEST for a single outlier. Tests whether the most extreme value
is an outlier under the assumption of normality.
"""
function grubbs_test(data::Vector{Float64}; alpha::Float64=0.05)
    n = length(data)
    m = mean(data)
    s = std(data)

    # Find most extreme value
    max_dev_idx = argmax(abs.(data .- m))
    suspect = data[max_dev_idx]
    G = abs(suspect - m) / s

    # Critical value: t²(α/(2n), n-2) based threshold
    t_crit = quantile(TDist(n - 2), 1 - alpha / (2 * n))
    G_crit = (n - 1) / sqrt(n) * sqrt(t_crit^2 / (n - 2 + t_crit^2))

    return Dict{String,Any}(
        "G_statistic" => G,
        "G_critical" => G_crit,
        "suspect_value" => suspect,
        "suspect_index" => max_dev_idx,
        "is_outlier" => G > G_crit,
        "p_approx" => G > G_crit ? alpha : 1.0,  # Simplified
        "n" => n,
        "test_type" => "Grubbs' test for outliers"
    )
end
