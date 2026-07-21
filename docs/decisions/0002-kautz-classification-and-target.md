<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# 2. Kautz Classification: Correct to Type 3, Target Type 4

Date: 2026-07-21

## Status

Accepted

## Context

Statistikles described itself as a **Kautz Type 1** neurosymbolic system in six
places — `README.adoc` (twice), `EXPLAINME.adoc`, `guix.scm`, `0-AI-MANIFEST.a2ml`,
`.machine_readable/6a2/ECOSYSTEM.a2ml`, and `.machine_readable/6a2/NEUROSYM.a2ml`
(prose plus `kautz-type = 1`).

That label contradicted the description attached to it. `NEUROSYM.a2ml` read:

```
kautz-type = 1
description = "Neural | Symbolic — strict separation with defined interface"
```

In Kautz's taxonomy (AAAI 2020 Engelmore Award lecture):

| Type | Notation | Meaning |
|---|---|---|
| 1 | `symbolic Neuro symbolic` | A plain neural net. Symbols in, symbols out — **the neural net does the work**. |
| 2 | `Symbolic[Neuro]` | A symbolic problem solver calling a neural subroutine (e.g. AlphaGo). |
| 3 | `Neuro \| Symbolic` | A neural and a symbolic engine **cooperating as co-routines** across a defined interface. |
| 4 | `Neuro:Symbolic → Neuro` | Symbolic knowledge **compiled back into** the neural component. |

The `|` pipe notation already in the description is Type 3's. More importantly, the
architecture actually implemented is Type 3's:

- The neural role is *"Natural language understanding and generation ONLY"*
- The symbolic role is *"ALL mathematical and statistical computation"*
- There is one named gate: `src/tools/executor.jl::execute_tool()`
- The MOLLOCK rule — no statistical value may originate from neural inference — is
  enforced at runtime by `validate_numeric_provenance()` in `src/tools/guardrail.jl`,
  which traces every numeric literal in LLM prose back to a recorded tool result

Under Type 1 the LLM would itself be computing, which is exactly the failure mode this
project exists to prevent. The old label did not merely misfile the project; it
described the thing the MOLLOCK rule forbids.

Separately, **no target end-state had ever been recorded.** `docs/decisions/` contained
only the template and ADR 0001, and no target appeared in `RSR_OUTLINE.adoc`,
`STATE.a2ml`, or `NEUROSYM.a2ml`. Elsewhere in the estate this *is* tracked per project
— `idaptik-ums` records its own goal in `docs/adr/0001-ai-edit-kautz6-nesy.adoc`
(Kautz 6) — so the convention existed and statistikles had simply not used it.

## Decision

1. **Classify Statistikles as Kautz Type 3.** Correct all six artefacts, including
   `kautz-type = 3` in `NEUROSYM.a2ml`, and record the taxonomy reasoning in that file
   so the correction is not silently reverted by a future reader.

2. **Adopt Kautz Type 4 (`Neuro:Symbolic → Neuro`) as the target end-state**, recorded
   as `kautz-target = 4`.

   The lever already exists in `NEUROSYM.a2ml [verification-pipeline]`, which lists six
   stages of which exactly one is `implemented`:

   | Stage | Engine | Status |
   |---|---|---|
   | compute | Julia symbolic functions | **implemented** |
   | explain | echidna GraphQL + mathematical working | planned |
   | prove | echidna formal verification | planned |
   | demonstrate | R/Julia visual walkthrough | planned |
   | annotate | code + mathematical annotation | planned |
   | **verify** | **adversarial neurosymbolic SLM** | **planned** |

   That final `verify` stage — feeding symbolic//proof knowledge into a trained
   adversarial model — is the Type 4 transition.

## Consequences

- **Reaching Type 3 is not a work item.** It is already built; this ADR corrects the
  paperwork. The engineering programme is 3 → 4, not 1 → 4.
- The five `planned` pipeline stages become the backlog for that programme.
- Those stages **must stay honestly marked `planned`** until they actually run. A
  `status = "implemented"` on an unbuilt stage would be the documentation equivalent of
  a MOLLOCK, and the same objection applies.
- Downstream consumers of `ECOSYSTEM.a2ml` / `NEUROSYM.a2ml` that key on `kautz-type`
  will see the value change from `1` to `3`.
- Kautz levels are **not** uniform across this estate. Do not infer a project's level
  from a sibling; read its own ADR.

## References

- H. Kautz, *The Third AI Summer*, AAAI Robert S. Engelmore Award Lecture, 2020
- `.machine_readable/6a2/NEUROSYM.a2ml` — classification, MOLLOCK rule, pipeline stages
- `src/tools/executor.jl` — `execute_tool()`, the neural→symbolic gate
- `src/tools/guardrail.jl` — `validate_numeric_provenance()`, runtime MOLLOCK enforcement
- `test/guardrail_test.jl` — tests for the above
