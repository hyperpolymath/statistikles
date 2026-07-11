# SPDX-License-Identifier: MPL-2.0
# Neural-boundary guardrail — enforcement of the no-mollocks guarantee.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  THE FLAGSHIP GUARANTEE, MADE REAL                                      │
# │                                                                        │
# │  Statistikles promises that NO number is ever produced by the LLM.     │
# │  Until now that promise lived only in the system prompt. This module   │
# │  makes it enforceable: every numeric literal in the assistant's prose  │
# │  is checked against the numbers that actually flowed out of symbolic   │
# │  tool calls. A number that matches nothing is an "orphan" — a likely   │
# │  mollock (a plausible-sounding fabrication).                           │
# │                                                                        │
# │  The guardrail NEVER rewrites the model's text silently. It flags.     │
# └─────────────────────────────────────────────────────────────────────────┘

# Matches numeric literals in prose: ints, decimals, scientific notation,
# and trailing-percent forms. A leading sign is intentionally NOT captured so
# that range dashes ("3-5") do not swallow a spurious negative; sign is handled
# by absolute-value comparison during matching instead.
const _NUMERIC_TOKEN_RE = r"\d+(?:\.\d+)?(?:[eE][-+]?\d+)?%?"

"""
    collect_numbers(x, acc::Vector{Float64}=Float64[]) -> Vector{Float64}

Recursively harvest every numeric value reachable inside a tool result —
Dicts, Vectors, Tuples and arbitrarily nested combinations thereof — into a
flat `Vector{Float64}`. Booleans and strings are ignored (event flags and
interpretation labels are not "numbers" in the provenance sense).
"""
function collect_numbers(x, acc::Vector{Float64}=Float64[])
    if x isa Bool
        # skip: a Bool is a Real in Julia, but it is a flag, not a statistic
    elseif x isa Real
        push!(acc, Float64(x))
    elseif x isa AbstractDict
        for (_, v) in x
            collect_numbers(v, acc)
        end
    elseif x isa AbstractVector || x isa Tuple || x isa AbstractSet
        for v in x
            collect_numbers(v, acc)
        end
    end
    # strings, symbols, `nothing`, `missing`, etc. carry no harvestable number
    return acc
end

"""
    extract_numeric_tokens(text::AbstractString) -> Vector{String}

Return the numeric literals appearing in assistant prose (ints, decimals,
scientific notation, percentages) as the raw matched substrings, in order.
"""
function extract_numeric_tokens(text::AbstractString)
    return String[String(m.match) for m in eachmatch(_NUMERIC_TOKEN_RE, text)]
end

# Parse one numeric token to (value, decimal_places). `decimal_places` records
# how many digits followed the decimal point (0 for a bare integer, -1 if the
# token could not be parsed) so that display-rounding can be reproduced.
function _parse_token(tok::AbstractString)
    s = strip(tok)
    ispct = endswith(s, "%")
    ispct && (s = s[1:prevind(s, lastindex(s))])
    s = replace(s, "," => "")            # tolerate thousands separators
    v = tryparse(Float64, s)
    v === nothing && return (NaN, -1, ispct)
    d = 0
    if occursin('.', s) && !occursin(r"[eE]", s)
        d = length(split(s, '.')[2])
    end
    return (Float64(v), d, ispct)
end

# Return the parsed numeric values (Float64) present in prose. Percent tokens
# keep their face value (e.g. "35%" -> 35.0); the /100·×100 logic lives in the
# matcher. Unparseable tokens are dropped.
function extract_numeric_values(text::AbstractString)
    vals = Float64[]
    for tok in extract_numeric_tokens(text)
        v, _, _ = _parse_token(tok)
        isnan(v) || push!(vals, v)
    end
    return vals
end

# Is token value `t` (with `d` decimal places) explained by any candidate
# number? A candidate explains `t` when `t` approximately equals the candidate,
# its sign flip, or its ÷100 / ×100 percent variant — either exactly (rtol) or
# after rounding the candidate to the token's displayed precision.
function _token_explained(t::Float64, d::Int, candidates, rtol::Float64)
    isfinite(t) || return true          # NaN/Inf token: do not flag
    for h in candidates
        isfinite(h) || continue
        for hv in (h, -h, h * 100, -h * 100, h / 100, -h / 100)
            if isapprox(t, hv; rtol=rtol, atol=1e-9)
                return true
            end
            if d >= 0 && isapprox(t, round(hv; digits=d); rtol=rtol, atol=1e-9)
                return true
            end
        end
    end
    return false
end

"""
    validate_numeric_provenance(text, tool_results, user_numbers=Float64[];
                                rtol=1e-6) -> (ok::Bool, orphans::Vector{String})

Audit every numeric literal in `text` against the numbers that were actually
produced by symbolic computation.

A token is legitimate when it approximately matches (within `rtol`, or after
display-rounding) any number harvested from `tool_results`, OR its ÷100 / ×100
percent variant matches, OR it matches a number supplied by the user
(`user_numbers`), OR it is a small structural integer in `0..12` (degrees of
freedom, group counts, list indices and the like).

`orphans` lists the tokens (as they appeared in the prose) that matched nothing.
`ok == isempty(orphans)`.
"""
function validate_numeric_provenance(text::AbstractString, tool_results,
                                     user_numbers=Float64[]; rtol::Float64=1e-6)
    harvested = collect_numbers(tool_results)
    users = collect_numbers(user_numbers)
    candidates = vcat(harvested, users)

    orphans = String[]
    for tok in extract_numeric_tokens(text)
        t, d, _ = _parse_token(tok)
        isnan(t) && continue                       # unparseable: skip
        if d == 0 && 0.0 <= t <= 12.0              # small structural integer
            continue
        end
        _token_explained(t, d, candidates, rtol) || push!(orphans, tok)
    end
    return (isempty(orphans), orphans)
end
