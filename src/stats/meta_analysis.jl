# SPDX-License-Identifier: MPL-2.0

# Meta-Analysis — Systematic Effect Size Synthesis.
#
# This module implements fixed and random effects models for meta-analysis.

"""
    meta_analysis(effect_sizes::Vector{Float64}, variances::Vector{Float64}; model="random") -> Dict

META-ANALYSIS: Synthesizes effect sizes across multiple studies.
- `effect_sizes`: List of observed effects (e.g., Cohen's d).
- `variances`: Corresponding variances for each study.
- `model`: "fixed" or "random".
"""
function meta_analysis(effect_sizes::Vector{Float64}, variances::Vector{Float64}; model::String="random")
    require_equal_length(effect_sizes, variances, "effect_sizes", "variances")
    k = length(effect_sizes)
    
    # Weights
    w = 1.0 ./ variances
    
    # Fixed effect estimate
    fixed_effect = sum(w .* effect_sizes) / sum(w)
    fixed_se = sqrt(1 / sum(w))
    
    if model == "fixed"
        return Dict{String, Any}(
            "combined_effect" => fixed_effect,
            "std_error" => fixed_se,
            "model" => "Fixed-Effects",
            "k_studies" => k
        )
    end
    
    # Random effects (DerSimonian-Laird)
    # Q statistic
    Q = sum(w .* (effect_sizes .- fixed_effect).^2)
    df = k - 1
    # Between-study variance (tau squared)
    tau2 = max(0.0, (Q - df) / (sum(w) - sum(w.^2) / sum(w)))
    
    # Random weights
    w_star = 1.0 ./ (variances .+ tau2)
    random_effect = sum(w_star .* effect_sizes) / sum(w_star)
    random_se = sqrt(1 / sum(w_star))
    
    # Heterogeneity: I^2 = (Q - df) / Q
    I2 = max(0.0, (Q - df) / max(Q, 1e-10))
    
    return Dict{String, Any}(
        "combined_effect" => random_effect,
        "std_error" => random_se,
        "tau_squared" => tau2,
        "I_squared" => I2,
        "Q_stat" => Q,
        "model" => "Random-Effects (DerSimonian-Laird)",
        "k_studies" => k
    )
end
