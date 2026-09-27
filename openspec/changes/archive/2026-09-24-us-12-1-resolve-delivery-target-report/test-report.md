# Test Report — us-12-1-resolve-delivery-target-report

Change: us-12-1-resolve-delivery-target-report
Story: US-12.1
Verdict: pass
Coverage: 6/6 acceptance criteria evaluated

Independent acceptance record (2026-09-24, revision `ae11530` + working tree). The
Tester did not write this code. Every result below was produced by running the command
shown under Evidence Commands, and the output shown is what I observed. The primary
evidence comes from a Tester-built sandbox (`mktemp -d /tmp/tst-us121.XXXXXX`). It holds
a copy of `scripts/`, a stub `SPECS.md` that I authored, and change fixtures that I
built. Read-only `resolve`/`next` probes on the real repository and the implementer's
`scripts/test-delivery.sh` are supplementary only. I ran no `start`, `refresh`,
`reopen`, or `stop` against the real repository. I removed the sandbox afterwards.

Stub design (in the sandbox `SPECS.md`, which `validate-product-artifacts.sh` passed
with exit 0):

- EPIC-1 lists its stories as US-1.1, US-1.3, US-1.2, deliberately out of numeric
  order, so SPECS.md order can be told apart from sorted order. US-1.1 has three tasks,
  and task 2 is `Implement the zebra-lexer module.` US-1.3 has a `Change:` line.
- EPIC-2 covers the cases that cannot proceed:
  - US-2.1 is NEEDS CLARIFICATION.
  - US-2.2 is READY but depends on US-2.3, which is READY and not DONE.
  - US-2.4 is IN PROGRESS, has an archived change, and depends on US-2.3 (not DONE).
  - US-2.5 is BLOCKED.

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | Resolve an epic into its stories | PASS | E-1: `delivery.sh resolve EPIC-1` exits 0 and lists `US-1.1`, `US-1.3`, `US-1.2`, which is exactly SPECS.md order, not numeric order. Each story gets a distinct change id: `us-1-1-build-alpha-parser` (derived), `us-1-3-alpha-renderer` (from its `Change:` line), and `us-1-2-document-alpha-pipeline` (derived). `--json` gives the same order and ids. No EPIC-2 story leaks in. On the real repo, `resolve EPIC-12` gives US-12.1, US-12.2, US-12.3 with 3 distinct ids. |
| 2 | Resolve a task to its parent story | PASS | E-2: `resolve 'US-1.1#2'` and the text target `resolve 'zebra-lexer'` both exit 0 with `Kind: task`, `Focus: Implement the zebra-lexer module.`, and a single story `US-1.1`, the parent. `start 'US-1.1#2'` writes `goal.md` with `\| Kind \| task \|` and `\| Focus \| Implement the zebra-lexer module. \|`. The Stories table holds only `US-1.1`. |
| 3 | Reject an unknown target | PASS | E-3: `resolve EPIC-77`, `US-9.9`, `US-1.1#9`, and `'qqq nonexistent'` each exit 1 with `unknown target: <target> (...)`, naming the target. `start EPIC-77` exits 1 with `no delivery goal recorded`, and `openspec/delivery` still does not exist. When a goal already exists, a rejected `start EPIC-77` leaves `goal.md` byte-identical (`cmp`). On the real repo, `resolve EPIC-99` exits 1 and names `EPIC-99`. |
| 4 | Derive the next action from repository artifacts | PASS | E-4: I built an active change for US-1.3 one artifact at a time. At every stage the `next` action matched `workflow-status.sh --json` `firstIncompleteGate`, and each action named an Owner and a Command: planning→`propose`/planner, plan-handoff→`plan`/planner, implementation→`implement`/implementer (`/opsx:apply`), review→`review`/reviewer (`/review-feature`), testing→`test`/tester (`/test-feature`). With all gates passing (`firstIncompleteGate: null`), the action came from `completion-gate.sh`. First, `escalate` named `openspec-verification`, which matched the gate's `firstFailingCondition`. After I made the change OpenSpec-valid, `completion-gate.sh` reported `eligible: true` and `next` gave `archive`/product-manager with `completion-gate.sh --record && openspec archive`. I then hand-edited `goal.md` to `Action: complete`, and `next` still derived `archive`, so the action is not read back from goal.md. On the real repo, `next EPIC-12` gave `test`/tester `/test-feature us-12-1-…`. |
| 5 | Escalate a story that cannot proceed | PASS | E-5: every case gave `Action: escalate`, `Owner: human-product-manager`, and a reason: US-2.1 `is NEEDS CLARIFICATION, not READY`; US-2.5 `is BLOCKED, not READY`; US-2.2 `depends on unfinished US-2.3 (READY)`; archived-change US-2.4 `depends on unfinished US-2.3 (READY)` (it did not go to `mark-done`). `next EPIC-2` escalates at its first undelivered story, US-2.1. A `find openspec/changes \| sort` snapshot was identical before and after all these calls and a `start EPIC-2`, so no change was created. Control: with US-2.3 set to DONE, US-2.4 gives `mark-done`, so the escalation comes from the dependency. On the real repo, `next US-12.2` escalates (`depends on unfinished US-12.1 (IN PROGRESS)`), and the real `openspec/changes` listing was unchanged. |
| 6 | Reopen a change after a failed review or acceptance test | PASS | E-6a, blocking review with 2 findings: `next` gives `reopen`. `reopen` exits 0 and moves `review.md` to `history/review-r1.md`, byte-identical to the original (`cmp`). The tasks.md diff is exactly 2 new `- [ ]` lines (R1.1, R1.2), one per finding, and nothing else changes. `next` then gives `implement`/implementer `/opsx:apply`. E-6b, failing test report with 1 failure: `next` gives `reopen`. `reopen` preserves `history/test-report-r2.md` byte-identical (and `review-r2.md`). Round-1 history is untouched. tasks.md gains exactly 1 new `- [ ]` line (R2.1), and `next` gives `implement`. E-6c control: when nothing has failed, `reopen` refuses with exit 1 and tasks.md is unchanged. |

