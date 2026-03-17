# SPDX-License-Identifier: PMPL-1.0-or-later

# Time Series Analysis — Deterministic Temporal Models.
#
# This module implements moving averages and basic decomposition.

"""
    moving_average(data::Vector{Float64}, window::Int; type="simple") -> Vector{Float64}

MOVING AVERAGE: Smoothes temporal data.
- `simple`: Unweighted mean.
- `exponential`: Weight decreases exponentially for older observations.
"""
function moving_average(data::Vector{Float64}, window::Int; type::String="simple")
    n = length(data)
    result = fill(NaN, n)
    
    if type == "simple"
        for i in window:n
            result[i] = mean(data[(i - window + 1):i])
        end
    elseif type == "exponential"
        alpha = 2 / (window + 1)
        result[1] = data[1]
        for i in 2:n
            result[i] = alpha * data[i] + (1 - alpha) * result[i-1]
        end
    end
    
    return result
end

"""
    autocorrelation(data::Vector{Float64}, max_lag::Int) -> Vector{Float64}

ACF: Measures correlation of a series with its own lagged values.
"""
function autocorrelation(data::Vector{Float64}, max_lag::Int)
    n = length(data)
    m = mean(data)
    v = var(data)
    acf = zeros(max_lag + 1)
    
    for lag in 0:max_lag
        num = sum((data[1:(n-lag)] .- m) .* (data[(lag+1):n] .- m))
        acf[lag+1] = num / ((n - 1) * v)
    end
    
    return acf
end

"""
    dynamic_time_warping(s::Vector{Float64}, t::Vector{Float64}) -> Float64

DYNAMIC TIME WARPING: Computes an optimal match between two temporal sequences.
Returns the warping distance.
"""
function dynamic_time_warping(s::Vector{Float64}, t::Vector{Float64})
    n, m = length(s), length(t)
    dtw = fill(Inf, n + 1, m + 1)
    dtw[1, 1] = 0.0
    
    for i in 1:n, j in 1:m
        cost = abs(s[i] - t[j])
        dtw[i+1, j+1] = cost + min(dtw[i, j+1], dtw[i+1, j], dtw[i, j])
    end
    
    return dtw[n+1, m+1]
end
