# Test Report — us-13-3-document-artifact-handoffs

Change: us-13-3-document-artifact-handoffs
Story: US-13.3
Verdict: pass
Coverage: 3/3 acceptance criteria evaluated

Independent acceptance record (2026-09-26, working tree). The Tester did not write this
change. The acceptance criteria were taken from `SPECS.md` `### US-13.3:` and the
change's `specs/harness-documentation/spec.md`, not from the implementer's claims. Every
result below comes from a check I wrote and ran, or from lines I inspected, and the
output shown is what I observed.

- **Method: mixed.** Criteria 1 and 2 are structural properties of `README.md`, judged
  by Tester-written Python checks that parse the document and compare it to the agent
  and skill definitions. Criterion 3 is a behavioral claim about the return path, judged
  by running `scripts/delivery.sh reopen` in a throwaway copy, plus inspection of the
  gate prose and cross-checks against `scripts/workflow-status.sh` and
  `scripts/completion-gate.sh`.
- **The checks are mine, not the implementer's.** I did not run `scripts/test-guards.sh`
  as the basis for any row; I wrote independent parsers for the handoff table and the
  Mermaid block, and I ran `delivery.sh reopen` myself. The implementer's suite was run
  only as supplementary regression (E-5).
- **Real repository:** I ran only read-only commands. `openspec/delivery/goal.md` was not
  modified; `scripts/delivery.sh resolve` and `next` are read-only reporters. `reopen`
  was exercised in a `mktemp -d` copy, which was removed with `rm -rf "$dir"`.

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | README explains every artifact handoff | PASS | Tester-written Python check (E-1) plus inspection. §19's `### How every artifact reaches the next role` subsection (`README.md:1014`) carries a handoff table (`README.md:1049`) with 5 rows and the columns `Handoff`, `Artifact`, `Written by`, `Read by`, `Gate that blocks the reader`. All five handoffs are present — `proposal → plan`, `plan → implement`, `implement → review`, `review → test`, `test → archive` — and each row names the artifact, the writer, and the reader. I cross-checked every writer/reader against the agent and skill definitions (E-2): **0 mismatches**. |
| 2 | README shows the handoffs as a diagram | PASS | Tester-written Python check (E-3). A `flowchart LR` block (`README.md:1022`–`1046`) is present. It is balanced (1 `subgraph` / 1 `end`), all labels are quoted (0 unquoted), and no node id contains a dot (0 dotted ids). The five artifacts — `proposal`, `plan`, `code`, `review`, `report` — plus `history` sit inside the single `subgraph change["openspec/changes/&lt;change-id&gt;/ — the medium"]`, which names the change directory as the medium. |
| 3 | README explains the mechanical gate on each handoff | PASS | Executable check (E-4) plus inspection. The handoff table's `Gate that blocks the reader` column names gate 2 `planning`, gate 3 `plan-handoff`, gate 4 `implementation`, gate 5 `review`, and gate 6 `testing` + `guard-archive.sh`; the reader-confirms-gate table (`README.md:1060`) names each reader's confirmed gate; and `README.md:1068`–`1089` explains `completion-gate.sh`'s four conditions and the failing-verdict return path. I cross-checked the gate names and order against `scripts/workflow-status.sh` (E-4a) and the four conditions against `scripts/completion-gate.sh` (E-4b), and I verified the return path myself in a throwaway copy (E-4c): `reopen` **moved** `review.md` to `history/review-r1.md` byte-identical, appended one unticked remediation task per finding, and left the first incomplete gate at `implementation` (owner `implementer`). |

## Evidence Commands

### E-0 — Preflight (real repository)

```bash
scripts/workflow-status.sh --change us-13-3-document-artifact-handoffs --quiet
```

```text
  PASS  selection        change 'us-13-3-document-artifact-handoffs' exists
  PASS  planning         proposal.md, specs/, tasks.md present
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
  PASS  implementation   7/7 tasks complete
  PASS  review           review.md present, no blocking findings
  ----  testing          test-report.md missing
        next owner: tester (/test-feature)
  PASS  acceptance       artifact contracts satisfied

  First incomplete gate: testing
  Next owner:            tester (/test-feature)
  NOT archive-eligible
```

Gate 5 (review) passes, so testing may proceed.

### E-1 — Handoff table (Tester-written check)

```bash
python3 - <<'PY'   # parses the handoff table under the §19 subsection
PY
```

