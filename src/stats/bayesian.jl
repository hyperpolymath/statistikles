# SPDX-License-Identifier: PMPL-1.0-or-later
# Bayesian statistics — symbolic computation only.

function bayesian_update(prior::Vector{Float64}, likelihood::Matrix{Float64}, data_index::Int)
    prior = prior ./ sum(prior)
    posterior = prior .* likelihood[:, data_index]
    posterior = posterior ./ sum(posterior)
    return Dict{String,Any}(
        "posterior" => posterior, "prior" => prior,
        "evidence" => sum(prior .* likelihood[:, data_index])
    )
end

function bayes_factor_bic(r_squared_full::Float64, r_squared_reduced::Float64,
                          n::Int, p_full::Int, p_reduced::Int)
    bic_full = n * log(1 - r_squared_full) + p_full * log(n)
    bic_reduced = n * log(1 - r_squared_reduced) + p_reduced * log(n)
    log_BF = (bic_reduced - bic_full) / 2
    BF10 = exp(log_BF)
    BF01 = 1 / BF10

    evidence = BF10 > 100 ? "Decisive for H1" : BF10 > 30 ? "Very strong for H1" :
               BF10 > 10 ? "Strong for H1" : BF10 > 3 ? "Moderate for H1" :
               BF10 > 1 ? "Anecdotal for H1" : BF01 > 100 ? "Decisive for H0" :
               BF01 > 30 ? "Very strong for H0" : BF01 > 10 ? "Strong for H0" :
               BF01 > 3 ? "Moderate for H0" : "Anecdotal for H0"

    return Dict{String,Any}(
        "BF10" => BF10, "BF01" => BF01, "log_BF10" => log_BF,
        "evidence" => evidence, "BIC_full" => bic_full, "BIC_reduced" => bic_reduced,
        "note" => "Jeffreys (1961) scale for interpretation"
    )
end

function credible_interval(samples::Vector{Float64}; level::Float64=0.95)
    alpha = 1 - level
    sorted = sort(samples)
    n = length(sorted)
    lower_idx = max(1, ceil(Int, alpha / 2 * n))
    upper_idx = min(n, floor(Int, (1 - alpha / 2) * n))
    eti = (sorted[lower_idx], sorted[upper_idx])

    interval_width = upper_idx - lower_idx
    best_lower = lower_idx
    best_width = eti[2] - eti[1]
    for i in 1:(n - interval_width)
        width = sorted[i + interval_width] - sorted[i]
        if width < best_width
            best_width = width
            best_lower = i
        end
    end
    hdi = (sorted[best_lower], sorted[best_lower + interval_width])

    return Dict{String,Any}(
        "ETI" => eti, "HDI" => hdi, "level" => level,
        "posterior_mean" => mean(samples), "posterior_median" => median(samples),
        "posterior_sd" => std(samples),
        "note" => "HDI = Highest Density Interval (narrowest interval containing $(level*100)% of posterior mass)"
    )
end
