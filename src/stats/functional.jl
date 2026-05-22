# SPDX-License-Identifier: MPL-2.0

# Functional Data Analysis — FPCA and Functional Linear Models.
#
# This module implements statistical methods for data that vary over a continuum.

"""
    functional_pca(data::Matrix{Float64}) -> Dict

FPCA: Principal Component Analysis for functional data (curves).
- `data`: [n_points x n_curves] matrix.
"""
function functional_pca(data::Matrix{Float64})
    # Basic discretized FPCA: PCA on the data points.
    res = pca(data')
    
    return Dict{String, Any}(
        "eigenfunctions" => res["components"],
        "explained_variance" => res["explained_variance_ratio"],
        "test_type" => "Functional PCA (Discretized)"
    )
end
