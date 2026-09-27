# README-EPIC-6 — Independent Review

Implementation record for **EPIC-6** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-6 — Independent Review |
| Stories | US-6.1 |
| Status | Complete — all acceptance criteria verified |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-6-1-reviewer-agent/` |
| SPECS.md status | DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-24 |
| Claude Code | 2.1.128 |
| Spec source | `SPECS.md` lines 772–816; `PRD.md` FR-008, BR-002 |

---

## 1. Objective

Verify implementation against the approved specification without allowing the reviewer
to silently repair the code it evaluates.

## 2. The problem: gate 5 was checking the wrong thing

EPIC-6's third scenario is the whole point of the epic:

> Given the Reviewer identifies a product-code defect
> When remediation is required
> Then the Reviewer MUST NOT silently modify application source code
> And MUST return the finding to the Implementer

Gate 5, as EPIC-3 left it, read one line of `review.md`:

```bash
if grep -iE '^[[:space:]]*(#+[[:space:]]*)?(blocking|blocking findings)[[:space:]]*:[[:space:]]*none[[:space:]]*$' ...
```

That is a string match on a self-reported field. It answers *"does the file say it
passed?"* — not *"did a real review happen?"* A reviewer could write:

```markdown
# Review

Blocking: None
```

…and gate 5 would pass, with no findings, no coverage, no evidence, and no indication
that any acceptance criterion had been looked at.

So EPIC-6 adds a **contract** for `review.md` and wires gate 5 to it, the same way
EPIC-4 fixed gate 3. The gate now means "an independent review was performed and it
found no blockers", not "a file contains a reassuring string."

Two mechanisms, matching the epic's two prohibitions:

| Requirement | Mechanism |
|---|---|
| Must not repair product code | `PreToolUse` hook on the reviewer — product-code writes blocked |
| Must produce actionable findings | `validate-review.sh` contract + gate 5 delegation |

## 3. Scope

### In scope

- **US-6.1** — `reviewer` agent (with mirror write-scope hook), `review-feature` skill,
  the `review.md` schema, `/opsx:verify` integration, and the review validator.

### Out of scope

- The Tester (EPIC-7) authors `test-report.md`. This epic only guarantees the Reviewer
  cannot.
- Rules files and the remaining hook guards (EPIC-8).
- `status.md` (EPIC-9).

## 4. Plan

```text
1. Recon: gate 5 detection, reviewer scope, /opsx:verify behaviour
2. Build + test the review validator              (the mechanism)
3. Build fixtures, incl. a self-contradicting review
4. Author the reviewer agent with the mirror hook
5. Author the review-feature skill (runs /opsx:verify)
6. Wire gate 5 to the validator
7. Regression across the whole harness
8. Verify every acceptance criterion
9. Document the result in this file
```

## 5. Step-by-step execution

### 5.1 Recon — what gate 5 actually checked

```bash
sed -n '/^# Review: blocking findings/,/^fi$/p' scripts/workflow-status.sh
```

```bash
REVIEW_STATE="absent"
if has review.md; then
  if grep -qiE '^[[:space:]]*(#+[[:space:]]*)?(blocking|blocking findings)[[:space:]]*:' ...; then
    if grep -iE '...:[[:space:]]*none[[:space:]]*$' ...; then
      REVIEW_STATE="pass"
