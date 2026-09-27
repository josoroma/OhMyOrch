# Review — us-12-1-resolve-delivery-target-report

Change: us-12-1-resolve-delivery-target-report
Story: US-12.1
Verdict: changes-requested
Blocking: 1 finding
Coverage: 6/6 acceptance criteria evaluated
OpenSpec verify: MISMATCH — artifacts valid (`openspec validate us-12-1-resolve-delivery-target-report --strict`: "Change 'us-12-1-resolve-delivery-target-report' is valid"), but the implementation does not meet requirement "Escalate a story that cannot proceed" for a non-READY story whose change is archived (see F-1)

## Summary

`scripts/delivery.sh` resolves epics, stories, and tasks correctly. It works out every
gate-driven action from `workflow-status.sh` and `completion-gate.sh`, and never reads
it back from `goal.md`. `reopen` preserves evidence byte for byte and cannot write a
verdict. Five of the six scenarios are met. One MUST in "Escalate a story that cannot
proceed" is violated: when the first undelivered story is not READY or IN PROGRESS but
its change is archived, `next` returns `mark-done` instead of `escalate`. That tells
the Product Manager to set `Status: DONE` on a story a human has marked
`NEEDS CLARIFICATION` or `BLOCKED`. The delta is otherwise in scope. The regression
suite passes 85/85 on bash 3.2.57.

## Findings

### Finding F-1: an archived change bypasses readiness escalation

Requirement: Scenario: Escalate a story that cannot proceed — "Given the first undelivered story is not READY or IN PROGRESS … Then the action MUST be "escalate" with the reason"
Observed: in `derive_next` (`scripts/delivery.sh` lines 283–289), the `change_archived "$change"` branch returns `mark-done` before the readiness `case "$status"` check at lines 291–299 runs. Reproduced in a throwaway `/tmp` copy with a stub `SPECS.md` holding `### US-1.1` at `Status: NEEDS CLARIFICATION` and `Change: \`openspec/changes/archive/2026-09-24-us-1-1-x/\``, with that archive directory present. `scripts/delivery.sh next US-1.1` printed `Action:  mark-done`, `Owner:   product-manager`, `Command: set 'Status: DONE' for US-1.1 in SPECS.md …`, `Reason:  change us-1-1-x is archived but US-1.1 is NEEDS CLARIFICATION`. `scripts/test-delivery.sh` has no case for this combination.
Expected: a story that is not READY or IN PROGRESS escalates to the human Product Manager, with the reason, whatever state its change is in. The loop must not route a story a human has marked `NEEDS CLARIFICATION` or `BLOCKED` into a DONE transition. `design.md` §3 lists the `mark-done` row but does not rank it above readiness, and the spec's MUST decides.
Remediation: in `derive_next`, run the readiness check (`READY|"IN PROGRESS"`, else `escalate`) before the `change_archived` branch, so `mark-done` applies only to a READY or IN PROGRESS story whose change is archived. Add a regression case to `scripts/test-delivery.sh` under "Escalate a story that cannot proceed": a NEEDS CLARIFICATION story whose `Change:` points at an existing archive directory must yield `escalate`, with a reason naming the status. Keep the existing "archived but not DONE -> mark-done" case (IN PROGRESS) passing.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| Resolve an epic into its stories | PASS | `scripts/delivery.sh resolve EPIC-12` lists US-12.1, US-12.2, US-12.3 in file order with three distinct change ids (`us-12-1-resolve-delivery-target-report`, `us-12-2-run-delivery-goal-loop`, `us-12-3-document-delivery-orchestrator`), exit 0. `parse_specs` awk (lines 93–151) emits stories in file order, and `change_for` (lines 176–195) maps each to its own id. Suite §"Resolve an epic" 7/7 ok. |
| Resolve a task to its parent story | PASS | `resolve 'US-12.1#2'` and `resolve 'regression suite'` both give `Kind: task`, the parent story `US-12.1`, and the task text as `Focus`. `write_goal` writes `\| Focus \| … \|` (line 453). In the suite, `start 'US-1.1#2'` writes `\| Focus \| Wire the widget renderer. \|`. Ambiguous text and out-of-range index both exit 1 (fail closed). |
| Reject an unknown target | PASS | `scripts/delivery.sh resolve EPIC-99; echo $?` prints `unknown target: EPIC-99 (no '# EPIC-99:' heading in SPECS.md)` and `1`. `openspec/delivery/` is still absent afterwards. `start` exits before any write (line 669). The suite checks there is no `goal.md` after `start US-9.9`, and that an existing goal is byte-identical after `start EPIC-99` (`cmp`). |
| Derive the next action from repository artifacts | PASS | `scripts/delivery.sh next EPIC-12` gives `Action: review`, `Owner: reviewer`, `Command: /review-feature us-12-1-resolve-delivery-target-report (includes /opsx:verify)`, `Reason: gate review: review.md missing`. This matches `workflow-status.sh --json` (`firstIncompleteGate: "review"`). Lines 340–413 map every gate. With all gates passing, the result comes from `completion-gate.sh --json` `"eligible"`, and anything other than `true` escalates. The suite covers propose, plan, implement, review, reopen×2, test, archive, completion-escalate, acceptance-escalate, and a hand-edited `goal.md` that is ignored. |
| Escalate a story that cannot proceed | FAIL | The status and dependency paths work: `next US-12.2` gives `escalate`, `Reason: US-12.2 depends on unfinished US-12.1 (IN PROGRESS)`, and the suite's NEEDS CLARIFICATION and dependency cases pass with an unchanged `openspec/changes` snapshot. The script never creates a change (only `mkdir -p` of `openspec/delivery` and `history/`). But a non-READY story with an archived change yields `mark-done`, not `escalate` — see F-1. |
| Reopen a change after a failed review or acceptance test | PASS | `do_reopen` (lines 570–643) `mv`s the verdict to `history/<artifact>-r<round>.md`, with the round set to max+1 so earlier rounds are never overwritten. It appends one `- [ ] R<round>.<k>` task per `### Finding` or `### Criterion`, copying the Remediation or Expected text verbatim. A test failure also moves `review.md`. The script never writes `review.md` or `test-report.md`. A passing review is refused with exit 1 and `tasks.md` is left unchanged. Suite: byte-identical preservation (`cmp`), 2 R1 tasks, 1 R2 task, `next` returns `implement` after each reopen. |

