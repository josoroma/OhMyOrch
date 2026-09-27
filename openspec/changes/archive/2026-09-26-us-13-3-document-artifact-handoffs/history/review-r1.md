# Review — us-13-3-document-artifact-handoffs

Change: us-13-3-document-artifact-handoffs
Story: US-13.3
Verdict: pass
Blocking: None
Coverage: 3/3 acceptance criteria evaluated
OpenSpec verify: VERIFIED — `openspec validate us-13-3-document-artifact-handoffs --strict` reports "Change 'us-13-3-document-artifact-handoffs' is valid"; no blocking mismatch

## Summary

The implementation satisfies the delta spec. README.md §19 gains a new
`### How every artifact reaches the next role` subsection that names all five
handoffs (proposal, plan, implementation, review, acceptance evidence) with the
artifact, writer, and reader for each; a `flowchart LR` diagram that nests the five
artifacts inside a `subgraph` labelled `openspec/changes/<change-id>/ — the medium`;
and a gate explanation naming gates 2–6 plus the `guard-archive.sh` / four-condition
archive decision, with the failing-verdict return path. Every factual claim I checked
against the implementation holds. No blocking findings.

## Blocking Issues

None.

## Observations

- **The `test-guards.sh` sample-output block is stale (non-blocking).** README.md
  line 1585 shows `passed: 38` in the illustrative run of `scripts/test-guards.sh`,
  while the prose at lines 1520 and 1573 now cites `103 cases` and the suite actually
  reports `passed: 103`. The plan flagged this pre-existing inconsistency (line 1508
  in the plan's read) and left it optional; the change updated the two cited counts
  but not the sample block. It is illustrative output, not a claim about the current
  count, so it is not a MUST violation — but aligning it would remove a reader's
  reason to doubt the cited count.
- **The three pre-existing US-13.1 navigation failures are gone.** The plan's
  §Risks predicted `test-guards.sh` would report `passed: 82, failed: 3` because
  `SPECS.md` contained US-13.3 but its TOC, status table, and dependency diagram did
  not. The suite now reports `passed: 103, failed: 0`, so the US-13.1 navigation
  structure is current for US-13.3. No finding.
- **The new subsection cross-references rather than duplicates the plan-handoff
  subsection.** §19's existing "How the plan reaches the Implementer" (lines 958–1012)
  is retained; the new subsection generalises the mechanism and does not restate the
  plan-handoff detail. This matches the proposal's §Out of Scope.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| README explains every artifact handoff | PASS | README.md lines 1014–1072: the handoff table (lines 1049–1056) names all five handoffs — `proposal → plan`, `plan → implement`, `implement → review`, `review → test`, `test → archive` — with `Artifact`, `Written by`, and `Read by` columns. Writers/readers verified against `.claude/skills/openspec-propose/SKILL.md` (planner writes proposal/specs/tasks/design), `.claude/skills/plan-feature/SKILL.md` Step 5 (planner writes `implementation-plan.md`), `.claude/agents/implementer.md` §Allowed write scope (implementer writes product code, tests, `tasks.md`), `.claude/agents/reviewer.md` (reviewer writes `review.md`), `.claude/agents/tester.md` (tester writes `test-report.md`). |
| README shows the handoffs as a diagram | PASS | README.md lines 1021–1047: a `flowchart LR` block whose `subgraph change["openspec/changes/&lt;change-id&gt;/ — the medium"]` (line 1022) contains `proposal`, `plan`, `code`, `review`, `report`, and `history` nodes; the block is closed with a matching `end`. Node ids carry no dots; labels are quoted. |
| README explains the mechanical gate on each handoff | PASS | README.md lines 1049–1072: the handoff table's `Gate that blocks the reader` column names gate 2 `planning`, gate 3 `plan-handoff`, gate 4 `implementation`, gate 5 `review`, and gate 6 `testing` + `guard-archive.sh`; the reader-confirms-gate table (lines 1060–1066) names each reader's confirmed gate; lines 1068–1072 explain `completion-gate.sh`'s four conditions and `guard-archive.sh`'s rejection. Lines 1074–1089 explain the failing-verdict return path to the Implementer. |

## Verification Detail

**Gate names and order.** `scripts/workflow-status.sh` line 265 defines
`GATE_NAMES=(selection planning plan-handoff implementation review testing acceptance)`,
matching the README's stated order (line 1068). The README's gate numbers map
correctly: gate 2 `planning` (line 283), gate 3 `plan-handoff` (line 297), gate 4
`implementation` (line 306), gate 5 `review` (line 321), gate 6 `testing` (line 335).

**Archive decision.** `scripts/completion-gate.sh` line 134 defines
`COND_SOURCE=(tasks.md review.md test-report.md "openspec validate")` — the four
conditions the README names (line 1070). `scripts/guard-archive.sh` delegates the
verdict to `workflow-status.sh` and, when present, to `completion-gate.sh`, and exits
`2` (blocked) while any condition fails (lines 175–200).

**Return path.** `scripts/delivery.sh` `do_reopen` (lines 578–650): line 615
`mv "$cdir/review.md" "$cdir/history/review-r$round.md"` and line 618
`mv "$cdir/test-report.md" "$cdir/history/test-report-r$round.md"` — both **move**, not
delete, byte-identical. Lines 622–641 append one unticked remediation task per finding
to `tasks.md`. A test failure also moves `review.md` (the `if [ -f "$cdir/review.md" ]`
branch runs regardless of `kind`). Line 649 sets the next owner to
`implementer (/opsx:apply ...), then reviewer, then tester`. The README's claim that a
test failure also moves `review.md` aside (line 1086) is accurate.

**Reader-confirms-gate table.** Each reader's preflight was confirmed: planner
(`.claude/agents/planner.md` §Required inputs — stops if planning artifacts are
missing), implementer (`.claude/agents/implementer.md` §Required inputs — "Gate 3
(`plan-handoff`) must be `pass`"), reviewer (`.claude/agents/reviewer.md` §Required
inputs — stops if gate 3 is not passing), tester (`.claude/agents/tester.md` §Required
preflight — "Gate 5 (`review`) must be passing"), product-manager
(`.claude/agents/product-manager.md` §The archive decision — evaluates
`completion-gate.sh` and rejects while any condition fails).

**Diagram syntax.** Balanced `subgraph`/`end`; quoted labels; no dots in node ids;
the five artifacts sit inside the change-directory subgraph.

**Mutation check.** In a `mktemp -d` copy, removing the `| review → test |` row from
the handoff table made `scripts/test-guards.sh` report
`FAIL the handoff table names the review — missing: | review → test |` and
`passed: 102, failed: 1, RESULT: FAIL`. The regression case is load-bearing.

**Scope.** `scripts/check-scope.sh --plan
openspec/changes/us-13-3-document-artifact-handoffs/implementation-plan.md --quiet`
exits `0` with no unpredicted files. The diff touches only `README.md`,
`scripts/test-guards.sh`, and `tasks.md` checkboxes — all predicted.

## Handoff

No remediation requested. Control proceeds to acceptance testing.
