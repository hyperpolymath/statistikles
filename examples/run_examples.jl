# SPDX-License-Identifier: MPL-2.0
# Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# Offline example — no LLM required.
#
# Every number printed here is computed by StatistEase's Julia symbolic
# layer, never by a neural model. This is the "no mollocks" guarantee in
# action: run it with
#
#     julia --project=. examples/run_examples.jl
#
# and cross-check any figure against a textbook or reference implementation.

using StatistEase

StatistEase.run_examples()

# A few extra offline calls straight against the executor dispatch chokepoint,
# demonstrating that tool routing produces the same numbers as direct calls.
println("\n  Executor dispatch (same numbers, via the tool boundary):")

anova_direct = one_way_anova([[5.0, 6, 7, 8], [8.0, 9, 10, 11], [3.0, 4, 5, 6]])
anova_tool = StatistEase.execute_tool("anova",
    Dict{String,Any}("groups" => [[5.0, 6, 7, 8], [8.0, 9, 10, 11], [3.0, 4, 5, 6]]))

println("     ANOVA F (direct call): ", round(anova_direct["F_statistic"], digits = 4))
println("     ANOVA F (via executor): ", round(anova_tool["F_statistic"], digits = 4))
println("     Match: ", isapprox(anova_direct["F_statistic"], anova_tool["F_statistic"]))
