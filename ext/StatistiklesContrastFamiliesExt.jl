# SPDX-License-Identifier: MPL-2.0
#
# Loaded only when ContrastFamilies.jl is present. It lets the caller hand
# `adjust_p_values` the test family a formula defines, so the correction is
# applied over the whole family: m = n_features × n_contrasts. Passing one
# contrast's slice (m = 1500 instead of 9000) would be anti-conservative, so it
# throws `ContrastFamilies.FamilyMismatch` instead of returning an error Dict.

module StatistiklesContrastFamiliesExt

using Statistikles
using ContrastFamilies: BHFamily, assert_family_size

"""
    adjust_p_values(p_values, fam::BHFamily; method = "fdr") -> Dict

Adjust `p_values` over the family `fam`. Throws `FamilyMismatch` unless there
is exactly one p-value per test in the family (`length(p_values) == fam.m`);
otherwise returns what `adjust_p_values(p_values; method)` returns, with the
family's size, derivation and formula hashes added under `"family"`.
"""
function Statistikles.adjust_p_values(p_values::Vector{Float64}, fam::BHFamily;
                                      method::String = "fdr")
    assert_family_size(fam, p_values)
    r = Statistikles.adjust_p_values(p_values; method = method)
    r["family"] = Dict("m" => fam.m, "n_features" => fam.n_features,
                       "n_contrasts" => fam.n_contrasts,
                       "contrasts" => fam.contrast_names,
                       "provenance" => fam.provenance,
                       "equivalence" => fam.equivalence)
    return r
end

end # module
