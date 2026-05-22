# SPDX-License-Identifier: MPL-2.0

# Path Analysis — Symbolic Structural Equation Modeling (Observed Variables).
#
# This module implements Path Analysis, which is SEM restricted to observed 
# variables. It fits a system of linear equations using OLS.

"""
    path_analysis(data::DataFrame, model_spec::Vector{Pair{Symbol, Vector{Symbol}}}) -> Dict

PATH ANALYSIS: Fits a recursive system of linear equations and computes fit indices.
- `data`: A DataFrame containing all observed variables.
- `model_spec`: A list of equations, e.g., `[:Y => [:X1, :X2], :X2 => [:X1]]`.
"""
function path_analysis(data::DataFrame, model_spec::Vector{Pair{Symbol, Vector{Symbol}}})
    results = Dict{String, Any}()
    all_path_coeffs = Dict{String, Float64}()
    n = nrow(data)
    
    total_ss_res = 0.0
    total_ss_tot = 0.0
    total_df_res = 0
    
    for (dep, indeps) in model_spec
        # Prepare data for this specific path
        y = convert(Vector{Float64}, data[!, dep])
        X = Matrix{Float64}(data[!, indeps])
        p = length(indeps)
        
        # Fit OLS model using existing kernel
        reg = multiple_regression(X, y; var_names=string.(indeps))
        
        # Store results for this node
        results[string(dep)] = reg
        
        # Collect statistics for global fit indices
        y_pred = hcat(ones(n), X) * [reg["coefficients"]["Intercept"]; [reg["coefficients"][string(v)] for v in indeps]]
        ss_res = sum((y .- y_pred).^2)
        ss_tot = sum((y .- mean(y)).^2)
        
        total_ss_res += ss_res
        total_ss_tot += ss_tot
        total_df_res += (n - p - 1)
        
        # Collect coefficients for global overview
        for (name, val) in reg["coefficients"]
            if name != "Intercept"
                all_path_coeffs["$name -> $(string(dep))"] = val
            end
        end
    end
    
    # Simple Fit Indices (Pseudo-indices for OLS path analysis)
    # RMSEA approximation: sqrt(max(0, (chi2 - df) / (df * (n-1))))
    # Here we treat (SS_res) as a proxy for discrepancy
    rmsea = sqrt(max(0.0, (total_ss_res / (total_ss_tot/n)) / (total_df_res * n)))
    
    return Dict{String, Any}(
        "equations" => results,
        "path_coefficients" => all_path_coeffs,
        "fit_indices" => Dict(
            "RMSEA_approx" => rmsea,
            "R2_global_proxy" => 1 - (total_ss_res / total_ss_tot)
        ),
        "test_type" => "Path Analysis (Observed SEM)",
        "note" => "Fit indices are OLS-based approximations."
    )
end
