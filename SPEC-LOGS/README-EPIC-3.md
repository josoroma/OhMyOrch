# README-EPIC-3 — Product Manager Orchestration

Implementation record for **EPIC-3** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-3 — Product Manager Orchestration |
| Stories | US-3.1, US-3.2 |
| Status | Complete — all acceptance criteria verified |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-3-1-product-manager-agent/`<br>`openspec/changes/archive/2026-09-24-us-3-2-product-iteration-skill/` |
| SPECS.md status | DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-24 |
| Claude Code | 2.1.128 |
| Spec source | `SPECS.md` lines 565–650; `PRD.md` sections 5, 7, 12, 13, 14 |

---

## 1. Objective

Give a Product Manager agent deterministic control over backlog selection, workflow
transitions, and completion gates.

## 2. The design problem

EPIC-3 asks for two things that are hard to enforce with prose alone:

> "MUST select **exactly one** manageable story"
> "MUST **resume from the first incomplete gate**"

An agent can intend to follow both and still select two stories, or restart work it
already finished, because nothing in the repository tells it otherwise. Prose in a
prompt is not a gate.

So the epic is built on a mechanical signal. `scripts/workflow-status.sh` inspects the
repository and answers two questions with an exit code and a JSON field:

- **Which gate is first incomplete?** → `firstIncompleteGate`
- **May this change be archived?** → `archiveEligible`

Every rule in the Product Manager agent and the iteration skill is expressed in terms
of that signal, so "resume from the first incomplete gate" becomes an instruction with
a definite answer rather than a judgement call.

## 3. Scope

### In scope

- **US-3.1** — `product-manager` agent: story-selection rules, state-transition rules,
  completion gate.
- **US-3.2** — `product-iteration` skill: fresh-start flow, resume flow.

### Out of scope

- The Planner, Implementer, Reviewer, and Tester (EPIC-4 … EPIC-7). This epic
  *delegates* to them; it does not define them.
- The `status.md` format and resumption persistence (EPIC-9). US-9.1 adds the
  durable state file; this epic consumes whatever it finds.
- Hook guards (EPIC-8).

## 4. Plan

```text
1. Recon: inspect a real OpenSpec change, its status --json, and list --json
2. Design the gate model and the resume signal
3. Build + test scripts/workflow-status.sh            (the mechanism)
4. Author the product-manager agent                     (US-3.1)
5. Author the product-iteration skill                  (US-3.2)
6. Register the script in settings.json
7. Verify every acceptance criterion
8. Document the result in this file
```

As in EPIC-2, the mechanically testable piece was built and proven **first**.

## 5. Step-by-step execution

### 5.1 Recon — inspect a real OpenSpec change

The change internals and the JSON output shapes were inspected rather than assumed.

```bash
openspec new change inspect-scaffold
find openspec/changes/inspect-scaffold -type f
cat openspec/changes/inspect-scaffold/.openspec.yaml
```

```text
Created change 'inspect-scaffold' at openspec/changes/inspect-scaffold/
Schema: spec-driven

=== tree ===
openspec/changes/inspect-scaffold/.openspec.yaml

