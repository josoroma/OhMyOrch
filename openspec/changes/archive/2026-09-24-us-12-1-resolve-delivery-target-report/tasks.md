# Tasks — us-12-1-resolve-delivery-target-report

Story: US-12.1

## 1. Deliverables (SPECS.md US-12.1 Tasks)

- [x] 1.1 Create `scripts/delivery.sh` `resolve` for epic, story, and task targets — Scenario: Resolve an epic into its stories; Scenario: Resolve a task to its parent story; Scenario: Reject an unknown target
- [x] 1.2 Define the `openspec/delivery/goal.md` format and implement `start`, `refresh`, `stop` — Scenario: Resolve a task to its parent story; Scenario: Reject an unknown target
- [x] 1.3 Implement `next`: map every gate and completion condition to one action and owner — Scenario: Derive the next action from repository artifacts
- [x] 1.4 Implement readiness and dependency escalation in `next` — Scenario: Escalate a story that cannot proceed
- [x] 1.5 Implement `reopen` (history, remediation tasks) — Scenario: Reopen a change after a failed review or acceptance test
- [x] 1.6 Add `scripts/test-delivery.sh` covering every scenario — all scenarios
- [x] 1.7 Allow-list the new scripts in `.claude/settings.json`; ignore `openspec/delivery/loop.state` — Scenario: Derive the next action from repository artifacts

## 2. Implementation tests (Implementer-owned; acceptance evidence is the Tester's)

- [x] 2.1 Regression cases for Scenario: Resolve an epic into its stories
- [x] 2.2 Regression cases for Scenario: Resolve a task to its parent story
- [x] 2.3 Regression cases for Scenario: Reject an unknown target
- [x] 2.4 Regression cases for Scenario: Derive the next action from repository artifacts
- [x] 2.5 Regression cases for Scenario: Escalate a story that cannot proceed
- [x] 2.6 Regression cases for Scenario: Reopen a change after a failed review or acceptance test

## R1. Remediation — reopened 2026-09-24 from review

Preserved: history/review-r1.md

- [x] R1.1 Resolve review finding F-1: an archived change bypasses readiness escalation — in `derive_next`, run the readiness check (`READY|"IN PROGRESS"`, else `escalate`) before the `change_archived` branch, so `mark-done` applies only to a READY or IN PROGRESS story whose change is archived. Add a regression case to `scripts/test-delivery.sh` under "Escalate a story that cannot proceed": a NEEDS CLARIFICATION story whose `Change:` points at an existing archive directory must yield `escalate`, with a reason naming the status. Keep the existing "archived but not DONE -> mark-done" case (IN PROGRESS) passing.

## R2. Remediation — reopened 2026-09-24 from review

Preserved: history/review-r2.md

- [x] R2.1 Resolve review finding F-2: an archived change bypasses dependency escalation — in `derive_next`, move the dependency block (the `# Dependencies: every named story must already be DONE.` loop and its `escalate`) ahead of the `change_archived` branch. The order becomes: readiness → dependencies → archived/`mark-done` → select → gates. Add a regression case to `scripts/test-delivery.sh` under "Escalate a story that cannot proceed": a READY or IN PROGRESS story whose `Change:` points at an existing archive directory, and whose `Dependencies:` names a story that is not DONE, must yield `escalate` with a reason naming that dependency. Keep `archived but not DONE -> mark-done` (US-4.2, no dependencies) passing. Feasibility check (throwaway `/tmp` copy only): moving the block this way leaves the suite at `passed: 88  failed: 0`.
