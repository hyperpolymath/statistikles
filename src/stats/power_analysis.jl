# SPDX-License-Identifier: PMPL-1.0-or-later
# Power analysis and sample size calculations — symbolic computation only.

function power_analysis_t_test(; effect_size::Union{Float64,Nothing}=nothing,
                                 n::Union{Int,Nothing}=nothing,
                                 alpha::Float64=0.05,
                                 power::Union{Float64,Nothing}=nothing,
                                 two_tailed::Bool=true)
    results = Dict{String,Any}()

    if !isnothing(effect_size) && !isnothing(n)
        df = 2 * n - 2
        ncp = effect_size * sqrt(n / 2)
        t_crit = two_tailed ? quantile(TDist(df), 1 - alpha / 2) : quantile(TDist(df), 1 - alpha)
        achieved_power = 1 - cdf(NoncentralT(df, ncp), t_crit) +
                         cdf(NoncentralT(df, ncp), -t_crit)
        results["power"] = achieved_power
        results["n_per_group"] = n
        results["effect_size"] = effect_size
        results["alpha"] = alpha
    elseif !isnothing(effect_size) && !isnothing(power)
        for n_try in 2:10000
            df = 2 * n_try - 2
            ncp = effect_size * sqrt(n_try / 2)
            t_crit = two_tailed ? quantile(TDist(df), 1 - alpha / 2) : quantile(TDist(df), 1 - alpha)
            achieved = 1 - cdf(NoncentralT(df, ncp), t_crit) +
                       cdf(NoncentralT(df, ncp), -t_crit)
            if achieved >= power
                results["n_per_group"] = n_try
                results["n_total"] = 2 * n_try
                results["achieved_power"] = achieved
                results["effect_size"] = effect_size
                results["alpha"] = alpha
                break
            end
        end
    end

    results["recommendation"] = "Convention: power >= 0.80 is adequate"
    return results
end

function sample_size_calculator(; design::String="means",
                                  effect_size::Float64=0.5,
                                  alpha::Float64=0.05,
                                  power::Float64=0.80,
                                  n_groups::Int=2,
                                  n_predictors::Int=1)
    if design == "means"
        return power_analysis_t_test(effect_size=effect_size, power=power, alpha=alpha)
    elseif design == "proportions"
        z_a = quantile(Normal(), 1 - alpha / 2)
        z_b = quantile(Normal(), power)
        p1 = 0.5 + effect_size / 2
        p2 = 0.5 - effect_size / 2
        p_bar = (p1 + p2) / 2
        n = ((z_a * sqrt(2 * p_bar * (1 - p_bar)) +
              z_b * sqrt(p1 * (1 - p1) + p2 * (1 - p2))) / (p1 - p2))^2
        return Dict{String,Any}("n_per_group" => ceil(Int, n), "n_total" => 2 * ceil(Int, n),
                                "design" => "Two proportions")
    elseif design == "correlation"
        z_a = quantile(Normal(), 1 - alpha / 2)
        z_b = quantile(Normal(), power)
        z_r = atanh(effect_size)
        n = ((z_a + z_b) / z_r)^2 + 3
        return Dict{String,Any}("n" => ceil(Int, n), "design" => "Correlation",
                                "effect_size_r" => effect_size)
    elseif design == "regression"
        n_test = 104 + n_predictors
        n_ind = 50 + 8 * n_predictors
        return Dict{String,Any}("n_for_overall_model" => n_test,
                                "n_for_individual_predictors" => n_ind,
                                "n_recommended" => max(n_test, n_ind),
                                "design" => "Multiple regression",
                                "source" => "Green (1991) rules of thumb")
    elseif design == "anova"
        z_a = quantile(Normal(), 1 - alpha / 2)
        z_b = quantile(Normal(), power)
        n_pg = ceil(Int, ((z_a + z_b) / effect_size)^2)
        return Dict{String,Any}("n_per_group" => n_pg, "n_total" => n_pg * n_groups,
                                "design" => "One-way ANOVA")
    end
    return Dict{String,Any}("error" => "Unknown design: $design")
end
