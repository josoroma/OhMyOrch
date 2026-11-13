# Delivery Loop

Rules for goal-driven delivery: `/ohmyorch:deliver` takes one `SPECS.md` target and
drives it to completion, one OpenSpec change per story.

## A goal is a target, delivered story by story

| Target | Delivers |
|---|---|
| `EPIC-N` | every story of the epic, in `SPECS.md` order |
| `US-N.M` | that story |
| `US-N.M#k` or task text | the parent story; the task is the goal's **Focus** |

The **story** is the unit of delivery. Each story is its own OpenSpec change; there is
no epic-sized change. A task is never delivered alone, because it has no acceptance
criteria of its own.

One goal is recorded at a time, in `openspec/delivery/goal.md`. Only one change is
active at a time.

## The next action is derived, never remembered

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" delivery next
```

Every call recomputes the action, its command and its reason from `SPECS.md` and the
change directory. Act on that result. Do not act on the transcript, on memory, or on
`goal.md`, which is a record for human readers. Below, `delivery <command>` is
shorthand for this CLI form.

There are six actions. The rules below are checked in order against the first story
of the target that is not `DONE`; the first match decides:

1. Every story is `DONE`: `complete`.
2. The story is neither `READY` nor `IN PROGRESS`: `escalate`. A product decision is
   required.
3. A dependency is missing from `SPECS.md` or is not `DONE`: `escalate`. Deliver or
   re-scope the dependency first.
4. The story's change is archived and no active directory has its id: `mark-done`.
   Set `Status: DONE` and point the story's `Change:` line at the archived change.
   When a directory named for the story (`us-<n>-<m>-*`) is still active, the
   action is `escalate` instead: point the `Change:` line at that change, or remove
   the directory if it is not the story's.
5. The story has no change and another change is active: `escalate`. Finish or
   archive the active change first.
6. The story has no change: `propose`. Run `/ohmyorch:opsx-propose <change>` with the
   derived change id, then set the story to `IN PROGRESS` with a `Change:` line.
7. The change exists but its planning artifacts are incomplete: `propose`. Continue
   the existing change and author only what is missing.
8. A task in `tasks.md` is unticked: `apply`. Run `/ohmyorch:opsx-apply <change>`.
9. Every task is ticked: `verify`. Run `/ohmyorch:opsx-verify <change>`; with no
   CRITICAL issue, run `openspec archive <change> -y` as a separate Bash call.

Planning is complete when `proposal.md` and `tasks.md` exist, `tasks.md` has at least
one checkbox, and `specs/` holds at least one `.md` file. `specs/` is not required
when the change's `.openspec.yaml` sets `skip_specs: true`. `design.md` is never
required.

There is no separate archive action: `verify` ends with the archive, after which rule
4 applies. A CRITICAL verify finding is appended to `tasks.md` as an unticked task,
which makes rule 8 match again. `tasks.md` is the only tracking file, and its tasks
are counted the way OpenSpec counts them: any checkbox marker other than `x` is
unfinished.

## The loop stops only for a reason it records

| Condition | Stop? | Goal status |
|---|---|---|
| work remains (any action but `escalate` / `complete`) | **blocked** | `ACTIVE` |
| next action is `escalate` | allowed | `BLOCKED` + escalation reason |
| the session ran `delivery block --reason` for a human decision it needs | allowed | `BLOCKED` + that reason |
| the next action cannot be derived | allowed | `BLOCKED` + the error |
| derived state unchanged across 3 blocked stop attempts, so the 4th unchanged stop is allowed | allowed | `BLOCKED` "no progress" |
| every story is `DONE` | allowed | `COMPLETE` |
| human runs `delivery stop` | allowed | `STOPPED` |

The stall limit of 3 is `delivery.maxStalls` in `.claude/ohmyorch/project.json`;
`DELIVERY_MAX_STALLS` overrides it.

"Progress" means the derived next action changed, including its reason, such as
`3/10 tasks complete`. Talking about the work is not progress. A stall is a finding,
not a failure to hide: report what was tried.

`delivery start <same target>` resumes a `BLOCKED` or `STOPPED` goal. Completed
stories are never redone. To redo a `DONE` story, set it back to `READY` with a new
`Change:` id: while the story still names the archived change, rule 4 marks it `DONE`
again.

## The guards have no loop exception

- `guard-archive.sh` refuses `openspec archive` while `tasks.md` has an unticked task.
- `guard-story-done.sh` refuses `Status: DONE` for a story whose change is still
  active. Archive first.
- The authoring agents (`ohmyorch:codebase-analyst`, `ohmyorch:product-specifier`,
  `ohmyorch:spec-ingestor`) cannot write files. They return content and the caller
  persists it.

When a guard refuses an action, return to the derived next action. Do not work
around the guard.

## Enforcement

| Rule | Mechanism |
|---|---|
| keep working while the goal is ACTIVE | `Stop` hook: `guard-delivery-loop.sh` exits 2 and prints the next action |
| record BLOCKED / COMPLETE on halt | `guard-delivery-loop.sh` through `delivery block` / `delivery refresh` |
| next action is derived | `delivery next` |
| no archive with unticked tasks | Bash hook on `openspec archive`: `guard-archive.sh` |
| no DONE before archive | write hook on the mapped SPECS: `guard-story-done.sh` |
| authoring agents never write | write hook: any `ohmyorch:*` agent write is blocked |
| one session owns the goal | write hook: the mapped SPECS and `openspec/delivery/` are refused to another session while the goal is owned, and to any subagent |

Inactive projects are no-ops. Activated projects fail closed on malformed protected
operations or missing validators. The Stop loop runs only for an ACTIVE goal and the
owning main session.

The write hooks see the `Write`, `Edit` and `MultiEdit` tools only. A shell redirect
or another tool's write is not intercepted: the hooks are workflow guardrails, not
confinement.

Claude Code's default Stop continuation cap is 8 consecutive blocks; a tool call
resets that platform counter. `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` can change it. Keep
working within the turn. OhMyOrch separately counts unchanged derived actions across
stops: its default limit of 3 records `BLOCKED` on the fourth unchanged stop, without
relying on the platform counter.
