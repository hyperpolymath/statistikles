# SPDX-License-Identifier: MPL-2.0
# ZeroProb.jl Integration — Zero-probability event handling.
#
# Extends BetLang's ternary bets with proper handling of events that
# have probability 0 but are not impossible (measure-zero events).

"""
    zero_inflated_bet(a, b, c, zero_prob) -> Any

BetLang bet where outcome `c` has a zero-inflated probability.
With probability `zero_prob`, returns 0 (the zero-inflated component).
Otherwise, runs a standard bet(a, b, c).
"""
function zero_inflated_bet(a, b, c, zero_prob::Float64)
    if rand() < zero_prob
        return 0  # Zero-inflated component
    else
        return bet(a, b, c)
    end
end

"""
    zero_inflated_model(data::Vector{Float64}) -> Dict

Fit a zero-inflated model to data. Estimates:
- π: probability of structural zero
- μ: mean of non-zero component
- σ: std of non-zero component
"""
function zero_inflated_model(data::Vector{Float64})
    n = length(data)
    n_zeros = count(==(0.0), data)
    nonzero = filter(!=(0.0), data)

    pi_hat = n_zeros / n
    mu_hat = isempty(nonzero) ? 0.0 : mean(nonzero)
    sigma_hat = isempty(nonzero) ? 0.0 : std(nonzero)

    # AIC for zero-inflated vs standard model
    # ZI has 3 parameters (π, μ, σ), standard has 2 (μ, σ)
    ll_zi = n_zeros * log(max(pi_hat, 1e-15)) +
            (n - n_zeros) * log(max(1 - pi_hat, 1e-15))
    aic_zi = -2 * ll_zi + 2 * 3

    return Dict{String,Any}(
        "n" => n,
        "n_zeros" => n_zeros,
        "zero_fraction" => pi_hat,
        "nonzero_mean" => mu_hat,
        "nonzero_std" => sigma_hat,
        "aic_zero_inflated" => aic_zi,
        "recommend_zi" => pi_hat > 0.1,  # >10% zeros suggests ZI model
        "test_type" => "Zero-inflated model fit"
    )
end

"""
    rare_event_probability(n_trials::Int, n_events::Int; method="wilson") -> Dict

Estimate probability of a rare event with confidence interval.
Wilson score interval is preferred for small counts.
"""
function rare_event_probability(n_trials::Int, n_events::Int; method::String="wilson", alpha::Float64=0.05)
    p_hat = n_events / n_trials
    z = quantile(Normal(), 1 - alpha / 2)

    if method == "wilson"
        denom = 1 + z^2 / n_trials
        center = (p_hat + z^2 / (2 * n_trials)) / denom
        margin = z * sqrt((p_hat * (1 - p_hat) + z^2 / (4 * n_trials)) / n_trials) / denom
        lower = max(0.0, center - margin)
        upper = min(1.0, center + margin)
    else  # Wald (naive)
        se = sqrt(p_hat * (1 - p_hat) / n_trials)
        lower = max(0.0, p_hat - z * se)
        upper = min(1.0, p_hat + z * se)
    end

    return Dict{String,Any}(
        "p_hat" => p_hat,
        "ci_lower" => lower,
        "ci_upper" => upper,
        "method" => method,
        "n_trials" => n_trials,
        "n_events" => n_events,
        "is_rare" => p_hat < 0.05
    )
end
