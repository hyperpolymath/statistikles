// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Production-readiness fleet runner. Reads the work orders in
// .claude/tasks/prod-readiness/ and executes each as implement -> adversarial-verify
// -> open-PR, routing every task to the Opus/Sonnet/Haiku model it names.
//
// Invoke:  Workflow({ name: "prod-readiness" })                 // all open tasks
//          Workflow({ name: "prod-readiness", args: { wave: 1 } })    // wave 1 only
//          Workflow({ name: "prod-readiness", args: { only: "w1-1" } }) // one task
//
// This is a HEAVY run (many agents, real spend). Run wave 1 first, merge, then wave 2.
export const meta = {
  name: 'prod-readiness',
  description: 'Execute the statistikles production-readiness work orders with per-task model routing',
  phases: [{ title: 'Implement' }, { title: 'Verify' }, { title: 'Finalize' }],
}

const DIR = '.claude/tasks/prod-readiness'

// Routing mirrors DIR/README.md. impl/verify are model names (opus|sonnet|haiku).
const TASKS = [
  { id: 'w1-1', wave: 1, branch: 'fix/neural-boundary-guardrail',        impl: 'opus',   verify: 'opus'   },
  { id: 'w1-2', wave: 1, branch: 'fix/stats-degenerate-inputs',          impl: 'sonnet', verify: 'opus'   },
  { id: 'w1-3', wave: 1, branch: 'test/executor-router-coverage',        impl: 'sonnet', verify: 'sonnet' },
  { id: 'w1-4', wave: 1, branch: 'fix/documented-install-path',          impl: 'sonnet', verify: 'haiku',  done: true }, // merged #34
  { id: 'w1-5', wave: 1, branch: 'fix/supply-chain-pinning',             impl: 'sonnet', verify: 'sonnet', done: true }, // merged #35
  { id: 'w1-6', wave: 1, branch: 'fix/zig-ffi-compiles',                 impl: 'opus',   verify: 'sonnet' },
  { id: 'w1-7', wave: 1, branch: 'fix/agda-proofs-ci',                   impl: 'opus',   verify: 'sonnet' },
  { id: 'w2-1', wave: 2, branch: 'feat/release-registrator-tagbot',      impl: 'opus',   verify: 'opus'   },
  { id: 'w2-2', wave: 2, branch: 'feat/guix-real-package',               impl: 'opus',   verify: 'sonnet' },
  { id: 'w2-3', wave: 2, branch: 'feat/containers-runnable',             impl: 'sonnet', verify: 'sonnet' },
  { id: 'w2-4', wave: 2, branch: 'docs/experimental-reframe',            impl: 'sonnet', verify: 'sonnet' },
  { id: 'w2-5', wave: 2, branch: 'test/reference-validation-extension',  impl: 'sonnet', verify: 'opus'   },
  { id: 'w2-6', wave: 2, branch: 'feat/structured-observability',        impl: 'sonnet', verify: 'sonnet' },
  { id: 'w2-7', wave: 2, branch: 'fix/prompt-injection-delimiting',      impl: 'sonnet', verify: 'haiku'  },
  { id: 'w2-8', wave: 2, branch: 'chore/polish-sweep',                   impl: 'haiku',  verify: 'haiku'  },
]

const FILES = { // work-order filename per id (basename in DIR)
  'w1-1': 'w1-1-neural-guardrail.md', 'w1-2': 'w1-2-stats-degenerate-inputs.md',
  'w1-3': 'w1-3-executor-router-coverage.md', 'w1-4': 'w1-4-documented-install-path.md',
  'w1-5': 'w1-5-supply-chain-pinning.md', 'w1-6': 'w1-6-zig-ffi-compiles.md',
  'w1-7': 'w1-7-agda-proofs-ci.md',
  'w2-1': 'w2-1-release-pipeline.md', 'w2-2': 'w2-2-guix-package.md',
  'w2-3': 'w2-3-containers.md', 'w2-4': 'w2-4-experimental-reframe.md',
  'w2-5': 'w2-5-reference-validation.md', 'w2-6': 'w2-6-observability.md',
  'w2-7': 'w2-7-prompt-injection.md', 'w2-8': 'w2-8-polish-sweep.md',
}

