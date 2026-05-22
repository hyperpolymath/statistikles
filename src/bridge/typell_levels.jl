# SPDX-License-Identifier: MPL-2.0
# TypeLL Statistical Type Levels 1-12
#
# Type safety hierarchy for statistical computations. Each level adds
# stronger guarantees. Levels 1-3 are enforced by Julia's type system,
# 4-8 by runtime validation, 9-12 by external proof systems.
#
# Level  1: Primitive types (Float64, Int, Bool, String)
# Level  2: Collection types (Vector, Matrix, DataFrame)
# Level  3: Statistical result types (TestResult, ConfidenceInterval)
# Level  4: Bounded types (Probability ∈ [0,1], EffectSize with label)
# Level  5: Distribution types (Normal{μ,σ}, ChiSquared{df})
# Level  6: Refinement types (HypothesisTest{TwoSided, α=0.05})
# Level  7: Tropical types (TropicalSemiring{MinPlus})
# Level  8: Algebraic types (PadicNumber{p}, ModularInt{n})
# Level  9: Verified types (Verified{Julia, Octave})
# Level 10: Proven types (FormallyProven{Agda, identity})
# Level 11: Epistemological types (KnowledgeState{certainty, provenance})
# Level 12: Session types (AuditProtocol{compute → verify → prove → persist})

# ===========================================================================
# Level 1-3: Julia type system enforced
# ===========================================================================

"""Level 1: Primitive wrapper with type tag."""
struct TypedValue{T}
    value::T
    level::Int
end

"""Level 3: Statistical test result with structured fields."""
struct TestResult
    test_name::String
    statistic::Float64
    p_value::Float64
    df::Float64
    significant::Bool
    effect_size::Union{Float64, Nothing}
    confidence_interval::Union{Tuple{Float64, Float64}, Nothing}
    level::Int  # TypeLL level of this result
end

"""Level 3: Confidence interval with coverage."""
struct ConfidenceInterval
    lower::Float64
    upper::Float64
    coverage::Float64  # 0.95 for 95% CI
    method::String     # "normal", "bootstrap", "exact"
end

# ===========================================================================
# Level 4-6: Runtime validated types
# ===========================================================================

"""Level 4: Probability ∈ [0, 1] — runtime checked."""
struct Probability
    value::Float64
    function Probability(v::Float64)
        @assert 0.0 <= v <= 1.0 "Probability must be in [0, 1], got $v"
        new(v)
    end
end

"""Level 4: Effect size with convention label."""
struct EffectSize
    value::Float64
    metric::String     # "cohens_d", "eta_squared", "r", etc.
    label::String      # "negligible", "small", "medium", "large"
    function EffectSize(v::Float64, metric::String)
        label = if metric == "cohens_d"
            abs(v) < 0.2 ? "negligible" : abs(v) < 0.5 ? "small" :
            abs(v) < 0.8 ? "medium" : "large"
        elseif metric == "r"
            abs(v) < 0.1 ? "negligible" : abs(v) < 0.3 ? "small" :
            abs(v) < 0.5 ? "medium" : "large"
        elseif metric == "eta_squared"
            v < 0.01 ? "negligible" : v < 0.06 ? "small" :
            v < 0.14 ? "medium" : "large"
        else
            "unclassified"
        end
        new(v, metric, label)
    end
end

"""Level 5: Parameterized distribution type."""
struct DistributionType
    family::String          # "Normal", "ChiSquared", "TDist", "FDist"
    parameters::Dict{String, Float64}  # e.g. {"mu" => 0, "sigma" => 1}
end

"""Level 6: Hypothesis test specification with refinements."""
struct HypothesisSpec
    alternative::String     # "two_sided", "greater", "less"
    alpha::Float64
    correction::String      # "none", "bonferroni", "holm", "fdr"
    power::Union{Float64, Nothing}
end

# ===========================================================================
# Level 7-8: Algebraic structure types
# ===========================================================================

"""Level 7: Tropical semiring value."""
struct TropicalValue
    value::Float64
    algebra::String  # "min_plus" or "max_plus"
end

