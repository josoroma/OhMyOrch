---
name: deliver
description: Goal-driven delivery from SPECS.md. Takes one target — an epic (EPIC-N), a user story (US-N.M), or a task (US-N.M#k or task text) — and delivers each story as one OpenSpec change (propose, apply, verify, archive) until the goal is COMPLETE or a human decision is required. Use when the user says "deliver", "deliver EPIC-3", "complete this epic/story/task", "run the delivery loop", or "resume delivery".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Agent
license: MIT
compatibility: Requires the openspec CLI 1.13.2 and a project initialized with /ohmyorch:bootstrap --with-openspec.
argument-hint: <EPIC-N | US-N.M | US-N.M#k | "task text">
---

## Installed plugin contract

`${CLAUDE_PLUGIN_ROOT}/references/contract.md` and `${CLAUDE_PLUGIN_ROOT}/references/rules/delivery-loop.md` are reference only: open one when a guard refuses, a command fails or a rule here is unclear. PRD/SPECS/CODEBASE mean the project's mapped documents (`"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" doctor --json` reports the mapping; run it when a command below fails, not as a ritual). Substituted paths are text: shell-escape them as literal arguments and never evaluate `$ARGUMENTS` as shell code.

Deliver **one target** from the mapped `SPECS.md`. Each story is one OpenSpec change that follows the real OpenSpec flow:

```text
propose  ->  apply  ->  verify  ->  archive  ->  story DONE
```

That is the whole process. A change's record is OpenSpec's own artifacts — `proposal.md`, `specs/`, `design.md` (only when needed) and `tasks.md` — and nothing else. You perform every step in this session.

While the goal is `ACTIVE`, a `Stop` hook re-derives the next action and refuses to end the turn until the goal is COMPLETE or needs a human.

## Step 0 — Start or resume the goal

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery start "$ARGUMENTS"
```

| Target | Delivers |
|---|---|
| `EPIC-N` | every `US-N.*` story of that epic, in `SPECS.md` order, one change each |
| `US-N.M` | that story |
| `US-N.M#k` / `"task text"` | the parent story, with the task recorded as the goal's **Focus** |

An unknown or ambiguous target exits non-zero and records nothing: report it and stop, do not guess. `start` with the same target resumes a `BLOCKED` or `STOPPED` goal. A *different* goal that is still `ACTIVE` or `BLOCKED` is refused: report it and ask whether to run `delivery stop` first. Another session owning the goal needs an explicit `--takeover`, a global flag placed before `delivery`.

With no argument, resume the recorded goal: run `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery next --json`, take its `target` field and pass that to `delivery start`. If no goal is recorded, ask for a target.

## Step 1 — Act, derive, repeat

`start` prints the first derived action: act on it, do not run `delivery next` first. After each action, derive the next one:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery next
```

The action is recomputed from `SPECS.md` and the change directory on every call. Never act on memory or on `goal.md`'s `## Next Action`; that section is a record for a human reader.

| Action | What you do |
|---|---|
| `propose` | Run `/ohmyorch:opsx-propose <change>` for the story, using exactly the derived change id. See "Proposing from a story" below. |
| `apply` | Run `/ohmyorch:opsx-apply <change>`: implement the pending tasks and tick each one in `tasks.md` only when it is really done. When every task is ticked, do not archive from the apply step: derive the next action (`verify`). |
| `verify` | Run `/ohmyorch:opsx-verify <change>`. See "Verifying and archiving" below. |
| `mark-done` | The change is archived. In one message, set the story's `Status: DONE`, point its `Change:` line at the archived path and tick its tasks with one Edit of the story block, and update its rows in `## Work Item Status` with a second Edit when that table exists. Never rewrite the whole file. |
| `escalate` | **Stop working.** Report the reason and the decision needed from the human. The Stop hook records the goal `BLOCKED`. |
| `complete` | Report the result. The Stop hook records the goal `COMPLETE`. |

### Proposing from a story

- The story in `SPECS.md` is the source: its description, its acceptance scenarios, its tasks and its dependencies. For a task-targeted goal, the goal's **Focus** (the `Focus` row of `openspec/delivery/goal.md`) is the priority inside the story; it does not narrow acceptance.
- Every acceptance scenario of the story becomes a `#### Scenario:` in the change's delta spec, and every task in `tasks.md` says how it is checked. Record the story id in `proposal.md`.
- The delivery goal is the user's standing request. When the artifacts are ready, do not wait for a new request: derive the next action. If the change already exists, continue it and author only what is missing; do not ask whether to start over.
- Then, in one message, set the story to `Status: IN PROGRESS` and add ``Change: `openspec/changes/<change>/` `` with one Edit of the story block, and update the story's row in `## Work Item Status` with a second Edit when that table exists. Never rewrite the whole file.
- `/ohmyorch:opsx-explore` is optional. Use it only when the story or the affected code is unclear.
- Never fill a gap in the story by inventing behavior. Record it with `delivery block --reason` (see Hard boundaries), then say what is missing and stop.

### Verifying and archiving

- `/ohmyorch:opsx-verify <change>` checks completeness, correctness and coherence against the change's artifacts. Also confirm each acceptance scenario of the story in `SPECS.md` is covered, and run the project's own tests where they exist. Never report a scenario as passing without evidence you actually observed.
- CRITICAL in this loop, whatever rank `/ohmyorch:opsx-verify` gives them: an acceptance scenario of the story that is not implemented, whose observed result contradicts its `Then`, or for which you have no observed evidence; and a project test that fails because of this change. A test that was already failing for an unrelated reason is reported, not turned into a task.
- For each CRITICAL issue, append an unticked task to `tasks.md` describing the fix. The derived action returns to `apply`. Nothing else records a finding.
- With no CRITICAL issue, archive with a separate, standalone Bash call:

  ```bash
  openspec archive <change> -y
  ```

  It validates the delta specs, merges them into `openspec/specs/` and moves the change to `openspec/changes/archive/`. Then do the `mark-done` edit right away.

## Step 2 — Continue until the hook lets you stop

If you try to stop while work remains, the `Stop` hook blocks you and prints the next action, its command and the reason. Do what it says. The loop ends only when the hook allows the stop:

| Outcome | Recorded as | You report |
|---|---|---|
| every story `DONE` | `COMPLETE` | stories delivered and their archived changes |
| next action `escalate` | `BLOCKED` + reason | the decision needed from the human |
| you ran `delivery block --reason` (a decision you need) | `BLOCKED` + your reason | the decision needed from the human |
| derived state unchanged: three stop attempts are blocked (the default limit), the fourth is allowed | `BLOCKED` "no progress" | the stuck action and what you tried |
| `delivery stop` (human request) | `STOPPED` | where the goal was left |

Resume any halted goal with `/ohmyorch:deliver <same target>`. Completed stories are never redone: every step is derived from the repository. A `DONE` story is redone only by setting it back to `READY` with a new `Change:` id; the same id would be marked `DONE` again.

## Hard boundaries

- **One story, one change; one active change at a time.** An epic is delivered story by story, in `SPECS.md` order.
- **Only OpenSpec's artifacts.** Do not create plan, review, test-report, status or completion files, and do not add stages.
- **Never bypass a guard.** `openspec archive` is refused while `tasks.md` has unticked tasks; `Status: DONE` is refused while the story's change is still active. Return to the derived next action.
- **Never resolve an ambiguity by inventing behavior.** The Stop hook cannot see a question you have and would refuse the stop, so record it first, then report it and stop: `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery block --reason '<story id: the decision needed>'` (single quotes; no quotes, backticks or `$` inside the reason). Do the same whenever an OpenSpec step tells you to pause, ask the user or wait for guidance. It is only for a missing human decision, never for work that is merely hard.
- **A validation finding about another story is not yours to fix.** The hook validates the whole `SPECS.md` after every edit: leave that story unchanged, continue with the derived action and list the finding in the report.
- **Never hand-edit the derived sections of `goal.md`.** `delivery refresh` rewrites them.
- **Keep working within the turn.** Claude Code overrides a Stop hook after 8 consecutive blocks, so do not end the turn to "check in" while work remains.

## Report

When the loop ends, report:

- the target, its kind, the focus (for a task), and the final goal status;
- each story, its change id, and whether it was delivered in this run;
- for `BLOCKED`, the exact reason and the decision needed;
- the command to resume: `/ohmyorch:deliver <target>`.
