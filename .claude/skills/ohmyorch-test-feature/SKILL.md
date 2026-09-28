---
name: ohmyorch-test-feature
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

Produce `test-report.md`: the independent acceptance evidence proving whether the
delivered behavior satisfies the original criteria. This is **gate 6**.

**This skill writes exactly one artifact: `test-report.md`.** It never modifies product
code, tests, `tasks.md`, or the specification. The tester agent's write-scope hook
enforces this.

## Step 1 — Resolve the change and confirm review passed

Use `$ARGUMENTS` as the change id when given, otherwise the sole active change.

```bash
openspec list
scripts/workflow-status.sh --json
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

Delegate to the `tester` agent, which is read-only on product code. Provide:

- the change id and story id;
- the acceptance criteria verbatim;
- the checks to run and the commands to use;
- the review outcome;
- the instruction to report, never repair.

Ask it to return the full `test-report.md` plus its `TEST RESULT` block.

## Step 6 — Write test-report.md

Write to:

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
scripts/validate-test-report.sh \
  --report "openspec/changes/<change-id>/test-report.md" \
  --change <change-id> \
  --story <story-id>
```

Fix required failures. Do not silence a warning by inventing evidence.

## Step 8 — Route on the verdict

```bash
scripts/workflow-status.sh --change <change-id> --quiet
```

**If any criterion failed**, the change is not accepted and control returns to the
Implementer. Any subsequent code change must be reviewed again before the failed
criteria are retested — review is not skipped because the fix is small:

```text
Test outcome: FAIL — <n> criterion/criteria failed

Criterion <n>: <scenario>
Observed: <what happened>
Expected: <what the criterion requires>

Next: Implementer remediates -> Reviewer re-reviews -> /ohmyorch-test-feature runs again.
The change is NOT accepted.
```

**If all criteria pass**, the change is eligible for the completion gate:

```text
Test outcome: PASS — <n>/<n> criteria evaluated and passing
Gate 6 now passes. Next: the Product Manager evaluates the archive gate (/ohmyorch:opsx:archive).
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
