# SPDX-License-Identifier: MPL-2.0

# Multiple Comparison Corrections — Symbolic P-value Adjustment.
#
# This module implements deterministic algorithms for adjusting p-values 
# to control family-wise error rate (FWER) or false discovery rate (FDR).

"""
    adjust_p_values(p_values::Vector{Float64}; method="bonferroni") -> Dict

P-VALUE ADJUSTMENT: Corrects for multiple comparisons.
- `bonferroni`: Simple but conservative. Controls FWER.
- `holm`: Sequentially rejective Bonferroni. More power than Bonferroni.
- `sidak`: Assumes independence between tests.
- `fdr` (Benjamini-Hochberg): Controls False Discovery Rate.
"""
function adjust_p_values(p_values::Vector{Float64}; method::String="bonferroni")
    m = length(p_values)
    m == 0 && return Dict("error" => "No p-values provided")
    
    if method == "bonferroni"
        # p_adj = min(1, p * m)
        adj = min.(1.0, p_values .* m)
        return Dict("original" => p_values, "adjusted" => adj, "method" => "Bonferroni")

    elseif method == "holm"
        # Holm-Bonferroni (Step-down)
        sorted_indices = sortperm(p_values)
        sorted_p = p_values[sorted_indices]
        adj_sorted = zeros(m)
        
        # p_i_adj = max(p_i * (m - i + 1), previous_adj)
        for i in 1:m
            val = sorted_p[i] * (m - i + 1)
            if i == 1
                adj_sorted[i] = min(1.0, val)
            else
                adj_sorted[i] = min(1.0, max(val, adj_sorted[i-1]))
            end
        end
        
        # Restore original order
        adj = zeros(m)
        adj[sorted_indices] = adj_sorted
        return Dict("original" => p_values, "adjusted" => adj, "method" => "Holm-Bonferroni")

    elseif method == "sidak"
        # p_adj = 1 - (1 - p)^m
        adj = 1.0 .- (1.0 .- p_values) .^ m
        return Dict("original" => p_values, "adjusted" => adj, "method" => "Sidak")

    elseif method == "fdr" || method == "bh"
        # Benjamini-Hochberg (Step-up)
        sorted_indices = sortperm(p_values)
        sorted_p = p_values[sorted_indices]
        adj_sorted = zeros(m)
        
        # p_i_adj = p_i * m / i, then enforce monotonicity
        for i in m:-1:1
            val = sorted_p[i] * m / i
            if i == m
                adj_sorted[i] = min(1.0, val)
            else
                adj_sorted[i] = min(1.0, min(val, adj_sorted[i+1]))
            end
        end
        
        adj = zeros(m)
        adj[sorted_indices] = adj_sorted
        return Dict("original" => p_values, "adjusted" => adj, "method" => "Benjamini-Hochberg (FDR)")

    else
        return Dict("error" => "Unknown adjustment method: $method")
    end
end
