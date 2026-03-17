# SPDX-License-Identifier: PMPL-1.0-or-later
# Advanced estimation — James-Stein and MLE. Symbolic computation only.

"""
    james_stein_estimator(observations, grand_mean=nothing) -> Dict

Shrinkage estimator that improves upon MLE for 3 or more dimensions.
"""
function james_stein_estimator(observations::Vector{Float64},
                               grand_mean::Union{Float64,Nothing}=nothing)
    n = length(observations)
    if isnothing(grand_mean)
        grand_mean = mean(observations)
    end
    variance = var(observations)
    variance == 0 && return Dict{String,Any}("error" => "Zero variance in observations")

    shrinkage = max(0.0, 1 - (n - 3) / (n * variance))
    estimates = shrinkage * grand_mean .+ (1 - shrinkage) * observations

    return Dict{String,Any}(
        "estimates" => estimates, "shrinkage_factor" => shrinkage,
        "grand_mean" => grand_mean, "original_mean" => mean(observations),
        "improvement" => "Reduces total squared error compared to MLE",
        "note" => "James-Stein dominates MLE for p >= 3 dimensions"
    )
end

"""
    mle_fit(data::Vector{Float64}, dist_type::String) -> Dict

MAXIMUM LIKELIHOOD ESTIMATION: Finds parameters that maximize the log-likelihood.
Supported distributions: "normal", "poisson", "exponential".
"""
function mle_fit(data::Vector{Float64}, dist_type::String="normal")
    n = length(data)
    
    if dist_type == "normal"
        # Analytic solution for Normal: mu = mean, sigma = std(pop)
        mu_mle = mean(data)
        sigma_mle = sqrt(sum((data .- mu_mle).^2) / n)
        log_lk = sum(logpdf.(Normal(mu_mle, sigma_mle), data))
        
        return Dict{String,Any}(
            "mu" => mu_mle,
            "sigma" => sigma_mle,
            "log_likelihood" => log_lk,
            "dist" => "Normal"
        )
        
    elseif dist_type == "poisson"
        # Analytic solution for Poisson: lambda = mean
        lambda_mle = mean(data)
        log_lk = sum(logpdf.(Poisson(lambda_mle), data))
        
        return Dict{String,Any}(
            "lambda" => lambda_mle,
            "log_likelihood" => log_lk,
            "dist" => "Poisson"
        )
        
    elseif dist_type == "exponential"
        # Analytic solution for Exponential: lambda = 1/mean
        lambda_mle = 1.0 / mean(data)
        log_lk = sum(logpdf.(Exponential(1.0 / lambda_mle), data))
        
        return Dict{String,Any}(
            "lambda" => lambda_mle,
            "log_likelihood" => log_lk,
            "dist" => "Exponential"
        )
    else
        return Dict{String,Any}("error" => "Unsupported distribution type: $dist_type")
    end
end