```text
subsection line: 1014
handoff table header line: 1049
handoff rows: 5
   ['proposal → plan', '`proposal.md`, `specs/`, `tasks.md`, `design.md`', 'planner (`/opsx:propose`)', 'planner (`/plan-feature`)', 'gate 2 `planning`']
   ['plan → implement', '`implementation-plan.md`', 'planner (`/plan-feature`)', 'implementer (`/opsx:apply`)', 'gate 3 `plan-handoff`']
   ['implement → review', 'product code, tests, ticked `tasks.md`', 'implementer (`/opsx:apply`)', 'reviewer (`/review-feature`)', 'gate 4 `implementation`']
   ['review → test', '`review.md`', 'reviewer (`/review-feature`)', 'tester (`/test-feature`)', 'gate 5 `review`']
   ['test → archive', '`test-report.md`', 'tester (`/test-feature`)', 'product-manager (archive decision)', 'gate 6 `testing`, then `guard-archive.sh`']
```

Five handoffs, each naming artifact, writer, and reader.

### E-2 — Writer/reader cross-check (Tester-written inspection)

```bash
grep -n "proposal.md\|tasks.md\|design.md\|specs/" .claude/skills/openspec-propose/SKILL.md
grep -n "implementation-plan.md\|Step 5" .claude/skills/plan-feature/SKILL.md
grep -n "Allowed write scope\|tasks.md\|gate 3" .claude/agents/implementer.md
grep -n "review.md\|gate 3\|gate 4" .claude/agents/reviewer.md
grep -n "test-report.md\|gate 5" .claude/agents/tester.md
grep -n "propose\|plan\|implement\|review\|test\|archive" .claude/skills/deliver/SKILL.md
```

```text
openspec-propose/SKILL.md:18-21  proposal.md, specs/<capability>/spec.md, design.md, tasks.md
plan-feature/SKILL.md:18         "writes exactly one artifact: implementation-plan.md"
plan-feature/SKILL.md:87         "## Step 5 — Write the plan"
implementer.md:28                "## Allowed write scope" (product code, tests, tasks.md checkboxes)
implementer.md:51                "Gate 3 (plan-handoff) must be pass"
reviewer.md:35                   "write exactly one artifact — review.md"
reviewer.md:62                   "If implementation-plan.md is missing or gate 3 is not passing, stop"
tester.md:97                     "Gate 5 (review) must be passing"
tester.md:108                    "Exactly one artifact: test-report.md"
deliver/SKILL.md:75-81           propose→planner, plan→planner, implement→implementer,
                                 review→reviewer, test→tester, archive→product-manager
```

Every writer and reader in the README table matches the definitions: the planner writes
the proposal artifacts and the plan; the implementer writes product code, tests, and
ticked `tasks.md`; the reviewer writes `review.md`; the tester writes `test-report.md`;
the product-manager owns the archive decision. **0 mismatches.**

### E-3 — Mermaid diagram (Tester-written check)

```bash
python3 - <<'PY'   # parses the mermaid fence, counts subgraph/end, checks ids and labels
PY
```

```text
mermaid block lines: 1022 - 1046
header: flowchart LR
subgraph count: 1 end count: 1
  subgraph: subgraph change["openspec/changes/&lt;change-id&gt;/ — the medium"]
node ids: ['change', 'code', 'history', 'implementer', 'plan', 'planner', 'planner2', 'pm', 'proposal', 'reopen', 'report', 'review', 'reviewer', 'tester']
dotted ids: []
unquoted labels: []
nodes inside subgraph: ['proposal', 'plan', 'code', 'review', 'report', 'history']
```

The block is balanced, node ids carry no dots, labels are quoted, and the five artifacts
sit inside the change-directory subgraph.

### E-4a — Gate names and order (cross-check)

```bash
grep -n "GATE_NAMES=" scripts/workflow-status.sh
```

```text
265:GATE_NAMES=(selection planning plan-handoff implementation review testing acceptance)
```

The README's gate numbers map correctly onto this 1-indexed list: gate 2 `planning`,
gate 3 `plan-handoff`, gate 4 `implementation`, gate 5 `review`, gate 6 `testing`.

### E-4b — Archive conditions (cross-check)

```bash
grep -n "COND_SOURCE=" scripts/completion-gate.sh
```

```text
134:COND_SOURCE=(tasks.md review.md test-report.md "openspec validate")
```

