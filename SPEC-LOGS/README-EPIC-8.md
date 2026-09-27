# README-EPIC-8 — Workflow Rules and Mechanical Gates

Implementation record for **EPIC-8** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-8 — Workflow Rules and Mechanical Gates |
| Stories | US-8.1, US-8.2 |
| Status | Complete — all acceptance criteria verified |
| OpenSpec changes | `openspec/changes/archive/2026-09-24-us-8-1-team-responsibility-rules/`<br>`openspec/changes/archive/2026-09-24-us-8-2-workflow-hooks/` |
| SPECS.md status | DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-24 |
| Claude Code | 2.1.128 |
| OpenSpec | 1.13.2 |
| Spec source | `SPECS.md` lines 901–1005; `PRD.md` sections 6, 7, FR-010, NFR-002 |

---

## 1. Objective

Make the workflow gates **mechanical** rather than advisory, and write the durable
rules those gates enforce.

EPIC-3 through EPIC-7 built a workflow where the Product Manager checks each gate.
The obvious weakness: every check runs *after* the fact and depends on the agent
choosing to run it. An implementer that never runs `workflow-status.sh` is never
stopped by it. This epic closes that gap in two parts:

- **US-8.1** — six always-loaded rules files that state what each role must and
  must not do.
- **US-8.2** — four guard scripts wired as hooks, so the critical transitions are
  rejected by code rather than by prompt compliance.

## 2. The design problem: prevention versus detection

The pre-existing `PostToolUse` hook detects violations after they happen. For a
validation that is correct — the file is written, then judged. But for the two
gates this epic adds, detection is too late:

| Gate | After the fact | Before the fact |
|---|---|---|
| Planning handoff | Product code already written; now it must be reverted | The write is rejected, so no rework exists |
| Archival | Change already archived; canonical specs already rewritten | The command is rejected, so no state change exists |

So US-8.2's guards are `PreToolUse`, and it is precisely the scenarios marked
**MUST** (archive) and **SHOULD** (planning handoff, which the spec hedges with
"where Claude Code hook capabilities permit it") that get immediate rejection. The
one scenario without teeth — "configured fast project validation **SHOULD** run" —
is deliberately `PostToolUse`, because it reports a finding rather than blocking.

### The speculative-generality trap

The harness is stack-neutral (NFR-001). It cannot know how to build or test an
arbitrary host project, and it must not guess. Scenario 6 says *"configured fast
project validation"* — the word **configured** is the whole design. The harness
supplies the hook point; the host project supplies the command
(`scripts/fast-validate.sh`). Inventing a command would produce a hook that either
fails on every legitimate project or silently validates nothing.

## 3. Scope

### In scope

- Six rules files in `.claude/rules/` satisfying US-8.1's four MUST clauses.
- Three `PreToolUse` guards and one `PostToolUse` adapter satisfying US-8.2's
  six scenarios.
- `.claude/settings.json` wiring, extendable without disturbing the existing hook.
- A regression suite proving all of it.

### Out of scope

- `status.md` persistence (EPIC-9).
- The completion gate consuming `archiveEligible` (EPIC-10).
- A `fast-validate.sh` for this repository — it is Markdown-only with no build or
  test runner, so it has nothing to validate.

## 4. Plan

1. Recon: rules directory contents; current `settings.json` hook surface; the
   `openspec archive` CLI surface.
2. US-8.1: six rules files, plus an index replacing the placeholder `README.md`.
3. US-8.2: build and test one guard at a time.
4. Wire the guards into `settings.json` without disturbing the existing entry.
5. Verify each hook command *verbatim*, extracted from the settings file.
6. Full regression, then document.

---

## 5. Step-by-step execution

### 5.1 Recon

```bash
ls -la .claude/rules/
node -e "const c=require('./.claude/settings.json');console.log(JSON.stringify(c.hooks,null,2))"
openspec archive --help
```

The rules directory held only a placeholder listing the six files to author:

```text
$ ls .claude/rules/
README.md
```

The hook surface was a single `PostToolUse` entry:

