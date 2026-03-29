# SPDX-License-Identifier: PMPL-1.0-or-later
# BowtieRisk.jl Integration — Risk analysis with barrier modeling.
#
# Extends BetLang's VaR/risk-of-ruin with structured threat modeling.

"""
    bowtie_from_bets(threat_prob, barrier_probs, consequences) -> Dict

Build a bowtie risk model from betting primitives.
- threat_prob: P(threat occurs)
- barrier_probs: [P(barrier_i holds)] — each barrier independently
- consequences: [(name, severity)] if all barriers fail
"""
function bowtie_from_bets(threat_prob::Float64,
                         barrier_probs::Vector{Float64},
                         consequences::Vector{Tuple{String, Float64}})
    # Probability of reaching top event (all barriers fail)
    barrier_failure_prob = prod(1.0 .- barrier_probs)
    top_event_prob = threat_prob * barrier_failure_prob

    # Expected loss = P(top event) × Σ(severity × conditional probability)
    total_severity = sum(s for (_, s) in consequences)
    expected_loss = top_event_prob * total_severity

    # Individual barrier criticality: how much does removing this barrier increase risk?
    criticalities = Float64[]
    for i in eachindex(barrier_probs)
        # Remove barrier i
        reduced_probs = [j == i ? 0.0 : barrier_probs[j] for j in eachindex(barrier_probs)]
        reduced_failure = prod(1.0 .- reduced_probs)
        reduced_top_event = threat_prob * reduced_failure
        push!(criticalities, reduced_top_event - top_event_prob)
    end

    return Dict{String,Any}(
        "threat_prob" => threat_prob,
        "n_barriers" => length(barrier_probs),
        "barrier_probs" => barrier_probs,
        "barrier_failure_prob" => barrier_failure_prob,
        "top_event_prob" => top_event_prob,
        "expected_loss" => expected_loss,
        "barrier_criticalities" => criticalities,
        "most_critical_barrier" => argmax(criticalities),
        "risk_level" => top_event_prob > 0.01 ? "HIGH" :
                       top_event_prob > 0.001 ? "MEDIUM" : "LOW"
    )
end

"""
    monte_carlo_bowtie(threat_prob, barrier_probs, n_sims) -> Dict

Simulate a bowtie model n_sims times using BetLang ternary bets.
Each simulation: threat occurs? → barriers hold? → consequences.
"""
function monte_carlo_bowtie(threat_prob::Float64,
                           barrier_probs::Vector{Float64};
                           n_sims::Int=10_000)
    threat_events = 0
    barrier_failures = 0
    top_events = 0

    for _ in 1:n_sims
        if rand() < threat_prob
            threat_events += 1
            all_failed = all(rand() > p for p in barrier_probs)
            if all_failed
                barrier_failures += 1
                top_events += 1
            end
        end
    end

    return Dict{String,Any}(
        "n_sims" => n_sims,
        "threat_rate" => threat_events / n_sims,
        "top_event_rate" => top_events / n_sims,
        "theoretical_top_event" => threat_prob * prod(1.0 .- barrier_probs),
        "barrier_effectiveness" => threat_events > 0 ?
            1.0 - barrier_failures / threat_events : 1.0
    )
end
