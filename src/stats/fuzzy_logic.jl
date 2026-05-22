# SPDX-License-Identifier: MPL-2.0
# Fuzzy logic operations — symbolic computation only.

function fuzzy_membership(value::Float64, center::Float64, width::Float64)
    return exp(-((value - center)^2) / (2 * width^2))
end

function fuzzy_and(memberships::Vector{Float64})
    return minimum(memberships)
end

function fuzzy_or(memberships::Vector{Float64})
    return maximum(memberships)
end

function fuzzy_not(membership::Float64)
    return 1.0 - membership
end

function fuzzy_inference(value::Float64, rules::Vector{Tuple{Float64,Float64,String}})
    results = Dict{String,Any}[]
    for (center, width, label) in rules
        mu = fuzzy_membership(value, center, width)
        push!(results, Dict{String,Any}("label" => label, "membership" => mu,
                                         "center" => center, "width" => width))
    end
    sort!(results, by=r -> r["membership"], rev=true)
    return Dict{String,Any}(
        "value" => value, "memberships" => results,
        "dominant_set" => results[1]["label"],
        "dominant_degree" => results[1]["membership"]
    )
end
