# SPDX-License-Identifier: MPL-2.0
# Qualitative and mixed methods support — symbolic computation only.

function cohens_kappa(rater1::Vector{Int}, rater2::Vector{Int})
    n = length(rater1)
    categories = sort(unique(vcat(rater1, rater2)))
    k = length(categories)
    confusion = zeros(Int, k, k)
    cat_idx = Dict(c => i for (i, c) in enumerate(categories))
    for i in 1:n
        confusion[cat_idx[rater1[i]], cat_idx[rater2[i]]] += 1
    end
    p_o = sum(diag(confusion)) / n
    row_totals = sum(confusion, dims=2) ./ n
    col_totals = sum(confusion, dims=1) ./ n
    p_e = sum(row_totals .* col_totals')
    kappa = (p_o - p_e) / (1 - p_e)

    kappa_interp = kappa >= 0.81 ? "Almost perfect" : kappa >= 0.61 ? "Substantial" :
                   kappa >= 0.41 ? "Moderate" : kappa >= 0.21 ? "Fair" : "Slight/Poor"

    return Dict{String,Any}(
        "kappa" => kappa, "observed_agreement" => p_o, "expected_agreement" => p_e,
        "interpretation" => kappa_interp, "confusion_matrix" => confusion,
        "categories" => categories, "n" => n,
        "scale" => "Landis & Koch (1977) benchmarks"
    )
end

function fleiss_kappa(ratings_matrix::Matrix{Int})
    n, k = size(ratings_matrix)
    N = sum(ratings_matrix[1, :])
    p_j = sum(ratings_matrix, dims=1) ./ (n * N)
    P_i = [(sum(ratings_matrix[i, :] .^ 2) - N) / (N * (N - 1)) for i in 1:n]
    P_bar = mean(P_i)
    P_e = sum(p_j .^ 2)
    kappa = (P_bar - P_e) / (1 - P_e)

    return Dict{String,Any}(
        "kappa" => kappa, "P_observed" => P_bar, "P_expected" => P_e,
        "n_subjects" => n, "n_raters" => N, "n_categories" => k,
        "interpretation" => kappa >= 0.81 ? "Almost perfect" : kappa >= 0.61 ? "Substantial" :
                           kappa >= 0.41 ? "Moderate" : kappa >= 0.21 ? "Fair" : "Slight/Poor"
    )
end

function thematic_saturation(themes_per_interview::Vector{Int}; window::Int=3)
    n = length(themes_per_interview)
    cumulative = cumsum(themes_per_interview)
    pct_new = [themes_per_interview[i] / cumulative[i] * 100 for i in 1:n]
    moving_avg = Float64[]
    for i in 1:n
        start_idx = max(1, i - window + 1)
        push!(moving_avg, mean(themes_per_interview[start_idx:i]))
    end

    saturation_point = nothing
    for i in window:n
        if moving_avg[i] < 0.5
            saturation_point = i
            break
        end
    end

    return Dict{String,Any}(
        "total_themes" => cumulative[end],
        "themes_per_interview" => themes_per_interview,
        "cumulative_themes" => cumulative,
        "pct_new_themes" => pct_new,
        "moving_average" => moving_avg,
        "saturation_point" => saturation_point,
        "saturated" => !isnothing(saturation_point),
        "recommendation" => isnothing(saturation_point) ?
            "Saturation not yet reached — continue data collection" :
            "Saturation reached at interview $saturation_point"
    )
end
