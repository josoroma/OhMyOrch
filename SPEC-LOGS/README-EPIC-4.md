# README-EPIC-4 — Planning

Implementation record for **EPIC-4** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-4 — Planning |
| Stories | US-4.1 |
| Status | Complete — all acceptance criteria verified |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-4-1-planner-agent/` |
| SPECS.md status | DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-24 |
| Claude Code | 2.1.128 |
| Spec source | `SPECS.md` lines 661–712; `PRD.md` FR-007 |

---

## 1. Objective

Separate technical exploration and implementation planning from code modification, so
implementation starts from an explicit, repository-aware handoff.

## 2. Two problems, two mechanisms

**Problem 1 — the Planner must not write code.** "The Planner MUST NOT modify
application source code" is a narrative rule. As in EPIC-2, it is enforced
structurally: the agent's `tools` list omits `Write` and `Edit`, so the action is
unavailable rather than merely discouraged.

**Problem 2 — gate 3 was vacuous.** This is the more interesting finding. EPIC-3 left
gate 3 asserting only that `implementation-plan.md` **exists**:

```bash
if has implementation-plan.md; then
  GATE_STATE[2]="pass"; GATE_DETAIL[2]="implementation-plan.md present"
```

A one-line file named `implementation-plan.md` satisfied the gate. Since gate 3 is what
blocks implementation, that meant the harness would let an Implementer start work with
no plan at all — the exact failure EPIC-4 exists to prevent.

So US-4.1's acceptance criteria were turned into an executable contract,
`validate-implementation-plan.sh`, and gate 3 now delegates to it:

```bash
elif [ "$PLAN_STATE" = "fail" ]; then
  GATE_STATE[2]="fail"
  GATE_DETAIL[2]="implementation-plan.md fails the US-4.1 contract ($PLAN_DETAIL failure(s))"
```

Gate 3 now means "a usable handoff exists", not "a file exists".

## 3. Scope

### In scope

- **US-4.1** — `planner` agent (read-only), `plan-feature` skill, the
  `implementation-plan.md` template, and the plan validator.

### Out of scope

- The Implementer (EPIC-5). This epic produces the handoff it consumes.
- Rules files and hook guards (EPIC-8).
- `status.md` (EPIC-9).

## 4. Plan

```text
1. Recon: locate gate 3 and the PRD requirements it must satisfy
2. Build + test the plan validator               (the mechanism)
3. Author the planner agent                     (read-only)
4. Author the plan-feature skill
5. Author the implementation-plan template
6. Upgrade gate 3 to use the validator
7. Fix defects found by testing
8. Verify every acceptance criterion
9. Document the result in this file
```

## 5. Step-by-step execution

### 5.1 Recon — find gate 3 and its contract

```bash
grep -n "plan-handoff\|implementation-plan" scripts/workflow-status.sh
```

```text
17:#   3 plan-handoff   implementation-plan.md exists              (EPIC-4)
189:GATE_NAMES=(selection planning plan-handoff implementation review testing acceptance)
207:if has implementation-plan.md; then
208:  GATE_STATE[2]="pass"; GATE_DETAIL[2]="implementation-plan.md present"
210:  GATE_STATE[2]="fail"; GATE_DETAIL[2]="implementation-plan.md missing"
```

```bash
grep -n "FR-007\|Planner" PRD.md
```

```text
68:- **Planner** — explores the codebase and produces implementation planning artifacts.
215:### FR-007 — Planner Handoff
217:The Planner SHALL produce an `implementation-plan.md` that maps tasks to requirements,
    likely files, dependencies, risks, and expected tests.