const selected = TASKS.filter((t) =>
  (args && args.only ? t.id === args.only : !t.done) &&   // skip merged tasks unless named explicitly
  (args && args.wave ? t.wave === args.wave : true))

const IMPL_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['branch', 'pushed', 'tests_ran', 'tests_passed', 'summary'],
  properties: {
    branch: { type: 'string' }, pushed: { type: 'boolean' },
    tests_ran: { type: 'boolean' }, tests_passed: { type: 'boolean' },
    summary: { type: 'string' },
  },
}
const VERDICT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['approved', 'must_fix'],
  properties: { approved: { type: 'boolean' }, must_fix: { type: 'array', items: { type: 'string' } } },
}
const FINAL_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['pr_url', 'status'],
  properties: { pr_url: { type: 'string' }, status: { type: 'string', enum: ['opened', 'opened_after_fixes', 'failed'] } },
}

const contract = `Read ${DIR}/README.md (the execution contract + verified toolchain facts) AND your work order in full before doing anything. Follow the contract exactly: branch from up-to-date origin/main, SSH-signed commits with the model Co-Authored-By trailer, run the Local verification (Julia under flock /tmp/statistikles-julia.lock in a WSL login shell), surgical diffs, SHA-pinned actions with step-level conditionals only, DO NOT open issues, DO NOT merge/delete/force-push, open exactly one PR to main. Never claim verification you did not run.`

const run = (task) => {
  const wo = `${DIR}/${FILES[task.id]}`
  return agent(
    `${contract}\n\nYou are the IMPLEMENTER for work order ${task.id} at ${wo} (branch ${task.branch}). Implement it end to end: code + tests, local verification, commit(s), push the branch. Do NOT open the PR (a later stage does).`,
    { label: `impl:${task.id}`, phase: 'Implement', model: task.impl, schema: IMPL_SCHEMA },
  ).then(async (impl) => {
    if (!impl || !impl.pushed) return { task, impl, verdict: { approved: false, must_fix: ['no pushed branch'] } }
    const verdict = await agent(
      `${contract}\n\nYou are an ADVERSARIAL REVIEWER for work order ${task.id} at ${wo}, implemented on branch ${impl.branch}. Clone/fetch and diff origin/main...origin/${impl.branch}. Try to REFUTE it against the work order's Acceptance criteria, line by line: skipped/half-done items, introduced bugs, tests that don't test the claim, unrelated reformatting, missing runtests.jl wiring, workflow YAML using job-level secrets/hashFiles. Default approved=false when uncertain; must_fix must be concrete.`,
      { label: `verify:${task.id}`, phase: 'Verify', model: task.verify, schema: VERDICT_SCHEMA, effort: 'high' },
    )
    return { task, impl, verdict }
  }).then(async ({ task, impl, verdict }) => {
    const fin = await agent(
      `${contract}\n\nYou FINALIZE work order ${task.id} (branch ${task.branch}). Reviewer approved=${verdict.approved}; must_fix:\n${(verdict.must_fix || []).map((m) => '- ' + m).join('\n') || '(none)'}\nIf must_fix is non-empty (or nothing was pushed), apply the fixes / implement from the work order, re-run local verification, commit signed and push. Then open the PR to main per the work order's contract (title from the work order; body: what changed & why with file refs, verification run + result, anything skipped; end with the Claude Code generation line). Do NOT merge.`,
      { label: `final:${task.id}`, phase: 'Finalize', model: task.impl, schema: FINAL_SCHEMA },
    )
    return { id: task.id, branch: task.branch, approved: verdict.approved, ...fin }
  })
}

log(`prod-readiness: running ${selected.length} task(s): ${selected.map((t) => t.id).join(', ')}`)
const results = (await parallel(selected.map((t) => () => run(t)))).filter(Boolean)
log(`Done: ${results.filter((r) => r.pr_url).length}/${selected.length} PRs opened`)
return { results }
