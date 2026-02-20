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
