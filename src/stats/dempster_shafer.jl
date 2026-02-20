# SPDX-License-Identifier: PMPL-1.0-or-later
# Dempster-Shafer Theory of Evidence — symbolic computation only.

function dempster_shafer_combination(m1::Dict{String,Float64}, m2::Dict{String,Float64})
    combined = Dict{String,Float64}()
    conflict = 0.0

    for (h1, v1) in m1
        for (h2, v2) in m2
            if h1 == h2
                combined[h1] = get(combined, h1, 0.0) + v1 * v2
            else
                conflict += v1 * v2
            end
        end
    end

    if conflict < 1.0
        for key in keys(combined)
            combined[key] /= (1 - conflict)
        end
    end

    return Dict{String,Any}(
        "combined_mass" => combined, "conflict" => conflict,
        "valid" => conflict < 1.0,
        "interpretation" => conflict > 0.5 ? "High conflict — consider source reliability" :
                           conflict > 0.2 ? "Moderate conflict" : "Low conflict — evidence converges"
    )
end
