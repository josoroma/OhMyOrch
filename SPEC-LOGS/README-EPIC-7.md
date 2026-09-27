# README-EPIC-7 — Independent Acceptance Testing

Implementation record for **EPIC-7** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-7 — Independent Acceptance Testing |
| Stories | US-7.1 |
| Status | Complete — all acceptance criteria verified |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-7-1-tester-agent/` |
| SPECS.md status | DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-24 |
| Claude Code | 2.1.128 |
| Spec source | `SPECS.md` lines 833–878; `PRD.md` FR-009, BR-002 |

---

## 1. Objective

Prove that the delivered behavior satisfies the original acceptance criteria, based on
observable evidence rather than implementation claims.

## 2. The defect this epic closed: gate 6 was fail-open

Gates 3 and 5 were fixed in EPIC-4 and EPIC-6 by adding contracts. Gate 6 had a
different and worse flaw — its check was **negative**:

```bash
if grep -qE '\|[[:space:]]*FAIL[[:space:]]*\|' "$CDIR/test-report.md" ...; then
  TEST_STATE="fail"
else
  TEST_STATE="pass"
fi
```

It asked *"is there a FAIL row?"*. A file with no FAIL row passed. That includes an
**empty file**, a file containing only `All criteria PASS.`, and a file saying
`Nothing was tested.` All three passed gate 6 before this epic:

```text
-- 1. bare file naming one PASS (no criteria, no evidence) --
  PASS  testing          test-report.md present, no FAIL rows
-- 2. ZERO criteria listed --
  PASS  testing          test-report.md present, no FAIL rows
-- 3. report is empty --
  PASS  testing          test-report.md present, no FAIL rows
```

A change could reach the archive gate having never tested anything, and every gate
would be green.

The fix is a **positive** requirement: the report must demonstrate that criteria were
evaluated. Absence of failure is not evidence of testing.

Same structure as EPIC-4 and EPIC-6 — a contract plus gate delegation — plus the
tester's write-scope hook, built generically in EPIC-5 and now pointed at its third
role.

## 3. Scope

### In scope

- **US-7.1** — `tester` agent (with write-scope hook), `test-feature` skill, the
  `test-report.md` schema, and the test-report validator.

### Out of scope

- The completion/archive gate and `SPECS.md` story state (EPIC-10). Acceptance makes a
  change *eligible* for archive; it does not archive it.
- Rules files and remaining hook guards (EPIC-8).
- `status.md` (EPIC-9).

## 4. Plan

```text
1. Recon: gate 6 detection, tester scope in the guard
2. Probe gate 6 for the weakness
3. Build + test the test-report validator        (the mechanism)
4. Build fixtures, incl. the previously-passing empty reports
5. Author the tester agent with the mirror hook
6. Author the test-feature skill
7. Wire gate 6 to the validator
8. Add a frontmatter checker for the 22 definitions
9. Regression across the whole harness
10. Verify every acceptance criterion
11. Document the result in this file
```

## 5. Step-by-step execution

### 5.1 Recon — gate 6 and the tester role

```bash
sed -n '/^# Testing: any FAIL row/,/^fi$/p' scripts/workflow-status.sh
sed -n '/^  tester)/,/^    ;;/p' scripts/check-write-scope.sh
```

Gate 6's code is quoted above. The guard already knew the `tester` role:

```text
the Tester must not repair failing behavior — return the finding to the Implementer (US-7.1)
```

EPIC-5 built the guard across all five roles specifically so EPIC-6 and EPIC-7 would
need no new enforcement code — only a hook pointing at `--role tester`. That held.

### 5.2 Probe gate 6 before changing it

Rather than assume the weakness, I proved it. Three content-free reports:

```bash
printf 'All criteria PASS.\n' > "$D/test-report.md"          # three words
printf '# Test Report\n\nNothing was tested.\n' > ...        # explicit non-testing
printf '' > "$D/test-report.md"                              # empty file
```

All three:

```text
  PASS  testing          test-report.md present, no FAIL rows
