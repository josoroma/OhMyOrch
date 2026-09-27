# Review — us-12-1-resolve-delivery-target-report

Change: us-12-1-resolve-delivery-target-report
Story: US-12.1
Verdict: changes-requested
Blocking: 1 finding
Coverage: 6/6 acceptance criteria evaluated
OpenSpec verify: MISMATCH — artifacts valid (`openspec validate us-12-1-resolve-delivery-target-report --strict`: "Change 'us-12-1-resolve-delivery-target-report' is valid"), but the implementation does not meet requirement "Escalate a story that cannot proceed" for a story whose change is archived and whose dependency is not DONE (see F-2)

Review round: 2. This review supersedes `history/review-r1.md`.

## Summary

Round-1 finding F-1 is fixed. `derive_next` now runs the readiness check first, before
the `change_archived` branch, and a regression case pins that order. Observation O-4
is also fixed: an inline `Dependencies: US-x.y` line is now parsed, and it has its own
regression case. Mutation testing shows that each new case catches the defect it
targets. All five suites pass, and the read-only probes on the real repository behave
correctly.

One MUST in the same scenario is still violated, through the same mechanism as F-1.
The dependency check still runs *after* the `change_archived` branch. A READY or IN
PROGRESS story whose change is archived, but whose dependency is not DONE, therefore
gets `mark-done` instead of `escalate`. Round 1 missed this: F-1's remediation named
only the readiness half of the scenario. It is recorded here as F-2.

## Round-1 Remediation Verified

| Item | Result | Evidence |
|---|---|---|
| F-1 (archived change bypassed readiness escalation) | RESOLVED | `scripts/delivery.sh` lines 310–320: the readiness `case "$status" in READY\|"IN PROGRESS") ;; *) escalate` block now comes before the `change_archived "$change"` branch at lines 322–328. Regression cases in `scripts/test-delivery.sh` lines 255–256: `on-hold story with archived change escalates` (US-3.4, NEEDS CLARIFICATION, `Change:` pointing at an existing `archive/2026-09-24-us-3-4-x`) and `on-hold reason names the status` (`US-3.4 is NEEDS CLARIFICATION`). Both pass. Mutation check: in a `/tmp` copy with the two blocks swapped back, the suite reports `FAIL on-hold story with archived change escalates want 'escalate' got 'mark-done'` (`failed: 1`). The existing `archived but not DONE -> mark-done` case (IN PROGRESS, line 328) still passes. Task R1.1 is ticked honestly. |
| O-4 (inline `Dependencies:` ignored) | RESOLVED | The `parse_specs` awk block `/^Dependencies:/` (line 128 onward) now collects `US-n.m` ids from the heading line itself. The bulleted `sect == "deps"` reader (line 141) is unchanged. Regression case at line 254: `inline Dependencies: line escalates` (US-3.3 `Dependencies: US-3.2`). It passes. Mutation check: in a `/tmp` copy with the inline loop removed, the suite reports `FAIL inline Dependencies: line escalates want 'escalate' got 'select'`. |

## Findings

### Finding F-2: an archived change bypasses dependency escalation