```json
{
  "PostToolUse": [
    {
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [
        {
          "type": "command",
          "command": "sh -c 'd=\"${CLAUDE_PROJECT_DIR:-$PWD}\"; test -x \"$d/scripts/validate-product-artifacts.sh\" && exec \"$d/scripts/validate-product-artifacts.sh\" --hook --quiet; exit 0'",
          "statusMessage": "Validating product artifacts"
        }
      ]
    }
  ]
}
```

The archive CLI confirmed the interception point, and that `--help` must be
exempted (describing archival is not performing it):

```text
$ openspec archive --help
Usage: openspec archive [options] [change-name]

Archive a completed change and update main specs

Options:
  -y, --yes      Skip confirmation prompts
  --skip-specs   Skip spec update operations (useful for infrastructure,
                 tooling, or doc-only changes)
  --no-validate  Skip validation (not recommended, requires confirmation)
  --json         Output as JSON (non-interactive)
  --store <id>   Store id to use as the OpenSpec root
  -h, --help     display help for command
```

### 5.2 Author the six rules files (US-8.1)

Each file is bound to a specific rule source, so a reader can trace it:

| File | Governs | Source |
|---|---|---|
| `team-responsibilities.md` | Eight roles, three prohibitions | US-8.1, BR-002 |
| `codebase-context.md` | `CODEBASE.md` as evidence, not intent | BR-006, NFR-005 |
| `openspec.md` | Lifecycle, artifacts, archival, status vocabulary | US-8.2, BR-004 |
| `gherkin.md` | Testable acceptance criteria | FR-003, BR-005 |
| `testing.md` | Tester role and acceptance evidence | US-7.1, NFR-004 |
| `specification-ingestion.md` | Bounded, testable backlog | BR-001, BR-003, BR-005 |

The three prohibitions are written as blockquotes so they are greppable and
unmistakable:

```text
> **The Implementer MUST NOT approve its own implementation.**
> **The Reviewer MUST NOT silently fix reviewed product code.**
> **The Tester MUST NOT silently repair failed implementation behavior.**
```

### 5.3 `guard-planning-handoff.sh`

The first version classified product code with an include-list of extensions
(`*.ts`, `*.py`, …). That was rejected on review: an include-list silently misses
whatever language the host project uses, which is the exact failure mode the guard
exists to prevent. Rewritten as an **exclusion** list — everything is product code
except the harness's own control surface, the repository's contracts, and the
change's artifacts.

```bash
scripts/guard-planning-handoff.sh --file src/app.ts
```

```text
BLOCKED  src/app.ts
  Change guard-test has no implementation plan.
  Expected: openspec/changes/guard-test/implementation-plan.md

  US-8.2: implementation must not begin before the planning handoff.
  Run /plan-feature guard-test first, then retry the write.
exit=2
```

Hook mode normalises the absolute path Claude Code supplies:

```bash
printf '{"tool_input":{"file_path":"/Users/josoroma/projects/claude-dev/src/app.ts"}}' \
  | scripts/guard-planning-handoff.sh --hook --quiet
```

```text
BLOCKED  src/app.ts
...
exit=2
```

### 5.4 `guard-context-preflight.sh`

An early design attempted to have this hook inspect the `CODEBASE Context:` marker
in the artifact being written. That is impossible: `PreToolUse` runs before the
write, so the new content does not exist on disk yet. The marker check is a
post-write concern and stays with `validate-product-artifacts.sh` (US-2.7).

The guard was redesigned to enforce what it *can* observe — the state of the
repository when generation starts — covering all three CODEBASE scenarios:

```bash
scripts/guard-context-preflight.sh --file PRD.md
```

```text
BLOCKED  PRD.md
  A meaningful codebase is present but CODEBASE.md does not exist.

  US-8.2: generation must not silently pretend repository context was considered.
  Either:
    a) run /analyze-codebase to create CODEBASE.md, then retry; or
    b) record a deliberate skip by adding this line to PRD.md:
       CODEBASE Context: skipped (<reason>)
exit=2
```

With a `CODEBASE.md` whose recorded revision `HEAD` has moved past:

