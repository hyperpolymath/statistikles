# W2-7 · Prompt-injection delimiting

**Model:** impl=sonnet · verify=haiku · **Branch:** `fix/prompt-injection-delimiting`

## Context

User-supplied data (dataset values, column names, free text) flows into LLM prompts with
no delimiting or labeling, so a crafted dataset/caption can carry instructions that the
model may follow — and, absent the W1-1 output guardrail, could forge a statistic.
**Depends on W1-1** (the numeric-provenance guardrail is the primary defense; this task
is defense-in-depth on the input side).

## Requirements

1. In `src/tools/chat.jl` / prompt construction: wrap all untrusted user data in clearly
   delimited, labeled segments (e.g. a fenced `<user_data>…</user_data>` block or a
   documented delimiter), and add a system-prompt clause instructing the model to treat
   everything inside as data, never as instructions. Neutralize/escape any delimiter
   collisions in the user content.
2. Keep it minimal and robust — do not attempt to "sanitize" statistical content
   (numbers/strings must pass through intact for computation); the goal is *framing*, not
   filtering.
3. Tests: NEW `test/prompt_injection_test.jl` — construct a prompt from user data that
   contains an injection string and a delimiter-collision attempt; assert the built prompt
   places the data inside the labeled block with collisions neutralized. (Unit-test the
   prompt-construction function directly — no live LLM.)

## Acceptance criteria

- [ ] Untrusted data is delimited + labeled in the constructed prompt (tested).
- [ ] Delimiter-collision in user content is neutralized (tested).
- [ ] System prompt instructs data-not-instructions handling.
- [ ] Full suite green + new test.

## Local verification

`flock /tmp/statistikles-julia.lock -c 'cd <repo> && julia --project=. -e "using Pkg; Pkg.test()"'`
(WSL login shell).

## Out of scope

The output-provenance guardrail (W1-1, the primary control); model-side jailbreak
robustness (out of our control).