```

A single self-reported line decided the gate. Nothing checked that the review
evaluated anything, cited anything, or explained anything.

### 5.2 Recon — what `/opsx:verify` actually does

This mattered, because the epic's task list says "Integrate `/opsx:verify` into review
flow" and the integration shape depends on its behaviour.

```bash
ls .claude/commands/opsx/
```

```text
apply.md   archive.md explore.md propose.md sync.md    update.md  verify.md
```

Reading `verify.md` revealed two facts that shaped the design:

1. **It is advisory.** Its own text: *"Treat apply `state` and `instruction` as
   context, not a verification verdict."*
2. **It writes no file.** It produces a report in the conversation, and its outcome
   vocabulary includes `VERIFIED`, `Not verified (<reason>)`, and `Not applicable`.

Fact 2 is the important one. If the Reviewer runs `/opsx:verify` and does not record
the outcome, the result is lost when the session ends — and `NFR-003` resumability
depends on repository artifacts. So the skill requires an `OpenSpec verify:` line in
`review.md`, and the validator warns when it is absent.

Fact 1 is why the review is not merely a wrapper around verify: a clean verify is
necessary but not sufficient, and the Reviewer still judges the acceptance criteria.

### 5.3 Build the review validator

Created `scripts/validate-review.sh`. It checks the contract **and** the review's
internal consistency.

```bash
chmod +x scripts/validate-review.sh
bash -n scripts/validate-review.sh
```

```text
syntax OK
```

**Defect 1 — the field parser was not portable.** The first version used `sed` with
`\?`, which BSD `sed` does not support in a BRE:

```bash
sed "s/^[[:space:]]*\([-*][[:space:]]*\)\?$1[[:space:]]*:[[:space:]]*//"
```

Every field read came back with its own key still attached:

```text
PASS  names the change (Change: add-codebase-analyst)
FAIL  expected change 'add-codebase-analyst' but the review names 'Change: add-codebase-analyst'
FAIL  unrecognised verdict 'Verdict: pass'
WARN  cannot parse a count from 'Blocking: Blocking: None'
```

Three spurious failures from one non-portable escape. Replaced with `awk`, which
handles the optional bullet without regex-portability risk:

```bash
field() {
  awk -v key="$1" '
    {
      line = $0
      sub(/^[[:space:]]*/, "", line); sub(/^[-*][[:space:]]*/, "", line)
      lk = tolower(key) ":"
      if (index(tolower(line), lk) == 1) {
        sub(/^[^:]*:[[:space:]]*/, "", line); sub(/[[:space:]]*$/, "", line)
        print line; exit
      }
    }' "$REVIEW"
}
```

**Defect 2 — the repair detector missed the natural phrasing.** I seeded the invalid
fixture with the most human version of the violation:

```markdown
I fixed the two things I noticed while reading through, so no need for another pass.
```

The detector was anchored to line start with a fixed keyword list:

```bash
grep -qiE '^[[:space:]]*([-*][[:space:]]*)?(Fixed|Repaired|Applied the fix|I changed)[[:space:]]'
```

The line begins with `I fixed`, not `Fixed`, so **it did not match**:

```bash
grep -iE '<pattern>' scripts/fixtures/reviews/invalid/review.md
```

```text
NO MATCH — detection is too narrow
```

This is the defect that matters most, because it is silent: the validator would have
reported a clean "no repair claim" on a review that openly admits to repairing the
code. Widened to match anywhere in the text with verb variants:

```bash
grep -qiE '(^|[^a-z])(I|we)[[:space:]]+(have[[:space:]]+)?(fixed|repaired|corrected|patched|updated|changed)[[:space:]]'
```

After the fix, with no false positive on the valid fixture:

```text
=== repair detection now fires? ===
  FAIL  review claims to have fixed the code it reviewed

=== no false positive on the valid review? ===
clean (no false positive)
```

### 5.4 The self-contradiction cases

The validator enforces verdict/blocking consistency, because a review that contradicts
itself is more dangerous than a terse one — the reassuring half is what a reader
remembers. Three cases were verified against purpose-built inputs:

```bash
T=$(mktemp -d)
# Case A: Verdict: pass + Blocking: 2 findings
./scripts/validate-review.sh --review "$T/a.md" --quiet
```

```text
=== CASE A: verdict=pass but blocking findings (expect FAIL) ===
  FAIL  verdict says pass but 2 blocking finding(s) are declared
  RESULT: FAIL — 1 required check(s) failed.

=== CASE B: verdict=changes-requested but Blocking: None (expect FAIL) ===
  FAIL  verdict requests changes but declares no blocking findings
  RESULT: FAIL — 1 required check(s) failed.