```text
BLOCKED  PRD.md
  CODEBASE.md describes 372f9a8908e673a1944240559eca0542d3355ba5, but HEAD has moved on (2 file(s) changed).

  US-8.2: surface the stale-context condition before treating CODEBASE.md as current.
  Run /analyze-codebase to refresh it, or record an explicit decision to proceed.
  To proceed deliberately, put this line in PRD.md:
    CODEBASE Context: consumed (372f9a8908e673a1944240559eca0542d3355ba5, staleness accepted)
exit=2
```

### 5.5 `guard-archive.sh` — and a real portability bug

The guard reads `archiveEligible` from `workflow-status.sh --json` rather than
recomputing the gates, so the gate state keeps one source of truth. The extraction
was written as:

```bash
sed -n 's/.*"archiveEligible":[[:space:]]*\(true\|false\).*/\1/p'
```

It matched nothing, and the guard reported `could not read archive eligibility`:

```text
$ scripts/guard-archive.sh --change guard-arch
ALLOW  could not read archive eligibility; not blocking
exit=0
```

The cause was already fixed once in this project for a different reason: **BSD
`sed` BRE has no `\|` alternation**. The honest fix, consistent with the EPIC-6
`awk` change, is two separate patterns rather than one alternation group, since
an alternation here would silently report "no verdict" — which the guard reads as
approval.

```bash
sed -n 's/.*"archiveEligible":[[:space:]]*\(true\).*/\1/p; s/.*"archiveEligible":[[:space:]]*\(false\).*/\1/p'
```

Behaviour after the fix:

```text
$ scripts/guard-archive.sh --change guard-arch
BLOCKED  archive guard-arch
  Change is not archive-eligible.
  First incomplete gate: acceptance

  US-8.2: a change with unresolved review findings or failing acceptance
  tests must not be archived.
  Run scripts/workflow-status.sh --change guard-arch for the full gate report.
exit=2
```

Isolating the two conditions named in the scenario, using the EPIC-6/EPIC-7
fixtures:

```text
$ cp scripts/fixtures/reviews/blocking/review.md  "$C/review.md"
$ scripts/guard-archive.sh --change guard-arch --json
{ "change": "guard-arch", "archiveEligible": false, "blocked": true, "firstIncompleteGate": "review" }

$ cp scripts/fixtures/reviews/valid/review.md     "$C/review.md"
$ cp scripts/fixtures/test-reports/failing/test-report.md "$C/test-report.md"
$ scripts/guard-archive.sh --change guard-arch --json
{ "change": "guard-arch", "archiveEligible": false, "blocked": true, "firstIncompleteGate": "testing" }
```

### 5.6 `run-project-validation.sh` (scenario 6)

The adapter strategy, and the reason for it:

```text
$ scripts/run-project-validation.sh --file src/app.ts
SKIP   no scripts/fast-validate.sh configured for this project
exit=0
```

In a host project that does configure one:

```text
$ scripts/run-project-validation.sh --file src/app.ts
Running project fast validation: scripts/fast-validate.sh
linting...
PASS   scripts/fast-validate.sh
exit=0

$ scripts/run-project-validation.sh --file src/app.ts     # with a failing validator
Running project fast validation: scripts/fast-validate.sh
2 lint errors
WARN   fast validation failed: scripts/fast-validate.sh
  US-8.2 scenario 6 is a SHOULD. Record this in test-report.md; the
  backend must not treat implementation as handed off until it is resolved.
exit=1
```

A missing validator reports `SKIP`, never `PASS`. Reporting a pass for a
validation that never ran is the same fail-open defect this project already fixed
in gate 6.

### 5.7 Wire the hooks

The existing `PostToolUse` entry was extended, not replaced, and new `PreToolUse`
matchers added:

```text
PreToolUse
  Write|Edit|MultiEdit  -> guard-planning-handoff.sh
                           guard-context-preflight.sh
  Bash                  -> guard-archive.sh
PostToolUse
  Write|Edit|MultiEdit  -> validate-product-artifacts.sh   (pre-existing)
                           run-project-validation.sh       (new)
```

