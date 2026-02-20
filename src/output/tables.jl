# SPDX-License-Identifier: PMPL-1.0-or-later
# Table formatting for terminal and export output.

"""
    format_table(headers::Vector{String}, rows::Vector{Vector}; title="") -> String

Format data as a Unicode box-drawing table for terminal display.
"""
function format_table(headers::Vector{String}, rows::Vector{Vector{Any}};
                      title::String="", alignment::Vector{Symbol}=Symbol[])
    n_cols = length(headers)
    if isempty(alignment)
        alignment = fill(:right, n_cols)
    end

    # Convert all values to strings
    str_headers = headers
    str_rows = [[_format_cell(cell) for cell in row] for row in rows]

    # Calculate column widths
    widths = [length(h) for h in str_headers]
    for row in str_rows
        for (j, cell) in enumerate(row)
            j <= n_cols && (widths[j] = max(widths[j], length(cell)))
        end
    end

    # Build table
    lines = String[]

    # Title
    total_width = sum(widths) + 3 * (n_cols - 1) + 4
    if !isempty(title)
        push!(lines, "┌" * "─"^(total_width - 2) * "┐")
        push!(lines, "│ " * rpad(title, total_width - 4) * " │")
    end

    # Top border
    push!(lines, "┌" * join(["─"^(w + 2) for w in widths], "┬") * "┐")

    # Headers
    header_cells = [" " * _align_cell(str_headers[j], widths[j], alignment[j]) * " "
                    for j in 1:n_cols]
    push!(lines, "│" * join(header_cells, "│") * "│")

    # Separator
    push!(lines, "├" * join(["─"^(w + 2) for w in widths], "┼") * "┤")

    # Data rows
    for row in str_rows
        cells = [" " * _align_cell(j <= length(row) ? row[j] : "", widths[j], alignment[j]) * " "
                 for j in 1:n_cols]
        push!(lines, "│" * join(cells, "│") * "│")
    end

    # Bottom border
    push!(lines, "└" * join(["─"^(w + 2) for w in widths], "┴") * "┘")

    return join(lines, "\n")
end

function _format_cell(value)
    if value isa Float64
        abs(value) < 0.001 && value != 0.0 ? @sprintf("%.2e", value) :
        abs(value) > 1e6 ? @sprintf("%.2e", value) :
        @sprintf("%.4f", value)
    elseif value isa Int
        string(value)
    elseif value isa Bool
        value ? "Yes" : "No"
    elseif isnothing(value) || (value isa AbstractFloat && isnan(value))
        "-"
    else
        string(value)
    end
end

function _align_cell(text::String, width::Int, align::Symbol)
    if align == :left
        rpad(text, width)
    elseif align == :right
        lpad(text, width)
    else  # :center
        pad = width - length(text)
        lpad = div(pad, 2)
        " "^lpad * text * " "^(pad - lpad)
    end
end

"""
    results_to_table(result::Dict; title="") -> String

Convert a statistical result dictionary to a formatted table.
"""
function results_to_table(result::Dict; title::String="Results")
    headers = ["Statistic", "Value"]
    rows = Vector{Any}[]

    for (k, v) in sort(collect(result), by=first)
        if v isa Dict || v isa Vector
            continue  # Skip nested structures
        end
        push!(rows, Any[string(k), v])
    end

    return format_table(headers, rows; title, alignment=[:left, :right])
end
