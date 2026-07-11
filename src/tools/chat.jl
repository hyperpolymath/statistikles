# SPDX-License-Identifier: MPL-2.0
# Main chat interface for Statistikles.
#
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  NEUROSYMBOLIC STATISTICAL ANALYSIS ASSISTANT                          ║
# ║                                                                         ║
# ║  This is a conversational interface to verified statistical methods.    ║
# ║  Unlike traditional SPSS/R/Stata menu-driven interfaces, you can       ║
# ║  ask questions in natural language. Unlike pure LLM responses,         ║
# ║  every number comes from auditable symbolic code.                      ║
# ║                                                                         ║
# ║  ┌───────────────────────────────────────────────────────────────┐      ║
# ║  │  MOLLOCK WARNING                                              │      ║
# ║  │                                                               │      ║
# ║  │  A "mollock" is a plausible-sounding but fabricated answer.  │      ║
# ║  │  LLMs are KNOWN to produce mollocks in statistical contexts: │      ║
# ║  │  • Invented p-values that "look right"                       │      ║
# ║  │  • Fabricated effect sizes                                    │      ║
# ║  │  • Misremembered formulas                                     │      ║
# ║  │  • Confident but wrong test recommendations                  │      ║
# ║  │                                                               │      ║
# ║  │  Statistikles eliminates mollocks by REQUIRING all numbers    │      ║
# ║  │  to flow through symbolic computation. The LLM interprets,  │      ║
# ║  │  it does not calculate. If you see a statistic that didn't   │      ║
# ║  │  come from a [symbolic] tool call, treat it with suspicion.  │      ║
# ║  └───────────────────────────────────────────────────────────────┘      ║
# ╚══════════════════════════════════════════════════════════════════════════╝

const SYSTEM_PROMPT = """You are Statistikles, a neurosymbolic statistical analysis assistant.

CRITICAL DESIGN PRINCIPLE: You are the NEURAL component. You handle natural language
understanding and interpretation. You NEVER perform calculations yourself. ALL statistics
must be computed by your symbolic tools (Julia functions).

If a user asks for a calculation, ALWAYS use a tool. Never estimate, approximate,
or "recall" a statistical value. If no tool exists for the calculation, say so explicitly.

Your tools cover:
- Descriptive statistics, frequency analysis
- t-tests (independent, paired, one-sample), ANOVA, chi-square
- Pearson/Spearman correlation, simple/multiple regression with VIF
- Non-parametric: Mann-Whitney U, Wilcoxon signed-rank, Kruskal-Wallis
- Effect sizes (Cohen's d, r, eta-squared, odds ratio, Hedges' g)
- Power analysis and sample size calculation
- Bayesian updating, Bayes Factor, credible intervals
- Fuzzy logic membership functions
- Dempster-Shafer evidence combination
- Granger causality testing
- James-Stein shrinkage estimation
- Reliability (Cronbach's alpha, McDonald's omega)
- Measurement (ICC, SEM, item analysis)
- Validity (CVR, criterion, convergent/discriminant)
- Diagnostic metrics (sensitivity, specificity, PPV, NPV)
- PRE measures
- Assumptions testing (normality, Levene's)
- Sampling design (design effects, margin of error)
- Inter-rater reliability (Cohen's kappa, Fleiss' kappa)
- Qualitative: thematic saturation

When explaining, be thorough but accessible. Always interpret results in context.
Mention assumptions and limitations. For methodology questions, draw on both
quantitative and qualitative traditions.

IMPORTANT: When you report a number, it MUST come from a tool call. If the tool
result doesn't include what you need, call another tool. Never fill gaps with
neural computation — that produces mollocks (plausible fabrications)."""