=== .openspec.yaml ===
schema: spec-driven
created: 2026-09-24
```

A new change contains only a metadata file — no artifact files. That established
gate 1 (`selection`) as "the change directory exists", distinct from gate 2
(`planning`).

```bash
openspec status --change inspect-scaffold --json
```

```json
{
  "changeName": "inspect-scaffold",
  "artifactPaths": {
    "proposal": { "outputPath": "proposal.md", "existingOutputPaths": [] },
    "specs":    { "outputPath": "specs/**/*.md", "existingOutputPaths": [] },
    "design":   { "outputPath": "design.md", "existingOutputPaths": [] },
    "tasks":    { "outputPath": "tasks.md", "existingOutputPaths": [] }
  },
  "isPlanningComplete": false,
  "isComplete": false,
  "applyRequires": ["tasks"],
  "artifacts": [
    { "id": "design", "status": "blocked", "requires": ["proposal"] },
    { "id": "tasks",  "status": "blocked", "requires": ["specs", "design"] }
  ]
}
```

```bash
openspec list --json
```

```json
{
  "changes": [
    {
      "name": "inspect-scaffold",
      "completedTasks": 0,
      "totalTasks": 0,
      "lastModified": "2026-09-24T15:47:08.218Z",
      "status": "no-tasks"
    }
  ]
}
```

Both commands produce usable machine-readable state. `workflow-status.sh` therefore
does **not** re-implement OpenSpec's planning graph; it relies on the artifact files
OpenSpec declares and delegates task counting to the same `- [ ]` / `- [x]` convention
OpenSpec's own `list --json` uses (`completedTasks` / `totalTasks`).

The scaffold was removed after inspection:

```bash
rm -rf openspec/changes/inspect-scaffold
openspec list
```

```text
No active changes found.
```

### 5.2 Build the gate reporter

Created `scripts/workflow-status.sh`. It is **read-only** by design: it reports, and
never advances state, writes an artifact, or touches product code.

```bash
chmod +x scripts/workflow-status.sh
bash -n scripts/workflow-status.sh
```

```text
syntax: OK
```

### 5.3 Three defects found and fixed during testing

The script was tested against a deliberately staged change before being trusted. It
failed three times, each with a different root cause — all three recorded because they
are the kind of bug that silently produces plausible-looking wrong output.

**Defect 1 — `specs/**` never matched.**

The first version used `find -path "$CDIR/specs/**/*.md"`. `find`'s `-path` does not
support globstar, so it treated `**` as a literal and never matched. A change with a
real `specs/x.md` was reported as `missing: specs/**`.

```text
  ----  planning         missing: specs/**
```

Fixed by testing for a non-empty directory instead of a glob:

```bash
has_any_under() {
  [ -d "$CDIR/$1" ] && find "$CDIR/$1" -type f 2>/dev/null | head -1 | grep -q .
}
```

**Defect 2 — `"$GATE_DETAIL[2]"` expanded as element 0 plus literal `[2]`.**

Bash expands `$GATE_DETAIL[2]` inside double quotes as `${GATE_DETAIL[0]}` followed by
the literal text `[2]`. The output gave the bug away:

```text
  ----  plan-handoff     change 'probe-gates' exists[2] (blocked by planning)
```

Note the detail text is gate 1's message — element 0 — with `[2]` appended. Fixed with
braces, and the whole file was swept for the pattern:

```bash
grep -nE '\$[A-Z_]+\[[0-9$]' scripts/workflow-status.sh
```

```text
211:  [ "${GATE_STATE[1]}" = "fail" ] && GATE_DETAIL[2]="$GATE_DETAIL[2] (blocked by planning)"
```

That was the only occurrence.

**Defect 3 — `mapfile` is unavailable on macOS bash 3.2.**

The first change-detection version used `mapfile -t FOUND < <(...)`. `mapfile` requires
bash 4.0; macOS ships 3.2 at `/bin/bash`. Replaced with a `find` + `grep -c .` count,
which works on both:

```bash
FOUND=$(find "$CHANGES_DIR" -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null | sed 's|.*/||' | sort)
FOUND_COUNT=$(printf '%s\n' "$FOUND" | grep -c . || true)
```

A fourth issue was found by inspection rather than by running: an `Owner:` line used a
nested `$([ ... ] && echo 0)` to index `GATE_OWNER`, which was both unreadable and
fragile. Replaced with an explicit `FIRST_INCOMPLETE_OWNER` variable captured in the
same loop that finds the gate.

### 5.4 Prove the gate progression

A change was staged through each gate and the report checked at every step.