```

Confirmed. The gate could not distinguish an empty file from a real acceptance report.

### 5.3 Build the validator

Created `scripts/validate-test-report.sh`.

```bash
chmod +x scripts/validate-test-report.sh
bash -n scripts/validate-test-report.sh
```

```text
syntax OK
```

The core check counts rows carrying a PASS or FAIL result — the positive evidence
requirement gate 6 lacked:

```bash
PASS_ROWS=$(grep -cE '\|[[:space:]]*(PASS|Pass|pass)[[:space:]]*\|' "$REPORT" ...)
FAIL_ROWS=$(grep -cE '\|[[:space:]]*(FAIL|Fail|fail)[[:space:]]*\|' "$REPORT" ...)
EVALUATED_COUNT=$((PASS_ROWS + FAIL_ROWS + RESULT_LINES_P + RESULT_LINES_F))
```

Two result shapes are accepted (a table cell and a `Result: PASS` line), because the
schema should permit reasonable formatting without permitting no content. I reused the
`awk`-based `field()` helper from EPIC-6 rather than reintroducing the BSD `sed` `\?`
bug fixed there.

### 5.4 Prove the previously-passing reports now fail

The regression that motivated the epic, run against the new validator:

```bash
./scripts/validate-test-report.sh --report "$T/empty.md" --quiet
./scripts/validate-test-report.sh --report "$T/bare.md" --quiet
./scripts/validate-test-report.sh --report "$T/nothing.md" --quiet
```

```text
-- empty.md --
  FAIL  test report is empty
  RESULT: FAIL — report empty.
exit=1

-- bare.md --
  FAIL  lists no evaluated acceptance criterion
  FAIL  no '## Acceptance Criteria Evaluated' section
  FAIL  identifies no command, test, or evidence
exit=1

-- nothing.md --
  FAIL  lists no evaluated acceptance criterion
  FAIL  no '## Acceptance Criteria Evaluated' section
  FAIL  identifies no command, test, or evidence
exit=1
```

All three now fail. Gate 6 no longer accepts them:

```text
=== 2. EMPTY report (previously passed!) ===
  ----  testing          test-report.md fails the US-7.1 contract (1 failure(s))

=== 3. content-free report (previously passed!) ===
  ----  testing          test-report.md fails the US-7.1 contract (4 failure(s))
```

### 5.5 Fixtures

Three fixtures, following the EPIC-6 pattern — **valid**, **failing** (well formed but
reports a failure), and **invalid**.

```bash
./scripts/validate-test-report.sh --report scripts/fixtures/test-reports/valid/test-report.md --change add-codebase-analyst --story US-2.1
```

```text
Report — scripts/fixtures/test-reports/valid/test-report.md
  PASS  names the change (add-codebase-analyst)
  PASS  change matches the expected 'add-codebase-analyst'
  PASS  story matches the expected 'US-2.1'

Acceptance evidence
  PASS  lists 3 evaluated criterion/criteria (3 PASS, 0 FAIL)
  PASS  has an acceptance criteria section
  PASS  identifies a command, test, or evidence for its results
  PASS  verdict declares acceptance
  PASS  coverage is complete (3/3)
  PASS  no claim of having repaired the tested behavior

Summary
  failures: 0
  warnings: 0

  RESULT: PASS — all required checks passed, 0 warning(s).
```

The **failing** fixture is well formed — it reports a genuine failure with observed vs
expected — and correctly exits `0`, because the validator judges form, not outcome:

```bash
./scripts/validate-test-report.sh --report scripts/fixtures/test-reports/failing/test-report.md --quiet
```

```text
exit=0
```

The **invalid** fixture is caught on five counts, including the repair claim:

```bash
./scripts/validate-test-report.sh --report scripts/fixtures/test-reports/invalid/test-report.md
```

```text
  FAIL  lists no evaluated acceptance criterion
  FAIL  no '## Acceptance Criteria Evaluated' section
  FAIL  identifies no command, test, or evidence
  WARN  report uses vague assurance language
  FAIL  no 'Verdict:' line
  FAIL  report claims to have fixed the behavior it tested

Summary
  failures: 5
```

That fixture reads *"I fixed the one thing that was broken while I was testing"* —
the natural phrasing of the violation, matched because EPIC-6 established that
detectors must not be anchored to a keyword at line start.

### 5.6 Consistency rules

Four verdict/FAIL combinations were tested against purpose-built inputs:

```text
-- verdict=pass but a criterion FAILs (expect FAIL) --
  FAIL  verdict says pass but 1 criterion/criteria are recorded FAIL
  FAIL  records FAIL but has no failures section

-- verdict=fail but nothing FAILs (expect FAIL) --
  FAIL  verdict says fail but no criterion is recorded FAIL

-- failing report with no ## Failures section (expect FAIL) --
  FAIL  records FAIL but has no failures section
  WARN  does not state what happens next

-- coverage 0/2 with a row present (expect FAIL) --
  FAIL  coverage says 0 of 2 criteria evaluated