```bash
$ node -e "JSON.parse(require('fs').readFileSync('.claude/settings.json','utf8'));console.log('settings.json: valid JSON')"
settings.json: valid JSON
$ node -e "const c=require('./.claude/settings.json');console.log('PreToolUse matchers :',c.hooks.PreToolUse.map(x=>x.matcher).join(', '));console.log('PreToolUse hooks    :',c.hooks.PreToolUse.reduce((n,x)=>n+x.hooks.length,0));console.log('PostToolUse matchers:',c.hooks.PostToolUse.map(x=>x.matcher).join(', '));console.log('PostToolUse hooks   :',c.hooks.PostToolUse.reduce((n,x)=>n+x.hooks.length,0));console.log('allow rules         :',c.permissions.allow.length)"
PreToolUse matchers : Write|Edit|MultiEdit, Bash
PreToolUse hooks    : 3
PostToolUse matchers: Write|Edit|MultiEdit
PostToolUse hooks   : 2
allow rules         : 41
```

### 5.8 Verify the hook commands verbatim

Every hook command was extracted **from the settings file itself** and executed
with `CLAUDE_PROJECT_DIR` unset, which is how every hook in this project has been
validated. Running a command retyped by hand would prove nothing about what Claude
Code will actually execute.

```bash
unset CLAUDE_PROJECT_DIR
node -e "const c=require('./.claude/settings.json');process.stdout.write(c.hooks.PreToolUse[0].hooks[0].command)" > /tmp/h1.sh
printf '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"%s/src/app.ts"}}' "$PWD" | sh /tmp/h1.sh
```

```text
BLOCKED  src/app.ts
  Change guard-arch has no implementation plan.
  ...
exit=2
```

Archive guard, same method:

```bash
node -e "const c=require('./.claude/settings.json');process.stdout.write(c.hooks.PreToolUse[1].hooks[0].command)" > /tmp/h3.sh
printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"openspec archive guard-arch --yes"}}' | sh /tmp/h3.sh
```

```text
BLOCKED  archive guard-arch
  Change is not archive-eligible.
  First incomplete gate: plan-handoff
  ...
exit=2
```

### 5.9 Verify fail-open

A copied `settings.json` in a repository with no `scripts/` must not block work.
All five hooks were run in that configuration:

```text
=== fail-open: copied settings without scripts/ ===
PreToolUse[0].hooks[0] exit=0
PreToolUse[0].hooks[1] exit=0
PreToolUse[1].hooks[0] exit=0

=== PostToolUse hooks fail-open ===
PostToolUse[0].hooks[0] exit=0
PostToolUse[0].hooks[1] exit=0
```

The property comes from the `test -x` in each command: when the script is absent
the `&&` short-circuits into `exit 0`.

### 5.10 A second real defect: the missing executable bit

The adapter's usage-error path returned `126`, not `3`:

```text
$ scripts/run-project-validation.sh --bogus >/dev/null 2>&1; echo "exit=$?"
exit=126
```

`chmod +x` had been applied to `guard-*.sh` only, and the new script's name did not
match that glob. A `PreToolUse` hook whose script is not executable fails *open* by
design here, so the consequence was not a false block — it was a guard that would
never have run at all. Fixed and re-verified:

```text
$ chmod +x scripts/run-project-validation.sh
$ scripts/run-project-validation.sh --bogus >/dev/null 2>&1; echo "exit=$?"
exit=3
```

### 5.11 Regression suite

A new suite was added so EPIC-8's behaviour is testable, following the EPIC-5
precedent of proving guards against staged states:

```bash
scripts/test-guards.sh
```

