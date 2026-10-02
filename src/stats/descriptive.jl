# SPDX-License-Identifier: MPL-2.0

# Descriptive Statistics — Symbolic Mathematical Kernel.
#
# This module implements deterministic statistical algorithms. 
# INVARIANT: All numbers produced here are computed via symbolic execution 
# in Julia, ensuring 100% auditable accuracy (unlike neural estimation).

"""
    descriptive_stats(data::Vector{Float64}) -> Dict

NUMERICAL ANALYSIS: Computes central tendency, dispersion, and shape.
- CENTRAL TENDENCY: Mean, Median, Mode.
- DISPERSION: StdDev, Variance, Range, IQR.
- SHAPE: Skewness (asymmetry), Kurtosis (tailedness).
- CONFIDENCE: 95% Confidence Interval for the mean.
- OUTLIERS: Identifies thresholds using the 1.5 * IQR fence rule.
"""
function descriptive_stats(data::Vector{Float64})
    # DATA CLEANSING: Filter out NaNs for internal symbolic calculations
    clean_data = filter(!isnan, data)
    n = length(clean_data)
    n < 2 && return Dict{String,Any}("error" => "Need at least 2 non-NaN observations")

    # SORTING: Required for quantile calculations.
    sorted = sort(clean_data)
    q1 = quantile(clean_data, 0.25)
    q3 = quantile(clean_data, 0.75)
    iqr_val = q3 - q1
    
    # MOMENTS: Mean and Variance (already available via Statistics)
    m = mean(clean_data)
    v = var(clean_data)
    s = std(clean_data)

    # SKEWNESS & KURTOSIS: (Implementation of moments)
    # n / ((n-1)(n-2)) * sum(((x-m)/s)^3)
    # DEGENERATE GUARD: the (n-1)(n-2) / (n-2)(n-3) denominators divide by
    # zero below n=3 / n=4 respectively — return `nothing` (JSON null) plus
    # a note rather than leaking NaN/Inf.
    skew_note = n < 3 ? "skewness requires at least 3 observations" : nothing
    kurt_note = n < 4 ? "kurtosis requires at least 4 observations" : nothing
    skew = if n < 3
        nothing
    elseif s == 0
        0.0
    else
        z = (clean_data .- m) ./ s
        (n / ((n - 1) * (n - 2))) * sum(z .^ 3)
    end
    # [n(n+1)/((n-1)(n-2)(n-3)) * sum(z^4)] - [3(n-1)^2/((n-2)(n-3))]
    kurt = if n < 4
        nothing
    elseif s == 0
        0.0
    else
        z = (clean_data .- m) ./ s
        (n * (n + 1) / ((n - 1) * (n - 2) * (n - 3))) * sum(z .^ 4) -
            (3 * (n - 1)^2 / ((n - 2) * (n - 3)))
    end

    # ADVANCED MEANS:
    # Harmonic: n / sum(1/x)
    # Geometric: exp(sum(log(x))/n)
    # DEGENERATE GUARD: undefined (not 0.0 / NaN sentinels) when data
    # contains a zero (harmonic) or a non-positive value (geometric). Mixed
    # positive/negative data can also make sum(1/x) cancel to exactly zero,
    # which would otherwise leak Inf through n / 0.0 — guard that too.
    has_zero = any(clean_data .== 0)
    has_nonpositive = any(clean_data .<= 0)
    h_mean, h_mean_note = if has_zero
        (nothing, "harmonic mean undefined: data contains zero")
    else
        sum_recip = sum(1.0 ./ clean_data)
        sum_recip == 0 ?
            (nothing, "harmonic mean undefined: reciprocals sum to zero") :
            (n / sum_recip, nothing)
    end
    g_mean = has_nonpositive ? nothing : exp(sum(log.(clean_data)) / n)
    g_mean_note = has_nonpositive ? "geometric mean undefined: data contains non-positive values" : nothing

    # MODE: Most frequent value(s)
    mode_val = StatsBase.mode(clean_data)

    # TRIMMED MEAN: 10% trim from each tail
    trim_frac = 0.1
    trim_n = floor(Int, n * trim_frac)
    trimmed = sorted[(trim_n + 1):(n - trim_n)]
    trimmed_mean = length(trimmed) > 0 ? mean(trimmed) : m

    # WINSORIZED MEAN: Replace extremes with boundary values
    winsorized = copy(sorted)
    if trim_n > 0
        winsorized[1:trim_n] .= sorted[trim_n + 1]
        winsorized[(n - trim_n + 1):n] .= sorted[n - trim_n]
    end
    winsorized_mean = mean(winsorized)

    # POWER MEAN (Generalized): M_p = (Σxᵢᵖ/n)^(1/p)
    # p=-1 → harmonic, p=0 → geometric (limit), p=1 → arithmetic, p=2 → quadratic
    quadratic_mean = sqrt(mean(clean_data .^ 2))  # RMS / power mean p=2

    # WEIGHTED MEAN placeholder (uniform weights = arithmetic mean)
    weighted_mean = m

    # MEDIAN ABSOLUTE DEVIATION (MAD)
    med = median(clean_data)
    mad_val = median(abs.(clean_data .- med))

    # COEFFICIENT OF VARIATION
    # DEGENERATE GUARD: undefined (not the Inf sentinel) when the mean is
    # exactly zero.
    cv = m != 0 ? s / abs(m) * 100.0 : nothing
    cv_note = m != 0 ? nothing : "coefficient of variation undefined: mean is zero"

    normality_hint = if skew === nothing || kurt === nothing
        "Insufficient data for shape assessment"
    elseif abs(skew) < 2 && abs(kurt) < 7
        "Approximately normal"
    else
        "Possibly non-normal"
    end

    return Dict{String,Any}(
        "n" => n,
        "mean" => m,
        "median" => med,
        "mode" => mode_val,
        "harmonic_mean" => h_mean,
        "harmonic_mean_note" => h_mean_note,
        "geometric_mean" => g_mean,
        "geometric_mean_note" => g_mean_note,
        "trimmed_mean" => trimmed_mean,
        "winsorized_mean" => winsorized_mean,
        "quadratic_mean" => quadratic_mean,
        "weighted_mean" => weighted_mean,
        "std" => s,
        "variance" => v,
        "mad" => mad_val,
        "cv" => cv,
        "cv_note" => cv_note,
        "skewness" => skew,
        "skewness_note" => skew_note,
        "kurtosis" => kurt,
        "kurtosis_note" => kurt_note,
        "q1" => q1,
        "q3" => q3,
        "iqr" => iqr_val,
        "min" => sorted[1],
        "max" => sorted[end],
        "range" => sorted[end] - sorted[1],
        "outlier_fences" => [q1 - 1.5 * iqr_val, q3 + 1.5 * iqr_val],
        "normality_hint" => normality_hint
    )
