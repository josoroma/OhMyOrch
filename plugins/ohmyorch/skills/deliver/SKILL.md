---
name: deliver
description: Goal-driven delivery orchestrator. Takes one SPECS.md target — an epic (EPIC-N), a user story (US-N.M), or a task (US-N.M#k or task text) — and drives it to completion. Each story becomes its own OpenSpec change, which is planned, implemented, reviewed, tested, and archived by the owning role, until the goal is COMPLETE or a human decision is required. Use when the user says "deliver", "deliver EPIC-3", "complete this epic/story/task", "run the delivery loop", or "resume delivery".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Agent
license: MIT
compatibility: Requires "${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery, "${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" guard-delivery-loop (wired as a Stop hook), the ohmyorch:planner/ohmyorch:implementer/ohmyorch:reviewer/ohmyorch:tester agents, and the openspec CLI.
metadata:
  author: claude-harness
  version: "1.0"
  implements: "US-12.2"
argument-hint: <EPIC-N | US-N.M | US-N.M#k | "task text">
---

## Installed plugin contract

Read `${CLAUDE_PLUGIN_ROOT}/references/contract.md` and the applicable bundled rules before acting. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" doctor --json` and stop on FAIL/UNSUPPORTED checks. Resolve every PRD/SPECS/CODEBASE reference through its `documents` mapping. These artifact names never imply a root-only layout. Use concrete resolved paths in Read/Write/Edit/Bash calls; do not copy plugin code/rules into the project. Resolve project files from the explicit project root and bundled files from the plugin root.

Inline path substitution supplies text, not automatic Bash environment variables. Shell-escape each substituted path/argument as a literal argument; never evaluate user `$ARGUMENTS` as shell code. Essential rules also reach delegated agents directly through the `ohmyorch:contract` preload. Pass project root, change, story, configured artifacts and prior evidence explicitly when delegating. Reviewer/tester agents persist their own selected verdict; the caller reads and validates it.
Drive **one delivery target** from `SPECS.md` to completion. The target can be an
epic, a user story, or a task, and the loop runs until the goal is COMPLETE or a
human Product Manager decision is required.

You are the **orchestrator**, which is the Product Manager role running in the main
session. You own selection, gates, archival, and `SPECS.md` story state. Every
technical stage belongs to a specialist. You do not plan, implement, review, or test.

The loop is mechanical, not voluntary. While the goal is `ACTIVE`,
`"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" guard-delivery-loop` runs as a `Stop` hook and refuses to let this
session end its turn. The hook's message names the next action, its owner, and the
command that performs it. Rules: `${CLAUDE_PLUGIN_ROOT}/references/rules/delivery-loop.md`.

## Step 0 — Start or resume the goal

Resolve `$ARGUMENTS` first. Resolution is read-only:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery resolve "$ARGUMENTS"
```

| Target | Delivers |
|---|---|
| `EPIC-N` | every `US-N.*` story of that epic, in `SPECS.md` order, one change each |
| `US-N.M` | that story |
| `US-N.M#k` / `"task text"` | the parent story, with the task recorded as the goal's **Focus** |

An unknown or ambiguous target exits non-zero and records nothing. Report it and
stop. Do not guess.

Record (or resume) the goal:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery start "$ARGUMENTS"
```

`start` with the same target resumes a `BLOCKED` or `STOPPED` goal as `ACTIVE`. A
*different* goal still `ACTIVE` or `BLOCKED` is refused. Report it and ask whether to
`"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery stop` it first. With no argument, resume the recorded goal:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery next
```

## Step 1 — Derive the next action

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery next
```

The action is **derived** from `SPECS.md`, `workflow-status.sh` (seven gates), and
`completion-gate.sh` (four conditions). It is recomputed on every call. Never act on
`goal.md`'s `## Next Action` or on memory; it is a record for a human reader.

## Step 2 — Delegate by owner

Perform exactly one action, delegating to its owner. Then go back to Step 1.

| Action | Owner | How |
|---|---|---|
| `select` | ohmyorch:product-manager (you) | `openspec new change <id>`; set the story `Status: IN PROGRESS` and add `Change: \`openspec/changes/<id>/\`` in `SPECS.md`; `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" status --change <id>` |
| `propose` | ohmyorch:planner | `/ohmyorch:opsx-explore <story>`, then `/ohmyorch:opsx-propose <id>`, the read-only planner returns content and the coordinator persists `proposal.md`, `specs/<capability>/spec.md`, `tasks.md` (+ `design.md` when an external contract changes). Map every task to a Gherkin scenario of the story. |
| `plan` | ohmyorch:planner | `/ohmyorch:plan-feature <id>`: delegate to the read-only `ohmyorch:planner` subagent, which returns `implementation-plan.md` |
| `implement` | ohmyorch:implementer | `/ohmyorch:opsx-apply <id>`: delegate to the `ohmyorch:implementer` subagent. Product code and implementation tests only; it ticks `tasks.md` honestly |
| `review` | ohmyorch:reviewer | `/ohmyorch:review-feature <id>`: delegate to the `ohmyorch:reviewer` subagent. It writes `review.md` and records `/ohmyorch:opsx-verify` |
| `test` | ohmyorch:tester | `/ohmyorch:test-feature <id>`: delegate to the `ohmyorch:tester` subagent. It writes `test-report.md` from its own evidence |
| `reopen` | ohmyorch:product-manager (you) | `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery reopen --change <id>`: preserves the failing verdict under `history/` and appends one remediation task per finding |
| `archive` | ohmyorch:product-manager (you) | `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" completion-gate --change <id> --record` then a separate Bash call `openspec archive <id> -y` (guarded by `guard-archive.sh`) |
| `mark-done` | ohmyorch:product-manager (you) | set the story `Status: DONE`, point its `Change:` line at the archive path and tick its `SPECS.md` tasks (guarded by `guard-story-done.sh`) |
| `escalate` | human Product Manager | **stop working.** Report the reason and the decision needed. The Stop hook records the goal `BLOCKED` |
| `complete` | — | report the result. The Stop hook records the goal `COMPLETE` |

For a task-targeted goal, give the goal's **Focus** to the Planner and the
Implementer as the priority within the story. It does not narrow acceptance: the
story's scenarios are still the definition of done.

After every action, refresh the durable records:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" status --change <id> --quiet
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery refresh
```

## Step 3 — Continue until the hook lets you stop

If you try to stop while work remains, the `Stop` hook blocks you and prints:

```text
Delivery goal EPIC-12 is ACTIVE — do not stop yet.
Next action: review  (owner: ohmyorch:reviewer, story: US-12.2)
Command: /ohmyorch:review-feature us-12-2-run-delivery-goal-loop (includes /ohmyorch:opsx-verify)
```

Do what it says. The loop ends only when the hook allows the stop:

| Outcome | Recorded as | You report |
|---|---|---|
| every story `DONE` | `COMPLETE` | stories delivered, their archived changes |
| next action `escalate` | `BLOCKED` + reason | the decision needed from the human Product Manager |
| derived state unchanged across `DELIVERY_MAX_STALLS` (default 3) stop attempts | `BLOCKED` "no progress" | the stuck action and what you tried |
| `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery stop` (human request) | `STOPPED` | where the goal was left |

Resume any halted goal with `/ohmyorch:deliver <same target>`. Completed stories are never
redone: every step is derived from the repository.

## Hard boundaries

- **Never author `review.md` or `test-report.md`.** While a goal is `ACTIVE`,
  `guard-delivery-loop.sh` blocks main-session writes to them. Delegate to the
  `ohmyorch:reviewer` / `ohmyorch:tester` subagents, whose scoped role checks allow exactly their
  artifact.
- **Never repair what a Reviewer or Tester found.** `reopen`, then delegate to the
  Implementer, then re-review, then re-test.
- **Never bypass a gate.** `guard-archive.sh` and `guard-story-done.sh` still apply
  inside the loop. If one rejects an action, the gate is telling you the truth: return
  to the derived next action.
- **Never resolve an ambiguity by inventing behavior** (BR-001). Escalate.
- **One story, one change; one active change at a time** (BR-003). An epic is
  delivered story by story, in `SPECS.md` order.
- **Never hand-edit derived sections** of `goal.md` or `status.md`. Refresh them.
- **Never write a verdict through Bash** (`cat > review.md`) or through a delegated
  `ohmyorch:product-manager` subagent. The verdict guard cannot see either path, but the rule
  still applies. Do your own actions in this session.
- **Keep working within the turn.** Claude Code overrides a Stop hook after 8
  consecutive blocks, so do not end the turn to "check in" while work remains.

## Report

When the loop ends, report:

- the target, its kind, the focus (for a task), and the final goal status;
- each story, its change id, and whether it was delivered in this run;
- what was delegated to which role, including every reopen round;
- for `BLOCKED`, the exact reason and the decision needed;
- the command to resume: `/ohmyorch:deliver <target>`.
