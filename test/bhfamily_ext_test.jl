# SPDX-License-Identifier: MPL-2.0
#
# The ContrastFamilies extension. ContrastFamilies.jl is not in a registry yet
# and Julia 1.10 has no [sources], so the test environment adds it by URL,
# pinned to a commit. The extension must load: a missing extension fails here,
# it is never skipped.

using Pkg

"""Commit of ContrastFamilies.jl the extension is tested against."""
const CONTRASTFAMILIES_REV = "82262db35e0eea7c354ca8a1a832d6fcafcda518"

if Base.find_package("ContrastFamilies") === nothing
    Pkg.add(url = "https://github.com/hyperpolymath/ContrastFamilies.jl", rev = CONTRASTFAMILIES_REV)
end
using ContrastFamilies

@testset "ContrastFamilies extension (BHFamily)" begin
    @test Base.get_extension(Statistikles, :StatistiklesContrastFamiliesExt) !== nothing

    cols = [:abundance, :group, :batch]
    f = parse_formula("abundance ~ group + batch"; columns = cols)
    g = contrasts(f, :group; levels = ["control", "low", "mid", "high"], scheme = :pairwise)
    fam = bh_family(f, g; n_features = 1500)
    @test fam.m == 9000

    rng = Random.MersenneTwister(4)
    p = rand(rng, fam.m)
    r = adjust_p_values(p, fam)
    @test r["adjusted"] == adjust_p_values(p; method = "fdr")["adjusted"]
    @test r["family"]["m"] == 9000
    @test r["family"]["n_contrasts"] == 6
    @test r["family"]["provenance"] == provenance_hash(f)

    # One contrast's slice is not the family: refused, not adjusted with m = 1500.
    @test_throws FamilyMismatch adjust_p_values(p[1:1500], fam)
    @test_throws FamilyMismatch adjust_p_values(vcat(p, 0.5), fam)

    r2 = adjust_p_values(p, fam; method = "holm")
    @test r2["adjusted"] == adjust_p_values(p; method = "holm")["adjusted"]
end
