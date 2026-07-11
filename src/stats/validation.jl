# SPDX-License-Identifier: MPL-2.0

# Validation — Shared Input-Validation Helpers for User/LLM-Supplied Data.
#
# Julia documents `@assert` as disable-able (e.g. under custom system images
# or `-O3` builds), so it must never be the sole guard on data arriving from
# a user or an LLM tool call — a disabled assertion would let mismatched
# lengths or out-of-range values proceed to a `BoundsError` or a silently
# wrong number. These helpers throw `ArgumentError` with a precise message
# instead, and are used throughout `src/stats/`, `src/bridge/`, and
# `src/integrations/` at validation boundaries.
#
# `@assert` remains appropriate only for true internal invariants — a
# self-consistency check on values the function itself computed, which a
# caller cannot trigger through the public API.

"""
    require_equal_length(a, b, name_a::String, name_b::String)

Throw `ArgumentError` unless `a` and `b` have the same `length`.
"""
function require_equal_length(a, b, name_a::String, name_b::String)
    length(a) == length(b) || throw(ArgumentError(
        "$name_a and $name_b must be of the same length (got $(length(a)) and $(length(b)))"))
    return nothing
end

"""
    require_length(x, n::Int, name::String)

Throw `ArgumentError` unless `length(x) == n`.
"""
function require_length(x, n::Int, name::String)
    length(x) == n || throw(ArgumentError(
        "$name must have length $n, got $(length(x))"))
    return nothing
end

"""
    require_nonempty(x, name::String)

Throw `ArgumentError` if `x` is empty.
"""
function require_nonempty(x, name::String)
    isempty(x) && throw(ArgumentError("$name must not be empty"))
    return nothing
end

"""
    require_min_length(x, n::Int, name::String)

Throw `ArgumentError` unless `length(x) >= n`.
"""
function require_min_length(x, n::Int, name::String)
    length(x) >= n || throw(ArgumentError(
        "$name requires at least $n observation(s), got $(length(x))"))
    return nothing
end

"""
    require_at_least(n::Int, min_n::Int, name::String)

Throw `ArgumentError` unless `n >= min_n`.
"""
function require_at_least(n::Int, min_n::Int, name::String)
    n >= min_n || throw(ArgumentError("$name requires at least $min_n, got $n"))
    return nothing
end

"""
    require_positive(x, name::String)

Throw `ArgumentError` unless every element of `x` is strictly positive.
"""
function require_positive(x, name::String)
    all(v -> v > 0, x) || throw(ArgumentError("$name must be strictly positive"))
    return nothing
end

"""
    require_probability(v::Real, name::String="value")

Throw `ArgumentError` unless `v` lies in `[0, 1]`.
"""
function require_probability(v::Real, name::String="value")
    (0.0 <= v <= 1.0) || throw(ArgumentError("$name must be in [0, 1], got $v"))
    return nothing
end

"""
    require_nonnegative(x, name::String)

Throw `ArgumentError` unless every element of `x` is `>= 0`.
"""
function require_nonnegative(x, name::String)
    all(v -> v >= 0, x) || throw(ArgumentError("$name must not contain negative values"))
    return nothing
end

"""
    require_square(M::AbstractMatrix, name::String="matrix")

Throw `ArgumentError` unless `M` is square.
"""
function require_square(M::AbstractMatrix, name::String="matrix")
    size(M, 1) == size(M, 2) || throw(ArgumentError(
        "$name must be square, got $(size(M, 1))×$(size(M, 2))"))
    return nothing
end

"""
    require_dims_match(M::AbstractMatrix, n::Int, name::String="matrix")

Throw `ArgumentError` unless `M` is `n`×`n`.
"""
function require_dims_match(M::AbstractMatrix, n::Int, name::String="matrix")
    size(M) == (n, n) || throw(ArgumentError(
        "$name must be $(n)×$(n) to match the data dimension, got $(size(M, 1))×$(size(M, 2))"))
    return nothing
end