The four conditions the README names (`tasks.md`, `review.md`, `test-report.md`,
`openspec validate`) match.

### E-4c — Return path (executable check, throwaway copy)

```bash
dir=$(mktemp -d)
cp -R . "$dir/repo"; cd "$dir/repo"
cp -R openspec/changes/us-13-3-document-artifact-handoffs openspec/changes/test-reopen
rm -rf openspec/changes/test-reopen/history
cat > openspec/changes/test-reopen/review.md <<'EOF'
# Review — test-reopen
Change: test-reopen
Story: US-99.1
Verdict: fail
Blocking: 2

## Blocking Issues

### Finding B-1: first problem
Remediation: fix the first problem.

### Finding B-2: second problem
Remediation: fix the second problem.
EOF
scripts/delivery.sh reopen --change test-reopen
ls openspec/changes/test-reopen/history
tail -6 openspec/changes/test-reopen/tasks.md
scripts/workflow-status.sh --change test-reopen --json | grep -o '"firstIncompleteGate": *"[^"]*"'
rm -rf "$dir"
```

```text
REOPENED  test-reopen — round 1 from review
  preserved:   history/review-r1.md
  appended:    2 remediation task(s) to openspec/changes/test-reopen/tasks.md
  next owner:  implementer (/opsx:apply test-reopen), then reviewer, then tester

history/review-r1.md

## R1. Remediation — reopened 2026-09-26 from review

Preserved: history/review-r1.md

- [ ] R1.1 Resolve review finding B-1: first problem — fix the first problem.
- [ ] R1.2 Resolve review finding B-2: second problem — fix the second problem.

"firstIncompleteGate": "implementation"
```

The verdict was **moved** to `history/review-r1.md` (not deleted; a byte-identical
`diff` reported IDENTICAL), one unticked remediation task was appended per finding
(2 findings → 2 tasks), and the first incomplete gate became `implementation`, whose
owner is `implementer` — so the next derived action is `implement`. This confirms the
README's return-path claim.

### E-5 — Regression (real repository)

```bash
scripts/validate-product-artifacts.sh
scripts/delivery.sh resolve EPIC-13
scripts/delivery.sh next
scripts/test-guards.sh | tail -5
```

```text
validate-product-artifacts.sh
  PASS  Epic identifiers unique (13 found)
  PASS  User Story identifiers unique (27 found)
  PASS  every story declares a valid status
  PASS  every READY story has complete Given/When/Then acceptance criteria
  PASS  every READY story is source-traceable
  failures: 0   warnings: 0
  (closing line: "RESULT: PASS — all required checks passed, 0 warning(s).")   exit=0

delivery.sh resolve EPIC-13
   1  US-13.1  DONE          us-13-1-navigable-specs-structure
   2  US-13.2  DONE          us-13-2-document-orchestrator-loop
   3  US-13.3  IN PROGRESS   us-13-3-document-artifact-handoffs   exit=0

delivery.sh next
  Action:  test
  Story:   US-13.3
  Owner:   tester
  Command: /test-feature us-13-3-document-artifact-handoffs
  Reason:  gate testing: test-report.md missing   exit=0

test-guards.sh (supplementary only)
  passed: 103
  failed: 0
  (closing line: "RESULT: PASS — all guard behaviours hold.")
```

The README changes did not disturb the artifact validator, the delivery resolver, or the
gate reporters. `test-guards.sh` was run as supplementary regression only; no row in this
report rests on it.

## Failures

None.

## Result

All three criteria were evaluated, and all three passed. Criterion 1 rests on a
Tester-written check plus inspection: the handoff table has 5 rows naming artifact,
writer, and reader for each of the five handoffs, with 0 writer/reader mismatches against
the agent and skill definitions. Criterion 2 rests on a Tester-written check: a balanced
`flowchart LR` with quoted labels, no dotted node ids, and the five artifacts inside the
change-directory subgraph. Criterion 3 rests on an executable check of the return path in
a throwaway copy (verdict moved byte-identical, one remediation task per finding, next
gate `implementation`) plus cross-checks of the gate names/order and the four archive
conditions. No criterion was scored without observed evidence.

## Handoff

All criteria pass. Gate 6 now passes. The change is eligible for the completion gate; the
Product Manager evaluates the archive gate (`/opsx:archive`). Acceptance alone does not
archive the change.