```bash
D=openspec/changes/probe-gates
mkdir -p "$D/specs"
printf 'schema: spec-driven\n' > "$D/.openspec.yaml"
printf '# Proposal\n' > "$D/proposal.md"
printf '# Spec\n' > "$D/specs/x.md"
printf '# Tasks\n- [ ] one\n- [x] two\n- [ ] three\n' > "$D/tasks.md"
./scripts/workflow-status.sh
```

```text
  PASS  selection        change 'probe-gates' exists
  PASS  planning         proposal.md, specs/, tasks.md present
  ----  plan-handoff     implementation-plan.md missing
        next owner: planner
  ----  implementation   1/3 tasks complete
        next owner: implementer
  ----  review           review.md missing
        next owner: reviewer
  ----  testing          test-report.md missing
        next owner: tester
  ----  acceptance       SPECS.md fails the readiness/context contract
        next owner: product-manager

  First incomplete gate: plan-handoff
```

Adding `implementation-plan.md` and completing every task advanced two gates:

```text
  PASS  implementation   3/3 tasks complete
  ----  review           review.md missing
```

### 5.5 Prove the review and testing gate detection

```bash
printf '# Review\n\nBlocking: 1 finding\n' > "$D/review.md"
./scripts/workflow-status.sh --quiet
```

```text
  ----  review           review.md reports blocking findings
```

```bash
printf '# Review\n\nBlocking: None\n\nVerdict: pass\n' > "$D/review.md"
```

```text
  PASS  review           review.md present, no blocking findings
```

```bash
printf '# Test Report\n\n| Criterion | Result |\n|---|---|\n| AC-1 | FAIL |\n' > "$D/test-report.md"
```

```text
  ----  testing          test-report.md reports FAIL
```

```bash
printf '# Test Report\n\n| Criterion | Result |\n|---|---|\n| AC-1 | PASS |\n' > "$D/test-report.md"
```

```text
  PASS  testing          test-report.md present, no FAIL rows
```

The full chain then reported every gate passing except `acceptance`, which correctly
surfaced the known `SPECS.md` defect from EPIC-2:

```bash
./scripts/workflow-status.sh --json
```

```json
{
  "change": "probe-gates",
  "tasks": { "total": 3, "complete": 3 },
  "firstIncompleteGate": "acceptance",
  "archiveEligible": false,
  "gates": [
    { "gate": "selection",      "status": "pass" },
    { "gate": "planning",       "status": "pass" },
    { "gate": "plan-handoff",   "status": "pass" },
    { "gate": "implementation", "status": "pass" },
    { "gate": "review",         "status": "pass" },
    { "gate": "testing",        "status": "pass" },
    { "gate": "acceptance",     "status": "fail" }
  ]
}
```

JSON output was verified to parse:

```bash
./scripts/workflow-status.sh --json | node -e "…JSON.parse…"
```

```text
valid JSON
change: probe-gates
tasks: 3/3
firstIncompleteGate: acceptance
archiveEligible: false
```

### 5.6 The probe cleanup and the real no-change path

```bash
rm -rf openspec/changes/probe-gates
openspec list
```

```text
No active changes found.
```

```bash
./scripts/workflow-status.sh
```

```text
error: no active change found under openspec/changes
hint: create one with 'openspec new change <id>'
exit=1
```

### 5.7 Author the Product Manager agent

Created `.claude/agents/product-manager.md`. Unlike the three EPIC-2 agents it carries
`Write` and `Edit`, because it must update `SPECS.md` story state and `status.md`. Its
prompt forbids product-code edits and mandates delegation of every technical stage.

The agent is structured around **the two decisions it owns**:

1. **What work happens next** — select exactly one `READY` story; never collapse
   several stories into one change; split an oversized story rather than widening the
   change.
2. **Whether work is finished** — verify the completion gate; never accept an
   assertion that a gate passes.

It documents the separation of duties explicitly (it must never write
`implementation-plan.md`, `review.md`, `test-report.md`, or product code), and routes
every blocking ambiguity to the human Product Manager rather than resolving it.

