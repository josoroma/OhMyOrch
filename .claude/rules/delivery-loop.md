# Delivery Loop

Rules for goal-driven delivery: handing the harness one `SPECS.md` target and having
it driven to completion. Source: `PRD.md` FR-019; `SPECS.md` EPIC-12 (US-12.1, US-12.2).

## A goal is a target, delivered story by story

| Target | Delivers |
|---|---|
| `EPIC-N` | every story of the epic, in `SPECS.md` order |
| `US-N.M` | that story |
| `US-N.M#k` or task text | the parent story; the task is the goal's **Focus** |

The **story** is the unit of delivery. Each story is its own OpenSpec change (BR-003).
There is no epic-sized change. A task is never delivered alone, because it has no
acceptance criteria of its own (BR-005).

One goal is recorded at a time, in `openspec/delivery/goal.md`. Only one change is
active at a time.

## The next action is derived, never remembered

`scripts/delivery.sh next` recomputes the next action, its owner, and its command
from `SPECS.md`, `scripts/workflow-status.sh`, and `scripts/completion-gate.sh` on
every call. `goal.md` is a record for human readers.

The orchestrator MUST act on the derived action. It must not act on the transcript,
memory, or a hand-edited `goal.md` (BR-004, NFR-003).

## Roles do not collapse inside the loop

The orchestrator is the Product Manager role in the main session. It MAY select,
reopen, archive, mark stories `DONE`, and refresh records. It MUST delegate every
other action to its owner:

| Action | Owner |
|---|---|
| `propose`, `plan` | Planner |
| `implement` | Implementer |
| `review` | Reviewer (writes `review.md`, records `/opsx:verify`) |
| `test` | Tester (writes `test-report.md`) |
| `escalate` | human Product Manager |

The orchestrator MUST NOT author `review.md` or `test-report.md` (BR-002). A loop that
could approve its own work would turn "keep going until done" into "declare done".

## The loop stops only for a reason it records

| Condition | Stop? | Goal status |
|---|---|---|
| work remains (any action but `escalate` / `complete`) | **blocked** | `ACTIVE` |
| next action is `escalate` | allowed | `BLOCKED` + escalation reason |
| derived state unchanged across `DELIVERY_MAX_STALLS` (default 3) blocked stop attempts — the stop is allowed after that many, so the default allows it on the 4th (`--max-stalls <n>` overrides) | allowed | `BLOCKED` "no progress" |
| every story is `DONE` | allowed | `COMPLETE` |
| human runs `scripts/delivery.sh stop` | allowed | `STOPPED` |

"Progress" means the derived next action changed, including its gate detail, such as
`3/10 tasks complete`. Talking about the work is not progress. A stall is a finding,
not a failure to hide: report what was tried.

`start <same target>` resumes a `BLOCKED` or `STOPPED` goal. Completed stories are
never redone.

## No gate has a loop exception

The loop runs under every existing guard, unchanged:

- `guard-archive.sh` rejects archival while any completion condition fails;
- `guard-story-done.sh` rejects `Status: DONE` before archival;
- `guard-planning-handoff.sh` rejects implementation before `implementation-plan.md`;
- the role write-scope hooks keep each subagent inside its boundary.

When a guard rejects an action, the orchestrator MUST return to the derived next
action. It must not work around the guard.

## Enforcement

| Rule | Mechanism |
|---|---|
| keep working while the goal is ACTIVE | `scripts/guard-delivery-loop.sh` as a `Stop` hook (exit 2 blocks the stop) |
| record BLOCKED / COMPLETE on halt | `guard-delivery-loop.sh` → `scripts/delivery.sh block` / `refresh` |
| orchestrator never authors verdicts | `guard-delivery-loop.sh` as a `PreToolUse` hook on `Write\|Edit\|MultiEdit` |
| no archive or DONE bypass | `guard-archive.sh`, `guard-story-done.sh` (unchanged) |
| next action is derived | `scripts/delivery.sh next` |

All of these fail open when the harness is not installed or no goal is `ACTIVE`.

## Known limits of the verdict guard

The `PreToolUse` verdict guard intercepts the `Write`, `Edit`, and `MultiEdit` tools.
It matches paths case-insensitively, because `REVIEW.md` is `review.md` on a
case-insensitive filesystem. It does **not** see:

- a shell redirect such as `cat > review.md` inside a `Bash` call;
- a write made by a `product-manager` *subagent*, which carries `agent_id` and has no
  write-scope hook of its own.

The rule still applies to both, and the Reviewer's review is the backstop: a verdict
whose author is not the Reviewer or Tester is a blocking finding. Run Product Manager
actions in the main session, never as a delegated `product-manager` subagent.

Claude Code overrides a `Stop` hook after 8 consecutive blocks in one turn. Keep
delegating within the turn, and do not end the turn to "check in". The stall limit,
default 3, records `BLOCKED` before that cap is reached.
