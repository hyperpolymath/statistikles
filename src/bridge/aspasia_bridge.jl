# SPDX-License-Identifier: PMPL-1.0-or-later
# Aspasia Bridge — Cross-verification interface between StatistEase (Julia)
# and Aspasia (GNU Octave + Prolog).
#
# ARCHITECTURE:
#   StatistEase writes JSON transactions → shared directory
#   Aspasia reads transactions, audits independently, writes audit reports
#   StatistEase reads audit reports and flags disagreements
#
# This is PULL-based, non-blocking. Aspasia is never in the critical path.

using JSON3
using Dates
using UUIDs

# ===========================================================================
# Configuration
# ===========================================================================

const BRIDGE_DIR = get(ENV, "STATISTEASE_BRIDGE_DIR", joinpath(homedir(), ".statistease", "bridge"))
const TRANSACTIONS_DIR = joinpath(BRIDGE_DIR, "transactions")
const AUDITS_DIR = joinpath(BRIDGE_DIR, "audits")

"""Ensure bridge directories exist."""
function init_bridge()
    mkpath(TRANSACTIONS_DIR)
    mkpath(AUDITS_DIR)
    return BRIDGE_DIR
end

# ===========================================================================
# Transaction Writing (StatistEase → Aspasia)
# ===========================================================================

"""
    write_transaction(test_name, input_data, result, explanation; kwargs...) -> String

Write a JSON transaction for Aspasia to audit. Returns the transaction ID.
"""
function write_transaction(test_name::String, input_data::Dict, result::Dict,
                          explanation::String;
                          data_scale::String="interval",
                          sample_size::Int=0,
                          alpha::Float64=0.05)
    init_bridge()

    txn_id = string(uuid4())
    txn = Dict{String,Any}(
        "id" => txn_id,
        "timestamp" => string(now()),
        "test_name" => test_name,
        "input_data" => input_data,
        "result" => result,
        "explanation" => explanation,
        "data_scale" => data_scale,
        "sample_size" => sample_size,
        "alpha" => alpha,
        "source" => "StatistEase.jl"
    )

    path = joinpath(TRANSACTIONS_DIR, "$(txn_id).json")
    open(path, "w") do io
        JSON3.pretty(io, txn)
    end

    return txn_id
end

# ===========================================================================
# Audit Reading (Aspasia → StatistEase)
# ===========================================================================

"""
    read_audit(txn_id) -> Union{Dict, Nothing}

Read an audit report for a given transaction ID. Returns Nothing if not yet audited.
"""
function read_audit(txn_id::String)
    path = joinpath(AUDITS_DIR, "$(txn_id)_audit.json")
    if isfile(path)
        return JSON3.read(read(path, String))
    end
    return nothing
end

"""
    list_pending_audits() -> Vector{String}

List transaction IDs that have been written but not yet audited by Aspasia.
"""
function list_pending_audits()
    init_bridge()
    txn_files = filter(f -> endswith(f, ".json"), readdir(TRANSACTIONS_DIR))
    audit_files = Set(replace(f, "_audit.json" => "") for f in
                      filter(f -> endswith(f, "_audit.json"), readdir(AUDITS_DIR)))

    pending = String[]
    for f in txn_files
        txn_id = replace(f, ".json" => "")
        if !(txn_id in audit_files)
            push!(pending, txn_id)
        end
    end
    return pending
end

"""
    list_completed_audits() -> Vector{String}

List transaction IDs that have been audited by Aspasia.
"""
function list_completed_audits()
    init_bridge()
    audit_files = filter(f -> endswith(f, "_audit.json"), readdir(AUDITS_DIR))
    return [replace(f, "_audit.json" => "") for f in audit_files]
end

# ===========================================================================
# Cross-Verification Summary
# ===========================================================================

"""
    cross_verify_summary() -> Dict

Summary of cross-verification status: pending, passed, failed, disputed.
"""
function cross_verify_summary()
    pending = list_pending_audits()
    completed = list_completed_audits()

    passed = 0
    failed = 0
    disputed = 0

    for txn_id in completed
        audit = read_audit(txn_id)
        if audit !== nothing
            severity = get(audit, "severity", "info")
            if severity == "error"
                failed += 1
            elseif severity == "concern" || severity == "warning"
                disputed += 1
            else
                passed += 1
            end
        end
    end

    return Dict{String,Any}(
        "pending" => length(pending),
        "passed" => passed,
        "failed" => failed,
        "disputed" => disputed,
        "total_audited" => length(completed),
        "bridge_dir" => BRIDGE_DIR
    )
end
