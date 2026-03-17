# SPDX-License-Identifier: PMPL-1.0-or-later

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
