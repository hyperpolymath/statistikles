# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# benchmarks.jl — Performance benchmarks for StatistEase core operations
#
# Uses BenchmarkTools.jl to measure the throughput and latency of
# descriptive_stats at three dataset scales, plus a batch computation
# scenario representative of real analysis workloads.
#
# Run with:
#   julia benches/benchmarks.jl
# Or from the project root:
#   julia --project=. benches/benchmarks.jl

using BenchmarkTools
using Random
using Statistics
using StatistEase

# ── Reproducible random data ──────────────────────────────────────────────────
Random.seed!(20260101)

println("=" ^ 70)
println("StatistEase Benchmarks")
println("Julia $(VERSION)  |  $(Sys.cpu_info()[1].model)")
println("=" ^ 70)
println()

# ── Benchmark 1: Small array (10 elements) ───────────────────────────────────
# Representative of interactive use with tiny datasets.

println("Benchmark 1: Small array — 10 elements")
println("-" ^ 50)
small_data = randn(10) .* 5 .+ 20.0

b_small = @benchmark descriptive_stats($small_data)
display(b_small)
println()
println(
    "  median: $(round(median(b_small.times) / 1e3, digits=2)) μs  |  " *
    "min: $(round(minimum(b_small.times) / 1e3, digits=2)) μs  |  " *
    "allocs: $(b_small.allocs)"
)
println()

# ── Benchmark 2: Medium array (1 000 elements) ───────────────────────────────
# Representative of per-variable analysis in a moderate survey dataset.

println("Benchmark 2: Medium array — 1 000 elements")
println("-" ^ 50)
medium_data = randn(1_000) .* 15 .+ 100.0

b_medium = @benchmark descriptive_stats($medium_data)
display(b_medium)
println()
println(
    "  median: $(round(median(b_medium.times) / 1e3, digits=2)) μs  |  " *
    "min: $(round(minimum(b_medium.times) / 1e3, digits=2)) μs  |  " *
    "allocs: $(b_medium.allocs)"
)
println()

# ── Benchmark 3: Large array (100 000 elements) ──────────────────────────────
# Representative of population-scale or sensor-stream analysis.

println("Benchmark 3: Large array — 100 000 elements")
println("-" ^ 50)
large_data = randn(100_000) .* 20 .+ 500.0

b_large = @benchmark descriptive_stats($large_data)
display(b_large)
println()
println(
    "  median: $(round(median(b_large.times) / 1e3, digits=2)) μs  |  " *
    "min: $(round(minimum(b_large.times) / 1e3, digits=2)) μs  |  " *
    "allocs: $(b_large.allocs)"
)
println()

# ── Benchmark 4: Batch computation — 100 arrays of 100 elements ──────────────
# Representative of running descriptive_stats across 100 variables in a
# dataset (e.g., 100-item psychometric questionnaire).

println("Benchmark 4: Batch — 100 arrays × 100 elements each")
println("-" ^ 50)
batch_data = [randn(100) .* 10 .+ 50.0 for _ in 1:100]

b_batch = @benchmark begin
    for arr in $batch_data
        descriptive_stats(arr)
    end
end
display(b_batch)
println()
println(
    "  median total: $(round(median(b_batch.times) / 1e6, digits=3)) ms  |  " *
    "per-array: $(round(median(b_batch.times) / 1e3 / 100, digits=2)) μs  |  " *
    "allocs: $(b_batch.allocs)"
)
println()

# ── Benchmark 5: Power mean sweep — multiple p values ────────────────────────
# Tests the power_mean function across a range of p values.

println("Benchmark 5: Power mean sweep — 1 000 elements, p ∈ {-2,-1,0,1,2,3}")
println("-" ^ 50)
pm_data = abs.(randn(1_000)) .+ 0.5  # Positive for all power means
p_values = [-2.0, -1.0, 0.0, 1.0, 2.0, 3.0]

b_pm = @benchmark begin
    for p in $p_values
        power_mean($pm_data, p)
    end
end
display(b_pm)
println()
println(
    "  median: $(round(median(b_pm.times) / 1e3, digits=2)) μs  |  " *
    "allocs: $(b_pm.allocs)"
)
println()

# ── Summary table ─────────────────────────────────────────────────────────────
println("=" ^ 70)
println("Summary (median latency)")
println("=" ^ 70)
println("  Small  (10 elems):         $(round(median(b_small.times)  / 1e3, digits=2)) μs")
println("  Medium (1 000 elems):      $(round(median(b_medium.times) / 1e3, digits=2)) μs")
println("  Large  (100 000 elems):    $(round(median(b_large.times)  / 1e3, digits=2)) μs")
println("  Batch  (100 × 100 elems):  $(round(median(b_batch.times)  / 1e6, digits=3)) ms total")
println("  Power mean sweep (6 p):    $(round(median(b_pm.times)     / 1e3, digits=2)) μs")
println("=" ^ 70)
