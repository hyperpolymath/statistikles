# SPDX-License-Identifier: MPL-2.0

# Information Theory — Symbolic Entropy and Surprise.
#
# This module implements measures of information content and distribution similarity.

"""
    shannon_entropy(data::Vector; base=2) -> Float64

ENTROPY: Measures uncertainty or information density in a discrete dataset.
"""
function shannon_entropy(data::Vector; base::Real=2)
    counts = countmap(data)
    n = length(data)
    probs = [c / n for c in values(counts)]
    return -sum(p * log(base, p) for p in probs if p > 0)
end

"""
    kl_divergence(p::Vector{Float64}, q::Vector{Float64}; base=2) -> Float64

KULLBACK-LEIBLER DIVERGENCE: Measures how one probability distribution 
differs from a reference distribution.
"""
function kl_divergence(p::Vector{Float64}, q::Vector{Float64}; base::Real=2)
    @assert length(p) == length(q) "Distributions must have same support size"
    return sum(p[i] * log(base, p[i] / q[i]) for i in 1:length(p) if p[i] > 0)
end