Requirement: Scenario: Escalate a story that cannot proceed — "Given the first undelivered story is not READY or IN PROGRESS, or depends on a story that is not DONE … When the next action is requested … Then the action MUST be "escalate" with the reason"
Observed: in `derive_next` (`scripts/delivery.sh`), the `change_archived "$change"` branch at lines 322–328 returns `mark-done` before the dependency check at lines 330–345 runs. I reproduced this in a throwaway `/tmp` copy with a stub `SPECS.md`: `### US-1.1` with `Status: IN PROGRESS`, `Change: \`openspec/changes/archive/2026-09-24-us-1-1-x/\``, and `Dependencies:` / `- US-1.2`, plus `### US-1.2` at `Status: READY`, with the archive directory present. `scripts/delivery.sh next US-1.1` printed `Action:  mark-done`, `Owner:   product-manager`, `Command: set 'Status: DONE' for US-1.1 in SPECS.md (guarded by scripts/guard-story-done.sh)`, and `Reason:  change us-1-1-x is archived but US-1.1 is IN PROGRESS`, then exited 0. `scripts/guard-story-done.sh` does not check dependencies (grep for `depend` finds nothing relevant), so the guard does not catch this either. `scripts/test-delivery.sh` has no case for this combination. This is the same defect class as round-1 F-1. The F-1 remediation, which the round-1 reviewer wrote, named only the readiness condition, so the Implementer's fix matched that wording without covering the whole MUST.
Expected: a story that depends on a story that is not DONE escalates to the human Product Manager with the reason naming the unfinished dependency, whatever state its own change is in. The loop must not steer a story into a DONE transition while one of its dependencies is undelivered. `design.md` §3 lists the `mark-done` row but does not rank it above escalation, and the spec's MUST governs.
Remediation: in `derive_next`, move the dependency block (the `# Dependencies: every named story must already be DONE.` loop and its `escalate`) ahead of the `change_archived` branch. The order becomes: readiness → dependencies → archived/`mark-done` → select → gates. Add a regression case to `scripts/test-delivery.sh` under "Escalate a story that cannot proceed": a READY or IN PROGRESS story whose `Change:` points at an existing archive directory, and whose `Dependencies:` names a story that is not DONE, must yield `escalate` with a reason naming that dependency. Keep `archived but not DONE -> mark-done` (US-4.2, no dependencies) passing. Feasibility check (throwaway `/tmp` copy only): moving the block this way leaves the suite at `passed: 88  failed: 0`.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| Resolve an epic into its stories | PASS | On the real repo, `scripts/delivery.sh resolve EPIC-12` lists `US-12.1`, `US-12.2`, `US-12.3` in file order with three distinct change ids (`us-12-1-resolve-delivery-target-report`, `us-12-2-run-delivery-goal-loop`, `us-12-3-document-delivery-orchestrator`) and exits 0. Suite section "Resolve an epic into its stories": 7/7 ok. |
| Resolve a task to its parent story | PASS | Suite: `US-1.1#2` and the text `widget parser` both resolve to `US-1.1`, with `Kind: task`. `start 'US-1.1#2'` writes `\| Focus \| Wire the widget renderer. \|`. An out-of-range index and ambiguous text both exit 1. All cases ok. `parse_specs` was touched only in the `/^Dependencies:/` rule, and the task rows are unchanged. |
| Reject an unknown target | PASS | On the real repo, `scripts/delivery.sh resolve EPIC-99` prints `unknown target: EPIC-99 (no '# EPIC-99:' heading in SPECS.md)` and exits 1. `openspec/delivery` was absent both before and after the read-only probes (`ls: openspec/delivery: No such file or directory`). Suite: no `goal.md` after `start US-9.9`, and the existing goal is byte-identical (`cmp`) after `start EPIC-99`. |
| Derive the next action from repository artifacts | PASS | On the real repo, `scripts/delivery.sh next EPIC-12` gives `Action: review`, `Owner: reviewer`, `Command: /review-feature us-12-1-resolve-delivery-target-report (includes /opsx:verify)`, and `Reason: gate review: review.md missing`. This matches `scripts/workflow-status.sh --change … --quiet` (`First incomplete gate: review`). Suite section "Derive the next action…": propose, plan, implement, review, reopen×2, test, archive, completion-escalate, acceptance-escalate, hand-edited `goal.md` ignored, `--json`, mark-done, and complete all ok. |
| Escalate a story that cannot proceed | FAIL | The readiness half now holds in every change state: NEEDS CLARIFICATION with no change escalates, and NEEDS CLARIFICATION with an archived change escalates (F-1 resolved). Both the bulleted and the inline dependency forms escalate when there is no change, and the `openspec/changes` snapshot is unchanged. But a READY or IN PROGRESS story with an archived change and an unfinished dependency yields `mark-done`, not `escalate` — see F-2. |
| Reopen a change after a failed review or acceptance test | PASS | Unchanged since round 1, and the suite section "Reopen…" is 20/20 ok: byte-identical preservation under `history/`, one R-task per finding or failure, round 1 never overwritten, `next` returns `implement` after each reopen, and `reopen` never authors `review.md` or `test-report.md`. Live evidence: this change's own round-1 reopen preserved `history/review-r1.md` and appended exactly one `R1.1` task carrying F-1's Remediation text verbatim. |

## Regression Checks

- `bash -n scripts/delivery.sh` and `bash -n scripts/test-delivery.sh`: clean.
- `scripts/test-delivery.sh`: exit 0, `passed: 88 failed: 0` (85 in round 1, plus the 3 new cases).
- `scripts/test-write-scope.sh` 36/0, `scripts/test-guards.sh` 38/0, `scripts/test-status.sh` 46/0, `scripts/test-completion.sh` 63/0; all exit 0.
- `openspec validate us-12-1-resolve-delivery-target-report --strict`: "Change 'us-12-1-resolve-delivery-target-report' is valid".
- `scripts/workflow-status.sh --change us-12-1-resolve-delivery-target-report --quiet`: gates 1–4 PASS (implementation 14/14 tasks), gate 7 PASS, review pending.
- Scope: `scripts/check-scope.sh --plan … --diff <.gitignore, scripts/delivery.sh, scripts/test-delivery.sh, .claude/settings.json>` again lists only `.gitignore` as unaccounted, the same tool limitation as round-1 O-2. The plan names the file, and the round-2 delta touched only `scripts/delivery.sh` and `scripts/test-delivery.sh`. `.claude/settings.json` lines 60–63 still hold exactly the four paired entries. The `.gitignore` diff is still +5 lines.
- No start/stop/refresh/reopen was run against the real repository. All mutation, reproduction, and feasibility probes ran in throwaway `/tmp` copies that were removed afterwards.

## Non-Blocking Observations

- O-1 (process, planned risk; carried forward): `scripts/` is harness control surface. The main session implemented this change and its R1 remediation, as recorded in `implementation-plan.md` §Risks. This review is the independent check.
- O-2 (scope tooling; carried forward): `check-scope.sh` does not extract `.gitignore` from the plan, because the token has no `/` and no known extension. This is a tool limitation, not drift.
- O-5 (parsing, defensive; still open): an empty `firstIncompleteGate` still falls through to the completion gate. `scripts/delivery.sh` does not read `"archiveEligible"` at all. The path is still fail-closed: only `"eligible": true` yields `archive`, and `guard-archive.sh` still guards the archive itself.
- O-6 (robustness; still open): `write_goal` writes `\| Target \| %s \|` (line 472) without the `tr '|' '/'` sanitising that `Focus` (line 474) and `Reason` (line 476) get. It fails closed through `load_goal`.
- O-7 (cwd; still open): run from `scripts/`, `./delivery.sh resolve EPIC-12` prints `error: SPECS.md not found (looked for docs/SPECS.md and SPECS.md)` and exits 1, the same exit code as an unknown target. This matches the `workflow-status.sh` convention.

## Handoff

Control returns to the Implementer to fix F-2: move the dependency check ahead of the
archived-change branch in `derive_next`, and add the regression case. After that,
`/review-feature us-12-1-resolve-delivery-target-report` runs again (round 3).
Acceptance testing must not proceed while F-2 is open.
