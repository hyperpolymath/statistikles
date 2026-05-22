# SPDX-License-Identifier: MPL-2.0
# VeriSimDB Schema — Statistical results persistence layer.
#
# VeriSimDB instance: port 8096
# 8 modalities for statistical data:
#   1. numerical   — computed results (p-values, statistics, CIs)
#   2. audit       — Aspasia cross-verification reports
#   3. proof       — ECHIDNA formal proof certificates
#   4. metadata    — test parameters, data characteristics
#   5. timeseries  — repeated analyses over time
#   6. graph       — correlation matrices, DAGs
#   7. raw         — input datasets (hashed, not stored in full)
#   8. config      — analysis configuration and reproducibility info

using JSON3
using HTTP
using Dates
using UUIDs

const VERISIMDB_PORT = parse(Int, get(ENV, "STATISTEASE_VERISIMDB_PORT", "8096"))
const VERISIMDB_URL = "http://localhost:$(VERISIMDB_PORT)"

"""
    store_result(test_name, result, input_hash; modality="numerical") -> String

Persist a statistical result to VeriSimDB. Returns the record ID.
"""
function store_result(test_name::String, result::Dict, input_hash::String;
                     modality::String="numerical")
    record = Dict{String,Any}(
        "id" => string(uuid4()),
        "timestamp" => string(now()),
        "modality" => modality,
        "test_name" => test_name,
        "result" => result,
        "input_hash" => input_hash,
        "source" => "StatistEase.jl",
        "version" => "0.1.0"
    )

    try
        resp = HTTP.post("$(VERISIMDB_URL)/api/v1/store",
                        ["Content-Type" => "application/json"],
                        JSON3.write(record))
        return record["id"]
    catch e
        @warn "VeriSimDB not available on port $(VERISIMDB_PORT): $(e)"
        return record["id"]  # Return ID anyway for local tracking
    end
end

"""
    query_results(vql_query::String) -> Vector{Dict}

Query VeriSimDB using VQL-UT (Verified Query Language — Universal Types).
"""
function query_results(vql_query::String)
    try
        resp = HTTP.post("$(VERISIMDB_URL)/api/v1/query",
                        ["Content-Type" => "application/json"],
                        JSON3.write(Dict("query" => vql_query)))
        return JSON3.read(String(resp.body))
    catch e
        @warn "VeriSimDB query failed: $(e)"
        return Dict[]
    end
end

"""
    store_audit(txn_id, audit_report) -> String

Persist an Aspasia audit report to VeriSimDB (audit modality).
"""
function store_audit(txn_id::String, audit_report::Dict)
    return store_result("aspasia_audit", audit_report, txn_id; modality="audit")
end

"""
    store_proof(test_name, proof_certificate) -> String

Persist an ECHIDNA proof certificate to VeriSimDB (proof modality).
"""
function store_proof(test_name::String, proof_certificate::Dict)
    return store_result("echidna_proof", proof_certificate, test_name; modality="proof")
end