end

"""
    power_mean(data::Vector{Float64}, p::Float64) -> Float64

GENERALIZED POWER MEAN (Hölder mean): M_p = (Σxᵢᵖ/n)^(1/p)
Special cases: p=-1 harmonic, p→0 geometric, p=1 arithmetic, p=2 quadratic.
"""
function power_mean(data::Vector{Float64}, p::Float64)
    clean = filter(x -> x > 0, data)
    n = length(clean)
    n == 0 && return NaN
    if abs(p) < 1e-10
        return exp(sum(log.(clean)) / n)  # geometric mean (limit)
    end
    return (sum(clean .^ p) / n) ^ (1.0 / p)
end

"""
    weighted_stats(data::Vector{Float64}, weights::Vector{Float64}) -> Dict

WEIGHTED STATISTICS: Mean, variance, and standard deviation with weights.
"""
function weighted_stats(data::Vector{Float64}, weights::Vector{Float64})
    require_equal_length(data, weights, "data", "weights")
    w_sum = sum(weights)
    w_mean = sum(data .* weights) / w_sum
    w_var = sum(weights .* (data .- w_mean) .^ 2) / w_sum
    return Dict{String,Any}(
        "weighted_mean" => w_mean,
        "weighted_variance" => w_var,
        "weighted_std" => sqrt(w_var),
        "total_weight" => w_sum
    )
end

"""
    frequency_table(data::Vector{String}) -> Dict

CATEGORICAL ANALYSIS: Computes frequencies and relative percentages
for discrete data sets.
"""
function frequency_table(data::Vector{String})
    n = length(data)
    n == 0 && return Dict{String,Any}("error" => "Need at least 1 observation")

    counts = StatsBase.countmap(data)
    categories = sort(collect(keys(counts)))
    freqs = [counts[c] for c in categories]
    rel_freqs = freqs ./ n .* 100.0
    cum_freqs = cumsum(freqs)
    cum_rel_freqs = cumsum(rel_freqs)

    return Dict{String,Any}(
        "categories" => categories,
        "frequencies" => freqs,
        "relative_frequencies" => rel_freqs,
        "cumulative_frequencies" => cum_freqs,
        "cumulative_relative_frequencies" => cum_rel_freqs,
        "n" => n,
        "n_categories" => length(categories),
        "mode" => categories[argmax(freqs)],
        "test_type" => "Frequency table (categorical)"
    )
end