## Evidence Commands

All sandbox commands ran with the sandbox as the working directory. `$C` is
`openspec/changes/us-1-3-alpha-renderer`, and `$F` is the real repo's `scripts/fixtures`.

### E-0 — Preflight (real repository)

```bash
scripts/workflow-status.sh --change us-12-1-resolve-delivery-target-report --quiet
```

```text
  PASS  review           review.md present, no blocking findings
  ----  testing          test-report.md missing
  First incomplete gate: testing
```

Gate 5 (review) passes, so testing may proceed.

### E-1 — Resolve an epic into its stories

```bash
scripts/delivery.sh resolve EPIC-1; echo "exit=$?"
scripts/delivery.sh resolve EPIC-1 --json
```

```text
   1  US-1.1   READY                us-1-1-build-alpha-parser                Build the alpha parser
   2  US-1.3   IN PROGRESS          us-1-3-alpha-renderer                    Ship the alpha renderer
   3  US-1.2   DONE                 us-1-2-document-alpha-pipeline           Document the alpha pipeline
exit=0
{ "target": "EPIC-1", "kind": "epic", "focus": "-", "stories": [ { "story": "US-1.1", ... "change": "us-1-1-build-alpha-parser" }, { "story": "US-1.3", ... "change": "us-1-3-alpha-renderer" }, { "story": "US-1.2", ... "change": "us-1-2-document-alpha-pipeline" } ] }
```

### E-2 — Resolve a task to its parent story

```bash
scripts/delivery.sh resolve 'US-1.1#2'
scripts/delivery.sh resolve 'zebra-lexer'
scripts/delivery.sh start 'US-1.1#2'
grep -E '^\| (Target|Kind|Focus|Status) \|' openspec/delivery/goal.md
```

```text
Target: US-1.1#2
Kind:   task
Focus:  Implement the zebra-lexer module.
   1  US-1.1   READY                us-1-1-build-alpha-parser                Build the alpha parser
exit=0
Target: zebra-lexer
Kind:   task
Focus:  Implement the zebra-lexer module.
   1  US-1.1   READY                us-1-1-build-alpha-parser                Build the alpha parser
exit=0
| Target | US-1.1#2 |
| Kind | task |
| Focus | Implement the zebra-lexer module. |
| Status | ACTIVE |
| 1 | US-1.1 | us-1-1-build-alpha-parser | READY | Build the alpha parser |
```

### E-3 — Reject an unknown target

```bash
scripts/delivery.sh resolve EPIC-77; scripts/delivery.sh resolve US-9.9
scripts/delivery.sh resolve 'US-1.1#9'; scripts/delivery.sh resolve 'qqq nonexistent'
scripts/delivery.sh start EPIC-77; ls openspec/delivery
# with an existing goal:
scripts/delivery.sh start EPIC-1; cp openspec/delivery/goal.md goal.before
scripts/delivery.sh start EPIC-77; cmp openspec/delivery/goal.md goal.before
```

