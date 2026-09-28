---
name: ohmyorch-review-feature
description: Independently review an implemented change against its specification and produce review.md. Use after the Implementer reports completion and before acceptance testing. Also use when the user says "review feature", "review the change", or "run the review".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Agent
license: MIT
compatibility: Requires the reviewer agent and the openspec CLI.
metadata:
  author: claude-harness
  version: "1.0"
  implements: "US-6.1"
argument-hint: [change-id]
---

Produce `review.md`: the independent verdict on whether an implementation satisfies
the approved specification. This is **gate 5**.

**This skill writes exactly one artifact: `review.md`.** It never modifies product
code, tests, `tasks.md`, or the specification. The reviewer agent's write-scope hook
enforces this.

## Step 1 — Resolve the change and confirm readiness

Use `$ARGUMENTS` as the change id when given, otherwise the sole active change.

```bash
openspec list
scripts/workflow-status.sh --json
```

Confirm gates 1–4 pass. Reviewing an implementation that began without a plan is
itself a finding — report it rather than reviewing anyway:

```text
Cannot review: gate 3 (plan-handoff) is not passing.
Reason: <from the gate report>
The implementation began without an approved handoff. That is a finding in itself.
```

## Step 2 — Gather the standard and the evidence

Read the specification before the code, so the requirement frames what you look at:

```bash
cat "openspec/changes/<change-id>/proposal.md"
find "openspec/changes/<change-id>/specs" -type f -exec cat {} +
cat "openspec/changes/<change-id>/tasks.md"
cat "openspec/changes/<change-id>/design.md" 2>/dev/null
cat "openspec/changes/<change-id>/implementation-plan.md"
```

Then read the acceptance criteria for the story:

```bash
grep -n "### US-" SPECS.md
```

Then the implementation:

```bash
git diff --name-only
git diff
```

Read the diff itself, not the Implementer's summary of it.

## Step 3 — Run `/ohmyorch:opsx:verify`

```text
/ohmyorch:opsx:verify <change-id>
```

Record its outcome. It is **advisory** and writes no file — you must carry its result
into `review.md` yourself, on an `OpenSpec verify:` line. A blocking mismatch it
reports becomes one of your blocking findings.

## Step 4 — Check scope

```bash
scripts/check-scope.sh --plan "openspec/changes/<change-id>/implementation-plan.md"
```

Unpredicted files are a finding unless the diff explains them.

## Step 5 — Delegate the review to the Reviewer

Delegate to the `reviewer` agent, which is read-only on product code. Provide:

- the change id and story id;
- the acceptance criteria verbatim;
- the artifact paths and the diff;
- the `/ohmyorch:opsx:verify` outcome;
- the scope-check result;
- the instruction to report, never repair.

Ask it to return the full `review.md` plus its `REVIEW RESULT` block.

## Step 6 — Write review.md

Write to:

```text
openspec/changes/<change-id>/review.md
```

Required lines — gate 5 and the validator read these:

```text
Change: <change-id>
Story: <US-n.m>
Verdict: pass | changes-requested
Blocking: None | <n> finding(s)
Coverage: <evaluated>/<total> acceptance criteria evaluated
OpenSpec verify: <outcome>
```

Every finding needs all four of `Requirement`, `Observed`, `Expected`, `Remediation`.

**Watch the two consistency traps:**

```text
Verdict: pass              + Blocking: 2 findings    -> invalid
Verdict: changes-requested + Blocking: None          -> invalid
```

A review with blocking findings cannot pass. A review requesting changes must name
what blocks.

## Step 7 — Validate

```bash
scripts/validate-review.sh \
  --review "openspec/changes/<change-id>/review.md" \
  --change <change-id> \
  --story <story-id>
```

Fix required failures. A warning is a prompt to confirm, not to invent content.

## Step 8 — Confirm the gate moved, then route

```bash
scripts/workflow-status.sh --change <change-id> --quiet
```

**If blocking findings exist**, control returns to the Implementer, and the change
must pass review again before the failed criteria are retested:

```text
Review outcome: CHANGES REQUESTED — <n> blocking finding(s)

F-1: <title> — Requirement: <criterion>
F-2: <title> — Requirement: <criterion>

Next: Implementer remediates, then /ohmyorch-review-feature <change-id> runs again.
Acceptance testing does not proceed on a change with blocking findings.
```

**If the review passes**, control proceeds to the Tester:

```text
Review outcome: PASS
Gate 5 now passes. Next: /ohmyorch-test-feature <change-id> for independent acceptance.
```

## Step 9 — Report

Return:

- the change id, story id, and verdict;
- the blocking count and the affected requirements;
- criteria evaluated out of total;
- the `/ohmyorch:opsx:verify` outcome;
- the scope-check result;
- the validator result;
- confirmation that no product code was modified;
- the next owner.

## Boundaries

- Never modify product code, tests, `tasks.md`, or the specification.
- Never write `test-report.md`.
- Never repair a defect — return it to the Implementer.
- Never score an unverified criterion as passing.
- Never record a verdict that contradicts the blocking count.
- Never let acceptance testing proceed while a blocking finding is open.