### 5.8 Author the product-iteration skill

Created `.claude/skills/product-iteration/SKILL.md` with a **Step 0** that decides
between fresh-start and resume from repository state, never from assumption:

| Observation | Situation | Flow |
|---|---|---|
| No active change | Fresh start | Step 1 |
| Change exists, `firstIncompleteGate` is `selection` | Fresh start | Step 2 |
| Change exists, other gate | Resume | Step 5 |
| Several changes, none matching | Ambiguous — stop and ask | — |

The resume flow instructs the agent to report what it found, listing passing gates it
must **not** redo, before continuing.

### 5.9 Register the script

```json
"Bash(bash scripts/workflow-status.sh:*)",
"Bash(scripts/workflow-status.sh:*)"
```

Added to `permissions.allow` in `.claude/settings.json`. The script is read-only, so
pre-approving it is safe.

### 5.10 Validate frontmatter

```bash
node -e "…YAML.parse frontmatter of the two new files…"
```

```text
OK    .claude/agents/product-manager.md           name=product-manager
OK    .claude/skills/product-iteration/SKILL.md   name=product-iteration
```

---

## 6. The gate model

```text
  1 selection      story READY + change exists          product-manager
        |
  2 planning       proposal.md, specs/, tasks.md        planner
        |
  3 plan-handoff   implementation-plan.md               planner
        |
  4 implementation every tasks.md checkbox checked      implementer
        |
  5 review         review.md, no blocking               reviewer
        |
  6 testing        test-report.md, no FAIL              tester
        |
  7 acceptance     artifact contracts                    product-manager
        |
        v
    archive-eligible
```

Each gate requires every earlier gate to pass. The first non-passing gate is the
resume point.

### How each gate is detected

| Gate | Probe |
|---|---|
| selection | the change directory exists |
| planning | `proposal.md` present, `specs/` non-empty, `tasks.md` present |
| plan-handoff | `implementation-plan.md` present |
| implementation | `grep -c` of `- [x]` equals `- [ ]` + `- [x]` in `tasks.md` |
| review | `Blocking: None` or an explicit `Verdict: pass`; `Blocking: <other>` fails |
| testing | no `\| FAIL \|` table cell and no `FAIL:` line in `test-report.md` |
| acceptance | `CODEBASE.md` context marker present when required, and the EPIC-2 validator passes |

Gate 7 delegates to `validate-product-artifacts.sh` and reports `n/a` when that script
is absent, so `workflow-status.sh` works standalone.

---

## 7. Deliverables

### Created

| Path | Implements | Purpose |
|---|---|---|
| `.claude/agents/product-manager.md` | US-3.1 | Orchestration, selection, gates, archive decision |
| `.claude/skills/product-iteration/SKILL.md` | US-3.2 | One entry point; fresh-start + resume flows |
| `scripts/workflow-status.sh` | US-3.1, US-3.2 | Read-only gate reporter and resume signal |
| `README-EPIC-3.md` | — | This document |

### Modified

| Path | Change |
|---|---|
| `.claude/settings.json` | Pre-approved the read-only `workflow-status.sh` |
| `.claude/agents/README.md` | Recorded `product-manager` as delivered; documented its tool grant |
| `scripts/README.md` | Documented `workflow-status.sh`: options, exit codes, gate order, detection rules |

---

## 8. Acceptance verification

### US-3.1 — Create Product Manager Agent

> **Scenario: Select one manageable unit of work**
> Then the Product Manager MUST select exactly one manageable story
> And it MUST record the selected story identifier
> And it MUST establish a corresponding OpenSpec change identifier

| Criterion | Evidence | Result |
|---|---|---|
| Selects exactly one story | Agent: "Select **exactly one** manageable story or cohesive feature per iteration" | PASS |
| Records the story identifier | Report format requires the story id and change id | PASS |
| Establishes a change identifier | Agent step 3 derives a kebab-case id and runs `openspec new change` | PASS |