```text
US-8.2 scenario 1 — implementation requires a plan
  ok    product code, no plan                                exit=2
  ok    harness control surface allowed                      exit=0
  ok    change artifact allowed                              exit=0
  ok    CLAUDE.md allowed                                    exit=0
  ok    hook mode, absolute path                             exit=2
  ok    hook mode, empty stdin                               exit=0
  ok    product code, plan present                           exit=0
  ok    ambiguous: two active changes                        exit=0
  ok    no active change                                     exit=0

US-8.2 scenarios 3-5 — CODEBASE context preflight
  ok    brownfield, no CODEBASE.md (scenario 5)              exit=2
  ok    recorded skip decision                               exit=0
  ok    CODEBASE.md current (scenario 3/4)                   exit=0
  ok    CODEBASE.md stale                                    exit=2
  ok    non-target artifact ignored                          exit=0
  ok    greenfield: no codebase                              exit=0

US-8.2 scenario 2 — archive requires every gate
  ok    missing review and test evidence                     exit=2
  ok    blocking review findings                             exit=2
  ok    failing acceptance tests                             exit=2
  ok    hook mode rejects archive                            exit=2
  ok    hook mode ignores archive --help                     exit=0
  ok    hook mode ignores other commands                     exit=0
  ok    all gates pass -> eligible                           exit=0

US-8.2 scenario 6 — configured fast validation
  ok    not configured -> skip, allow                        exit=0
  ok    non-source file ignored                              exit=0
  ok    configured and passing                               exit=0
  ok    configured and failing                               exit=1

Usage errors
  ok    planning: unknown option                             exit=3
  ok    planning: missing path                               exit=3
  ok    context: unknown option                              exit=3
  ok    archive: unknown option                              exit=3
  ok    validation: unknown option                           exit=3

=======================================================
  passed: 31
  failed: 0

  RESULT: PASS — all guard behaviours hold.
```

### 5.12 End-to-end: all seven gates, then archival

Staged a change in a scratch harness so every gate passed, and confirmed the
archive guard then allows:

```text
$ scripts/workflow-status.sh --change ok --quiet
  PASS  selection        change 'ok' exists
  PASS  planning         proposal.md, specs/, tasks.md present
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
  PASS  implementation   1/1 tasks complete
  PASS  review           review.md present, no blocking findings
  PASS  testing          test-report.md present, no FAIL rows
  PASS  acceptance       artifact contracts satisfied

  All gates passed — archive-eligible

$ scripts/guard-archive.sh --change ok
ALLOW  ok is archive-eligible
exit=0

$ printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"openspec archive ok --yes"}}' | scripts/guard-archive.sh --hook --json
{ "change": "ok", "archiveEligible": true, "blocked": false }
exit=0
```

This also confirmed the guard *derives* its verdict rather than duplicating it: the
change became eligible because gate 7 was satisfied, and the guard's answer changed
with no edit to the guard.

### 5.13 Full regression

```text
=== test-write-scope.sh ===
  passed: 36
  failed: 0
  RESULT: PASS — separation of duties holds across all roles.

=== test-guards.sh ===
  passed: 31
  failed: 0
  RESULT: PASS — all guard behaviours hold.

=== check-frontmatter.js ===
RESULT: PASS — all definitions valid.
```

Validators against both fixture sets — the pass path and the fail path both
unchanged by this epic:

```text
=== valid fixtures (expect 0) ===
product-artifacts  exit=0
implementation-plan exit=0
review              exit=0
test-report         exit=0

=== invalid fixtures (expect 1) ===
product-artifacts  exit=1
implementation-plan exit=1
review              exit=1
test-report         exit=1
```

---

## 6. Deliverables

### Created

| File | Purpose |
|---|---|
| `.claude/rules/team-responsibilities.md` | Eight roles; three separation-of-duties prohibitions |
| `.claude/rules/codebase-context.md` | `CODEBASE.md` as evidence, not intent; fidelity; staleness |
| `.claude/rules/openspec.md` | Lifecycle, artifacts, archival rule, status vocabulary |
| `.claude/rules/gherkin.md` | The three keywords; testability; MUST/SHOULD/MAY |
| `.claude/rules/testing.md` | Tester independence; evidence; `UNVERIFIED` is not `PASS` |
| `.claude/rules/specification-ingestion.md` | Decomposition without invention; bounded stories |
| `scripts/guard-planning-handoff.sh` | `PreToolUse`: no implementation before the plan |
| `scripts/guard-context-preflight.sh` | `PreToolUse`: CODEBASE context for PRD/SPECS |
| `scripts/guard-archive.sh` | `PreToolUse`: reject premature archival |
| `scripts/run-project-validation.sh` | `PostToolUse`: project fast-validation adapter |
| `scripts/test-guards.sh` | 31-case regression suite for the guards |

### Modified

