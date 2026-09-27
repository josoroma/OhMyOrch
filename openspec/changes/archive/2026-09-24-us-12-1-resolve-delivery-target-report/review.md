# Review — us-12-1-resolve-delivery-target-report

Change: us-12-1-resolve-delivery-target-report
Story: US-12.1
Verdict: approved
Blocking: none
Coverage: 6/6 acceptance criteria evaluated
OpenSpec verify: PASS — `openspec validate us-12-1-resolve-delivery-target-report --strict` reports "Change 'us-12-1-resolve-delivery-target-report' is valid"; implementation matches every requirement of `specs/delivery-target/spec.md`, the `design.md` §3 gate→action mapping, and all 15 ticked tasks in `tasks.md`; no blocking mismatch

Review round: 3. This review supersedes `history/review-r2.md` (which superseded `history/review-r1.md`).

## Summary

Round-2 finding F-2 is resolved. `derive_next` in `scripts/delivery.sh` now checks
readiness, then dependencies, then the archived/`mark-done` case, then select, then
the gates. Two new regression cases pin that order. A mutation test that reverts the
order makes both cases fail. All six US-12.1 scenarios hold against the implementation,
with evidence from the suite, from throwaway-copy probes, and from read-only probes on
the real repository. I found no other MUST violation in the delta spec. All five suites
pass, and `openspec validate --strict` is clean.

## Round-2 Remediation Verified

| Item | Result | Evidence |
|---|---|---|
| F-2 (archived change bypassed dependency escalation) | RESOLVED | `scripts/delivery.sh`: readiness `case` at lines 310–320, then the dependency loop and its `escalate` at lines 322–341 (commented "review F-2, r2"), then `if change_archived "$change"` → `mark-done` at lines 342–348, then select at line 350, then the gates at line 365. The order matches R2.1 exactly: readiness → dependencies → archived/`mark-done` → select → gates. The stub `SPECS.md` in `scripts/test-delivery.sh` adds `### US-3.5` (line 162): `Status: IN PROGRESS`, `Change:` pointing at the staged `archive/2026-09-24-us-3-5-x`, and `Dependencies: - US-3.2` (READY). New cases at lines 267–268: `archived change, unfinished dependency escalates` and `archived-change reason names the dependency` (`US-3.5 depends on unfinished US-3.2 (READY)`). Both pass. The existing `archived but not DONE -> mark-done` case (US-4.2, no dependencies) still passes. |
| F-2 mutation check | CAUGHT | In a `mktemp -d /tmp/rv3-mut.XXXXXX` copy of `scripts/`, I moved the archived block (lines 342–349) back above the dependency block (lines 322–341). `bash -n` was clean, and `diff` confirmed that only the swap changed. The suite then reported `FAIL archived change, unfinished dependency escalates want 'escalate' got 'mark-done'` and `FAIL archived-change reason names the dependency missing: US-3.5 depends on unfinished US-3.2 (READY)`, with `passed: 88 failed: 2`. I removed the copy afterwards. |
| R2.1 task honesty | HONEST | `tasks.md` R2.1 is ticked. Its text is F-2's Remediation verbatim, as `reopen` requires. `history/review-r2.md` is preserved. Gate 4 reports `15/15 tasks complete`. |

## Blocking Issues

