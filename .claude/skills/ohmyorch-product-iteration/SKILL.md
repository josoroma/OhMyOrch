---
name: ohmyorch-product-iteration
description: Orchestration entry point that moves one selected READY story through the complete harness workflow, or resumes it from the first incomplete gate. Use when starting or continuing a product iteration. Also use when the user says "product iteration", "start iteration", "resume iteration", or "next story".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Agent
license: MIT
compatibility: Requires the product-manager agent and openspec CLI.
metadata:
  author: claude-harness
  version: "1.0"
  implements: "US-3.2"
argument-hint: [story-id]
---

Move **one** story through the complete harness workflow, or resume it from the first
incomplete gate.

This skill is a thin coordinator. It establishes or locates the change, delegates each
stage to the owning agent, and enforces the gates. It does not plan, implement, review,
or test.

**Start with `$ARGUMENTS`.** If it names a story id (for example `US-2.3`), this is a
fresh start or a resume for that story. If it is empty, detect the situation in
step 0.

## Step 0 — Determine fresh-start vs resume

Never assume. Inspect the repository first.

```bash
scripts/workflow-status.sh --json
openspec list
```

| Observation | Situation | Go to |
|---|---|---|
| No active change | Fresh start | Step 1 |
| The story's change exists and `firstIncompleteGate` is `selection` | Fresh start (change created, nothing planned) | Step 2 |
| The story's change exists and `firstIncompleteGate` is anything else | **Resume** | Step 5 |
| Several active changes, none matching the story | Ambiguous — report and ask | stop |
| Several active changes, one matching the story | Resume that one | Step 5 |

Report what you found and which flow you are taking before proceeding.

## Step 1 — Fresh start: select work

Delegate selection to the `product-manager` agent, or perform it inline using the same
rules.

Locate the story and confirm eligibility:

```bash
grep -n "### $ARGUMENTS:" SPECS.md
scripts/validate-product-artifacts.sh --specs SPECS.md
```

Confirm, and report:

- the story exists and its `Status:` is `READY`;
- its `Dependencies:` are satisfied or explicitly handled;
- the whole backlog passes the readiness contract.

**Stop and report if any check fails.** Do not select a story that is
`NEEDS CLARIFICATION`, `BLOCKED`, or `DONE`, and do not fix a malformed story by
guessing.

## Step 2 — Fresh start: establish exactly one change

Derive a kebab-case change id from the story and check for an existing change.

```bash
openspec list
```

If no change exists for this story:

```bash
openspec new change <change-id>
```

One story, one change. Never create a change that bundles several stories.

## Step 3 — Fresh start: mark the story IN PROGRESS

Update that story's `Status:` to `IN PROGRESS` in `SPECS.md`. This is the only
`SPECS.md` edit made during the iteration. Do not touch other stories.

Then record durable state so a later session can resume without this transcript
(US-9.1):

```bash
scripts/status.sh --change <change-id>
scripts/validate-status.sh --change <change-id>
```

The gates table in `status.md` is **derived** from `workflow-status.sh`, so never
hand-edit it — refresh it. The `## Blockers` section is yours to write and is
preserved across refreshes; record anything that needs a human decision there:

```bash
scripts/status.sh --change <change-id> --blocker "waiting on the CI runner"
```

## Step 4 — Fresh start: walk the gates in order

Delegate one stage at a time, and inspect each result before advancing.

```text
Gate 2  planning       /ohmyorch:opsx:explore  then  /ohmyorch:opsx:propose <change-id>
                       expect: proposal.md, specs/, tasks.md

Gate 3  plan-handoff   /ohmyorch-plan-feature <change-id>
                       expect: implementation-plan.md

Gate 4  implementation /ohmyorch:opsx:apply <change-id>
                       expect: product code + tests; tasks.md checkboxes complete

Gate 5  review         /ohmyorch-review-feature <change-id>
                       expect: review.md, no blocking findings; includes /ohmyorch:opsx:verify

Gate 6  testing        /ohmyorch-test-feature <change-id>
                       expect: test-report.md, no FAIL

Gate 7  acceptance     scripts/validate-product-artifacts.sh
```

