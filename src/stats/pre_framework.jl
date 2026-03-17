# SPDX-License-Identifier: PMPL-1.0-or-later

# Proportional Reduction in Error (PRE) Framework.
#
# This module implements a unifying framework for association and predictive 
# measures, based on comparing a predictive model to a baseline model.

abstract type PREMeasure end

"""
    compute_pre(m::PREMeasure) -> Float64

Calculates (E1 - E2) / E1 where E1 is baseline error and E2 is predictive error.
"""
function compute_pre(m::PREMeasure)
    e1 = compute_E1(m)
    e2 = compute_E2(m)
    (e1 == 0 || isnan(e1)) && return NaN
    return (e1 - e2) / e1
end

"""
    interpret_pre(m::PREMeasure) -> String
"""
function interpret_pre(m::PREMeasure)
    pre = compute_pre(m)
    if isnan(pre)
        return "Baseline error is zero or PRE is undefined for this measure."
    elseif pre == 1.0
        return "Perfect prediction"
    elseif pre > 0.0
        return @sprintf("%.1f%% reduction in error", pre * 100)
    elseif pre == 0.0
        return "No improvement over baseline"
    else
        return @sprintf("%.1f%% increase in error", abs(pre) * 100)
    end
end

# --- LAMBDA (Goodman & Kruskal) ---
struct LambdaPRE <: PREMeasure
    data::Matrix{Int} # Contingency table [x, y]
end

function compute_E1(m::LambdaPRE)
    # Error predicting the mode of Y
    margin_y = sum(m.data, dims=1)
    return sum(margin_y) - maximum(margin_y)
end

function compute_E2(m::LambdaPRE)
    # Error predicting the mode of Y within each category of X
    error_sum = 0
    for i in 1:size(m.data, 1)
        row = m.data[i, :]
        row_sum = sum(row)
        if row_sum > 0
            error_sum += (row_sum - maximum(row))
        end
    end
    return error_sum
end

# --- TAU (Goodman & Kruskal) ---
struct TauPRE <: PREMeasure
    data::Matrix{Int}
end

function compute_E1(m::TauPRE)
    n = sum(m.data)
    margin_y = sum(m.data, dims=1) ./ n
    return 1.0 - sum(margin_y .^ 2)
end

function compute_E2(m::TauPRE)
    n = sum(m.data)
    margin_x = sum(m.data, dims=2) ./ n
    e2 = 0.0
    for i in 1:size(m.data, 1)
        row_sum = sum(m.data[i, :])
        if row_sum > 0
            p_y_given_x = m.data[i, :] ./ row_sum
            e2 += margin_x[i] * (1.0 - sum(p_y_given_x .^ 2))
        end
    end
    return e2
end

# --- GAMMA (Goodman & Kruskal) ---
# Gamma is not strictly a PRE measure in the same E1/E2 sense, 
# but often grouped. We implement it via the C/D pair logic.
struct GammaPRE <: PREMeasure
    data::Matrix{Int}
end

function compute_cd_pairs(matrix::Matrix{Int})
    r, c = size(matrix)
    concordant = 0
    discordant = 0
    for i in 1:r, j in 1:c
        count = matrix[i, j]
        count == 0 && continue
        # Concordant: below and to the right
        for i2 in (i+1):r, j2 in (j+1):c
            concordant += count * matrix[i2, j2]
        end
        # Discordant: below and to the left
        for i2 in (i+1):r, j2 in 1:(j-1)
            discordant += count * matrix[i2, j2]
        end
    end
    return concordant, discordant
end

function compute_pre(m::GammaPRE)
    C, D = compute_cd_pairs(m.data)
    (C + D) == 0 && return NaN
    return (C - D) / (C + D)
end

# --- CRAMER'S V ---
struct CramersVPRE <: PREMeasure
    data::Matrix{Int}
end

function compute_pre(m::CramersVPRE)
    n = sum(m.data)
    r, k = size(m.data)
    
    row_sums = sum(m.data, dims=2)
    col_sums = sum(m.data, dims=1)
    
    chi2 = 0.0
    for i in 1:r, j in 1:k
        expected = (row_sums[i] * col_sums[j]) / n
        if expected > 0
            chi2 += (m.data[i, j] - expected)^2 / expected
        end
    end
    
    return sqrt(chi2 / (n * (min(r, k) - 1)))
end

# --- THEIL'S U (Uncertainty Coefficient) ---
struct TheilsUPRE <: PREMeasure
    data::Matrix{Int}
end

function compute_pre(m::TheilsUPRE)
    n = sum(m.data)
    margin_x = sum(m.data, dims=2) ./ n
    margin_y = sum(m.data, dims=1) ./ n
    
    hy = -sum(p * log(p) for p in margin_y if p > 0)
    hy == 0 && return NaN
    
    hy_x = 0.0
    for i in 1:size(m.data, 1)
        row_sum = sum(m.data[i, :])
        if row_sum > 0
            p_y_given_x = m.data[i, :] ./ row_sum
            h_row = -sum(p * log(p) for p in p_y_given_x if p > 0)
            hy_x += margin_x[i] * h_row
        end
    end
    
    return (hy - hy_x) / hy
end

# --- KENDALL'S TAU-B ---
struct KendallsTauBPRE <: PREMeasure
    data::Matrix{Int}
end

function compute_pre(m::KendallsTauBPRE)
    C, D = compute_cd_pairs(m.data)
    n = sum(m.data)
    row_sums = sum(m.data, dims=2)
    col_sums = sum(m.data, dims=1)
    
    tx = 0.5 * sum(rs * (rs - 1) for rs in row_sums)
    ty = 0.5 * sum(cs * (cs - 1) for cs in col_sums)
    
    den = sqrt((C + D + tx) * (C + D + ty))
    den == 0 && return NaN
    return (C - D) / den
end

# --- GLOBAL WRAPPER ---
function calculate_PRE_suite(matrix::Matrix{Int})
    measures = [
        "Lambda" => LambdaPRE(matrix),
        "Tau" => TauPRE(matrix),
        "Gamma" => GammaPRE(matrix),
        "Cramer's V" => CramersVPRE(matrix),
        "Theil's U" => TheilsUPRE(matrix),
        "Kendall's Tau-b" => KendallsTauBPRE(matrix)
    ]
    
    results = Dict{String, Any}()
    for (name, m) in measures
        results[name] = Dict(
            "value" => compute_pre(m),
            "interpretation" => interpret_pre(m)
        )
    end
    return results
end