```

FR-007 names five things the plan must contain: task-to-requirement mapping, likely
files, dependencies, risks, and expected tests. Combined with US-4.1's two scenarios,
that defined the validator's contract.

The finding: gate 3 checked existence only. A file named `implementation-plan.md`
containing one line would satisfy it.

### 5.2 Build the plan validator

Created `scripts/validate-implementation-plan.sh` — bash only, read-only.

```bash
chmod +x scripts/validate-implementation-plan.sh
bash -n scripts/validate-implementation-plan.sh
```

```text
syntax: OK
```

### 5.3 Four defects found by testing

**Defect 1 — `grep -c` with `|| echo 0` produced a double zero.**

```bash
AC_REFS=$(grep -coE 'Scenario:|Given |When |Then |AC-[0-9]+' "$PLAN" 2>/dev/null || echo 0)
```

`grep -c` prints `0` **and exits 1** when nothing matches. The `|| echo 0` then appended
a *second* zero, and the output was a two-line string:

```text
./scripts/validate-implementation-plan.sh: line 204: [: 0
0: integer expression expected
```

The check still "worked" — a non-numeric operand makes `[` fail, which happened to
produce the right verdict — but it leaked a shell error into the report. Fixed:

```bash
AC_REFS=$(grep -coE '...' "$PLAN" 2>/dev/null || true)
AC_REFS=${AC_REFS:-0}
```

The same bug was then found **latent in EPIC-3's `workflow-status.sh`**, where it caused
visible output corruption rather than a stray error:

```bash
D=openspec/changes/bugcheck   # tasks.md with zero checkboxes
./scripts/workflow-status.sh --quiet
```

Before:

```text
  ----  implementation   0
```

The intended message was truncated to `0` and the `(blocked by planning)` style suffix
lost. After the fix:

```text
  ----  implementation   no task checkboxes in tasks.md
```

Both occurrences were swept for with:

```bash
grep -n 'grep -c[^|]*||[[:space:]]*echo 0' scripts/*.sh
```

**Defect 2 — `--quiet` suppressed failures, in three scripts.**

The documented behaviour was "Print only warnings and failures", but the implementation
routed everything through a `say()` helper that `--quiet` disabled:

```bash
say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
fail() { FAILURES=$((FAILURES + 1)); say "  ...FAIL..."; }
```

So `--quiet` on a failing run printed nothing at all:

```bash
./scripts/validate-implementation-plan.sh --plan scripts/fixtures/plans/invalid/implementation-plan.md --quiet
```

```text
(no output)
```

A flag that hides the reason a command failed is worse than useless. Fixed by making
`warn`/`fail`/`note` print unconditionally, keeping only `pass` and `section` behind
`say()`:

```bash
# Warnings, failures and their guidance print even under --quiet: suppressing a
# failure would hide the reason a run failed.
warn() { WARNINGS=$((WARNINGS + 1)); printf '  %sWARN%s  %s\n' "$c_yellow" "$c_reset" "$*"; }
fail() { FAILURES=$((FAILURES + 1)); printf '  %sFAIL%s  %s\n' "$c_red" "$c_reset" "$*"; }
note() { printf '  %s%s%s\n' "$c_dim" "$*" "$c_reset"; }
```

The `RESULT: FAIL` verdict was changed the same way, so it survives `--quiet`.

**Defect 3 — `workflow-status.sh --quiet` hid its own answer.**

The same root cause had a worse effect here: `--quiet` suppressed the
`First incomplete gate:` line, which is the entire output the caller asked for.

```bash
./scripts/workflow-status.sh --quiet
```

Before:

```text
  PASS  selection        change 'quietcheck' exists
  ...
  ----  acceptance       SPECS.md fails the readiness/context contract
        next owner: product-manager
```

The verdict line — the reason to run the command — was missing. Fixed by printing the
verdict unconditionally.

**Defect 4 — `--quiet` on a per-gate check.** `workflow-status.sh` counts plan failures
by piping the validator's output through `grep -c`, which carries defect 1's pattern.
Guarded with `${PLAN_DETAIL:-0}`.

All four were found by running the scripts against deliberately broken inputs rather
than by reading them.

### 5.4 Prove the validator

```bash
./scripts/validate-implementation-plan.sh --plan scripts/fixtures/plans/valid/implementation-plan.md --story US-2.1 --change add-codebase-analyst
```

```text
Plan — scripts/fixtures/plans/valid/implementation-plan.md
  PASS  identifies the selected story (US-2.1)
  PASS  story matches the expected 'US-2.1'
  PASS  names the OpenSpec change (add-codebase-analyst)
  PASS  change matches the expected 'add-codebase-analyst'
  PASS  has required section: Selected Story
  PASS  has required section: OpenSpec Artifacts
  PASS  has required section: Task to Acceptance Mapping
  PASS  has required section: Affected Files
  PASS  has required section: Test Strategy
  PASS  references OpenSpec artifacts
  PASS  maps tasks to acceptance criteria (3 acceptance reference(s))
  PASS  identifies likely affected files (6 path-like reference(s))
  PASS  states a test or verification approach
  PASS  all advisory sections present

Summary
  failures: 0
  warnings: 0

  RESULT: PASS — all required checks passed, 0 warning(s).
```

```bash
./scripts/validate-implementation-plan.sh --plan scripts/fixtures/plans/invalid/implementation-plan.md
```

```text
  FAIL  does not identify the selected story
  fix: add a 'Story: US-N.M' line naming the selected story
  WARN  does not name the OpenSpec change id
  FAIL  missing required section: Selected Story
  FAIL  missing required section: OpenSpec Artifacts
  FAIL  missing required section: Task to Acceptance Mapping
  FAIL  missing required section: Affected Files
  FAIL  missing required section: Test Strategy
  FAIL  references no OpenSpec artifact
  FAIL  maps no task to an acceptance criterion
  FAIL  identifies no affected file or module
  WARN  plan uses definite language about file scope
  repository evidence supports 'likely' scope, not certainty — see US-4.1
  PASS  states a test or verification approach
  WARN  no section for: Dependencies, Risks, Open Questions, Implementation Order

Summary
  failures: 9
  warnings: 3

  RESULT: FAIL — 9 required check(s) failed.
```

Every seeded defect detected. Exit codes confirmed without pipe interference:

```bash
./scripts/validate-implementation-plan.sh --plan <valid> --story US-2.1 --change add-codebase-analyst --quiet >/dev/null 2>&1; echo $?
./scripts/validate-implementation-plan.sh --plan <invalid> --quiet >/dev/null 2>&1; echo $?
./scripts/validate-implementation-plan.sh --plan <valid> --story US-9.9 --quiet >/dev/null 2>&1; echo $?
./scripts/validate-implementation-plan.sh --plan /nope.md --quiet >/dev/null 2>&1; echo $?
./scripts/validate-implementation-plan.sh --bogus >/dev/null 2>&1; echo $?
```

```text
valid plan:      exit=0 (expect 0)
invalid plan:    exit=1 (expect 1)
story mismatch:  exit=1 (expect 1)
missing plan:    exit=1 (expect 1)
usage error:     exit=2 (expect 2)
```

> A note for anyone reproducing this: piped commands report the **last** command's exit
> code. `./validate... | tail -6; echo $?` prints `0` even when the validator failed.
> The checks above redirect to `/dev/null` instead.

### 5.5 Author the Planner agent

Created `.claude/agents/planner.md` with `tools: Read, Grep, Glob, Bash` — no `Write`,
no `Edit`. The spec's "MUST NOT modify application source code" is therefore
structurally enforced.

The agent adds an **evidence discipline** table, because the acceptance criterion
"identify likely affected files ... when determinable from repository evidence" is about
grounding, not guessing:

| Claim | Acceptable evidence |
|---|---|
| "This file will change" | You read it and it implements the affected behavior |
| "This is the only caller" | You grepped and saw one call site |
| "Tests live here" | You found a test file or a test command in the manifest |
| "This is how the project does X" | You found two or more consistent instances |

It also requires the honest register: *"Likely" is the correct register; you have not
made the change, so you cannot know it with certainty.*

### 5.6 Author the plan-feature skill

Created `.claude/skills/plan-feature/SKILL.md`. It guards against planning before
proposal:

```text
Planning cannot begin: <change-id> has no planning artifacts.
Run /opsx:propose <change-id> first, then /plan-feature <change-id>.
```

and against the temptation to invent an acceptance criterion for an unmapped task:

```text
Unmapped task: <task>
No acceptance criterion covers this task.
Options: (a) the task is unnecessary, (b) a criterion is missing and the story is not READY.
This needs a Product Manager decision.
```

### 5.7 Author the template

Created `scripts/templates/implementation-plan.md`, carrying all five required sections
plus the advisory four. Verified it contains every heading the validator requires:

```text
OK  Selected Story
OK  OpenSpec Artifacts
OK  Task to Acceptance Mapping
OK  Affected Files
OK  Test Strategy
```

The template deliberately fails validation — its placeholders are unresolved — which is
correct for a skeleton:

```bash
./scripts/validate-implementation-plan.sh --plan scripts/templates/implementation-plan.md --quiet >/dev/null 2>&1
echo $?
```

```text
1
```

### 5.8 Upgrade gate 3

`workflow-status.sh` now validates the plan when the validator is present:

```bash
D=openspec/changes/gate3test
./scripts/workflow-status.sh --quiet   # with no plan
```

```text
  ----  plan-handoff     implementation-plan.md missing
        next owner: planner (/plan-feature)
```

With an empty plan:

```bash
printf '' > "$D/implementation-plan.md"
./scripts/workflow-status.sh --quiet
```

```text
  ----  plan-handoff     implementation-plan.md fails the US-4.1 contract (1 failure(s))
        next owner: planner (/plan-feature)
```

With the valid fixture:

```bash
cp scripts/fixtures/plans/valid/implementation-plan.md "$D/implementation-plan.md"
./scripts/workflow-status.sh --quiet
```

```text
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
  ----  implementation   0/1 tasks complete
```

The gate now distinguishes absent, malformed, and valid. The probe change was removed
afterward.

### 5.9 Register the validator

```json
"Bash(bash scripts/validate-implementation-plan.sh:*)",
"Bash(scripts/validate-implementation-plan.sh:*)"
```

Added to `permissions.allow`. The script is read-only, so pre-approving it is safe.

### 5.10 Regression suite

```bash
./scripts/validate-implementation-plan.sh --plan scripts/fixtures/plans/valid/implementation-plan.md --quiet >/dev/null 2>&1; echo $?
./scripts/validate-implementation-plan.sh --plan scripts/fixtures/plans/invalid/implementation-plan.md --quiet >/dev/null 2>&1; echo $?
./scripts/validate-product-artifacts.sh --specs scripts/fixtures/valid/SPECS.md --codebase scripts/fixtures/valid/CODEBASE.md --prd scripts/fixtures/valid/PRD.md --quiet >/dev/null 2>&1; echo $?
./scripts/validate-product-artifacts.sh --specs scripts/fixtures/invalid/SPECS.md --codebase scripts/fixtures/invalid/CODEBASE.md --prd scripts/fixtures/invalid/PRD.md --quiet >/dev/null 2>&1; echo $?
```

```text
valid plan:          exit=0 ✓
invalid plan:        exit=1 ✓
valid artifacts:     exit=0 ✓
invalid artifacts:   exit=1 ✓
```

The `--quiet` changes did not regress EPIC-2's validator.

---

## 6. The US-4.1 contract

| Check | Severity | Requirement |
|---|---|---|
| Identifies the selected story | required | A `Story: US-N.M` line |
| Names the change | advisory | A `Change: <change-id>` line |
| `## Selected Story` | required | The story this change implements |
| `## OpenSpec Artifacts` | required | The artifacts read |
| `## Task to Acceptance Mapping` | required | Every task mapped to a scenario |
| `## Affected Files` | required | Likely files, with evidence |
| `## Test Strategy` | required | How each criterion is demonstrated |
| References an OpenSpec artifact | required | Cites `proposal.md`, `specs/`, `design.md`, or `tasks.md` |
| Maps ≥1 acceptance reference | required | `Scenario:` / `Given` / `When` / `Then` / `AC-N` |
| Identifies ≥1 affected path | required | A path-like token |
| `## Dependencies`, `## Risks`, `## Open Questions`, `## Implementation Order` | advisory | Expected unless not applicable |

Advisory **smells** (warned, never failed), because they indicate a plan describing work
already done rather than work to be done:

- definite language about file scope — `exact`, `definitiv`, `will certainly`, `confirmed to be`
- `Modified` / `Changed` / `Implemented` at the start of a list item

---

## 7. Deliverables

### Created

| Path | Implements | Purpose |
|---|---|---|
| `.claude/agents/planner.md` | US-4.1 | Read-only Planner with evidence discipline |
| `.claude/skills/plan-feature/SKILL.md` | US-4.1 | Produces the handoff and validates it |
| `scripts/templates/implementation-plan.md` | US-4.1 | Plan skeleton |
| `scripts/validate-implementation-plan.sh` | US-4.1 | Plan contract validator |
| `scripts/fixtures/plans/valid/implementation-plan.md` | US-4.1 | Passing fixture |
| `scripts/fixtures/plans/invalid/implementation-plan.md` | US-4.1 | Failing fixture |
| `README-EPIC-4.md` | — | This document |

### Modified

| Path | Change |
|---|---|
| `scripts/workflow-status.sh` | Gate 3 now validates the contract instead of checking existence; owner shown as `planner (/plan-feature)`; **two bug fixes** |
| `scripts/validate-product-artifacts.sh` | **Bug fix**: `--quiet` no longer suppresses failures |
| `.claude/settings.json` | Pre-approved the read-only plan validator |
| `scripts/README.md` | Documented the plan validator, contract, fixtures, and the gate-3 change |
| `.claude/agents/README.md` | Recorded `planner` as delivered; read-only table now five rows |

---

## 8. Acceptance verification

### US-4.1 — Create Planner Agent

> **Scenario: Explore without modifying product code**
> Then it MUST inspect relevant code, specifications, dependencies, and risks
> And it MUST NOT modify application source code

| Criterion | Evidence | Result |
|---|---|---|
| Inspects relevant code, specs, dependencies, risks | Agent requires reading `proposal.md`, `specs/`, `tasks.md`, `SPECS.md`, `CODEBASE.md`; 9-step method | PASS |
| Must not modify application source code | `tools: Read, Grep, Glob, Bash` — `Write`/`Edit` absent | PASS |

> **Scenario: Produce implementation plan**
> Then `implementation-plan.md` MUST exist for the active change
> And it MUST identify the selected story
> And it MUST reference relevant OpenSpec artifacts
> And it MUST map tasks to acceptance criteria
> And it MUST identify likely affected files and expected tests when determinable

| Criterion | Evidence | Result |
|---|---|---|
| File exists for the active change | Skill Step 5 writes to `openspec/changes/<change-id>/implementation-plan.md`; gate 3 reads there | PASS |
| Identifies the selected story | Validator check, required; fixture-proven | PASS |
| References OpenSpec artifacts | Validator check, required; fixture-proven | PASS |
| Maps tasks to acceptance criteria | Validator check, required; fixture-proven; 3 references in the valid fixture | PASS |
| Identifies likely affected files | Validator check, required; 6 path references in the valid fixture | PASS |
| Identifies expected tests | `## Test Strategy` required; validator also requires test/verification language | PASS |

### Scripted check

```bash
grep -q "^name: planner" .claude/agents/planner.md                          # PASS
grep -q "Read, Grep, Glob, Bash" .claude/agents/planner.md                  # PASS
grep -qi "never modify application source code" .claude/agents/planner.md   # PASS
grep -q "## Task to Acceptance Mapping" .claude/agents/planner.md           # PASS
grep -q "## Affected Files" .claude/agents/planner.md                       # PASS
grep -q "## Test Strategy" .claude/agents/planner.md                        # PASS
grep -q "^name: plan-feature" .claude/skills/plan-feature/SKILL.md          # PASS
test -f scripts/templates/implementation-plan.md                            # PASS
test -x scripts/validate-implementation-plan.sh                             # PASS
grep -q "validate-implementation-plan.sh" scripts/workflow-status.sh        # PASS
```

```text
--- US-4.1 Planner agent ---
PASS  agent defined
PASS  read-only tool list
PASS  no Write/Edit
PASS  no-modify rule
PASS  exploration required
PASS  task-to-criterion mapping
PASS  affected files section
PASS  test strategy section

--- US-4.1 plan-feature skill + template ---
PASS  skill defined
PASS  template present

--- validator + gate wiring ---
PASS  plan validator executable
PASS  gate 3 wired to validator

--- settings ---
PASS  validator pre-approved
```

### Frontmatter

```text
OK    .claude/agents/planner.md           name=planner
OK    .claude/skills/plan-feature/SKILL.md  name=plan-feature
```

---

## 9. Task checklist

### US-4.1 — Create Planner Agent
- [x] Create `.claude/agents/planner.md`.
- [x] Create `.claude/skills/plan-feature/SKILL.md`.
- [x] Define `implementation-plan.md` template.

---

## 10. Deviations and decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Built a validator rather than accepting gate 3 as written | Gate 3 checked existence only, so a one-line file unblocked implementation — the failure EPIC-4 exists to prevent |
| 2 | Planner is read-only via the tool allowlist | Same approach as EPIC-2: make the prohibition structural, not advisory |
| 3 | Advisory smells warn but never fail | A plan using `exact` may be legitimately certain; failing would push agents to hide wording rather than fix substance |
| 4 | Validator counts acceptance references rather than parsing tables | Keeps it bash-only and portable (§NFR-001); the mapping's *quality* is the Reviewer's job, not a regex's |
| 5 | Fixed `--quiet` in EPIC-2's validator too | Same defect class; leaving it would mean two scripts with contradictory documented behaviour |
| 6 | Fixed the `grep -c` bug in EPIC-3's script too | It was latent there and produced visibly truncated output |
| 7 | Template intentionally fails validation | Placeholders are unresolved; the skeleton must not be mistaken for a plan |
| 8 | Gate 3 reports `(validator unavailable)` and passes when the validator is absent | Keeps `workflow-status.sh` standalone-usable in a project that copied only that script |

---

## 11. Notes for reuse

- **Piping hides exit codes.** `./validate.sh ... | tail -6; echo $?` reports `tail`'s
  status, not the validator's. Redirect to `/dev/null` when checking pass/fail.
- **`grep -c` exits 1 on zero matches.** Use `|| true` plus `${VAR:-0}`, never
  `|| echo 0`, which appends a second zero and produces a multi-line operand.
- **`--quiet` means "warnings and failures only"** in all three scripts. Failures and the
  verdict always print, so a failing `--quiet` run is never silent.
- **Gate 3 needs the validator to be executable.** If `scripts/` was copied without the
  `+x` bit, gate 3 degrades to an existence check and reports
  `(validator unavailable)`.
- **Validate the filled plan, not the template.** `scripts/templates/*` fail by design.
- **A task with no mapped criterion is a finding.** The skill reports it for a Product
  Manager decision rather than inventing a criterion (`BR-001`).

---

## 12. Follow-ups

1. **Resolve the `SPECS.md` US-11.1 defect** (carried from EPIC-2). Still the sole reason
   gate 7 fails on this repository.
2. **EPIC-5 (Implementer)** consumes this handoff. Gate 4 (`implementation`) waits on it.
3. **EPIC-6 (Reviewer)** should verify that the plan's `## Affected Files` matched what
   actually changed — a mismatch is a planning defect worth feeding back.
4. **EPIC-8 hooks** can enforce gate 3 mechanically before an Implementer writes, using
   `validate-implementation-plan.sh` as the check.
5. **Commit this work.** Suggested message:
   `feat(EPIC-4): planning handoff, plan validator, and gate-3 contract enforcement`.