=== CASE C: blocking declared but no findings documented (expect FAIL) ===
  FAIL  declares 3 blocking finding(s) but documents none
  RESULT: FAIL — 1 required check(s) failed.
```

All three caught. Case A is the one that would otherwise sail through gate 5: it says
`pass` in the line the gate reads.

### 5.5 Fixtures

Three fixtures, including one that is **valid but blocking** — a distinction worth
making explicit, because it is easy to conflate "the review passed" with "the review
is well formed":

```bash
./scripts/validate-review.sh --review scripts/fixtures/reviews/valid/review.md --change add-codebase-analyst --story US-2.1
```

```text
Review — scripts/fixtures/reviews/valid/review.md
  PASS  names the change (add-codebase-analyst)
  PASS  change matches the expected 'add-codebase-analyst'
  PASS  story matches the expected 'US-2.1'
  PASS  verdict declares a pass
  PASS  declares no blocking findings
  PASS  documents acceptance criteria coverage
  PASS  coverage is complete (3/3)
  PASS  records the /opsx:verify outcome

Summary
  failures: 0
  warnings: 0

  RESULT: PASS — all required checks passed, 0 warning(s).
```

The blocking fixture is well formed and exits `0`:

```bash
./scripts/validate-review.sh --review scripts/fixtures/reviews/blocking/review.md --quiet
```

```text
  WARN  coverage is partial: 2 of 3
  WARN  no record of /opsx:verify
exit=0
```

The invalid fixture, with the repair claim now detected:

```bash
./scripts/validate-review.sh --review scripts/fixtures/reviews/invalid/review.md
```

```text
  FAIL  no 'Verdict:' line
  fix: add 'Verdict: pass' or 'Verdict: changes-requested' — gate 5 reads this
  FAIL  no 'Blocking:' line
  fix: add 'Blocking: None' or 'Blocking: <n> finding(s)' — gate 5 reads this
  FAIL  no acceptance criteria coverage section
  FAIL  review claims to have fixed the code it reviewed

Summary
  failures: 4
  warnings: 3
```

Exit codes confirmed without pipe interference:

```text
valid review:    exit=0
blocking review: exit=0   (well formed, requests changes)
invalid review:  exit=1
missing file:    exit=1
```

### 5.6 Author the Reviewer agent

Created `.claude/agents/reviewer.md` with the mirror of EPIC-5's hook:

```yaml
hooks:
  PreToolUse:
    - matcher: "Write|Edit|MultiEdit"
      hooks:
        - type: command
          command: "sh -c 'd=\"${CLAUDE_PROJECT_DIR:-$PWD}\"; test -x \"$d/scripts/check-write-scope.sh\" && exec \"$d/scripts/check-write-scope.sh\" --role reviewer --hook --quiet; exit 0'"
          statusMessage: "Checking Reviewer write scope"
```

EPIC-5 built the guard to cover all five roles precisely so this epic could reuse it.
Verified verbatim, with `CLAUDE_PROJECT_DIR` unset:

```bash
CMD=$(node -e "…parse frontmatter.hooks.PreToolUse[0].hooks[0].command…")
printf '%s' '{"tool_input":{"file_path":"src/app.ts"}}'                          | env -u CLAUDE_PROJECT_DIR sh -c "$CMD"
printf '%s' '{"tool_input":{"file_path":"openspec/changes/x/review.md"}}'        | env -u CLAUDE_PROJECT_DIR sh -c "$CMD"
printf '%s' '{"tool_input":{"file_path":"openspec/changes/x/test-report.md"}}'   | env -u CLAUDE_PROJECT_DIR sh -c "$CMD"
```

```text
-- product code (expect 2 BLOCK) --
BLOCKED  [reviewer] src/app.ts
  the Reviewer must not modify product code it evaluates — return the finding instead (US-6.1)
  Hand the artifact to the role that owns it; do not write it yourself.
exit=2

