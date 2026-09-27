# Test Report — us-13-2-document-orchestrator-loop

Change: us-13-2-document-orchestrator-loop
Story: US-13.2
Verdict: pass
Coverage: 3/3 acceptance criteria evaluated

Independent acceptance record (2026-09-26, working tree). The Tester did not write this
change. The acceptance criteria were taken from `SPECS.md` `### US-13.2:` and the
change's `specs/harness-documentation/spec.md`, not from the implementer's claims. Every
result below comes from a check I wrote and ran, or from lines I inspected, and the
output shown is what I observed.

- **Method: mixed.** Criteria 1 and 2 are structural properties of `README.md`, judged
  by Tester-written Python checks that derive the expected values from the document
  itself and compare them to the generated content. Criterion 3 is a behavioral claim
  about a guard, judged by running the guard in a throwaway copy, plus inspection of the
  handoff prose.
- **The checks are mine, not the implementer's.** I did not run `scripts/test-guards.sh`
  as the basis for any row; I wrote independent parsers for the table of contents and the
  Mermaid blocks, and I ran `guard-planning-handoff.sh` myself. The implementer's suite
  was run only as supplementary regression (E-5).
- **Real repository:** I ran only read-only commands. `openspec/delivery/goal.md` was not
  modified; `scripts/delivery.sh resolve` and `next` are read-only reporters. The guard
  was exercised in a `mktemp -d` copy, which was removed with `rm -rf "$dir"`.

## Acceptance Criteria Evaluated

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | README opens with a table of contents | PASS | Tester-written Python check (E-1). Derived 27 numbered `^## N. ` headings from the body; parsed the `## Table of Contents` block into 31 entries, of which 27 are numbered. Every numbered heading has a TOC entry and every numbered TOC entry has a heading — 0 missing, 0 extra. For each entry I derived the anchor from its own heading text (lowercase, drop punctuation, spaces→hyphens) and compared it to the link target: **0 anchor mismatches over 27 numbered entries**. The TOC starts at line 7, before the first numbered heading at line 198. All 31 TOC anchors resolve to a heading (0 unresolved). |
| 2 | README explains the orchestrator loop | PASS | Tester-written Python check (E-2) plus inspection (E-3). §19 (`README.md:896`) carries a loop table (`README.md:929`–`941`) mapping every action→owner→skill, and a `flowchart TD` block (`README.md:908`–`937`). I cross-checked the 11 action rows against the `set_action` calls in `derive_next` (`scripts/delivery.sh:308`–`424`) and the delegation table in `.claude/skills/deliver/SKILL.md:74`–`82`: **0 owner mismatches**. The Mermaid block is balanced (0 `subgraph`, 0 `end`, 15 node definitions, no dotted node ids). |
| 3 | README explains the plan-to-implement handoff | PASS | Executable check (E-4) plus inspection (E-3). §19's handoff subsection (`README.md:958`–`1012`) states the Planner writes `implementation-plan.md` into the change directory, the Implementer reads it, and the mechanical gate. I verified the gate myself in a `mktemp -d` copy: with the plan present `guard-planning-handoff.sh --file src/app.py` exits `0`; with the plan removed it exits `2` ("BLOCKED … has no implementation plan"); a `.claude/` path exits `0` in both cases; `SPECS.md` exits `2` without the plan and `0` with it. A `flowchart LR` block (`README.md:965`–`991`) is present and balanced (3 `subgraph` / 3 `end`). |

## Evidence Commands

### E-0 — Preflight (real repository)

```bash
scripts/workflow-status.sh --change us-13-2-document-orchestrator-loop --quiet
```

```text
  PASS  selection        change 'us-13-2-document-orchestrator-loop' exists
  PASS  planning         proposal.md, specs/, tasks.md present
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
  PASS  implementation   8/8 tasks complete
  PASS  review           review.md present, no blocking findings
  ----  testing          test-report.md missing
        next owner: tester (/test-feature)
  PASS  acceptance       artifact contracts satisfied
  First incomplete gate: testing
```

Gate 5 (review) passes, so testing may proceed.

### E-1 — Table of contents (Tester-written check)

```bash
python3 - <<'PY'   # derives numbered headings, parses the TOC, compares anchors
PY
```

```text
numbered headings: 27
first numbered heading line: 198 Install OpenSpec
TOC start line: 7
TOC entries: 31
numbered TOC entries: 27
mismatches: 0
TOC before first numbered heading: True
unresolved TOC anchors: 0 []
```

### E-2 — Loop action→owner mapping (Tester-written check)

```bash
grep -n "set_action" scripts/delivery.sh
sed -n '74,82p' .claude/skills/deliver/SKILL.md
```

```text
308:    set_action complete - - product-manager ...
350:    set_action mark-done "$sid" "$change" product-manager ...
365:    set_action select "$sid" "$change" product-manager ...
385:      set_action propose "$sid" "$change" planner ...
388:      set_action plan "$sid" "$change" planner "/plan-feature $change" ...
390:      set_action implement "$sid" "$change" implementer "/opsx:apply $change" ...
393:        set_action reopen "$sid" "$change" product-manager ...
396:        set_action review "$sid" "$change" reviewer ...
404:        set_action test "$sid" "$change" tester "/test-feature $change" ...
415:        set_action archive "$sid" "$change" product-manager ...
322/342/360/374/407/419/424: set_action escalate ... "human-product-manager"
```

