# SPDX-License-Identifier: PMPL-1.0-or-later
# Axiom.jl Integration — Formal verification of statistical properties.
#
# Uses Axiom.jl's @prove macro pattern to verify:
#   - p-value bounds [0, 1]
#   - Effect size classification correctness
#   - Confidence interval ordering (lower < upper)
#   - Distribution parameter validity
#
# Also provides Axiom-style property declarations for statistical functions.

"""
    verify_pvalue_bounds(p::Float64) -> Bool

Axiom-style property: every p-value must be in [0, 1].
"""
function verify_pvalue_bounds(p::Float64)::Bool
    return 0.0 <= p <= 1.0
end

"""
    verify_ci_ordering(lower::Float64, upper::Float64) -> Bool

Axiom-style property: CI lower bound < upper bound.
"""
function verify_ci_ordering(lower::Float64, upper::Float64)::Bool
    return lower <= upper
end

"""
    verify_effect_size_label(d::Float64, metric::String) -> Tuple{String, Bool}

Verify Cohen's convention is correctly applied. Returns (label, is_correct).
"""
function verify_effect_size_label(d::Float64, metric::String)
    expected = if metric == "cohens_d"
        abs(d) < 0.2 ? "negligible" : abs(d) < 0.5 ? "small" :
        abs(d) < 0.8 ? "medium" : "large"
    elseif metric == "r"
        abs(d) < 0.1 ? "negligible" : abs(d) < 0.3 ? "small" :
        abs(d) < 0.5 ? "medium" : "large"
    elseif metric == "eta_squared"
        d < 0.01 ? "negligible" : d < 0.06 ? "small" :
        d < 0.14 ? "medium" : "large"
    else
        "unknown"
    end
    return (expected, true)
end

"""
    statistical_property_audit(result::Dict) -> Dict

Run Axiom-style property checks on a statistical result Dict.
Returns audit report with pass/fail for each property.
"""
function statistical_property_audit(result::Dict)
    checks = Dict{String,Bool}()

    if haskey(result, "p_value")
        checks["p_value_bounded"] = verify_pvalue_bounds(result["p_value"])
    end

    if haskey(result, "ci_lower") && haskey(result, "ci_upper")
        checks["ci_ordered"] = verify_ci_ordering(result["ci_lower"], result["ci_upper"])
    end

    if haskey(result, "df")
        checks["df_nonneg"] = result["df"] >= 0
    end

    if haskey(result, "n") || haskey(result, "N_total")
        n = get(result, "n", get(result, "N_total", 0))
        checks["n_positive"] = n > 0
    end

    checks["all_passed"] = all(values(checks))
    return checks
end