```

The `0 of N` case matters: it is the explicit statement that nothing was tested, and it
must fail even if a row was added to look complete.

### 5.7 Author the Tester agent

Created `.claude/agents/tester.md` with the third write-scope hook:

```yaml
command: "sh -c 'd=\"${CLAUDE_PROJECT_DIR:-$PWD}\"; test -x \"$d/scripts/check-write-scope.sh\" && exec \"$d/scripts/check-write-scope.sh\" --role tester --hook --quiet; exit 0'"
```

Verified verbatim with `CLAUDE_PROJECT_DIR` unset:

```text
-- product code (expect 2 BLOCK) --
BLOCKED  [tester] src/app.ts
  the Tester must not repair failing behavior — return the finding to the Implementer (US-7.1)
exit=2

-- test-report.md (expect 0 ALLOW) --
exit=0

-- review.md (expect 2 BLOCK) --
BLOCKED  [tester] openspec/changes/x/review.md
  review.md belongs to the Reviewer, not the Tester
exit=2
```

The prompt includes an **evidence vs assurance** table, because US-7.1's "executable
checks **or explicit evidence**" is easy to satisfy in letter and violate in spirit:

| Not evidence | Why |
|---|---|
| "All criteria PASS." | Asserts a result without showing any work |
| "Everything looks fine." | A feeling, not an observation |
| "Should be fine." | A prediction, not a verification |
| "This is straightforward." | Difficulty is unrelated to correctness |

It also states clearly that inspection *is* legitimate when no executable check exists —
a documentation or prompt change may have no other valid method — and that an
unverifiable criterion must be recorded as unverified, never as PASS.

### 5.8 Author the test-feature skill

Created `.claude/skills/test-feature/SKILL.md`. The review precondition comes first,
because testing a change with blocking review findings wastes the run:

```text
Cannot test: gate 5 (review) is not passing.
Resolve the review findings first, then retest.
```

Step 3 tells the Tester to find the project's existing validation surface rather than
invent one, and Step 8 enforces US-7.1's third scenario in the routing:

```text
Next: Implementer remediates -> Reviewer re-reviews -> /test-feature runs again.
The change is NOT accepted.
```

Review is not skipped because a fix is small. That is the point of the rule.

### 5.9 Wire gate 6, preserving both signals

Gate 6 now combines the `FAIL` scan with the validator — the first says whether the
change passed, the second says whether the report is real:

```bash
elif [ "$TEST_CONTRACT" = "fail" ]; then
  GATE_STATE[5]="fail"
  GATE_DETAIL[5]="test-report.md fails the US-7.1 contract ($TEST_DETAIL failure(s))"
```

All five gate-6 states verified:

| State | Gate detail |
|---|---|
| no `test-report.md` | `test-report.md missing` |
| empty file | `fails the US-7.1 contract (1 failure(s))` |
| `All criteria PASS.` | `fails the US-7.1 contract (4 failure(s))` |
| failing report | `test-report.md reports FAIL` |
| valid report | `PASS  test-report.md present, no FAIL rows` |

Gate 6's owner label is now `tester (/test-feature)`.

### 5.10 Add a frontmatter checker

With seven agents and fifteen skills now defined, a malformed definition is a real
risk — and Claude Code **skips one silently** rather than erroring. Created
`scripts/check-frontmatter.js`:

```bash
node scripts/check-frontmatter.js
```

```text
OK    agent  codebase-analyst.md      codebase-analyst
OK    agent  implementer.md           implementer  [hook]
OK    agent  planner.md               planner
OK    agent  product-manager.md       product-manager
OK    agent  product-specifier.md     product-specifier
OK    agent  reviewer.md              reviewer  [hook]
OK    agent  spec-ingestor.md         spec-ingestor
OK    agent  tester.md                tester  [hook]
OK    skill  analyze-codebase         analyze-codebase
… (22 definitions)

RESULT: PASS — all definitions valid.
```

This is the only Node-dependent script in the harness. It is a development check on the
harness itself, not a runtime dependency of the workflow — the workflow scripts remain
pure `bash` for `NFR-001`.

### 5.11 End-to-end: six gates in sequence

With a plan, review, and test report all satisfying their contracts:

```bash
./scripts/workflow-status.sh --quiet
```

```text
  PASS  selection        change 'final' exists
  PASS  planning         proposal.md, specs/, tasks.md present
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
  PASS  implementation   1/1 tasks complete
  PASS  review           review.md present, no blocking findings
  PASS  testing          test-report.md present, no FAIL rows
  ----  acceptance       SPECS.md fails the readiness/context contract
        next owner: product-manager

  First incomplete gate: acceptance