"""Tropical addition: min(a, b) for min-plus."""
Base.:+(a::TropicalValue, b::TropicalValue) = TropicalValue(min(a.value, b.value), a.algebra)

"""Tropical multiplication: a + b for min-plus."""
Base.:*(a::TropicalValue, b::TropicalValue) = TropicalValue(a.value + b.value, a.algebra)

"""Level 8: p-adic number."""
struct PadicValue
    coefficients::Vector{Int}  # Digits in base p
    prime::Int
    valuation::Int             # p-adic valuation
end

"""Level 8: Modular integer."""
struct ModularInt
    value::Int
    modulus::Int
    ModularInt(v::Int, m::Int) = new(mod(v, m), m)
end
Base.:+(a::ModularInt, b::ModularInt) = (@assert a.modulus == b.modulus; ModularInt(a.value + b.value, a.modulus))
Base.:*(a::ModularInt, b::ModularInt) = (@assert a.modulus == b.modulus; ModularInt(a.value * b.value, a.modulus))

# ===========================================================================
# Level 9-10: Verification provenance types
# ===========================================================================

"""Level 9: Result verified by multiple independent systems."""
struct VerifiedResult
    result::Dict{String, Any}
    verified_by::Vector{String}   # e.g. ["Julia", "Octave"]
    agreement::Bool               # Do all verifiers agree?
    max_discrepancy::Float64      # Largest numerical difference
    timestamp::String
end

"""Level 10: Result with formal proof certificate."""
struct ProvenResult
    result::Dict{String, Any}
    proof_system::String          # "Agda", "Lean4", "Z3"
    identity_name::String         # e.g. "midrank_sum"
    trust_level::Int              # ECHIDNA trust 1-5
    certificate_hash::String      # BLAKE3 of proof certificate
end

# ===========================================================================
# Level 11-12: Epistemological and session types
# ===========================================================================

"""Level 11: Knowledge state with certainty and provenance tracking."""
struct KnowledgeState
    claim::String                 # What is being claimed
    certainty::Float64            # 0.0 to 1.0
    provenance::Vector{String}    # Chain of evidence
    assumptions::Vector{String}   # What must hold for this to be true
    falsifiable::Bool             # Can this claim be disproven?
end

"""Level 12: Session type — typed protocol for audit workflow.

The audit protocol enforces this sequence:
  compute → verify → prove → persist → report
Each step must complete before the next can begin.
"""
struct AuditSession
    state::Symbol    # :compute, :verify, :prove, :persist, :report, :complete
    txn_id::String
    compute_result::Union{Dict, Nothing}
    verify_result::Union{Dict, Nothing}
    proof_result::Union{Dict, Nothing}
    persist_id::Union{String, Nothing}
end

"""Advance audit session to next state (session type enforcement)."""
function advance(session::AuditSession, next_state::Symbol, data)
    valid_transitions = Dict(
        :compute => :verify,
        :verify => :prove,
        :prove => :persist,
        :persist => :report,
        :report => :complete
    )
    expected = get(valid_transitions, session.state, nothing)
    if expected != next_state
        error("TypeLL L12 violation: cannot transition from $(session.state) to $(next_state). Expected: $(expected)")
    end

    if next_state == :verify
        return AuditSession(:verify, session.txn_id, session.compute_result, data, nothing, nothing)
    elseif next_state == :prove
        return AuditSession(:prove, session.txn_id, session.compute_result, session.verify_result, data, nothing)
    elseif next_state == :persist
        return AuditSession(:persist, session.txn_id, session.compute_result, session.verify_result, session.proof_result, data)
    elseif next_state == :report
        return AuditSession(:report, session.txn_id, session.compute_result, session.verify_result, session.proof_result, session.persist_id)
    elseif next_state == :complete
        return AuditSession(:complete, session.txn_id, session.compute_result, session.verify_result, session.proof_result, session.persist_id)
    end
end

"""Create a new audit session starting at :compute."""
function new_audit_session(txn_id::String, compute_result::Dict)
    return AuditSession(:compute, txn_id, compute_result, nothing, nothing, nothing)
end
