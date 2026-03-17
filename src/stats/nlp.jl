# SPDX-License-Identifier: PMPL-1.0-or-later

# Natural Language Processing — Symbolic Text Analysis.
#
# This module implements deterministic NLP methods like lexicon-based sentiment
# and NMF-based topic modeling.

"""
    lexicon_sentiment(text::String, lexicon::Dict{String, Float64}) -> Float64

SENTIMENT ANALYSIS: Sums scores of tokens found in a provided lexicon.
"""
function lexicon_sentiment(text::String, lexicon::Dict{String, Float64})
    tokens = split(lowercase(text), r"[^a-z]+")
    score = sum(get(lexicon, t, 0.0) for t in tokens)
    return score
end

"""
    topic_modeling_nmf(X::Matrix{Float64}; k=3, max_iter=100) -> Dict

TOPIC MODELING: Uses Non-negative Matrix Factorization to identify latent topics.
- `X`: Term-document matrix [terms x documents].
- `k`: Number of topics.
"""
function topic_modeling_nmf(X::Matrix{Float64}; k::Int=3, max_iter::Int=100)
    # Simple multiplicative update rules for NMF
    m, n = size(X)
    W = rand(m, k)
    H = rand(k, n)
    
    for _ in 1:max_iter
        # H = H .* (Wt * X) / (Wt * W * H)
        H .*= (W' * X) ./ (W' * W * H .+ 1e-10)
        # W = W .* (X * Ht) / (W * H * Ht)
        W .*= (X * H') ./ (W * H * H' .+ 1e-10)
    end
    
    return Dict{String, Any}(
        "topic_word_matrix" => W,
        "document_topic_matrix" => H,
        "test_type" => "NMF Topic Modeling"
    )
end
