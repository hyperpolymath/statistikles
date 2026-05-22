# SPDX-License-Identifier: MPL-2.0
# ASCII/Unicode graph output for terminal display.
# These provide immediate visual feedback without external dependencies.

"""
    ascii_histogram(data::Vector{Float64}; bins=10, width=50) -> String

Render a horizontal ASCII histogram.
"""
function ascii_histogram(data::Vector{Float64}; bins::Int=10, width::Int=50,
                         title::String="Histogram")
    lo, hi = minimum(data), maximum(data)
    bin_width = (hi - lo) / bins
    bin_width == 0 && return "All values identical: $(lo)"

    counts = zeros(Int, bins)
    for x in data
        idx = min(bins, max(1, ceil(Int, (x - lo) / bin_width)))
        counts[idx] += 1
    end

    max_count = maximum(counts)
    lines = String["  $title (n=$(length(data)))"]
    push!(lines, "  " * "─"^(width + 20))

    for i in 1:bins
        bin_lo = lo + (i - 1) * bin_width
        bin_hi = lo + i * bin_width
        label = @sprintf("%7.1f-%7.1f", bin_lo, bin_hi)
        bar_len = max_count > 0 ? round(Int, counts[i] / max_count * width) : 0
        bar = "█"^bar_len
        push!(lines, "  $label │ $bar $(counts[i])")
    end

    push!(lines, "  " * "─"^(width + 20))
    return join(lines, "\n")
end

"""
    ascii_boxplot(data::Vector{Float64}; width=50) -> String

Render an ASCII box plot.
"""
function ascii_boxplot(data::Vector{Float64}; width::Int=50,
                       title::String="Box Plot")
    lo = minimum(data)
    hi = maximum(data)
    q1 = quantile(data, 0.25)
    med = median(data)
    q3 = quantile(data, 0.75)
    range_val = hi - lo

    range_val == 0 && return "All values identical: $lo"

    pos(x) = max(1, min(width, round(Int, (x - lo) / range_val * width)))

    p_lo = pos(lo)
    p_q1 = pos(q1)
    p_med = pos(med)
    p_q3 = pos(q3)
    p_hi = pos(hi)

    line = fill(' ', width + 1)
    # Whiskers
    for i in p_lo:p_q1
        line[i] = '─'
    end
    for i in p_q3:p_hi
        line[i] = '─'
    end
    # Box
    for i in p_q1:p_q3
        line[i] = '█'
    end
    # Median
    line[p_med] = '┃'
    # Endpoints
    line[p_lo] = '├'
    line[p_hi] = '┤'

    lines = String[]
    push!(lines, "  $title")
    push!(lines, "  " * String(line))
    push!(lines, "  " * lpad(@sprintf("%.1f", lo), p_lo) *
          " "^max(0, p_med - p_lo - length(@sprintf("%.1f", lo))) *
          @sprintf("%.1f", med) *
          " "^max(0, p_hi - p_med - length(@sprintf("%.1f", med))) *
          @sprintf("%.1f", hi))

    return join(lines, "\n")
end

"""
    ascii_scatter(x::Vector{Float64}, y::Vector{Float64}; width=50, height=20) -> String

Render an ASCII scatter plot.
"""
function ascii_scatter(x::Vector{Float64}, y::Vector{Float64};
                       width::Int=50, height::Int=20,
                       title::String="Scatter Plot")
    n = length(x)
    n != length(y) && return "Error: x and y must have same length"

    x_lo, x_hi = minimum(x), maximum(x)
    y_lo, y_hi = minimum(y), maximum(y)
    x_range = x_hi - x_lo
    y_range = y_hi - y_lo

    x_range == 0 && (x_range = 1.0)
    y_range == 0 && (y_range = 1.0)

    grid = fill(' ', height, width)

    for i in 1:n
        col = max(1, min(width, round(Int, (x[i] - x_lo) / x_range * (width - 1)) + 1))
        row = max(1, min(height, height - round(Int, (y[i] - y_lo) / y_range * (height - 1))))
        grid[row, col] = grid[row, col] == ' ' ? '*' : '#'
    end

    lines = String["  $title (n=$n)"]
    push!(lines, "  " * @sprintf("%7.1f", y_hi) * " ┐")
    for row in 1:height
        push!(lines, "          │" * String(grid[row, :]))
    end
    push!(lines, "  " * @sprintf("%7.1f", y_lo) * " ┘" * "─"^width)
    push!(lines, "          " * lpad(@sprintf("%.1f", x_lo), 1) *
          " "^(width - length(@sprintf("%.1f", x_lo)) - length(@sprintf("%.1f", x_hi))) *
          @sprintf("%.1f", x_hi))

    return join(lines, "\n")
end

"""
    ascii_bar_chart(labels::Vector{String}, values::Vector{Float64}; width=40) -> String

Render a horizontal bar chart.
"""
function ascii_bar_chart(labels::Vector{String}, values::Vector{Float64};
                         width::Int=40, title::String="Bar Chart")
    max_val = maximum(values)
    max_label = maximum(length.(labels))

    lines = String["  $title"]
    push!(lines, "  " * "─"^(max_label + width + 10))

    for (label, val) in zip(labels, values)
        bar_len = max_val > 0 ? round(Int, val / max_val * width) : 0
        bar = "█"^bar_len
        push!(lines, "  " * rpad(label, max_label) * " │ " * bar * " " * @sprintf("%.1f", val))
    end

    push!(lines, "  " * "─"^(max_label + width + 10))
    return join(lines, "\n")
end