```

Six consecutive gates pass on contract-validated artifacts. The remaining failure is
gate 7, which correctly reports the carried-over `SPECS.md` `US-11.1` defect — a
repository-level problem, not a change-level one.

### 5.12 Full regression

```text
all script syntax OK
write-scope matrix: 36 passed, 0 failed

test-report valid:    exit=0 (0)
test-report failing:  exit=0 (0, well formed)
test-report invalid:  exit=1 (1)
review valid:         exit=0 (0)
review invalid:       exit=1 (1)
plan valid:           exit=0 (0)
artifacts valid:      exit=0 (0)
artifacts invalid:    exit=1 (1)
frontmatter:          exit=0 (0)
```

Every validator's pass, fail, and error path behaves as documented, and the new gate-6
delegation did not regress gates 3 or 5.

---

## 6. The test-report contract

| Check | Severity | Requirement |
|---|---|---|
| `Change:` | advisory | Names the change |
| `Story:` | advisory | Names the story |
| **Evaluated criteria** | **required** | ≥ 1 row with a PASS or FAIL result |
| `## Acceptance Criteria Evaluated` | required | The section must exist |
| Evidence | required | A command, test, or explicit inspection |
| `Verdict:` | required | `pass` or `fail` |
| `## Failures` | required when any FAIL | Observed vs expected per failure |
| Routing back | advisory | States that a code change must be reviewed again |
| Coverage count | advisory | Declared count matches rows listed |
| No repair claim | required | The Tester must not have fixed the behavior |

Consistency rules that are hard failures:

| Verdict | FAIL rows | Result |
|---|---|---|
| `pass` | 0 | valid |
| `fail` | ≥ 1 | valid |
| `pass` | ≥ 1 | **FAIL** |
| `fail` | 0 | **FAIL** |

---

## 7. Deliverables

### Created

| Path | Implements | Purpose |
|---|---|---|
| `.claude/agents/tester.md` | US-7.1 | Tester, with write-scope hook |
| `.claude/skills/test-feature/SKILL.md` | US-7.1 | Acceptance flow, validates, routes on failure |
| `scripts/validate-test-report.sh` | US-7.1 | `test-report.md` contract + consistency validator |
| `scripts/check-frontmatter.js` | — | Validates all 22 agent/skill definitions (dev-time only) |
| `scripts/fixtures/test-reports/valid/test-report.md` | US-7.1 | Passing fixture |
| `scripts/fixtures/test-reports/failing/test-report.md` | US-7.1 | Well-formed failing fixture |
| `scripts/fixtures/test-reports/invalid/test-report.md` | US-7.1 | Failing fixture, incl. repair claim |
| `README-EPIC-7.md` | — | This document |

### Modified

| Path | Change |
|---|---|
| `scripts/workflow-status.sh` | Gate 6 delegates to the test-report validator; owner label → `tester (/test-feature)` |
| `.claude/settings.json` | Pre-approved the read-only test-report validator |
| `scripts/README.md` | Documented the test-report validator, the fail-open defect, `check-frontmatter.js` |
| `.claude/agents/README.md` | Recorded `tester` as delivered; hook table now covers three roles |

---

## 8. Acceptance verification

### US-7.1 — Create Tester Agent

> **Scenario: Map acceptance criteria to executable evidence**
> Given review has passed
> When the Tester starts validation
> Then every acceptance scenario MUST be mapped to one or more executable checks or explicit evidence

| Criterion | Evidence | Result |
|---|---|---|
| Requires review to have passed | Skill Step 1 stops when gate 5 is not passing | PASS |
| Every scenario mapped to a check or evidence | Validator requires ≥ 1 evaluated criterion and an evidence signal; "0 of N" fails | PASS |
| Inspection accepted as evidence | Validator accepts stated inspection; agent explains when it is the correct method | PASS |

> **Scenario: Produce test report**
> Then test-report.md MUST list every evaluated acceptance criterion
> And MUST record PASS or FAIL
> And MUST identify the command, test, or evidence used

| Criterion | Evidence | Result |
|---|---|---|
| Lists every evaluated criterion | Required: ≥ 1 result row plus the section heading; fixture-proven | PASS |
| Records PASS or FAIL | Both shapes counted; consistency rules applied | PASS |
| Identifies the command, test, or evidence | Required evidence signal; vague-assurance warnings; fixture-proven | PASS |

> **Scenario: Failed acceptance returns to implementation**
> Then the change MUST NOT be accepted
> And control MUST return to the Implementer
> And subsequent code changes MUST be reviewed before failed acceptance criteria are retested

