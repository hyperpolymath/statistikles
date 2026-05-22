# SPDX-License-Identifier: MPL-2.0
# Effect size calculators and converters — symbolic computation only.

function effect_sizes(; cohens_d::Union{Float64,Nothing}=nothing,
                       r::Union{Float64,Nothing}=nothing,
                       eta_squared::Union{Float64,Nothing}=nothing,
                       odds_ratio::Union{Float64,Nothing}=nothing,
                       n1::Union{Int,Nothing}=nothing,
                       n2::Union{Int,Nothing}=nothing)
    results = Dict{String,Any}()

    if !isnothing(cohens_d)
        d = cohens_d
        results["cohens_d"] = d
        results["d_interpretation"] = abs(d) >= 0.8 ? "Large" : abs(d) >= 0.5 ? "Medium" :
                                      abs(d) >= 0.2 ? "Small" : "Negligible"
        r_from_d = d / sqrt(d^2 + 4)
        results["r_from_d"] = r_from_d
        results["r_squared_from_d"] = r_from_d^2
        if !isnothing(n1) && !isnothing(n2)
            results["hedges_g"] = d * (1 - 3 / (4 * (n1 + n2) - 9))
        end
        results["CL_effect_size"] = cdf(Normal(), d / sqrt(2))
        nnt_val = cdf(Normal(), d) - 0.5
        results["NNT_approx"] = abs(nnt_val) > 0.001 ? 1 / nnt_val : Inf
    end

    if !isnothing(r)
        results["r"] = r
        results["r_squared"] = r^2
        results["r_interpretation"] = abs(r) >= 0.5 ? "Large" : abs(r) >= 0.3 ? "Medium" :
                                      abs(r) >= 0.1 ? "Small" : "Negligible"
        results["d_from_r"] = 2 * r / sqrt(1 - r^2)
    end

    if !isnothing(eta_squared)
        results["eta_squared"] = eta_squared
        results["eta"] = sqrt(eta_squared)
        results["eta_interpretation"] = eta_squared >= 0.14 ? "Large" :
                                        eta_squared >= 0.06 ? "Medium" :
                                        eta_squared >= 0.01 ? "Small" : "Negligible"
        results["f_from_eta"] = sqrt(eta_squared / (1 - eta_squared))
    end

    if !isnothing(odds_ratio)
        results["odds_ratio"] = odds_ratio
        results["log_odds_ratio"] = log(odds_ratio)
        results["d_from_OR"] = log(odds_ratio) * sqrt(3) / pi
        results["OR_interpretation"] = odds_ratio > 3 || odds_ratio < 1 / 3 ? "Large" :
                                       odds_ratio > 1.5 || odds_ratio < 1 / 1.5 ? "Medium" : "Small"
    end

    return results
end
