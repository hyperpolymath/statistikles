# SPDX-License-Identifier: PMPL-1.0-or-later
# Tool execution dispatcher.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │  CRITICAL: This is where neural meets symbolic.                        │
# │  The LLM requests a tool call → this code dispatches to verified       │
# │  Julia functions → results are EXACT, not hallucinated.                │
# │  Every number returned to the user passed through deterministic code.  │
# └─────────────────────────────────────────────────────────────────────────┘

function execute_tool(tool_name::String, arguments::Dict)
    try
        if tool_name == "descriptive_statistics"
            return descriptive_stats(convert(Vector{Float64}, arguments["data"]))

        elseif tool_name == "frequency_analysis"
            return frequency_table(convert(Vector{String}, arguments["data"]))

        elseif tool_name == "t_test"
            g1 = convert(Vector{Float64}, arguments["group1"])
            alpha = Float64(get(arguments, "alpha", 0.05))
            tt = arguments["type"]
            if tt == "independent"
                return t_test_independent(g1, convert(Vector{Float64}, arguments["group2"]); alpha)
            elseif tt == "paired"
                return t_test_paired(g1, convert(Vector{Float64}, arguments["group2"]); alpha)
            elseif tt == "one_sample"
                return t_test_one_sample(g1, Float64(get(arguments, "mu0", 0.0)); alpha)
            end

        elseif tool_name == "anova"
            return one_way_anova([convert(Vector{Float64}, g) for g in arguments["groups"]])

        elseif tool_name == "chi_square"
            if arguments["type"] == "independence"
                raw = arguments["observed"]
                mat = Matrix{Int}(hcat([convert(Vector{Int}, [Int(x) for x in row]) for row in raw]...)')
                return chi_square_test(mat)
            else
                obs = convert(Vector{Int}, [Int(x) for x in arguments["observed"]])
                ep = haskey(arguments, "expected_proportions") ?
                     convert(Vector{Float64}, arguments["expected_proportions"]) : nothing
                return chi_square_goodness_of_fit(obs, ep)
            end

        elseif tool_name == "correlation"
            x = convert(Vector{Float64}, arguments["x"])
            y = convert(Vector{Float64}, arguments["y"])
            m = get(arguments, "method", "pearson")
            return m == "pearson" ? pearson_correlation(x, y) : spearman_correlation(x, y)

        elseif tool_name == "regression"
            y = convert(Vector{Float64}, arguments["y"])
            raw_x = arguments["x"]
            vn = haskey(arguments, "var_names") ? convert(Vector{String}, arguments["var_names"]) : nothing
            if !isempty(raw_x) && (raw_x[1] isa AbstractVector || raw_x[1] isa AbstractArray)
                X = Matrix{Float64}(hcat([convert(Vector{Float64}, col) for col in raw_x]...))
                return multiple_regression(X, y; var_names=vn)
            else
                return simple_linear_regression(convert(Vector{Float64}, raw_x), y)
            end

        elseif tool_name == "nonparametric_test"
            tt = arguments["type"]
            if tt == "mann_whitney"
                return mann_whitney_u(convert(Vector{Float64}, arguments["group1"]),
                                     convert(Vector{Float64}, arguments["group2"]))
            elseif tt == "wilcoxon"
                return wilcoxon_signed_rank(convert(Vector{Float64}, arguments["group1"]),
                                           convert(Vector{Float64}, arguments["group2"]))
            elseif tt == "kruskal_wallis"
                return kruskal_wallis([convert(Vector{Float64}, g) for g in arguments["groups"]])
            end

        elseif tool_name == "permanova"
            raw_dm = arguments["distance_matrix"]
            dm = Matrix{Float64}(hcat([convert(Vector{Float64}, row) for row in raw_dm]...)')
            labels = arguments["group_labels"]
            n_perm = Int(get(arguments, "n_permutations", 999))
            alpha = Float64(get(arguments, "alpha", 0.05))
            return permanova(dm, labels; n_permutations=n_perm, alpha=alpha)

        elseif tool_name == "effect_size_calculator"
            kwargs = Dict{Symbol,Any}()
            for (k, v) in arguments
                if k in ["cohens_d", "r", "eta_squared", "odds_ratio"]
                    kwargs[Symbol(k)] = Float64(v)
                elseif k in ["n1", "n2"]
                    kwargs[Symbol(k)] = Int(v)
                end
            end
            return effect_sizes(; kwargs...)

        elseif tool_name == "power_analysis"
            es = Float64(arguments["effect_size"])
            n = haskey(arguments, "n") ? Int(arguments["n"]) : nothing
            alpha = Float64(get(arguments, "alpha", 0.05))
            power = haskey(arguments, "power") ? Float64(arguments["power"]) : nothing
            return power_analysis_t_test(effect_size=es, n=n, alpha=alpha, power=power)

        elseif tool_name == "sample_size_calculator"
            return sample_size_calculator(
                design=arguments["design"],
                effect_size=Float64(arguments["effect_size"]),
                alpha=Float64(get(arguments, "alpha", 0.05)),
                power=Float64(get(arguments, "power", 0.80)),
                n_groups=Int(get(arguments, "n_groups", 2)),
                n_predictors=Int(get(arguments, "n_predictors", 1)))

        elseif tool_name == "test_assumptions"
            if arguments["type"] == "normality"
                return test_normality(convert(Vector{Float64}, arguments["data"]))
            elseif arguments["type"] == "levene"
                return levenes_test([convert(Vector{Float64}, g) for g in arguments["groups"]])
            end

        elseif tool_name == "bayesian_analysis"
            prior = convert(Vector{Float64}, arguments["prior"])
            raw_lk = arguments["likelihood"]
            likelihood = Matrix{Float64}(hcat([convert(Vector{Float64}, row) for row in raw_lk]...)')
            return bayesian_update(prior, likelihood, Int(arguments["data_index"]))

        elseif tool_name == "bayes_factor"
            return bayes_factor_bic(Float64(arguments["r_squared_full"]),
                                    Float64(arguments["r_squared_reduced"]),
                                    Int(arguments["n"]),
                                    Int(arguments["p_full"]),
                                    Int(arguments["p_reduced"]))

        elseif tool_name == "credible_intervals"
            samples = convert(Vector{Float64}, arguments["samples"])
            level = Float64(get(arguments, "level", 0.95))
            return credible_interval(samples; level)

        elseif tool_name == "fuzzy_logic_analysis"
            mu = fuzzy_membership(Float64(arguments["value"]),
                                  Float64(arguments["center"]),
                                  Float64(arguments["width"]))
            return Dict{String,Any}("membership_degree" => mu,
                                     "interpretation" => mu > 0.5 ? "Strong membership" : "Weak membership")

        elseif tool_name == "dempster_shafer"
            m1 = Dict{String,Float64}(String(k) => Float64(v) for (k, v) in arguments["evidence1"])
            m2 = Dict{String,Float64}(String(k) => Float64(v) for (k, v) in arguments["evidence2"])
            return dempster_shafer_combination(m1, m2)

        elseif tool_name == "granger_causality"
            return granger_causality_test(convert(Vector{Float64}, arguments["series_x"]),
                                         convert(Vector{Float64}, arguments["series_y"]),
                                         Int(get(arguments, "lag", 1)))

        elseif tool_name == "james_stein"
            obs = convert(Vector{Float64}, arguments["observations"])
            gm = haskey(arguments, "grand_mean") ? Float64(arguments["grand_mean"]) : nothing
            return james_stein_estimator(obs, gm)

        elseif tool_name == "diagnostic_metrics"
            return sensitivity_specificity(Int(arguments["true_positive"]),
                                           Int(arguments["false_negative"]),
                                           Int(arguments["true_negative"]),
                                           Int(arguments["false_positive"]))

        elseif tool_name == "reliability_analysis"
            raw = arguments["items"]
            items = Matrix{Float64}(hcat([convert(Vector{Float64}, row) for row in raw]...)')
            return cronbachs_alpha(items)

        elseif tool_name == "measurement_analysis"
            mt = arguments["type"]
            if mt == "omega"
                raw = arguments["items"]
                items = Matrix{Float64}(hcat([convert(Vector{Float64}, row) for row in raw]...)')
                return mcdonalds_omega(items)
            elseif mt == "sem"
                return standard_error_measurement(Float64(arguments["reliability"]),
                                                  Float64(arguments["sd"]))
            elseif mt == "item_analysis"
                raw = arguments["items"]
                items = Matrix{Float64}(hcat([convert(Vector{Float64}, row) for row in raw]...)')
                return item_analysis(items, vec(sum(items, dims=2)))
            end

        elseif tool_name == "validity_assessment"
            return content_validity_ratio(Int(arguments["n_essential"]),
                                          Int(arguments["n_total"]))

        elseif tool_name == "criterion_validity_test"
            return criterion_validity(convert(Vector{Float64}, arguments["predictor"]),
                                      convert(Vector{Float64}, arguments["criterion"]);
                                      validity_type=get(arguments, "validity_type", "concurrent"))

        elseif tool_name == "inter_rater_reliability"
            irr = arguments["type"]
            if irr == "cohens_kappa"
                return cohens_kappa(convert(Vector{Int}, [Int(x) for x in arguments["rater1"]]),
                                    convert(Vector{Int}, [Int(x) for x in arguments["rater2"]]))
            elseif irr == "fleiss_kappa"
                raw = arguments["ratings_matrix"]
                return fleiss_kappa(Matrix{Int}(hcat([convert(Vector{Int}, [Int(x) for x in row]) for row in raw]...)'))
            elseif irr == "icc"
                raw = arguments["ratings_matrix"]
                mat = Matrix{Float64}(hcat([convert(Vector{Float64}, row) for row in raw]...)')
                return intraclass_correlation(mat; icc_type=get(arguments, "icc_type", "ICC(2,1)"))
            end

        elseif tool_name == "qualitative_analysis"
            themes = convert(Vector{Int}, [Int(x) for x in arguments["themes_per_interview"]])
            return thematic_saturation(themes; window=Int(get(arguments, "window", 3)))

        elseif tool_name == "calculate_pre"
            obs = convert(Vector{Float64}, arguments["observed"])
            pred = convert(Vector{Float64}, arguments["predicted"])
            bl = haskey(arguments, "baseline") ? convert(Vector{Float64}, arguments["baseline"]) : nothing
            return calculate_PRE(obs, pred, bl)

        elseif tool_name == "sampling_design"
            if arguments["type"] == "design_effect"
                return design_effect(Float64(arguments["icc"]), Int(arguments["cluster_size"]))
            elseif arguments["type"] == "margin_of_error"
                pop = haskey(arguments, "population") ? Int(arguments["population"]) : nothing
                return margin_of_error(
                    n=Int(get(arguments, "n", 100)),
                    proportion=Float64(get(arguments, "proportion", 0.5)),
                    confidence=Float64(get(arguments, "confidence", 0.95)),
                    population=pop)
            end

        else
            return Dict{String,Any}("error" => "Unknown tool: $tool_name")
        end
    catch e
        return Dict{String,Any}(
            "error" => "Tool execution failed: $(string(e))",
            "trace" => sprint(showerror, e, catch_backtrace())
        )
    end
end
