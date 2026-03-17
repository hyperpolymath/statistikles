# SPDX-License-Identifier: PMPL-1.0-or-later

# Structured and Dynamic Systems — Graphs and Fractals.
#
# This module implements statistical analysis for networks and complex temporal data.

"""
    degree_centrality(adj::Matrix{Int}) -> Vector{Float64}

GRAPH CENTRALITY: Measures the relative importance of nodes based on 
their connections.
"""
function degree_centrality(adj::Matrix{Int})
    n = size(adj, 1)
    degrees = sum(adj, dims=2)[:]
    return degrees ./ (n - 1)
end

"""
    box_counting_dimension(data::Matrix{Int}; scales=[2, 4, 8, 16]) -> Float64

FRACTAL DIMENSION: Estimates the complexity of a pattern (e.g., binary image).
Uses the log-log slope of scale vs box count.
"""
function box_counting_dimension(img::Matrix{Int}; scales::Vector{Int}=[2, 4, 8, 16, 32])
    counts = Float64[]
    for s in scales
        # Count non-empty boxes of size s
        rows, cols = size(img)
        n_rows = div(rows, s)
        n_cols = div(cols, s)
        boxes = 0
        for i in 1:n_rows, j in 1:n_cols
            if sum(img[(i-1)*s+1 : i*s, (j-1)*s+1 : j*s]) > 0
                boxes += 1
            end
        end
        push!(counts, boxes)
    end
    
    # log(N) = -D * log(eps) => D = log(N) / log(1/eps)
    log_eps = log.(1.0 ./ scales)
    log_N = log.(counts)
    
    # Slope via linear regression
    mx, my = mean(log_eps), mean(log_N)
    D = sum((log_eps .- mx) .* (log_N .- my)) / sum((log_eps .- mx).^2)
    return D
end

"""
    hurst_exponent(data::Vector{Float64}) -> Float64

HURST EXPONENT: Measures long-term memory of time series.
- H < 0.5: Mean-reverting.
- H = 0.5: Brownian motion (random walk).
- H > 0.5: Trending.
"""
function hurst_exponent(data::Vector{Float64})
    n = length(data)
    n < 10 && return NaN
    # Simple Rescaled Range (R/S) analysis foundation
    returns = diff(data)
    S = std(returns)
    S == 0 && return 0.5 # Random walk with zero variance returning to mean
    
    m = mean(returns)
    z = cumsum(returns .- m)
    R = maximum(z) - minimum(z)
    
    # Hurst H: R/S ~ n^H => log(R/S) = H * log(n)
    h = log(R / S) / log(n)
    return clamp(h, 0.0, 1.0)
end