function statistical_assistant_chat()
    println()
    println("=" ^ 72)
    println("  Statistikles — Neurosymbolic Statistical Analysis")
    println("=" ^ 72)
    println()
    println("  Every calculation is performed by verified Julia code.")
    println("  The LLM interprets results — it never invents numbers.")
    println()
    println("  CAPABILITIES:")
    println("  Descriptive | t-tests | ANOVA | Chi-square | Correlation | Regression")
    println("  Non-parametric | Effect sizes | Power analysis | Bayesian | Fuzzy logic")
    println("  Dempster-Shafer | Granger causality | James-Stein | Reliability")
    println("  Validity | Diagnostic metrics | PRE | Assumptions | Sampling")
    println("  Inter-rater reliability | Thematic saturation")
    println()
    println("  Type 'quit' to exit, 'help' for examples, 'offline' for demo")
    println("=" ^ 72)

    messages = [Dict{String,Any}("role" => "system", "content" => SYSTEM_PROMPT)]
    tools = get_tools()

    while true
        print("\n  You: ")
        user_input = readline()
        input = strip(user_input)

        input == "" && continue
        lowercase(input) == "quit" && (println("\n  Goodbye."); break)
        lowercase(input) == "help" && (print_help(); continue)
        lowercase(input) == "offline" && (run_examples(); continue)

        # One malformed turn must never kill the session — isolate the turn body.
        try
            push!(messages, Dict{String,Any}("role" => "user", "content" => input))

            print("\n  Statistikles: ")
            response = call_lm_studio(messages, tools)

            if haskey(response, "error")
                println("Error: $(response["error"])")
                pop!(messages)
                continue
            end

            pr = process_tool_calls(response, messages; tools=tools)
            final = pr.final

            content = nothing
            if haskey(final, "choices") && !isempty(final["choices"])
                content = get(final["choices"][1]["message"], "content", nothing)
            end

            if !isnothing(content)
                # NEURAL-BOUNDARY GUARDRAIL: every number in the reply must trace
                # back to a symbolic tool result before we trust (and print) it.
                user_numbers = extract_numeric_values(input)
                content = enforce_numeric_boundary!(
                    content, messages, tools, pr.tool_results,
                    user_numbers, pr.tool_calls_made)
                println(content)
                push!(messages, Dict{String,Any}("role" => "assistant", "content" => content))
            end
        catch e
            println("\n  [turn error] $(sprint(showerror, e)) — continuing.")
            continue
        end
    end
end

"""
    enforce_numeric_boundary!(content, messages, tools, tool_results,
                              user_numbers, tool_calls_made) -> String

Run the numeric-provenance guardrail on an assistant reply. If unverified
numbers remain, do ONE retry asking the model to restate using only numbers
from the tool results (or, when no tool ran this turn, to compute them or
refrain). If orphans still persist, return the reply with a clear warning block
appended. The model's text is NEVER silently rewritten — orphans are flagged,
never fabricated.
"""
function enforce_numeric_boundary!(content::AbstractString, messages, tools,
                                   tool_results, user_numbers, tool_calls_made::Bool)
    ok, orphans = validate_numeric_provenance(content, tool_results, user_numbers)
    ok && return String(content)

    # ── Single retry ─────────────────────────────────────────────────────────
    retry_msg = if tool_calls_made
        "Your previous reply contained numeric value(s) that do not appear in any " *
        "tool result: " * join(orphans, ", ") * ". Restate your answer using ONLY " *
        "numbers returned by the tool calls above. Do not introduce any other " *
        "numeric value; if a needed number is missing, call the appropriate tool."
    else
        "Your previous reply asserted numeric value(s) (" * join(orphans, ", ") *
        ") but NO symbolic computation was performed this turn, so none of them is " *
        "verified. Call the appropriate statistical tool to compute them, or restate " *
        "your answer without asserting specific numbers."
    end
    push!(messages, Dict{String,Any}("role" => "user", "content" => retry_msg))

    new_content = String(content)
    retry_resp = call_lm_studio(messages, tools)
    if !haskey(retry_resp, "error")
        pr = process_tool_calls(retry_resp, messages; tools=tools)
        append!(tool_results, pr.tool_results)
        if haskey(pr.final, "choices") && !isempty(pr.final["choices"])
            c = get(pr.final["choices"][1]["message"], "content", nothing)
            isnothing(c) || (new_content = String(c))
        end
    end

    ok2, orphans2 = validate_numeric_provenance(new_content, tool_results, user_numbers)
    ok2 && return new_content

    return new_content * _guardrail_warning_block(orphans2, tool_calls_made)
end

function _guardrail_warning_block(orphans, tool_calls_made::Bool)
    io = IOBuffer()
    println(io)
    println(io)
    println(io, "  " * "!"^70)
    println(io, "  UNVERIFIED NUMBERS — POSSIBLE MOLLOCK")
    tool_calls_made || println(io, "  (no symbolic computation was performed this turn)")
    println(io, "  The following number(s) in the reply above did not come from any")
    println(io, "  symbolic tool result and could not be verified:")
    for o in orphans
        println(io, "      - $o")
    end
    println(io, "  Trust only numbers produced by [symbolic] tool calls.")
    print(io,   "  " * "!"^70)
    return String(take!(io))
end

