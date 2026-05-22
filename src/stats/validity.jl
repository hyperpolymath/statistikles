# SPDX-License-Identifier: MPL-2.0
# Validity assessment — symbolic computation only.

function content_validity_ratio(n_essential::Int, n_total::Int)
    CVR = (n_essential - n_total / 2) / (n_total / 2)
    critical_values = Dict(5 => 0.99, 6 => 0.99, 7 => 0.99, 8 => 0.75,
                           9 => 0.78, 10 => 0.62, 15 => 0.49, 20 => 0.42)
    critical_val = get(critical_values, n_total, 0.5)

    return Dict{String,Any}(
        "CVR" => CVR, "n_essential" => n_essential, "n_total" => n_total,
        "critical_value" => critical_val, "valid" => CVR >= critical_val,
        "interpretation" => CVR >= critical_val ? "Item has content validity" :
                           "Item lacks content validity"
    )
end

function convergent_discriminant_validity(trait_correlations::Matrix{Float64},
                                          method_correlations::Matrix{Float64};
                                          trait_names::Union{Vector{String},Nothing}=nothing)
    n_traits = size(trait_correlations, 1)
    convergent_vals = diag(trait_correlations)
    discriminant_vals = Float64[]
    for i in 1:n_traits, j in (i+1):n_traits
        push!(discriminant_vals, trait_correlations[i, j])
    end
    avg_conv = mean(convergent_vals)
    avg_disc = isempty(discriminant_vals) ? 0.0 : mean(discriminant_vals)
    AVE = mean(convergent_vals .^ 2)

    return Dict{String,Any}(
        "convergent_correlations" => convergent_vals,
        "discriminant_correlations" => discriminant_vals,
        "avg_convergent" => avg_conv, "avg_discriminant" => avg_disc,
        "AVE" => AVE,
        "convergent_adequate" => AVE >= 0.50,
        "discriminant_adequate" => avg_conv > avg_disc,
        "overall_assessment" => (AVE >= 0.50 && avg_conv > avg_disc) ?
            "Both convergent and discriminant validity supported" :
            "Validity concerns — review construct operationalization"
    )
end

function criterion_validity(predictor::Vector{Float64}, criterion::Vector{Float64};
                           validity_type::String="concurrent")
    r_result = pearson_correlation(predictor, criterion)
    regression = simple_linear_regression(predictor, criterion)

    return Dict{String,Any}(
        "validity_coefficient" => r_result["r"],
        "r_squared" => r_result["r_squared"],
        "p_value" => r_result["p_value"],
        "significant" => r_result["significant"],
        "validity_type" => validity_type, "regression" => regression,
        "interpretation" => abs(r_result["r"]) >= 0.5 ? "Strong criterion validity" :
                           abs(r_result["r"]) >= 0.3 ? "Moderate criterion validity" :
                           "Weak criterion validity"
    )
end