## Non-Blocking Observations

- O-1 (process, planned risk): `scripts/` is harness control surface, so `check-write-scope.sh` blocks the implementer role there. The main session implemented this change, following the precedent in `README-OPENSPEC-COMMANDS.md` §4.5. This is recorded in `implementation-plan.md` §Risks, and this review is the independent check.
- O-2 (scope tooling): `scripts/check-scope.sh --plan … --diff <the four delta files>` reports `.gitignore` as unpredicted. The plan does name it (`Affected Files` row and §Implementation Order step 8). The extractor only accepts backticked tokens that contain `/` or a known extension, and `.gitignore` has neither. The other three files are in scope. The baseline comparison (`comm -13 /tmp/us121-baseline.txt /tmp/us121-after.txt`) shows only `.gitignore`, `scripts/delivery.sh`, and `scripts/test-delivery.sh` as new, so the change did not drift. This is an existing tool limitation, not a defect in this change.
- O-3 (`.claude/settings.json`): the file is untracked in git, so the four-entry delta cannot be shown with `git diff`. Lines 60–63 hold exactly the four paired entries (`bash scripts/delivery.sh`, `scripts/delivery.sh`, `bash scripts/test-delivery.sh`, `scripts/test-delivery.sh`), no hook was added, and the JSON parses. `.gitignore` line 20 ignores `openspec/delivery/loop.state` (`git check-ignore -v`), and `goal.md` is not ignored, as intended.
- O-4 (parsing, fail-open edge): the dependency reader handles only the bulleted form (`Dependencies:` then `- US-n.m`), which is the canonical format in `.claude/agents/spec-ingestor.md` and is used throughout `SPECS.md`. An inline `Dependencies: US-1.2` is silently ignored. A throwaway probe gave `select` instead of `escalate`. Consider parsing ids on the `Dependencies:` line itself, or failing closed on a non-empty inline value.
- O-5 (parsing, defensive): an empty `firstIncompleteGate` (JSON `null`, or a failed `sed` extraction) falls through to the completion gate. That path is still fail-closed, because only `"eligible": true` yields `archive`, and `guard-archive.sh` still guards the archive itself. Cross-checking `"archiveEligible": true` from the same JSON would make a malformed report escalate rather than depend on the second reporter.
- O-6 (robustness): `Target` is written to `goal.md` without the `|` → `/` sanitising that `Focus` and `Reason` get (line 451). A task-text target containing `|` would break `goal_field Target`. That fails closed, since `load_goal` dies with "no longer resolves".
- O-7 (cwd): like `workflow-status.sh` (`ROOT=$(pwd)`), the script assumes the repository root as cwd. Run from `scripts/`, it exits 1 with "SPECS.md not found", which shares the exit code of an unknown target.
- Compatibility: `/bin/bash` is 3.2.57. The code uses no `mapfile`, associative arrays, `${v^^}`, or empty-array expansions under `set -u`. Alternation goes through `grep -E`/awk, and `sed` uses only simple BRE `s///` and `-n …p`. `bash -n` is clean for both scripts. `test-write-scope.sh`, `test-guards.sh`, `test-status.sh`, and `test-completion.sh` all exit 0. `node scripts/check-frontmatter.js` and `scripts/validate-product-artifacts.sh` exit 0.

## Handoff

Control returns to the Implementer to fix F-1: move the readiness check ahead of the
archived-change branch in `derive_next`, and add the regression case. After that,
`/review-feature us-12-1-resolve-delivery-target-report` runs again. Acceptance testing
must not proceed while F-1 is open.