> **Scenario: Do not treat the entire backlog as one OpenSpec change**

| Criterion | Evidence | Result |
|---|---|---|
| Stories not collapsed into one change | Agent: "Never collapse multiple independently verifiable stories into one OpenSpec change"; oversized stories split, not widened | PASS |

> **Scenario: Product Manager owns archive decision**
> Then the Product Manager MUST verify all completion gates before invoking archive

| Criterion | Evidence | Result |
|---|---|---|
| Verifies gates before archive | Agent archive section re-verifies all five `PRD.md` §14 conditions; skill Step 6 repeats them | PASS |
| Rejects premature archive | Agent: "If any gate fails, reject archival and report which gate blocked it" | PASS |

### US-3.2 — Create Product Iteration Skill

> **Scenario: Start iteration from a story identifier**
> Then the skill MUST establish or locate the corresponding OpenSpec change
> And MUST coordinate Planner, Implementer, Reviewer, and Tester responsibilities
> And MUST enforce workflow gates

| Criterion | Evidence | Result |
|---|---|---|
| Establishes/locates the change | Skill Steps 0–2 | PASS |
| Coordinates the four roles | Skill Step 4 delegates planning → plan-handoff → implementation → review → testing | PASS |
| Enforces gates | `scripts/workflow-status.sh`; verified across all seven gates | PASS |

> **Scenario: Resume an existing iteration**
> Then the harness MUST inspect current repository state
> And MUST resume from the first incomplete required gate

| Criterion | Evidence | Result |
|---|---|---|
| Inspects repository state | Skill Step 0 runs `workflow-status.sh --json` and `openspec list` | PASS |
| Resumes from the first incomplete gate | `firstIncompleteGate` field; verified end-to-end in §5.5 | PASS |

### Scripted check

```bash
grep -q "^name: product-manager" .claude/agents/product-manager.md            # PASS
grep -q "exactly one" .claude/agents/product-manager.md                       # PASS
grep -q "Never collapse multiple independently verifiable stories" ...        # PASS
grep -qi "never advance a gate" .claude/agents/product-manager.md             # PASS
grep -q "^name: product-iteration" .claude/skills/product-iteration/SKILL.md  # PASS
grep -q "Fresh start" .claude/skills/product-iteration/SKILL.md               # PASS
grep -q "Resume: continue from the first incomplete gate" ...                 # PASS
grep -q "firstIncompleteGate" .claude/skills/product-iteration/SKILL.md       # PASS
test -x scripts/workflow-status.sh && bash -n scripts/workflow-status.sh      # PASS
```

```text
--- US-3.1 Product Manager agent ---
PASS  agent defined
PASS  one-story selection rule
PASS  no project-sized change rule
PASS  archive decision owned
PASS  gate enforcement

--- US-3.2 Product Iteration skill ---
PASS  skill defined
PASS  fresh-start flow
PASS  resume flow
PASS  deterministic resume signal

--- gate script ---
PASS  workflow-status.sh executable
PASS  syntax

--- frontmatter parse ---
OK    .claude/agents/product-manager.md           name=product-manager
OK    .claude/skills/product-iteration/SKILL.md   name=product-iteration
```

### Independent command evidence

```bash
./scripts/workflow-status.sh     # no active change
```

```text
error: no active change found under openspec/changes
hint: create one with 'openspec new change <id>'
exit=1
```

```bash
openspec new change demo-iteration && ./scripts/workflow-status.sh
```

```text
  PASS  selection        change 'demo-iteration' exists
  ----  planning         missing: proposal.md, specs/, tasks.md
        next owner: planner (via /opsx:propose)
  ...
  First incomplete gate: planning
  Next owner:            planner (via /opsx:propose)
  NOT archive-eligible
exit=0
```

```bash
./scripts/workflow-status.sh --json | grep -o '"firstIncompleteGate": [^,]*'
```

