# SPDX-License-Identifier: MPL-2.0
# Causals.jl Integration — Causal DAG modeling for bet chains and statistical tests.
#
# Maps bet sequences to causal DAGs and provides Bradford Hill assessment.

"""
    bet_chain_to_dag(n_steps::Int, outcomes::Vector{String}) -> Dict

Convert a betlang bet chain into a causal DAG representation.
Each step is a node, edges represent probabilistic transitions.
"""
function bet_chain_to_dag(n_steps::Int, outcomes::Vector{String})
    nodes = ["step_$i" for i in 1:n_steps]
    edges = [("step_$i", "step_$(i+1)") for i in 1:(n_steps-1)]

    # Each node has |outcomes| possible values
    adj = zeros(Int, n_steps, n_steps)
    for i in 1:(n_steps-1)
        adj[i, i+1] = 1
    end

    return Dict{String,Any}(
        "nodes" => nodes,
        "edges" => edges,
        "adjacency" => adj,
        "n_outcomes_per_step" => length(outcomes),
        "outcomes" => outcomes,
        "is_dag" => true,  # Chain is always acyclic
        "is_markov" => true,  # Each step depends only on previous
    )
end

"""
    bradford_hill_checklist(association::Dict) -> Dict

Evaluate a statistical association against Bradford Hill criteria
for causal inference. Input should contain effect size, p-value,
and contextual fields.
"""
function bradford_hill_checklist(association::Dict)
    criteria = Dict{String,Any}()

    # 1. Strength — large effect size
    es = get(association, "effect_size", 0.0)
    criteria["strength"] = abs(es) > 0.5 ? "strong" : abs(es) > 0.2 ? "moderate" : "weak"

    # 2. Consistency — reported across studies (need meta-analysis)
    criteria["consistency"] = haskey(association, "n_studies") && association["n_studies"] > 1 ?
        "multiple studies" : "single study (unverified)"

    # 3. Specificity — effect on specific outcome
    criteria["specificity"] = get(association, "specific_outcome", false) ? "specific" : "non-specific"

    # 4. Temporality — cause precedes effect
    criteria["temporality"] = get(association, "temporal_order", false) ? "established" : "unknown"

    # 5. Biological gradient — dose-response
    criteria["gradient"] = get(association, "dose_response", false) ? "present" : "not assessed"

    # 6. Plausibility
    criteria["plausibility"] = get(association, "mechanism_known", false) ? "plausible" : "speculative"

    # 7. Coherence
    criteria["coherence"] = get(association, "consistent_with_theory", false) ? "coherent" : "unknown"

    # 8. Experiment — interventional evidence
    criteria["experiment"] = get(association, "rct_available", false) ? "RCT" : "observational"

    # 9. Analogy
    criteria["analogy"] = get(association, "similar_causes", false) ? "analogous" : "novel"

    # Score: count how many criteria are met
    met = count(v -> v ∉ ["weak", "single study (unverified)", "non-specific",
                          "unknown", "not assessed", "speculative", "observational", "novel"],
                values(criteria))
    criteria["score"] = met
    criteria["out_of"] = 9
    criteria["assessment"] = met >= 7 ? "Strong causal evidence" :
                            met >= 4 ? "Moderate evidence" : "Weak — correlation only"

    return criteria
end

"""
    confounding_check(x, y, z) -> Dict

Check if z confounds the relationship between x and y.
Uses partial correlation: if r_xy.z ≈ 0 but r_xy ≫ 0, z is a confounder.
"""
function confounding_check(x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64})
    pc = partial_correlation(x, y, z)
    raw_r = pc["r_xy"]
    partial_r = pc["r_partial"]

    reduction = abs(raw_r) > 0 ? 1.0 - abs(partial_r) / abs(raw_r) : 0.0

    return Dict{String,Any}(
        "raw_correlation" => raw_r,
        "partial_correlation" => partial_r,
        "reduction_pct" => reduction * 100,
        "is_confounder" => reduction > 0.5,  # >50% reduction suggests confounding
        "assessment" => reduction > 0.5 ? "Z likely confounds X-Y" :
                       reduction > 0.2 ? "Z partially confounds X-Y" :
                       "Z does not confound X-Y"
    )
end