| File | Change |
|---|---|
| `.claude/settings.json` | +3 `PreToolUse` hooks, +1 `PostToolUse` hook, +8 allow rules (41 total) |
| `.claude/rules/README.md` | Placeholder replaced with the rules index and rule→gate mapping |
| `scripts/README.md` | Index and full sections for the four new scripts plus the suite |
| `CLAUDE.md` | Hard rules now point at `.claude/rules/README.md` and state rule precedence |
| `.claude/agents/product-manager.md` | Archive decision references `guard-archive.sh` and the rules |

---

## 7. Acceptance verification

### US-8.1 — Define Team Responsibility Rules

| Criterion | Evidence | Result |
|---|---|---|
| Rules define all eight roles | Scripted check (below) | PASS |
| Implementer MUST NOT self-approve | `The Implementer MUST NOT approve its own implementation` present | PASS |
| Reviewer MUST NOT silently fix code | `The Reviewer MUST NOT silently fix reviewed product code` present | PASS |
| Tester MUST NOT silently repair behavior | `The Tester MUST NOT silently repair failed implementation behavior` present | PASS |
| Six rules files created | All present, 72–112 lines each | PASS |

```text
=== US-8.1 clause 1: all eight roles defined ===
Codebase Analyst   defined
Product Specifier  defined
Spec Ingestor      defined
Product Manager    defined
Planner            defined
Implementer        defined
Reviewer           defined
Tester             defined

=== US-8.1 clauses 2-4: the three prohibitions ===
Implementer MUST NOT approve own work      present
Reviewer MUST NOT silently fix             present
Tester MUST NOT silently repair            present

=== all six rule files present and non-empty ===
team-responsibilities.md     112 lines
codebase-context.md          72 lines
openspec.md                  87 lines
gherkin.md                   76 lines
testing.md                   74 lines
specification-ingestion.md   78 lines
```

### US-8.2 — Add Workflow Hooks

| # | Scenario | Guard | Suite case | Verified |
|---|---|---|---|---|
| 1 | No implementation before planning handoff | `guard-planning-handoff.sh` | product code, no plan → `2`; plan present → `0` | PASS |
| 2 | Prevent premature archive | `guard-archive.sh` | blocking review → `2`; failing tests → `2`; eligible → `0` | PASS |
| 3 | CODEBASE context before PRD generation | `guard-context-preflight.sh` | current `CODEBASE.md` → `0`; stale → `2` | PASS |
| 4 | CODEBASE context before SPECS generation | `guard-context-preflight.sh` | same guard, `SPECS.md` target | PASS |
| 5 | Detect missing brownfield analysis | `guard-context-preflight.sh` | brownfield, no `CODEBASE.md` → `2`; skip recorded → `0` | PASS |
| 6 | Validate modified implementation | `run-project-validation.sh` | not configured → `0` (SKIP); failing → `1` | PASS |

Verdict-level: **all seven gates pass end-to-end** in a staged change (§5.12), and
the archive guard permits archival exactly when they do.

`31/31` guard-suite cases pass; `36/36` write-scope cases still pass.

---

## 8. Task checklist

### US-8.1 — Define Team Responsibility Rules
- [x] Create `team-responsibilities.md`.
- [x] Create `codebase-context.md`.
- [x] Create `openspec.md`.
- [x] Create `gherkin.md`.
- [x] Create `testing.md`.
- [x] Create `specification-ingestion.md`.

### US-8.2 — Add Workflow Hooks
- [x] Define `.claude/settings.json` hook configuration.
- [x] Add PRD/SPECS CODEBASE-context preflight guards.
- [x] Define portable hook scripts or project-adaptation strategy.
- [x] Add archive gate validation.

### Open question
- **Exact hook event names and matchers MUST follow the Claude Code version
  installed in the host project.** Resolved for 2.1.128: `PreToolUse` and
  `PostToolUse`, with matchers `Write|Edit|MultiEdit` and `Bash`. The
  `${CLAUDE_PROJECT_DIR:-$PWD}` pattern is used so the commands remain valid on
  versions before 2.1.196, where hook commands receive the variable as an exported
  environment variable rather than by substitution.

---

