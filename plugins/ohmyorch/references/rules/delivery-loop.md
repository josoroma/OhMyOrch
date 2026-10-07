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

`"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" delivery next` recomputes the next action, its owner, and its command
from `SPECS.md`, `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" workflow-status`, and `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" completion-gate` on
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
| `review` | Reviewer (writes `review.md`, records `/ohmyorch:opsx-verify`) |
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
| human runs `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" delivery stop` | allowed | `STOPPED` |

"Progress" means the derived next action changed, including its gate detail, such as
`3/10 tasks complete`. Talking about the work is not progress. A stall is a finding,
not a failure to hide: report what was tried.

`start <same target>` resumes a `BLOCKED` or `STOPPED` goal. Completed stories are
never redone.

## No gate has a loop exception

The loop runs under every existing guard, unchanged:

- `guard-archive.sh` rejects archival while any completion condition fails;
- `guard-story-done.sh` rejects an active story's DONE transition while it is ineligible; archive-before-DONE remains the workflow contract;
- `guard-planning-handoff.sh` rejects implementation before `implementation-plan.md`;
- the root identity dispatcher applies each scoped role's write boundary.

When a guard rejects an action, the orchestrator MUST return to the derived next
action. It must not work around the guard.

## Enforcement

| Rule | Mechanism |
|---|---|
| keep working while the goal is ACTIVE | `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" guard-delivery-loop` as a `Stop` hook (exit 2 blocks the stop) |
| record BLOCKED / COMPLETE on halt | `guard-delivery-loop.sh` → `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" delivery block` / `refresh` |
| orchestrator never authors verdicts | `hooks/dispatch.sh` identity/path checks on `Write\|Edit\|MultiEdit` |
| no archive or DONE bypass | `guard-archive.sh`, `guard-story-done.sh` (unchanged) |
| next action is derived | `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" delivery next` |

Inactive projects are no-ops. Activated projects fail closed on malformed protected operations or missing validators. The Stop loop runs only for an ACTIVE goal and the owning main session.

## Known limits of the verdict guard

The `PreToolUse` verdict guard intercepts the `Write`, `Edit`, and `MultiEdit` tools.
It resolves existing entry spelling on case-insensitive hosts before comparing scoped paths. It does **not** see:

- a shell redirect such as `cat > review.md` inside a `Bash` call;
- writes made by other tools or extensions outside the registered file-tool protocol.

Scoped Product Manager and unknown subagent writes to verdicts are blocked. Run delivery orchestration in the main session. Shell/MCP writes remain a policy boundary rather than OS confinement; independent review must surface unauthorized authorship.

Claude Code's default Stop continuation cap is 8 consecutive blocks; a tool call
resets that platform counter. `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` can change it.
Keep delegating within the turn. OhMyOrch separately counts unchanged derived
actions across stops: its default limit of 3 records `BLOCKED` on the fourth
unchanged stop, without relying on the platform counter.
