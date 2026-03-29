# SPDX-License-Identifier: PMPL-1.0-or-later
# Reliability analysis — symbolic computation only.

function cronbachs_alpha(items::Matrix{Float64})
    k = size(items, 2)
    item_variances = [var(items[:, i]) for i in 1:k]
    total_variance = var(vec(sum(items, dims=2)))

    alpha = (k / (k - 1)) * (1 - sum(item_variances) / total_variance)

    interpretation = alpha >= 0.9 ? "Excellent reliability" :
                     alpha >= 0.8 ? "Good reliability" :
                     alpha >= 0.7 ? "Acceptable reliability" :
                     alpha >= 0.6 ? "Questionable reliability" :
                     "Poor reliability"

    return Dict{String,Any}(
        "cronbachs_alpha" => alpha, "n_items" => k,
        "interpretation" => interpretation,
        "recommendation" => alpha < 0.7 ? "Consider revising items or increasing sample size" :
                           "Reliability is adequate"
    )
end

function mcdonalds_omega(items::Matrix{Float64})
    k = size(items, 2)
    cov_matrix = cov(items)
    total_var = sum(cov_matrix)
    off_diag_sum = total_var - sum(diag(cov_matrix))
    avg_r = off_diag_sum / (k * (k - 1))
    loadings = fill(sqrt(max(0, avg_r)), k)
    sum_loadings = sum(loadings)
    omega = sum_loadings^2 / (sum_loadings^2 + sum(1 .- loadings .^ 2))

    return Dict{String,Any}(
        "omega" => omega,
        "alpha" => cronbachs_alpha(items)["cronbachs_alpha"],
        "n_items" => k, "avg_inter_item_r" => avg_r,
        "note" => "Omega is generally preferred over alpha as it doesn't assume tau-equivalence"
    )
end

"""
    icc(data::Matrix{Float64}; model="twoway", type="agreement") -> Dict

INTRACLASS CORRELATION COEFFICIENT (ICC).
Rows = subjects, columns = raters. Reference: Shrout & Fleiss (1979).
"""
function icc(data::Matrix{Float64}; model::String="twoway", type::String="agreement")
    n, k = size(data)
    grand_mean = mean(data)
    subject_means = mean(data, dims=2)[:]
    MS_R = k * sum((subject_means .- grand_mean) .^ 2) / (n - 1)
    MS_W = sum((data .- subject_means) .^ 2) / (n * (k - 1))
    rater_means = mean(data, dims=1)[:]
    MS_C = n * sum((rater_means .- grand_mean) .^ 2) / (k - 1)
    MS_E = (sum((data .- subject_means .- rater_means' .+ grand_mean) .^ 2)) / ((n - 1) * (k - 1))

    icc_val = if model == "oneway"
        (MS_R - MS_W) / (MS_R + (k - 1) * MS_W)
    elseif type == "agreement"
        (MS_R - MS_E) / (MS_R + (k - 1) * MS_E + k * (MS_C - MS_E) / n)
    else
        (MS_R - MS_E) / (MS_R + (k - 1) * MS_E)
    end

    return Dict{String,Any}(
        "icc" => icc_val, "model" => model, "type" => type,
        "n_subjects" => n, "n_raters" => k,
        "interpretation" => icc_val >= 0.75 ? "Good-Excellent" : icc_val >= 0.5 ? "Moderate" : "Poor",
        "test_type" => "Intraclass Correlation Coefficient (Shrout & Fleiss)"
    )
end

"""
    bland_altman(method1, method2; alpha=0.05) -> Dict

BLAND-ALTMAN: Agreement analysis. Bias, 95% limits of agreement, proportional bias.
"""
function bland_altman(method1::Vector{Float64}, method2::Vector{Float64}; alpha::Float64=0.05)
    @assert length(method1) == length(method2)
    n = length(method1)
    diffs = method1 .- method2
    means_pair = (method1 .+ method2) ./ 2
    bias = mean(diffs)
    sd_diff = std(diffs)
    z = quantile(Normal(), 1 - alpha / 2)

    return Dict{String,Any}(
        "bias" => bias, "sd_diff" => sd_diff,
        "loa_lower" => bias - z * sd_diff, "loa_upper" => bias + z * sd_diff,
        "proportional_bias_r" => cor(means_pair, diffs),
        "n" => n, "test_type" => "Bland-Altman agreement analysis"
    )
end