None. No MUST in `specs/delivery-target/spec.md` is violated. See Non-Blocking Observations.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| Resolve an epic into its stories | PASS | Real repo: `scripts/delivery.sh resolve EPIC-12` exits 0 and lists `US-12.1`, `US-12.2`, `US-12.3` in `SPECS.md` order, with three distinct change ids (`us-12-1-resolve-delivery-target-report`, `us-12-2-run-delivery-goal-loop`, `us-12-3-document-delivery-orchestrator`). `resolve_target` (the `EPIC-[0-9]*` branch) filters `parse_specs` rows by epic in file order, and `change_for` derives a per-story id from the `Change:` line, then an existing directory, then a `us-N-M-<slug>` fallback. Suite section "Resolve an epic into its stories": 7/7 ok, including order, 3 unique change ids, no leakage from other epics, and the archive date prefix stripped. |
| Resolve a task to its parent story | PASS | Real repo: `scripts/delivery.sh resolve 'US-12.1#2'` exits 0 with `Kind: task` and `Focus: Define the \`openspec/delivery/goal.md\` format …`, and lists only `US-12.1`. `write_goal` records `\| Focus \| … \|`. Suite: `US-1.1#2` and the text `widget parser` both resolve to `US-1.1`. `start 'US-1.1#2'` writes `\| Focus \| Wire the widget renderer. \|` and `\| Kind \| task \|`. An out-of-range index and ambiguous text are refused with exit 1. All ok. |
| Reject an unknown target | PASS | Real repo: `resolve EPIC-99` prints `unknown target: EPIC-99 (no '# EPIC-99:' heading in SPECS.md)` and exits 1. `resolve 'no such task text zzz'` prints `unknown target: no such task text zzz (not an epic, story, or task in SPECS.md)` and exits 1. `openspec/delivery` was absent before and after every probe. Suite: `start US-9.9` exits 1 and leaves no `goal.md`. `start EPIC-99` over an existing goal leaves it byte-identical (`cmp`), because `resolve_target` fails before any write in the `start` branch. |
| Derive the next action from repository artifacts | PASS | Real repo: `scripts/delivery.sh next EPIC-12` gave `Action: review`, `Owner: reviewer`, `Command: /review-feature us-12-1-resolve-delivery-target-report (includes /opsx:verify)`, `Reason: gate review: review.md missing`, exit 0. This agrees with `scripts/workflow-status.sh --change … --quiet` (`First incomplete gate: review`). `derive_next` reads `workflow-status.sh --json` (output and exit code captured separately) and, when all gates pass, `completion-gate.sh --json`. Only `"eligible": true` yields `archive`. Every branch sets `Owner` and `Command`. Suite section "Derive the next action…": propose, plan, implement, review, reopen (blocking review), test, reopen (failing report), archive, completion-escalate (`openspec-verification`), acceptance-escalate, hand-edited `goal.md` ignored, `--json`, mark-done, complete, and single-active-change escalate are all ok. |
| Escalate a story that cannot proceed | PASS | Both halves of the Given now hold in every change state. Not READY or IN PROGRESS: NEEDS CLARIFICATION escalates with no change (US-2.1) and with an archived change (US-3.4, F-1). Unfinished dependency: the bulleted form (US-3.1), the inline form (US-3.3), and with an archived change (US-3.5, F-2) all escalate, with `Owner: human-product-manager` and a reason naming the dependency. The `openspec/changes` snapshot is unchanged after escalation and after select. Real repo: `next US-12.2` gives `Action: escalate`, `Reason: US-12.2 depends on unfinished US-12.1 (IN PROGRESS)`, and the directory listing of `openspec/changes` was byte-identical before and after (`cmp`). Extra throwaway-copy probes: a dependency absent from `SPECS.md` escalates (`US-9.9 (not in SPECS.md)`); BLOCKED + archived change + unfinished dependency escalates on readiness; archived + dependency DONE still yields `mark-done`; no change directory was created. |
| Reopen a change after a failed review or acceptance test | PASS | `do_reopen` acts only when `workflow-status.sh` reports `blocking findings` at review or `reports FAIL` at testing. Otherwise it refuses with exit 1 and leaves `tasks.md` unchanged (`cmp`). It moves (`mv`) the verdict to `history/<artifact>-r<round>.md` and appends one unticked `R<round>.<k>` task per `### Finding` / failure. Suite section "Reopen…": 20/20 ok, covering byte-identical preservation, 2 tasks for 2 findings, 1 task for 1 failure, round 1 not overwritten, `review.md` also moved on a test failure, `next` → `implement` after each reopen, and neither `review.md` nor `test-report.md` authored. Live evidence: this change's own round-1 and round-2 reopens preserved `history/review-r1.md` and `history/review-r2.md`, and appended exactly R1.1 and R2.1 carrying each finding's Remediation verbatim. |

## Regression Checks

- `bash -n scripts/delivery.sh` and `bash -n scripts/test-delivery.sh`: clean.
- `scripts/test-delivery.sh`: exit 0, `passed: 90 failed: 0` (88 in round 2, plus the 2 F-2 cases).
- `scripts/test-write-scope.sh` 36/0, `scripts/test-guards.sh` 38/0, `scripts/test-status.sh` 46/0, `scripts/test-completion.sh` 63/0. All exit 0.
- `openspec validate us-12-1-resolve-delivery-target-report --strict`: "Change 'us-12-1-resolve-delivery-target-report' is valid" (exit 0).
- `scripts/workflow-status.sh --change us-12-1-resolve-delivery-target-report --quiet` before this review: gates 1–4 PASS (implementation 15/15), review pending, testing pending, gate 7 PASS.
- Scope: `scripts/check-scope.sh --plan … --diff <.gitignore, scripts/delivery.sh, scripts/test-delivery.sh, .claude/settings.json>` lists only `.gitignore` as unaccounted. This is the same tool limitation recorded in O-2. `.gitignore` is named in the plan's Affected Files, and its diff is only the planned `openspec/delivery/loop.state` block (+5 lines). `.claude/settings.json` parses as JSON, and lines 60–63 hold exactly the four paired allow-list entries.
- I ran no `start`, `stop`, `refresh`, or `reopen` against the real repository. All mutation and edge-case probes ran in `mktemp -d` copies under `/tmp`, removed afterwards.

## Non-Blocking Observations

- O-1 (process, planned risk; carried forward): `scripts/` is harness control surface. As `implementation-plan.md` §Risks records, the main session implemented this change and its R1/R2 remediations. This review is the independent check.
- O-2 (scope tooling; carried forward): `check-scope.sh` does not extract `.gitignore` from the plan, because the token has no `/` and no known extension. This is a tool limitation, not drift.
- O-5 (parsing, defensive; still open): an empty `firstIncompleteGate` still falls through to the completion gate, and `"archiveEligible"` is never read. The path stays fail-closed: only `"eligible": true` yields `archive`, and `guard-archive.sh` still guards the archive.
- O-6 (robustness; still open): `write_goal` writes the `Target` field without the `tr '|' '/'` sanitising applied to `Focus` and `Reason`. It fails closed through `load_goal`.
- O-7 (cwd; still open): run from outside the repository root, `delivery.sh` reports `SPECS.md not found` with exit 1, the same code as an unknown target. This matches the `workflow-status.sh` convention.
- O-8 (cosmetic; new): a story with no `Status:` line escalates correctly, but the reason reads `US-1.2 is -, not READY`, showing the parser's `-` placeholder. Something like "has no Status" would be clearer. Behaviour is correct.

## Handoff

Gate 5 passes with this review. Control proceeds to the Tester:
`/test-feature us-12-1-resolve-delivery-target-report`, for independent acceptance
evidence in `test-report.md`. The Reviewer modified no product code.