-- review.md (expect 0 ALLOW) --
exit=0

-- test-report.md (expect 2 BLOCK) --
BLOCKED  [reviewer] openspec/changes/x/test-report.md
  test-report.md belongs to the Tester, not the Reviewer
exit=2
```

The agent prompt also confronts the temptation directly, because the rule is
counter-intuitive: when a one-line fix is obvious, fixing it *feels* efficient and
silently destroys the independence the review exists to provide.

> **Finding a defect is a success, not a failure.** … Do not manufacture findings to
> appear diligent, and do not soften a real one to appear agreeable.

### 5.7 Author the review-feature skill

Created `.claude/skills/review-feature/SKILL.md`. Two steps are specific to this epic:

**Step 3 runs `/opsx:verify`** and requires its outcome be recorded:

> Record its outcome. It is **advisory** and writes no file — you must carry its result
> into `review.md` yourself.

**Step 6 warns about the consistency traps** the validator enforces:

```text
Verdict: pass              + Blocking: 2 findings    -> invalid
Verdict: changes-requested + Blocking: None          -> invalid
```

**Step 8 routes on the verdict**, keeping acceptance testing from starting early:

```text
Review outcome: CHANGES REQUESTED — <n> blocking finding(s)
Next: Implementer remediates, then /review-feature <change-id> runs again.
Acceptance testing does not proceed on a change with blocking findings.
```

### 5.8 Wire gate 5 to the validator

Gate 5 now combines the two signals rather than substituting one for the other: the
`Blocking:` line says whether the review passed, and the validator says whether the
review is well formed.

```bash
D=openspec/changes/gate5test
./scripts/workflow-status.sh --quiet
```

| State | Gate detail |
|---|---|
| no `review.md` | `review.md missing` |
| `review.md` = `"Looks good, ship it."` | `review.md present but no explicit verdict` |
| well-formed blocking review | `review.md reports blocking findings` |
| well-formed passing review | `PASS  review.md present, no blocking findings` |

Plus the case that matters most — a review claiming `pass` while declaring blocking
findings:

```bash
./scripts/workflow-status.sh --quiet
```

```text
  ----  review           review.md reports blocking findings
        next owner: reviewer (/review-feature)
```

And the validator agrees, so the two never contradict each other:

```text
  FAIL  verdict says pass but 2 blocking finding(s) are declared
