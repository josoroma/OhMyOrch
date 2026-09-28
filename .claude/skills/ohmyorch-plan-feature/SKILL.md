---
name: ohmyorch-plan-feature
description: Produce implementation-plan.md for an active OpenSpec change by exploring the repository and mapping tasks to acceptance criteria. Use after a change is proposed and before implementation begins. Also use when the user says "plan feature", "create implementation plan", or "plan the change".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Agent
license: MIT
compatibility: Requires the planner agent and openspec CLI.
metadata:
  author: claude-harness
  version: "1.0"
  implements: "US-4.1"
argument-hint: [change-id]
---

Produce `implementation-plan.md`: the repository-aware handoff an Implementer works
from. This is **gate 3** of the harness workflow — implementation cannot begin without
it.

**This skill writes exactly one artifact: `implementation-plan.md`.** It never
modifies product source code, `tasks.md`, the delta specs, or `SPECS.md`.

## Step 1 — Resolve the change

Use `$ARGUMENTS` as the change id when given. Otherwise resolve the sole active change.

```bash
openspec list
scripts/workflow-status.sh --json
```

Confirm the planning artifacts exist. Planning runs **after** `/ohmyorch:opsx:propose`, so if
the change is not yet planned, stop:

```bash
ls openspec/changes/<change-id>/
```

```text
Planning cannot begin: <change-id> has no planning artifacts.
Run /ohmyorch:opsx:propose <change-id> first, then /ohmyorch-plan-feature <change-id>.
```

## Step 2 — Identify the story

```bash
scripts/workflow-status.sh --change <change-id> --json
```

Read `proposal.md` and the delta specs to determine which `SPECS.md` story this change
implements, then read that story's acceptance criteria:

```bash
grep -n "### US-" SPECS.md
```

Note the story id and its scenarios. These are the definition of done; every task must
serve one. If you cannot identify exactly one story, stop — one change implements one
story (`BR-003`).

## Step 3 — Read the full context

Read, in this order:

```bash
cat "openspec/changes/<change-id>/proposal.md"
find "openspec/changes/<change-id>/specs" -type f -exec cat {} +
cat "openspec/changes/<change-id>/tasks.md"
cat "openspec/changes/<change-id>/design.md" 2>/dev/null
test -f CODEBASE.md && cat CODEBASE.md
```

`CODEBASE.md` is descriptive current-state evidence. Use it for architecture,
conventions, commands, and integration points — never as a source of requirements.

## Step 4 — Delegate exploration to the Planner

Delegate to the `planner` agent, which is read-only by design. Provide:

- the change id and the selected story id;
- the locations of the artifacts it must read;
- the acceptance criteria verbatim;
- the repository areas the spec implies;
- the instruction to cite evidence for every scope claim, and to prefer "likely" over
  certainty.

Ask it to return the full `implementation-plan.md` plus its `PLANNING RESULT` block.

## Step 5 — Write the plan

Write the returned Markdown to:

```text
openspec/changes/<change-id>/implementation-plan.md
```

Required sections (all must be present):

- `## Selected Story` — the story id this change implements
- `## OpenSpec Artifacts` — the artifacts read, with paths
- `## Task to Acceptance Mapping` — every task mapped to a scenario
- `## Affected Files` — likely files with the evidence for each
- `## Test Strategy` — how each criterion will be demonstrated
- `## Dependencies`, `## Risks`, `## Open Questions`

If the Planner returned a task with no mapped acceptance criterion, do **not** invent
one. Surface it:

```text
Unmapped task: <task>
No acceptance criterion covers this task.
Options: (a) the task is unnecessary, (b) a criterion is missing and the story is not READY.
This needs a Product Manager decision. Recorded in the plan's Open Questions.
```

## Step 6 — Validate

```bash
scripts/validate-implementation-plan.sh \
  --plan "openspec/changes/<change-id>/implementation-plan.md" \
  --story <story-id> \
  --change <change-id>
```

Fix required failures. Do not silence a warning by inventing content — confirm the
concern genuinely does not apply and say so in the plan.

## Step 7 — Confirm the gate moved

```bash
scripts/workflow-status.sh --change <change-id> --quiet
```

The `plan-handoff` gate must now report `PASS`. If it does not, the plan is not where
the gate expects it.

## Step 8 — Report

Return:

- the change id and story id;
- the path written;
- tasks mapped, and any unmapped;
- the evidence inspected;
- open questions and risks needing a Product Manager decision;
- the validator result;
- confirmation that gate 3 now passes.

## Boundaries

- Never modify product source code, tests, `tasks.md`, or the delta specs.
- Never write `review.md` or `test-report.md`.
- Never change a story's `Status:` in `SPECS.md` — that is the Product Manager's.
- Never invent an acceptance criterion to make a task map.
- Never present uncertain scope as certain.