```text
unknown target: EPIC-77 (no '# EPIC-77:' heading in SPECS.md)
exit=1
unknown target: US-9.9 (no story US-9.9 in SPECS.md)
exit=1
unknown target: US-1.1#9 (story US-1.1 has no task #9)
exit=1
unknown target: qqq nonexistent (not an epic, story, or task in SPECS.md)
exit=1
unknown target: EPIC-77 (no '# EPIC-77:' heading in SPECS.md)
no delivery goal recorded
start exit=1
ls: openspec/delivery: No such file or directory
...
start exit=1
goal.md byte-identical after rejected start
```

### E-4 — Derive the next action from repository artifacts

```bash
probe() { scripts/workflow-status.sh --change us-1-3-alpha-renderer --json | grep -oE '"firstIncompleteGate": *[^,]*'
          scripts/delivery.sh next US-1.3 | grep -E '^(Action|Owner|Command|Reason):'; }
# stages: tasks.md only -> +proposal/specs -> +valid plan -> tasks ticked
#         -> +approved review -> +passing test report -> OpenSpec-valid change
scripts/completion-gate.sh --change us-1-3-alpha-renderer --json
```

```text
-- stage: tasks.md only
"firstIncompleteGate": "planning"
Action:  propose
Owner:   planner
Command: /opsx:explore US-1.3 then /opsx:propose us-1-3-alpha-renderer
-- stage: proposal+specs
"firstIncompleteGate": "plan-handoff"
Action:  plan
Owner:   planner
Command: /plan-feature us-1-3-alpha-renderer
-- stage: plan added
"firstIncompleteGate": "implementation"
Action:  implement
Owner:   implementer
Command: /opsx:apply us-1-3-alpha-renderer
-- stage: tasks ticked
"firstIncompleteGate": "review"
Action:  review
Owner:   reviewer
Command: /review-feature us-1-3-alpha-renderer (includes /opsx:verify)
-- stage: approved review
"firstIncompleteGate": "testing"
Action:  test
Owner:   tester
Command: /test-feature us-1-3-alpha-renderer
-- stage: passing test report
"firstIncompleteGate": null
Action:  escalate
Owner:   human-product-manager
Command: inspect scripts/completion-gate.sh --change us-1-3-alpha-renderer
Reason:  gates pass but completion condition 'openspec-verification' fails
"eligible": false
"firstFailingCondition": "openspec-verification"
-- after making the change OpenSpec-valid
Change 'us-1-3-alpha-renderer' is valid
Action:  archive
Owner:   product-manager
Command: scripts/completion-gate.sh --change us-1-3-alpha-renderer --record && openspec archive us-1-3-alpha-renderer -y
Reason:  all seven gates and all four completion conditions pass
"eligible": true
-- goal.md hand-edited to "Action: complete", then `next`
Action:  archive
```

### E-5 — Escalate a story that cannot proceed

```bash
find openspec/changes | sort > snap.before
for t in EPIC-2 US-2.1 US-2.2 US-2.4 US-2.5; do scripts/delivery.sh next $t; done
scripts/delivery.sh start EPIC-2
find openspec/changes | sort > snap.after; cmp snap.before snap.after
# control: set US-2.3 to DONE, then
scripts/delivery.sh next US-2.4
```

```text
-- next EPIC-2   Action: escalate  Story: US-2.1  Owner: human-product-manager
                 Reason: US-2.1 is NEEDS CLARIFICATION, not READY
-- next US-2.1   Action: escalate  Reason: US-2.1 is NEEDS CLARIFICATION, not READY
-- next US-2.2   Action: escalate  Reason: US-2.2 depends on unfinished US-2.3 (READY)
-- next US-2.4   Action: escalate  Reason: US-2.4 depends on unfinished US-2.3 (READY)
-- next US-2.5   Action: escalate  Reason: US-2.5 is BLOCKED, not READY
-- start EPIC-2  Action: escalate
openspec/changes tree identical before/after (13 entries)
-- control: dependency US-2.3 made DONE
Action:  mark-done
Reason:  change us-2-4-archived-work is archived but US-2.4 is IN PROGRESS
```

### E-6 — Reopen a change after a failed review or acceptance test