## 9. Deviations and decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | Guards are `PreToolUse`, the adapter is `PostToolUse` | MUST/SHOULD levels: archival and the planning handoff need prevention; scenario 6 only needs reporting |
| 2 | Product code defined by exclusion, not an extension include-list | An include-list silently misses the host project's language — the exact failure the guard exists to prevent |
| 3 | Context guard checks repository state, not the artifact marker | A `PreToolUse` hook cannot see unwritten content; the marker stays with `validate-product-artifacts.sh` |
| 4 | Archive verdict delegated to `workflow-status.sh --json` | Recomputing the gates would create a second source of truth that could silently disagree |
| 5 | Archive guard exempts `archive --help` | Describing archival is not performing it |
| 6 | Multi-change ambiguity warns instead of blocking | The guard cannot attribute a write to one change, and blocking on a guess is worse than proceeding |
| 7 | Scenario 6 is an adapter, not a command | The harness is stack-neutral; inventing a build command would be wrong for every project or vacuous |
| 8 | Missing validator reports `SKIP`, never `PASS` | Reporting a pass for a validation that never ran is the gate-6 fail-open defect again |
| 9 | `BSD sed` alternation replaced with two patterns | `\|` in a BRE silently matched nothing; the fall-through read as "approval", which is worse than a loud failure |
| 10 | Guards fail open when `scripts/` is absent | A copied settings file must not brick an unrelated project |
| 11 | Every guard was proven against staged states before wiring | The mechanism is tested, not assumed — the discipline applied since EPIC-2 |
| 12 | Added `test-guards.sh` in this epic | Four new hooks with no regression suite would make silent breakage a matter of time |

---

## 10. Notes for reuse

- **Enforcement must precede the effect.** A `PostToolUse` guard on archival would
  run after the canonical specs were rewritten. Choose the hook event from what
  must be prevented, not from what is easiest to inspect.
- **A version-tolerant hook command is one line.** `${CLAUDE_PROJECT_DIR:-$PWD}`
  inside the command works whether or not the host version substitutes the variable
  in skill bodies.
- **`test -x … && exec …; exit 0` is the fail-open idiom.** It makes the guard a
  no-op when absent, which is what allows a settings file to be copied safely.
- **Delegate verdicts; never duplicate them.** `guard-archive.sh` holds no gate
  logic. When the underlying state changed, its answer changed with no edit.
- **A silent non-match reads as approval.** The `sed` alternation bug did not
  produce an error — it produced `ALLOW`. Any extraction feeding a gate should fail
  loudly when it matches nothing.
- **`chmod +x` is part of the guard contract.** A non-executable hook script fails
  open, so the guard silently never runs. `scripts/*.sh` should be swept, not
  globbed by prefix.
- **Rules and gates are complements.** A rule tells an agent what to do; a gate
  determines what it can do. Every rule that matters has a gate behind it
  (mapping in `.claude/rules/README.md`).
- **Say `SKIP`, not `PASS`, when nothing ran.** This is the single most reusable
  lesson from EPIC-7, and it applies directly to the validation adapter.

---

## 11. Follow-ups

1. **Resolve the `SPECS.md` US-11.1 defect** (carried from EPIC-2). It remains the
   only thing between the harness and a fully green gate chain. `US-8.1` scenario 1
   uses `Given`/`Then` with no `When`, which is not testable — the very defect
   `.claude/rules/gherkin.md` now documents.
2. **All seven gates now pass** in a staged change; the archive guard proves the
   chain end-to-end. Nothing further is needed for archival, but the defect above
   keeps it red on this repository.
3. **EPIC-9** adds `status.md`; the guards already treat it as a change artifact and
   therefore never as product code.
4. **EPIC-10** consumes `archiveEligible` for the completion gate — reuse
   `guard-archive.sh --json` rather than re-deriving it.
5. **EPIC-11** updates `README.md`: it now needs to document thirteen scripts and
   the four-hook configuration.
6. **Rotate the OpenRouter token** in commit `ea0d29b` (carried from EPIC-1). Still
   unpushed, no remote configured.
7. **Commit this work.** Suggested message:
   `feat(EPIC-8): workflow rules and mechanical gate guards`.