Every action in the README table (`select`, `propose`, `plan`, `implement`, `review`,
`test`, `reopen`, `archive`, `mark-done`, `escalate`, `complete`) matches a `set_action`
call, and every owner matches the delegation table in `.claude/skills/deliver/SKILL.md`.
0 mismatches.

### E-3 — Mermaid blocks (Tester-written check)

```bash
python3 - <<'PY'   # parses mermaid fences, counts subgraph/end, checks node ids
PY
```

```text
mermaid blocks: 2
  block lines 908-937: header='flowchart TD' subgraph=0 end=0 node-defs=15 dotted-ids=[]
  block lines 965-991: header='flowchart LR' subgraph=3 end=3 node-defs=13 dotted-ids=[]
```

Both blocks are balanced, node ids contain no dots, and labels are quoted.

### E-4 — The mechanical gate (executable check, throwaway copy)

```bash
dir=$(mktemp -d)
mkdir -p "$dir/scripts" "$dir/openspec/changes/test-change"
cp scripts/guard-planning-handoff.sh "$dir/scripts/"
printf '# plan\n' > "$dir/openspec/changes/test-change/implementation-plan.md"
( cd "$dir" && scripts/guard-planning-handoff.sh --file src/app.py; echo "exit=$?" )
rm "$dir/openspec/changes/test-change/implementation-plan.md"
( cd "$dir" && scripts/guard-planning-handoff.sh --file src/app.py; echo "exit=$?" )
( cd "$dir" && scripts/guard-planning-handoff.sh --file SPECS.md; echo "exit=$?" )
( cd "$dir" && scripts/guard-planning-handoff.sh --file .claude/agents/x.md; echo "exit=$?" )
printf '# plan\n' > "$dir/openspec/changes/test-change/implementation-plan.md"
( cd "$dir" && scripts/guard-planning-handoff.sh --file SPECS.md; echo "exit=$?" )
rm -rf "$dir"
```

```text
--- with plan present ---
ALLOW  plan-handoff present for test-change
exit=0
--- without plan ---
BLOCKED  src/app.py
  Change test-change has no implementation plan.
  Expected: openspec/changes/test-change/implementation-plan.md
  Run /plan-feature test-change first, then retry the write.
exit=2
--- SPECS.md without plan ---
BLOCKED  SPECS.md
exit=2
--- .claude path without plan ---
exit=0
--- SPECS.md with plan ---
ALLOW  plan-handoff present for test-change
exit=0
```

The guard blocks a product-code write with exit `2` while the plan is missing, allows
harness control surfaces, and allows `SPECS.md` once the plan exists. This confirms the
README's corrected sentence (the R1.1 fix): `SPECS.md` is **not** on the allow-list while
the plan is missing.

### E-5 — Regression (real repository)

```bash
scripts/validate-product-artifacts.sh
scripts/delivery.sh resolve EPIC-13
scripts/delivery.sh next
scripts/workflow-status.sh --change us-13-2-document-orchestrator-loop --quiet
scripts/test-guards.sh | tail -4
```

```text
validate-product-artifacts.sh
  PASS  Epic identifiers unique (13 found)
  PASS  User Story identifiers unique (26 found)
  PASS  every story declares a valid status
  PASS  every READY story has complete Given/When/Then acceptance criteria
  PASS  every READY story is source-traceable
  failures: 0   warnings: 0
  (closing line: "RESULT: PASS — all required checks passed, 0 warning(s).")   exit=0

delivery.sh resolve EPIC-13
   1  US-13.1  DONE          us-13-1-navigable-specs-structure
   2  US-13.2  IN PROGRESS   us-13-2-document-orchestrator-loop   exit=0

delivery.sh next
  Action:  test
  Story:   US-13.2
  Owner:   tester
  Command: /test-feature us-13-2-document-orchestrator-loop
  Reason:  gate testing: test-report.md missing   exit=0

workflow-status.sh --change us-13-2-document-orchestrator-loop --quiet
  PASS  selection / planning / plan-handoff / implementation (8/8) / review / acceptance
  ----  testing          test-report.md missing
  First incomplete gate: testing   exit=0

test-guards.sh (supplementary only)
  passed: 85
  failed: 0
  (closing line: "RESULT: PASS — all guard behaviours hold.")
```

The README changes did not disturb the artifact validator, the delivery resolver, or the
gate reporters. The completion gate's only failing condition is `acceptance`, which is
the report this run produces. `test-guards.sh` was run as supplementary regression only;
no row in this report rests on it.

## Failures

None.

## Result

All three criteria were evaluated, and all three passed. Criterion 1 rests on a
Tester-written check: 27/27 numbered headings listed with 0 anchor mismatches, TOC before
the first numbered heading. Criterion 2 rests on a Tester-written check plus inspection:
the loop table's 11 action rows match `derive_next` and the delegation table with 0
mismatches, and a balanced `flowchart TD` is present. Criterion 3 rests on an executable
check of the guard in a throwaway copy (exit `2` without the plan, `0` with it) plus
inspection of the handoff prose and a balanced `flowchart LR`. No criterion was scored
without observed evidence.

## Handoff

All criteria pass. Gate 6 now passes. The change is eligible for the completion gate; the
Product Manager evaluates the archive gate (`/opsx:archive`). Acceptance alone does not
archive the change.