```bash
# 6a: blocking review (fixture with findings F-1, F-2), tasks all ticked
cp $F/reviews/blocking/review.md $C/review.md; cp $C/review.md rv.orig; cp $C/tasks.md tasks.before
scripts/delivery.sh next US-1.3; scripts/delivery.sh reopen --change us-1-3-alpha-renderer
cmp rv.orig $C/history/review-r1.md; diff tasks.before $C/tasks.md; scripts/delivery.sh next US-1.3
# 6b: approved review + failing test report (1 failure)
cp $F/test-reports/failing/test-report.md $C/test-report.md; cp $C/test-report.md tr.orig
scripts/delivery.sh reopen --change us-1-3-alpha-renderer
cmp tr.orig $C/history/test-report-r2.md; diff tasks.before $C/tasks.md; scripts/delivery.sh next US-1.3
# 6c: nothing failing
scripts/delivery.sh reopen --change us-1-3-alpha-renderer; cmp tasks.before $C/tasks.md
```

```text
== 6a
Action:  reopen
Reason:  gate review: review.md reports blocking findings
REOPENED  us-1-3-alpha-renderer — round 1 from review
  preserved:   history/review-r1.md
  appended:    2 remediation task(s) to openspec/changes/us-1-3-alpha-renderer/tasks.md
review.md moved out
history/review-r1.md byte-identical to failing review
> - [ ] R1.1 Resolve review finding F-1: analyst can write product code — remove `Write` and `Edit` ...
> - [ ] R1.2 Resolve review finding F-2: evidence rule is unenforceable as written — add the evidence-discipline table ...
new unticked tasks: 2
Action:  implement
Owner:   implementer
Command: /opsx:apply us-1-3-alpha-renderer
Reason:  gate implementation: 2/4 tasks complete
== 6b
Action:  reopen
Reason:  gate testing: test-report.md reports FAIL
REOPENED  us-1-3-alpha-renderer — round 2 from test-report
  preserved:   history/review-r2.md, history/test-report-r2.md
review-r1.md      review-r2.md      test-report-r2.md
round-1 review still intact
history/test-report-r2.md byte-identical to failing report
> - [ ] R2.1 Make failing criterion pass: Criterion 1 — Analyze an existing codebase — expected: the tool list omits `Write` and `Edit` ...
new unticked tasks: 1
Action:  implement
Owner:   implementer
Reason:  gate implementation: 4/5 tasks complete
== 6c
error: nothing to reopen: us-1-3-alpha-renderer has no blocking review or failing test report (first incomplete gate: testing)
reopen exit=1
tasks.md unchanged
```

### E-7 — Supplementary: real-repository read-only probes and regression suite

```bash
find openspec/changes -maxdepth 2 | sort > before
scripts/delivery.sh resolve EPIC-12; scripts/delivery.sh resolve 'US-12.1#2'
scripts/delivery.sh resolve EPIC-99; scripts/delivery.sh next EPIC-12; scripts/delivery.sh next US-12.2
find openspec/changes -maxdepth 2 | sort > after; cmp before after
scripts/test-delivery.sh
```

```text
   1  US-12.1  IN PROGRESS          us-12-1-resolve-delivery-target-report   ...
   2  US-12.2  READY                us-12-2-run-delivery-goal-loop           ...
   3  US-12.3  READY                us-12-3-document-delivery-orchestrator   ...
Focus:  Define the `openspec/delivery/goal.md` format (derived story table, authored notes).
unknown target: EPIC-99 (no '# EPIC-99:' heading in SPECS.md)
exit=1
Action:  test
Owner:   tester
Command: /test-feature us-12-1-resolve-delivery-target-report
Action:  escalate
Reason:  US-12.2 depends on unfinished US-12.1 (IN PROGRESS)
real openspec/changes unchanged
ls: openspec/delivery: No such file or directory
  passed: 90
  failed: 0
```

The suite's final summary line (`RESULT: PASS — goal-driven delivery holds.`, exit 0)
is quoted here inline instead of in the output block. At the start of a line, the
validator would count it as a criterion result.

## Result

All 6 criteria were exercised with executable checks against Tester-built fixtures, and
all 6 passed. No criterion was scored without observed evidence.

Observation, not blocking: the implementer's suite is consistent with my independent
results. I did not use it as primary evidence for any row.

## Failures

None.

## Handoff

All criteria pass, and gate 6 (testing) should now pass. Next: the Product Manager
evaluates the completion gate and archival (`/opsx:archive`). The Tester modified no
product code, scripts, SPECS.md, tasks.md, or review.md.
