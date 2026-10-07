---
name: test-feature
description: Independently validate every acceptance criterion of an implemented, reviewed change and produce test-report.md with PASS/FAIL and evidence. Use after review passes and before archival. Also use when the user says "test feature", "run acceptance", or "validate the change".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Agent
license: MIT
compatibility: Requires the tester agent and the openspec CLI.
metadata:
  author: claude-harness
  version: "1.0"
  implements: "US-7.1"
argument-hint: [change-id]
---

## Installed plugin contract

Read `${CLAUDE_PLUGIN_ROOT}/references/contract.md` and the applicable bundled rules before acting. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" doctor --json` and stop on FAIL/UNSUPPORTED checks. Resolve every PRD/SPECS/CODEBASE reference through its `documents` mapping. These artifact names never imply a root-only layout. Use concrete resolved paths in Read/Write/Edit/Bash calls; do not copy plugin code/rules into the project. Resolve project files from the explicit project root and bundled files from the plugin root.

Inline path substitution supplies text, not automatic Bash environment variables. Shell-escape each substituted path/argument as a literal argument; never evaluate user `$ARGUMENTS` as shell code. Essential rules also reach delegated agents directly through the `ohmyorch:contract` preload. Pass project root, change, story, configured artifacts and prior evidence explicitly when delegating. Reviewer/tester agents persist their own selected verdict; the caller reads and validates it.
Produce `test-report.md`: the independent acceptance evidence proving whether the
delivered behavior satisfies the original criteria. This is **gate 6**.

**This skill writes exactly one artifact: `test-report.md`.** It never modifies product
code, tests, `tasks.md`, or the specification. The tester root dispatcher's role check
enforces this.

## Step 1 — Resolve the change and confirm review passed

Use `$ARGUMENTS` as the change id when given, otherwise the sole active change.

```bash
openspec list
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" workflow-status --json
```

**Gate 5 (`review`) must pass before testing.** Testing a change with blocking review
findings wastes the run and risks accepting work already judged defective:

```text
Cannot test: gate 5 (review) is not passing.
Reason: <from the gate report>
Resolve the review findings first, then retest.
```

## Step 2 — Gather the criteria

Read them **from the specification**, not from the implementation or the plan:

```bash
grep -n "### US-" SPECS.md
cat "openspec/changes/<change-id>/proposal.md"
find "openspec/changes/<change-id>/specs" -type f -exec cat {} +
cat "openspec/changes/<change-id>/tasks.md"
cat "openspec/changes/<change-id>/review.md"
```

The acceptance criteria are the standard. The review tells you what the Reviewer
concluded; it does not decide your results.

## Step 3 — Derive the checks

Find the project's existing validation surface rather than inventing one:

```bash
cat CODEBASE.md 2>/dev/null
ls package.json Makefile pyproject.toml go.mod Cargo.toml 2>/dev/null
```

For each criterion decide the method:

| Method | When |
|---|---|
| Executable check | A test, command, build, type check, or script can demonstrate it |
| Explicit inspection | No executable check can, e.g. a prompt or documentation change |

Prefer executable checks. When you use inspection, say so and name what you inspected.
When neither is possible, the criterion is **unverified** — record that, never PASS.

## Step 4 — Run the checks

Run them. Capture the actual output for the report's `## Evidence Commands` section.
Do not record a result you did not observe.

## Step 5 — Delegate to the Tester

Delegate to the `ohmyorch:tester` agent, which is read-only on product code. Provide:

- the change id and story id;
- the acceptance criteria verbatim;
- the checks to run and the commands to use;
- the review outcome;
- the instruction to report, never repair.

Ask the Tester to persist the complete `test-report.md` with its own Write/Edit tool, then return the artifact path and `TEST RESULT` summary. The coordinator must not author the verdict.

## Step 6 — Confirm the Tester persisted test-report.md

The delegated Tester writes to:

```text
openspec/changes/<change-id>/test-report.md
```

Required lines:

```text
Change: <change-id>
Story: <US-n.m>
Verdict: pass | fail
Coverage: <evaluated>/<total> acceptance criteria evaluated
```

Plus a `## Acceptance Criteria Evaluated` table with a PASS/FAIL and evidence per row,
and a `## Failures` section for every FAIL.

**Watch the two consistency traps:**

```text
Verdict: pass + a criterion recorded FAIL   -> invalid
Verdict: fail + no criterion recorded FAIL  -> invalid
```

Make the declared `Coverage:` count match the rows you list — a mismatch is flagged.

## Step 7 — Validate

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" validate-test-report \
  --report "openspec/changes/<change-id>/test-report.md" \
  --change <change-id> \
  --story <story-id>
```

Return malformed-artifact diagnostics to the Tester to correct; the coordinator never repairs the verdict. Do not silence a warning by inventing evidence.

## Step 8 — Route on the verdict

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" workflow-status --change <change-id> --quiet
```

**If any criterion failed**, the change is not accepted and control returns to the
Implementer. Any subsequent code change must be reviewed again before the failed
criteria are retested — review is not skipped because the fix is small:

```text
Test outcome: FAIL — <n> criterion/criteria failed

Criterion <n>: <scenario>
Observed: <what happened>
Expected: <what the criterion requires>

Next: Implementer remediates -> Reviewer re-reviews -> /ohmyorch:test-feature runs again.
The change is NOT accepted.
```

**If all criteria pass**, the change is eligible for the completion gate:

```text
Test outcome: PASS — <n>/<n> criteria evaluated and passing
Gate 6 now passes. Next: the Product Manager evaluates the archive gate (/ohmyorch:opsx-archive).
```

Acceptance alone does not archive the change — the Product Manager owns that decision
(US-10.1).

## Step 9 — Report

Return:

- the change id, story id, and verdict;
- criteria evaluated, passed, and failed;
- the method used (executable checks, inspection, or mixed) and why;
- the commands run;
- the validator result;
- confirmation that no product code was modified;
- the next owner.

## Boundaries

- Never modify product code or tests — mechanically blocked.
- Never write `review.md`.
- Never repair failing behavior.
- Never score an unverified criterion as passing.
- Never record a verdict that contradicts the FAIL rows.
- Never archive a change — that is the Product Manager's decision.

## Verdict persistence authority

The delegated Tester must use Write/Edit itself to persist the complete selected verdict, then return only its path and findings summary. Do not ask the caller to write, reconstruct or repair the verdict. The coordinator validates the specialist-written file through the bundled validator and refreshes status. Any earlier generic return-content instruction applies only to the summary, never verdict authorship.
