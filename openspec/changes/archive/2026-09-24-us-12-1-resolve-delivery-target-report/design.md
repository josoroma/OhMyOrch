# Design — us-12-1-resolve-delivery-target-report

Story: US-12.1

This change adds a new durable artifact (`openspec/delivery/goal.md`) and a new
external contract (`scripts/delivery.sh` subcommands and exit codes), so a design
artifact is required by `openspec/config.yaml`.

## Decisions

### 1. The story is the unit of delivery; epics and tasks are views onto it

| Target | Resolves to | Why |
|---|---|---|
| `EPIC-N` | every `### US-N.*` story under `# EPIC-N:`, in file order | an epic is a backlog grouping, not a change (BR-003) |
| `US-N.M` | that story | the story is the smallest independently verifiable unit |
| `US-N.M#k` or task text | the parent story, with the task recorded as `Focus` | a task has no acceptance criteria of its own, so it cannot pass review or testing alone |

Rejected: one OpenSpec change per epic. It collapses independently verifiable stories
into one project-sized change, which BR-003 and US-3.1 prohibit.

Rejected: one OpenSpec change per task. A task has no Gherkin scenario, so it can be
neither reviewed against a specification nor accepted (BR-005).

### 2. The next action is derived, never stored as truth

`delivery.sh next` recomputes the action from `SPECS.md`, `workflow-status.sh`, and
`completion-gate.sh` on every call. `goal.md` records the last computed action for a
human reader, but no command trusts it. This mirrors `status.md` (US-9.1): the derived
section is refreshed, never hand-edited, and a stale record cannot steer the loop.

Rejected: a state machine persisted in `goal.md`. It would be a second source of truth
for gate state, able to disagree silently with the reporters.

### 3. Gate → action mapping

| First failing gate / condition | Detail | Action | Owner |
|---|---|---|---|
| no change directory | — | `select` | product-manager |
| `planning` | — | `propose` | planner |
| `plan-handoff` | — | `plan` | planner |
| `implementation` | — | `implement` | implementer |
| `review` | `review.md missing` / contract failure | `review` | reviewer |
| `review` | blocking findings | `reopen` | product-manager |
| `testing` | `test-report.md missing` / contract failure | `test` | tester |
| `testing` | a `FAIL` row | `reopen` | product-manager |
| `acceptance` | any | `escalate` | human Product Manager |
| all gates pass, completion eligible | — | `archive` | product-manager |
| all gates pass, completion not eligible | — | `escalate` | human Product Manager |
| change archived, story not `DONE` | — | `mark-done` | product-manager |
| every story `DONE` | — | `complete` | product-manager |

Failures that the loop cannot repair without a product or specification decision —
`acceptance`, OpenSpec verification — escalate. Failing closed is the NFR-005 default.

### 4. `reopen` preserves evidence and re-opens the downstream gates

A failing `review.md` or `test-report.md` is **moved**, not deleted, to
`openspec/changes/<id>/history/<artifact>-r<round>.md`. Findings become unticked
`R<round>.<k>` tasks, so gate 4 (implementation) fails again and the loop returns to
the Implementer. A test failure also moves `review.md`, because a change made after an
acceptance failure must be reviewed again before retesting (US-7.1 scenario 3).

`reopen` never writes a verdict. It moves the Reviewer's or Tester's artifact aside and
copies their stated remediation into `tasks.md` verbatim; it does not summarise or judge.

### 5. One active change at a time

When an active change exists that is not the current story's change, `next` escalates
instead of selecting. `guard-planning-handoff.sh` resolves the sole active change, so a
second concurrent change would make that guard's answer ambiguous.

## Goal record format

```markdown
# Delivery Goal

| Field | Value |
|---|---|
| Target | EPIC-12 |
| Kind | epic |
| Focus | - |
| Status | ACTIVE |
| Reason | - |
| Started | 2026-09-24 |

## Stories
| # | Story | Change | SPECS status |

## Next Action
Action: / Story: / Change: / Owner: / Command: / Reason:

<!-- BEGIN AUTHORED: notes -->
<!-- END AUTHORED: notes -->
```

Goal status vocabulary: `ACTIVE | BLOCKED | COMPLETE | STOPPED`. It describes the goal,
not a change or a story, so it does not extend either existing vocabulary.