function print_help()
    println("""

    EXAMPLE QUERIES
    ═══════════════

    DESCRIPTIVE     "Describe: 23, 45, 12, 67, 34, 56, 78, 29, 41, 53"
    T-TEST          "Compare groups: A=[85,90,78,92,88] vs B=[76,82,71,80,85]"
    ANOVA           "ANOVA on three groups: [5,6,7], [8,9,10], [3,4,5]"
    CHI-SQUARE      "Test independence: [[30,10],[15,45]]"
    CORRELATION     "Correlate [1,2,3,4,5] with [2,4,5,4,5]"
    REGRESSION      "Regress x=[1,2,3,4,5] on y=[2,4,5,4,5]"
    NON-PARAMETRIC  "Mann-Whitney U: [1,3,5,7] vs [2,4,6,8]"
    EFFECT SIZE     "Convert Cohen's d of 0.8"
    POWER           "Sample size for medium effect (d=0.5), 80% power?"
    BAYESIAN        "Bayes Factor: R2=0.35 (3 pred) vs R2=0.20 (1 pred), n=100"
    RELIABILITY     "Cronbach's alpha: [[4,5,4],[3,4,3],[5,5,4],[4,4,4]]"
    VALIDITY        "8/10 experts rated essential — content valid?"
    DIAGNOSTIC      "Sensitivity/specificity: TP=85, FN=15, TN=90, FP=10"
    NORMALITY       "Test normality: [2.1,3.4,2.8,3.1,2.9,3.3,2.7,3.0,2.5,3.2]"
    SAMPLING        "Margin of error for n=400, 95% confidence?"
    QUALITATIVE     "Saturation: new themes per interview [5,4,3,2,2,1,1,0,1,0,0]"

    CONCEPTUAL      "Explain the difference between validity and reliability"
                    "When should I use non-parametric tests?"
    """)
end

function run_examples()
    println("\n  Running offline examples (no LLM needed)...")
    println("  " * "-"^50)

    println("\n  1. Descriptive Statistics:")
    d = descriptive_stats([23.0, 45, 12, 67, 34, 56, 78, 29, 41, 53])
    println("     Mean: $(round(d["mean"], digits=2)), Median: $(d["median"])")
    println("     SD: $(round(d["std"], digits=2)), Skewness: $(round(d["skewness"], digits=3))")

    println("\n  2. Independent t-test:")
    t = t_test_independent([85.0, 90, 78, 92, 88], [76.0, 82, 71, 80, 85])
    println("     t($(round(t["df"], digits=1))) = $(round(t["t_stat"], digits=3)), p = $(round(t["p_value"], digits=4))")
    println("     Cohen's d = $(round(t["cohens_d"], digits=3)) ($(t["effect_size_interpretation"]))")

    println("\n  3. One-way ANOVA:")
    a = one_way_anova([[5.0,6,7,8], [8.0,9,10,11], [3.0,4,5,6]])
    println("     F($(a["df_between"]),$(a["df_within"])) = $(round(a["F_statistic"], digits=3)), p = $(round(a["p_value"], digits=4))")
    println("     eta-sq = $(round(a["eta_squared"], digits=3))")

    println("\n  4. Pearson Correlation:")
    c = pearson_correlation([1.0,2,3,4,5], [2.0,4,5,4,5])
    println("     r = $(round(c["r"], digits=3)), p = $(round(c["p_value"], digits=4))")
    println("     $(c["interpretation"]) association")

    println("\n  5. James-Stein Estimator:")
    js = james_stein_estimator([10.0, 12, 8, 15, 11])
    println("     Shrinkage = $(round(js["shrinkage_factor"], digits=3))")
    println("     Estimates: $(round.(js["estimates"], digits=2))")

    println("\n  6. Power Analysis:")
    pw = power_analysis_t_test(effect_size=0.5, power=0.80, alpha=0.05)
    n_needed = get(pw, "n_per_group", "N/A")
    println("     For d=0.5, 80% power: n=$n_needed per group")

    println("\n  " * "-"^50)
    println("  All numbers above were computed by Julia, not an LLM.")
end

function main()
    println()
    println("  ┌─────────────────────────────────────────────────────────────┐")
    println("  │  Statistikles v0.1.0                                        │")
    println("  │  Neurosymbolic Statistical Analysis Assistant              │")
    println("  │                                                             │")
    println("  │  DESIGN: LLM = natural language router/interpreter          │")
    println("  │          Julia = verified symbolic computation              │")
    println("  │                                                             │")
    println("  │  Every number is computed, never hallucinated.              │")
    println("  └─────────────────────────────────────────────────────────────┘")

    try
        test_response = HTTP.request("GET", "$BASE_URL/models", HEADERS;
                                     status_exception=false,
                                     connect_timeout=10, readtimeout=120, retry=false)
        if test_response.status == 200
            println("\n  Connected to LM Studio ($MODEL)")
        else
            println("\n  Warning: LM Studio not responding properly")
        end
    catch e
        println("\n  Cannot connect to LM Studio at $BASE_URL")
        println("  Start it with: lms server start")
        println("  Running offline demo instead...")
        run_examples()
        return
    end

    statistical_assistant_chat()
end