After each stage:

```bash
scripts/workflow-status.sh --change <change-id> --quiet
scripts/status.sh --change <change-id> --quiet
```

Advancing a gate is a state change, so refresh `status.md` at every transition —
that is what makes the recorded state current rather than merely present. If the
gate did not pass, return control to that gate's owner rather than advancing. A
failing review goes back to the Implementer; a failing test goes back to the
Implementer, then the Reviewer, then the Tester again.

## Step 5 — Resume: continue from the first incomplete gate

Do **not** restart completed work.

```bash
scripts/status.sh --resume --change <change-id>
scripts/workflow-status.sh --change <change-id> --json
openspec status --change <change-id> --json
```

`status.sh --resume` is the fastest read: it prints the gate table, the first
incomplete gate, the next owner, and any blocker the Product Manager recorded —
all derived from the live gate report, so it cannot disagree with the repository.

Confirm the recorded state is still current before trusting it:

```bash
scripts/validate-status.sh --change <change-id>
```

A failure here means the file is **STALE**, not malformed: someone advanced the
change without refreshing. Refresh, then continue:

```bash
scripts/status.sh --change <change-id>
```

Read the artifacts the report points at:

```bash
cat "openspec/changes/<change-id>/tasks.md"
cat "openspec/changes/<change-id>/implementation-plan.md" 2>/dev/null
cat "openspec/changes/<change-id>/review.md" 2>/dev/null
cat "openspec/changes/<change-id>/test-report.md" 2>/dev/null
cat "openspec/changes/<change-id>/status.md" 2>/dev/null
```

State clearly:

```text
Resuming <change-id> from gate: <firstIncompleteGate>
Reason: <what the report shows>
Already complete: <list of passing gates — do not redo these>
Next owner: <role for the first incomplete gate>
```

Then continue from Step 4 at that gate. If the report shows the change is
archive-eligible, go straight to Step 6.

## Step 6 — Evaluate the archive gate

Only when every gate passes:

```bash
scripts/workflow-status.sh --change <change-id> --json
scripts/completion-gate.sh --change <change-id> --json
openspec validate <change-id>
scripts/validate-product-artifacts.sh
```

**Run both the gate chain and the completion gate.** They are not the same list and
neither contains the other. `completion-gate.sh` evaluates the four US-10.1 conditions
and names the first that fails; condition 4 (OpenSpec verification) has no
corresponding gate, so a green gate chain does **not** imply completion.

Confirm all of these hold: tasks complete, review has no blocking findings, no
acceptance `FAIL`, and OpenSpec verification reports no blocking mismatch.

Record the evaluation for the audit trail, then archive:

```bash
scripts/completion-gate.sh --change <change-id> --record
scripts/validate-verification.sh --change <change-id>
```

**If any condition fails, reject archival and name it.** Do not archive partially
complete work, and do not mark the story `DONE`.

On full success:

```bash
openspec archive <change-id>
```

Then mark the story `DONE` in `SPECS.md`, and refresh the durable record so it agrees
with the archived state:

```bash
scripts/status.sh --change <change-id>
```

Archival itself is the Product Manager's decision and is enforced mechanically by
`scripts/guard-archive.sh`, which rejects the command while any completion condition
fails (US-8.2, US-10.1).

## Step 7 — Report

Return a summary containing:

- the story id and its change id;
- whether this run was a fresh start or a resume, and the resume gate;
- each gate's final status;
- what was delegated to which role;
- any blocker requiring a human Product Manager decision;
- the archive outcome, or the gate that blocked it.

## Boundaries

- One story per iteration, one change per story.
- Never modify product source code, `review.md`, or `test-report.md`.
- Never advance a gate while an earlier gate fails.
- Never hand-edit the gates table in `status.md`; refresh it with `scripts/status.sh`.
- Never mark a story `DONE` before a successful archive.
- Never invent product behavior to unblock a gate.
- Never restart completed work on resume without cause.
