# SPDX-License-Identifier: MPL-2.0

# Algebraic Statistics — Non-Standard Number Systems.
#
# This module implements statistical logic for Binary, p-adic, Complex, 
# and Quaternion-valued data.

"""
    mcnemar_test(b::Int, c::Int; alpha=0.05) -> Dict

MCNEMAR'S TEST: For paired binary data (2x2 contingency table).
- `b`: Number of discordant pairs (Group 1 pass, Group 2 fail).
- `c`: Number of discordant pairs (Group 1 fail, Group 2 pass).
"""
function mcnemar_test(b::Int, c::Int; alpha::Float64=0.05)
    chi2 = (abs(b - c) - 1)^2 / (b + c)
    p_val = 1 - cdf(Chisq(1), chi2)
    
    return Dict{String, Any}(
        "chi_squared" => chi2, "p_value" => p_val,
        "significant" => p_val < alpha,
        "test_type" => "McNemar's Test (Continuity Corrected)"
    )
end

"""
    padic_valuation(n::Int, p::Int) -> Int

P-ADIC VALUATION: Returns the largest exponent v such that p^v divides n.
Fundamental primitive for p-adic analysis.
"""
function padic_valuation(n::Int, p::Int)
    n == 0 && return Inf
    v = 0
    while n % p == 0
        v += 1
        n = div(n, p)
    end
    return v
end

"""
    modular_stats(data::Vector{Int}, modulus::Int) -> Dict

MODULAR ARITHMETIC STATISTICS: Frequency, entropy, and uniformity test in Z/nZ.
Tests whether data is uniformly distributed modulo n (chi-square goodness-of-fit).
"""
function modular_stats(data::Vector{Int}, modulus::Int)
    residues = mod.(data, modulus)
    counts = zeros(Int, modulus)
    for r in residues
        counts[r + 1] += 1  # 0-indexed residues → 1-indexed array
    end
    n = length(data)
    expected = n / modulus

    # Chi-square goodness-of-fit for uniformity
    chi2 = sum((counts .- expected) .^ 2 ./ expected)
    df = modulus - 1
    p_val = 1 - cdf(Chisq(df), chi2)

    # Shannon entropy of residue distribution
    probs = counts ./ n
    entropy = -sum(p > 0 ? p * log2(p) : 0.0 for p in probs)
    max_entropy = log2(modulus)

    return Dict{String,Any}(
        "modulus" => modulus,
        "residue_counts" => counts,
        "chi_squared" => chi2,
        "df" => df,
        "p_value" => p_val,
        "uniform" => p_val > 0.05,
        "entropy" => entropy,
        "max_entropy" => max_entropy,
        "entropy_ratio" => entropy / max_entropy,
        "test_type" => "Modular uniformity test (Z/$modulus Z)"
    )
end

"""
    gcd_stats(data::Vector{Int}) -> Dict

GCD/LCM STATISTICS: Common factors across a dataset. Useful for periodicity detection.
"""
function gcd_stats(data::Vector{Int})
    g = reduce(gcd, abs.(data))
    l = reduce(lcm, abs.(filter(!=(0), data)); init=1)
    return Dict{String,Any}(
        "gcd" => g,
        "lcm" => l,
        "all_even" => all(iseven, data),
        "all_odd" => all(isodd, data),
        "coprime_pairs" => sum(gcd(data[i], data[j]) == 1
            for i in 1:length(data) for j in (i+1):length(data); init=0)
    )
end

"""
    complex_circular_normality(data::Vector{ComplexF64}) -> Dict

COMPLEX NORMALITY: Tests if complex-valued data follows a circular
complex normal distribution (mean 0, independent Real/Imag parts).
"""
function complex_circular_normality(data::Vector{ComplexF64})
    # Circularity implies E[z^2] = 0
    circularity = abs(mean(data.^2))
    # Standard normality on parts
    res_re = test_normality(real(data))
    res_im = test_normality(imag(data))
    
    return Dict{String, Any}(
        "circularity_metric" => circularity,
        "real_normality" => res_re,
        "imag_normality" => res_im,
        "test_type" => "Complex Circular Normality Foundation"
    )
end
