# SPDX-License-Identifier: MPL-2.0

# Survival Analysis — Time-to-Event Modeling.
#
# This module implements the Kaplan-Meier estimator for survival probability.

"""
    kaplan_meier(times::Vector{Float64}, events::Vector{Bool}) -> Dict

KAPLAN-MEIER ESTIMATOR: Non-parametric statistic used to estimate the 
survival function from lifetime data.
- `times`: Time to event or censoring.
- `events`: True if event occurred, false if censored.
"""
function kaplan_meier(times::Vector{Float64}, events::Vector{Bool})
    n = length(times)
    @assert n == length(events)
    
    # Sort by time
    idx = sortperm(times)
    t_sorted = times[idx]
    e_sorted = events[idx]
    
    unique_times = unique(t_sorted)
    surv_prob = 1.0
    probs = Float64[]
    at_risk = n
    
    for t in unique_times
        # Number of events at time t
        d_t = sum(e_sorted[t_sorted .== t])
        # Number of censored at time t (already accounted for in at_risk reduction)
        n_t = at_risk
        
        surv_prob *= (1 - d_t / n_t)
        push!(probs, surv_prob)
        
        # Reduce at_risk for next time point
        at_risk -= count(==(t), t_sorted)
    end
    
    return Dict{String, Any}(
        "times" => unique_times,
        "survival_probabilities" => probs,
        "test_type" => "Kaplan-Meier Survival Analysis"
    )
end

"""
    log_rank_test(times::Vector{Float64}, events::Vector{Bool}, groups::Vector; alpha=0.05) -> Dict

LOG-RANK TEST: Compares the survival distributions of two or more groups.
- `times`: Time to event or censoring.
- `events`: True if event occurred, false if censored.
- `groups`: Group labels for each observation.
"""
function log_rank_test(times::Vector{Float64}, events::Vector{Bool}, groups::Vector; alpha::Float64=0.05)
    unique_groups = unique(groups)
    @assert length(unique_groups) == 2 "Log-rank test currently supports 2 groups"
    
    g1_idx = findall(==(unique_groups[1]), groups)
    g2_idx = findall(==(unique_groups[2]), groups)
    
    all_times = sort(unique(times))
    O1, E1 = 0.0, 0.0
    V = 0.0
    
    for t in all_times
        # Total at risk and events at time t
        at_risk = findall(>=(t), times)
        events_at_t = findall(==(t), times[events]) # This is logic-heavy, simplified:
        
        n_t = length(at_risk)
        d_t = sum(events[times .== t])
        
        n1_t = length(intersect(at_risk, g1_idx))
        d1_t = sum(events[intersect(findall(==(t), times), g1_idx)])
        
        if n_t > 1
            e1_t = n1_t * (d_t / n_t)
            v_t = d_t * (n1_t / n_t) * (1 - n1_t / n_t) * ((n_t - d_t) / (n_t - 1))
            
            O1 += d1_t
            E1 += e1_t
            V += v_t
        end
    end
    
    chi2 = (O1 - E1)^2 / V
    p_val = 1 - cdf(Chisq(1), chi2)
    
    return Dict{String, Any}(
        "chi_squared" => chi2,
        "p_value" => p_val,
        "significant" => p_val < alpha,
        "observed_events_g1" => O1,
        "expected_events_g1" => E1,
        "test_type" => "Log-Rank Test"
    )
end