```

Gate 5's owner label is now `reviewer (/review-feature)`, consistent with gates 3 and 4.

### 5.9 Register and regress

```json
"Bash(bash scripts/validate-review.sh:*)",
"Bash(scripts/validate-review.sh:*)"
```

Added to `permissions.allow`. Full harness regression:

```bash
for s in scripts/*.sh; do bash -n "$s" || echo "SYNTAX FAIL $s"; done
./scripts/test-write-scope.sh
./scripts/validate-review.sh --review <valid|blocking|invalid> --quiet
./scripts/validate-implementation-plan.sh --plan <valid> --quiet
./scripts/validate-product-artifacts.sh --specs <valid…> --quiet
```

```text
=== FULL REGRESSION ===
all syntax OK
  passed: 36
  failed: 0
  RESULT: PASS — separation of duties holds across all roles.

valid review:    exit=0 (0)
blocking review: exit=0 (0, well formed)
invalid review:  exit=1 (1)
valid plan:      exit=0 (0)
valid artifacts: exit=0 (0)
```

All 20 agent and skill definitions parse as valid frontmatter:

```text
OK    agent  reviewer.md                reviewer  [hook]
OK    skill  review-feature             review-feature
… (20/20)
```

---

## 6. The review.md contract

| Check | Severity | Requirement |
|---|---|---|
| `Change:` | advisory | Names the change |
| `Story:` | advisory | Names the story |
| `Verdict:` | required | `pass` or `changes-requested` |
| `Blocking:` | required | `None` or `<n> finding(s)` |
| Findings documented | required when blocking | A section per finding |
| `Requirement:` | required with findings | The criterion violated |
| `Observed:` | required with findings | What the code does |
| `Expected:` | required with findings | What the spec requires |
| `Remediation:` | required with findings | The concrete change requested |
| Coverage section | required | With ≥1 criterion evaluated |
| `OpenSpec verify:` | advisory | The recorded `/opsx:verify` outcome |
| No repair claim | required | The Reviewer must not have fixed the code |

Consistency rules that are hard failures:

| Verdict | Blocking | Result |
|---|---|---|
| `pass` | `None` | valid |
| `changes-requested` | `<n>`, n ≥ 1 | valid |
| `pass` | `<n>`, n ≥ 1 | **FAIL** |
| `changes-requested` | `None` | **FAIL** |

---

## 7. Deliverables

### Created

| Path | Implements | Purpose |
|---|---|---|
| `.claude/agents/reviewer.md` | US-6.1 | Reviewer, with mirror write-scope hook |
| `.claude/skills/review-feature/SKILL.md` | US-6.1 | Review flow, includes `/opsx:verify` |
| `scripts/validate-review.sh` | US-6.1 | `review.md` contract + consistency validator |
| `scripts/fixtures/reviews/valid/review.md` | US-6.1 | Passing fixture |
| `scripts/fixtures/reviews/blocking/review.md` | US-6.1 | Well-formed blocking fixture |
| `scripts/fixtures/reviews/invalid/review.md` | US-6.1 | Failing fixture, incl. repair claim |
| `README-EPIC-6.md` | — | This document |

### Modified

| Path | Change |
|---|---|
| `scripts/workflow-status.sh` | Gate 5 delegates to the review validator; owner label → `reviewer (/review-feature)` |
| `.claude/settings.json` | Pre-approved the read-only review validator |
| `scripts/README.md` | Documented the review validator, contract, consistency rules, and fixtures |
| `.claude/agents/README.md` | Recorded `reviewer` as delivered; hook table now covers two roles |

---

## 8. Acceptance verification

### US-6.1 — Create Reviewer Agent

> **Scenario: Review implementation against specification**
> Then it MUST inspect the active OpenSpec proposal, specs, design when present, tasks,
> implementation plan, and implementation diff
> And it MUST evaluate every relevant acceptance criterion

| Criterion | Evidence | Result |
|---|---|---|
| Inspects proposal, specs, design, tasks, plan, diff | Agent's required-inputs table lists all six; skill Step 2 reads each | PASS |
| Evaluates every relevant acceptance criterion | `## Acceptance Criteria Evaluated` required; coverage line checked; "0 of N" fails | PASS |

> **Scenario: Produce actionable review findings**
> Then review.md MUST identify the affected requirement
> And MUST describe observed behavior
> And MUST describe expected behavior
> And MUST request concrete remediation
> And control MUST return to the Implementer

| Criterion | Evidence | Result |
|---|---|---|
| Identifies the affected requirement | `Requirement:` required with findings; fixture-proven | PASS |
| Describes observed behavior | `Observed:` required; fixture-proven | PASS |
| Describes expected behavior | `Expected:` required; fixture-proven | PASS |
| Requests concrete remediation | `Remediation:` required; fixture-proven | PASS |
| Control returns to the Implementer | Skill Step 8 routes `changes-requested` back, and blocks acceptance testing | PASS |

> **Scenario: Reviewer does not repair product code**
> Then the Reviewer MUST NOT silently modify application source code
> And MUST return the finding to the Implementer

| Criterion | Evidence | Result |
|---|---|---|
| Must not modify source code | **Mechanically blocked**: `src/app.ts` → `BLOCKED`, exit 2, verified verbatim through the frontmatter hook | PASS |
| Returns the finding instead | Agent rule; validator fails a review that claims to have fixed the code | PASS |

Also enforced beyond the letter of the scenario:

| Rule | Mechanism | Verified |
|---|---|---|
| Must not write `test-report.md` | Blocked, exit 2 | PASS |
| Cannot pass while declaring blockers | Validator consistency rule; caught at gate 5 | PASS |
| Cannot request changes without naming a blocker | Validator consistency rule | PASS |

### Scripted check

```text
PASS  agent defined
PASS  mirror hook: reviewer scope
PASS  no-repair rule
PASS  returns findings
PASS  inspects proposal/plan/diff
PASS  evaluates acceptance criteria
PASS  concrete remediation
PASS  /opsx:verify integrated
PASS  review.md schema defined
PASS  review-feature skill
PASS  skill runs /opsx:verify
PASS  validator executable
PASS  gate 5 wired to validator
PASS  fixture: valid / blocking / invalid
```

### Frontmatter

```text
OK    .claude/agents/reviewer.md             name=reviewer  [hook]
OK    .claude/skills/review-feature/SKILL.md name=review-feature
```

---

## 9. Task checklist

### US-6.1 — Create Reviewer Agent
- [x] Create `.claude/agents/reviewer.md`.
- [x] Create `.claude/skills/review-feature/SKILL.md`.
- [x] Define `review.md` schema.
- [x] Integrate `/opsx:verify` into review flow.

---

## 10. Deviations and decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Wired gate 5 to a review contract | It previously matched one self-reported line, so `Blocking: None` alone passed the gate |
| 2 | Gate 5 combines the `Blocking:` line with the validator, rather than replacing it | They answer different questions: did the review pass, and is the review well formed |
| 3 | Recorded `/opsx:verify` in `review.md` | Verify is advisory and writes no file; without recording it, its result is lost and `NFR-003` resumability breaks |
| 4 | Repair detection matches anywhere, not line-start | The natural phrasing `"I fixed the two things"` slipped through the anchored pattern — a silent miss |
| 5 | `field()` uses `awk`, not `sed` | BSD `sed` has no `\?` in a BRE; the portable version is also simpler |
| 6 | Added a `blocking` fixture distinct from `invalid` | "The review passed" and "the review is well formed" are different, and both exit `0` |
| 7 | The agent names the temptation explicitly | The rule is counter-intuitive; a one-line fix feels efficient and destroys review independence |
| 8 | Unverified criteria may never be scored PASS | Adopted from `/opsx:verify`'s own rule: a skipped check is not a passing check |

---

## 11. Notes for reuse

- **Two different questions again.** Gate 5's `Blocking:` line = did the reviewer find
  blockers? `validate-review.sh` = is the review a real review? Both must hold.
- **A blocking review is a valid review.** `--quiet` on the blocking fixture exits `0`.
  Use `workflow-status.sh` for the gate verdict, not the validator's exit code alone.
- **Record `/opsx:verify`.** It writes nothing; if the outcome is not in `review.md`,
  the next session cannot see it.
- **`BSD sed` lacks `\?`.** Prefer `awk` for optional-group parsing in these scripts.
- **Detection must cover natural phrasing.** Line-anchored keyword lists miss how
  people actually write. Test the detector against a realistic sentence, not the
  keyword itself.
- **The guard already covers all roles.** `check-write-scope.sh --role reviewer` was
  built in EPIC-5 for exactly this reuse; EPIC-7 needs only `--role tester`.

---

## 12. Follow-ups

1. **Resolve the `SPECS.md` US-11.1 defect** (carried from EPIC-2). Still the sole
   reason gate 7 fails on this repository.
2. **EPIC-7 (Tester)** mirrors this pattern: a tester agent with
   `--role tester`, a `test-report.md` validator, and gate 6 delegation. The
   `test-report.md` shape is already parsed by gate 6's FAIL detection.
3. **EPIC-8** generalizes the guards and adds the archive gate;
   `workflow-status.sh --json` is the natural input.
4. **EPIC-9** adds `status.md`; the review's `OpenSpec verify:` line is useful evidence
   for resumption.
5. **Commit this work.** Suggested message:
   `feat(EPIC-6): reviewer agent, review.md contract, and gate-5 enforcement`.