```text
"firstIncompleteGate": "planning"
```

The demo change was removed afterward; `openspec list` returns `No active changes found.`

---

## 9. Task checklist

### US-3.1 — Create Product Manager Agent
- [x] Create `.claude/agents/product-manager.md`.
- [x] Define story-selection rules.
- [x] Define state-transition rules.
- [x] Define completion gate.

### US-3.2 — Create Product Iteration Skill
- [x] Create `.claude/skills/product-iteration/SKILL.md`.
- [x] Define fresh-start flow.
- [x] Define resume flow.

---

## 10. Deviations and decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Built `workflow-status.sh` as the mechanism behind both stories | "Select exactly one" and "resume from the first incomplete gate" need a definite answer; prose alone cannot supply one |
| 2 | Script is strictly read-only | `BR-004` makes repository artifacts the durable state. A reporter that also mutated state would create a second, competing writer |
| 3 | Did not re-implement OpenSpec's artifact graph | `openspec status --json` already exposes `isPlanningComplete` and per-artifact status; duplicating it would drift |
| 4 | Task counting uses the `- [ ]` / `- [x]` convention | Matches what OpenSpec's own `list --json` counts as `completedTasks` / `totalTasks` |
| 5 | `product-manager` granted `Write`/`Edit` | It must update `SPECS.md` story state and `status.md`; the alternative — a separate agent — adds a handoff without a gate |
| 6 | Gate 7 delegates to the EPIC-2 validator, reporting `n/a` if absent | Keeps this script standalone-usable while avoiding two definitions of the readiness contract |
| 7 | `review` gate requires an explicit verdict | A `review.md` with no stated conclusion is not evidence of review; it fails closed |
| 8 | Exit `1` means "could not report", not "work incomplete" | Failing gates exit `0` and report them; conflating the two would make the script unusable in `if` conditions |

---

## 11. Notes for reuse

- **A non-zero exit means "could not report".** A change with every gate failing exits
  `0`. Check `archiveEligible` / `firstIncompleteGate` in the JSON, not the exit code.
- **Gate 7 needs `SPECS.md`, not the change.** It validates the repository's product
  artifacts, so a perfectly built change still fails gate 7 while `SPECS.md` has an
  unresolved defect. This is intentional: the harness gates on the specification, not
  only on the change.
- **`review` fails closed.** A `review.md` without `Blocking: None` or an explicit
  `Verdict: pass` is reported as failing, not passing. Agents writing `review.md`
  (EPIC-6) must emit one of those markers.
- **Scripts are bash 3.2 compatible.** No `mapfile`, no `${var^^}`, no associative
  arrays. `bash -n` and `grep -nE '\$[A-Z_]+\[[0-9$]'` are a fast pre-commit check —
  the second catches the unbraced-array bug that produced `exists[2]`.
- **OpenSpec JSON is the authority on planning.** Use
  `openspec status --change <id> --json` for `isPlanningComplete`; use
  `workflow-status.sh` for the gates OpenSpec does not model (plan-handoff, review,
  testing, acceptance).

---

## 12. Follow-ups

1. **Resolve the `SPECS.md` US-11.1 defect** (carried from EPIC-2). It is currently
   the sole reason gate 7 fails on this repository, so `workflow-status.sh` will
   report `acceptance` as the first incomplete gate for any otherwise-complete change.
2. **EPIC-4 (Planner)** supplies gate 3. Until `implementation-plan.md` has a
   producer, gate 3 cannot pass by delegation.
3. **EPIC-9 (Durable Workflow State)** adds `status.md`. This epic already reads it
   during resume; US-9.1 gives it a defined format and producer.
4. **EPIC-8 hooks** can enforce the gates mechanically rather than by prompt
   compliance. `workflow-status.sh` is the natural thing for such a hook to call.
5. **Commit this work.** Suggested message:
   `feat(EPIC-3): product manager orchestration and workflow gate reporting`.
