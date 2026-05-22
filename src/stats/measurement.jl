# SPDX-License-Identifier: MPL-2.0
# Measurement theory — ICC, SEM, item analysis. Symbolic computation only.

function intraclass_correlation(ratings::Matrix{Float64}; icc_type::String="ICC(2,1)")
    n, k = size(ratings)
    gm = mean(ratings)
    row_means = mean(ratings, dims=2)
    col_means = mean(ratings, dims=1)
    SSR = k * sum((row_means .- gm) .^ 2)
    SSC = n * sum((col_means .- gm) .^ 2)
    SST = sum((ratings .- gm) .^ 2)
    SSE = SST - SSR - SSC
    MSR = SSR / (n - 1)
    MSC = SSC / (k - 1)
    MSE = SSE / ((n - 1) * (k - 1))

    icc = if icc_type == "ICC(1,1)"
        (MSR - MSE) / (MSR + (k - 1) * MSE)
    elseif icc_type == "ICC(2,1)"
        (MSR - MSE) / (MSR + (k - 1) * MSE + k * (MSC - MSE) / n)
    elseif icc_type == "ICC(3,1)"
        (MSR - MSE) / (MSR + (k - 1) * MSE)
    elseif icc_type == "ICC(2,k)"
        (MSR - MSE) / (MSR + (MSC - MSE) / n)
    elseif icc_type == "ICC(3,k)"
        (MSR - MSE) / MSR
    else
        return Dict{String,Any}("error" => "Unknown ICC type: $icc_type")
    end

    icc_interp = icc >= 0.90 ? "Excellent" : icc >= 0.75 ? "Good" :
                 icc >= 0.50 ? "Moderate" : "Poor"

    return Dict{String,Any}(
        "ICC" => icc, "type" => icc_type, "interpretation" => icc_interp,
        "n_subjects" => n, "k_raters" => k,
        "MSR" => MSR, "MSC" => MSC, "MSE" => MSE
    )
end

function standard_error_measurement(reliability::Float64, sd::Float64)
    sem = sd * sqrt(1 - reliability)
    return Dict{String,Any}(
        "SEM" => sem, "reliability" => reliability, "SD" => sd,
        "ci_68_band" => sem, "ci_95_band" => 1.96 * sem,
        "interpretation" => "True score falls within +/-$(round(1.96 * sem, digits=2)) of observed score (95% CI)"
    )
end

function item_analysis(responses::Matrix{Float64}, total_scores::Vector{Float64})
    n, k = size(responses)
    item_stats = Dict[]
    for j in 1:k
        item = responses[:, j]
        max_val = maximum(item)
        difficulty = max_val > 0 ? mean(item) / max_val : 0.0
        corrected_total = total_scores .- item
        discrimination = cor(item, corrected_total)

        diff_interp = difficulty > 0.8 ? "Easy" : difficulty > 0.3 ? "Moderate" : "Difficult"
        disc_interp = discrimination >= 0.40 ? "Very good" : discrimination >= 0.30 ? "Good" :
                      discrimination >= 0.20 ? "Acceptable" : "Poor — consider revising"

        push!(item_stats, Dict("item" => j, "difficulty" => difficulty,
                               "difficulty_interpretation" => diff_interp,
                               "discrimination" => discrimination,
                               "discrimination_interpretation" => disc_interp,
                               "mean" => mean(item), "sd" => std(item)))
    end

    return Dict{String,Any}(
        "item_statistics" => item_stats, "n_respondents" => n, "n_items" => k,
        "overall_reliability" => cronbachs_alpha(responses)["cronbachs_alpha"]
    )
end

function sensitivity_specificity(tp::Int, fn::Int, tn::Int, fp::Int)
    sensitivity = tp / (tp + fn)
    specificity = tn / (tn + fp)
    ppv = tp / (tp + fp)
    npv = tn / (tn + fn)
    accuracy = (tp + tn) / (tp + tn + fp + fn)

    return Dict{String,Any}(
        "sensitivity" => sensitivity, "specificity" => specificity,
        "PPV" => ppv, "NPV" => npv, "accuracy" => accuracy,
        "interpretation" => Dict(
            "sensitivity" => "True positive rate (recall)",
            "specificity" => "True negative rate",
            "PPV" => "Precision — probability positive test is correct",
            "NPV" => "Probability negative test is correct"
        )
    )
end

function calculate_PRE(observed::Vector{Float64}, predicted::Vector{Float64},
                       baseline::Union{Vector{Float64},Nothing}=nothing)
    if isnothing(baseline)
        baseline = fill(mean(observed), length(observed))
    end
    E1 = sum((observed .- baseline) .^ 2)
    E2 = sum((observed .- predicted) .^ 2)
    PRE = (E1 - E2) / E1
    r_sq = 1 - (E2 / sum((observed .- mean(observed)) .^ 2))

    return Dict{String,Any}(
        "PRE" => PRE, "r_squared" => r_sq,
        "baseline_error" => E1, "model_error" => E2,
        "percent_reduction" => PRE * 100,
        "interpretation" => "$(round(PRE * 100, digits=2))% reduction in prediction error"
    )
end