| Criterion | Evidence | Result |
|---|---|---|
| Change must not be accepted | Validator fails a report declaring FAIL without a failures section; gate 6 fails on any FAIL row | PASS |
| Control returns to the Implementer | Skill Step 8 routes failure back and states the change is not accepted | PASS |
| Reviewed before retest | Agent quotes the rule; skill Step 8 sequences Implementer → Reviewer → Tester | PASS |

Also enforced beyond the letter of the scenario:

| Rule | Mechanism | Verified |
|---|---|---|
| Tester must not repair failing behavior | Hook blocks product code, exit 2 | PASS |
| Tester must not write `review.md` | Hook blocks, exit 2 | PASS |
| A passing verdict cannot contradict a FAIL | Validator consistency rule | PASS |
| An empty or content-free report cannot pass | Validator; the gate-6 regression | PASS |

### Scripted check

```text
PASS  agent defined
PASS  mirror hook: tester scope
PASS  no-repair rule
PASS  criteria-to-check mapping
PASS  failed -> not accepted
PASS  re-review before retest
PASS  test-report schema defined

PASS  skill defined / validates / review precondition / re-review routing

PASS  validator executable
PASS  gate 6 wired
PASS  fixture valid / failing / invalid
PASS  validator pre-approved
```

### Frontmatter

```text
OK    agent  tester.md       tester  [hook]
OK    skill  test-feature    test-feature
RESULT: PASS — all definitions valid.  (22/22)
```

---

## 9. Task checklist

### US-7.1 — Create Tester Agent
- [x] Create `.claude/agents/tester.md`.
- [x] Create `.claude/skills/test-feature/SKILL.md`.
- [x] Define `test-report.md` schema.

---

## 10. Deviations and decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Replaced gate 6's negative check with a positive contract | Fail-open: an empty report has no FAIL row, so it passed |
| 2 | Gate 6 combines the FAIL scan with the validator | They answer different questions: did the change pass, and is the report real |
| 3 | Accept inspection as evidence | A documentation or prompt change may have no executable check; demanding one would force fabrication |
| 4 | Warn on vague assurance language | "Looks fine" is not evidence, but it is a phrasing problem best surfaced as a warning |
| 5 | Added a `failing` fixture distinct from `invalid` | "The report is well formed" and "the change passed" are different, and both exit `0` |
| 6 | Added `check-frontmatter.js` in this epic | With 22 definitions, a silently-skipped file is a real risk; the checker is cheap and catches it |
| 7 | The checker needs Node; workflow scripts do not | YAML parsing has no reasonable bash equivalent; it is a dev-time check, so `NFR-001` still holds for the workflow |
| 8 | Reused EPIC-6's `awk` `field()` helper | Avoids reintroducing the BSD `sed` `\?` portability bug already fixed once |

---

## 11. Notes for reuse

- **A negative check is fail-open.** "No FAIL row" passes on an empty file. Prefer
  positive requirements — evidence that something was evaluated.
- **A failing report is a valid report.** `validate-test-report.sh` on the failing
  fixture exits `0`. Use `workflow-status.sh` for the gate verdict.
- **Absence of failure is not evidence of testing.** This is the single sentence that
  justifies the whole validator.
- **Run `node scripts/check-frontmatter.js` after editing any definition.** A malformed
  file is skipped silently by Claude Code — no error, the agent simply never runs.
- **A code change after a failed test must be re-reviewed.** Not because the fix is
  risky, but because otherwise the retest is conducted by the author of the fix.
- **The write-scope guard now covers three roles.** `--role implementer|reviewer|tester`
  all have hooks; EPIC-8 generalizes the guard set.

---

## 12. Follow-ups

1. **Resolve the `SPECS.md` US-11.1 defect** (carried from EPIC-2). It is now the *only*
   thing standing between the harness and a fully green gate chain — six of seven gates
   pass end-to-end.
2. **EPIC-8** generalizes the guards, adds the rules files, and adds the archive gate.
   `workflow-status.sh --json` is the natural archive-gate input.
3. **EPIC-9** adds `status.md`; the test report's routing line is useful resumption
   evidence.
4. **EPIC-10** consumes `archiveEligible` from the gate reporter for the completion gate.
5. **EPIC-11** updates `README.md` with the operational handbook, including the eight
   scripts now in `scripts/`.
6. **Commit this work.** Suggested message:
   `feat(EPIC-7): tester agent, test-report contract, and fail-open gate-6 fix`.
