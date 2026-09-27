# Harness Scripts

Portable validation and guard scripts for the OhMyOrch Harness.

| Script | Purpose | Implements |
|---|---|---|
| `validate-product-artifacts.sh` | Validate `SPECS.md`, `CODEBASE.md`, and context markers | US-2.7 |
| `workflow-status.sh` | Report workflow gate status for a change (read-only) | US-3.1, US-3.2 |
| `validate-implementation-plan.sh` | Validate an `implementation-plan.md` Planner handoff | US-4.1 |
| `check-write-scope.sh` | Enforce role write scope (separation of duties) | US-5.1, BR-002 |
| `check-scope.sh` | Report changed files the plan did not predict | US-5.1 |
| `test-write-scope.sh` | Regression matrix for `check-write-scope.sh` | US-5.1 |
| `test-guards.sh` | Regression suite for the US-8.2 guards | US-8.2 |
| `status.sh` | Write or report durable workflow state for a change | US-9.1 |
| `validate-status.sh` | Validate a `status.md` against the US-9.1 contract | US-9.1 |
| `test-status.sh` | Regression suite for durable workflow state | US-9.1 |
| `completion-gate.sh` | Evaluate the four definition-of-done conditions | US-10.1 |
| `validate-verification.sh` | Validate a `completion.md` completion record | US-10.1 |
| `test-completion.sh` | Regression suite for the completion gate | US-10.1 |
| `validate-review.sh` | Validate a `review.md` verdict, findings, and consistency | US-6.1 |
| `validate-test-report.sh` | Validate a `test-report.md` and its acceptance evidence | US-7.1 |
| `check-frontmatter.js` | Validate every agent and skill definition loads | US-7.1 |
| `guard-planning-handoff.sh` | Block product-code writes before the planning handoff | US-8.2 |
| `guard-context-preflight.sh` | Block PRD/SPECS generation from missing or stale CODEBASE context | US-8.2 |
| `guard-archive.sh` | Reject archive while any completion condition is unmet | US-8.2, US-10.1 |
| `run-project-validation.sh` | Run the project's configured fast validation after a source change | US-8.2 |
| `guard-story-done.sh` | Block `Status: DONE` in `SPECS.md` before archival | US-10.1 |
| `delivery.sh` | Resolve a delivery target; derive the next action; record, refresh, reopen, stop, and block a goal | US-12.1, US-12.2 |
| `guard-delivery-loop.sh` | `Stop` hook keeping a delivery goal running; blocks the orchestrator from authoring verdicts | US-12.2 |
| `test-delivery.sh` | Regression suite for goal-driven delivery (179 cases) | US-12.1, US-12.2 |
| `validate-html-page.sh` | Validate a themed single-page HTML document against the page contract | US-14.1 |
| `test-html-page.sh` | Regression suite for themed HTML pages (151 cases) | US-14.1 |

All scripts are POSIX-friendly `bash` with no Node or Python dependency, so they
stay portable across arbitrary host repositories (NFR-001). The single exception is
`check-frontmatter.js`, a development-time tool for this repository only.

Validators, guards, and reporters are read-only. A few commands write durable
records, and only the records named here:

- `status.sh` writes `status.md`;
- `completion-gate.sh --record` writes `completion.md`;
- `delivery.sh start|refresh|stop|block` writes `openspec/delivery/goal.md`;
- `delivery.sh reopen` moves a failing verdict to `history/` and appends tasks;
- `guard-delivery-loop.sh` keeps a stall counter in `openspec/delivery/loop.state`.

None of them edits product code or authors a verdict.

---

## `workflow-status.sh`

Reports which workflow gates a change has passed and which is the first incomplete
one. **Read-only** — it reports; it never advances state, writes artifacts, or edits
product code. The Product Manager agent owns every transition.

```bash
scripts/workflow-status.sh [options]
```

| Option | Default | Purpose |
|---|---|---|
| `--change <id>` | sole active change | Change to inspect |
| `--json` | off | Machine-readable output |
| `--quiet` | off | Suppress the advisory footer |
| `-h`, `--help` | — | Usage |

**Exit codes**

| Code | Meaning |
|---|---|
| `0` | Reported successfully, regardless of how many gates remain |
| `1` | No active change found |
| `2` | Usage error |

A non-zero exit means "could not report", never "work is incomplete". A change with
failing gates exits `0` and reports them.

### Gate order

Each gate requires all earlier gates to pass. The first non-passing gate is the
resume point.

| # | Gate | Passes when | Owner |
|---|---|---|---|
| 1 | `selection` | the change directory exists | Product Manager |
| 2 | `planning` | `proposal.md`, `specs/` (non-empty), `tasks.md` exist | Planner |
| 3 | `plan-handoff` | `implementation-plan.md` satisfies the US-4.1 contract | Planner |
| 4 | `implementation` | every `- [ ]` / `- [x]` checkbox in `tasks.md` is checked | Implementer |
| 5 | `review` | `review.md` exists with no blocking findings **and** satisfies the US-6.1 contract | Reviewer |
| 6 | `testing` | `test-report.md` satisfies the US-7.1 contract: evidence that criteria were evaluated, and no `FAIL` | Tester |
| 7 | `acceptance` | artifact contracts satisfied | Product Manager |

Gate 3 delegates to `validate-implementation-plan.sh` when that script is present, so
a present-but-malformed plan fails the gate rather than passing on existence alone.
Gates 5 and 6 do the same with `validate-review.sh` and `validate-test-report.sh`,
**in addition to** reading the `Blocking:` line and the `FAIL` rows — the two signals
are combined, not substituted. When a validator is absent the gate falls back to
existence and reports `(validator unavailable)`, so this script stays
standalone-usable.

> **Why gate 6 needed this.** Its original check was negative — *"is there a FAIL
> row?"* — which is fail-open: an **empty** `test-report.md` has no FAIL row, so it
> passed. So did a file containing only `All criteria PASS.` The validator supplies the
> missing positive requirement: evidence that criteria were actually evaluated.

### How gates 5–7 are detected

| Gate | Pass | Fail |
|---|---|---|
| `review` | `Blocking: None` or an explicit `Verdict: pass` | `Blocking: <anything else>`, or no explicit verdict |
| `testing` | `test-report.md` present, no FAIL | a `\| FAIL \|` table cell or a `FAIL:` line |
| `acceptance` | contracts pass | `CODEBASE.md` exists without a `CODEBASE Context:` marker in `SPECS.md`, or the EPIC-2 validator fails |

Gate 7 delegates to `validate-product-artifacts.sh` when that script is present, and
reports `n/a` when it is not — so `workflow-status.sh` works standalone.

### Output

```bash
scripts/workflow-status.sh --change add-codebase-analyst
```

```text
  PASS  selection        change 'add-codebase-analyst' exists
  PASS  planning         proposal.md, specs/, tasks.md present
  ----  plan-handoff     implementation-plan.md missing
        next owner: planner
  ...

  First incomplete gate: plan-handoff
  Next owner:            planner
  NOT archive-eligible
```

```bash
scripts/workflow-status.sh --json
```

```json
{
  "change": "add-codebase-analyst",
  "tasks": { "total": 3, "complete": 0 },
  "firstIncompleteGate": "plan-handoff",
  "archiveEligible": false,
  "gates": [
    { "gate": "selection", "status": "pass", "detail": "...", "owner": "product-manager" }
  ]
}
```

Use `--json` for scripting, for the Product Manager's archive decision, and for
deterministic resume detection:

```bash
scripts/workflow-status.sh --json | jq -r '.firstIncompleteGate'
```

---

## `validate-product-artifacts.sh`

Validates harness product artifacts against the **US-2.7** contracts. Written in
POSIX-friendly `bash` with no Node/Python dependency, so it stays portable across
arbitrary host repositories (NFR-001).

```bash
scripts/validate-product-artifacts.sh [options]
```

| Option | Default | Purpose |
|---|---|---|
| `--specs <file>` | `SPECS.md` | Path to the backlog |
| `--prd <file>` | `PRD.md` | Path to the product requirements document |
| `--codebase <file>` | `CODEBASE.md` | Path to the current-state model |
| `--hook` | off | Hook mode: read Claude Code hook JSON on stdin, validate only the edited file, exit 2 to block |
| `--quiet` | off | Print only warnings and failures |
| `-h`, `--help` | — | Usage |

**Exit codes**

| Code | Meaning |
|---|---|
| `0` | All required checks passed (warnings may exist) |
| `1` | At least one required check failed |
| `2` | Usage error, unreadable input, or hook mode blocking a write |

### Validation contracts

#### `SPECS.md` readiness contract

| Check | Severity | Requirement |
|---|---|---|
| Epic identifiers unique | required | Every `# EPIC-N:` identifier is unique |
| User Story identifiers unique | required | Every `### US-N.M:` identifier is unique |
| Status present | required | Every story declares `Status:` |
| Status value valid | required | One of `READY`, `NEEDS CLARIFICATION`, `BLOCKED`, `IN PROGRESS`, `DONE` |
| READY has ≥1 scenario | required | A `READY` story has at least one Gherkin scenario |
| Scenario has Given/When/Then | required | Every scenario contains all three keywords |
| READY is traceable | required | A `READY` story has a `Source:` reference |

Only `READY` stories are subject to acceptance and traceability checks — a story that
is honestly `NEEDS CLARIFICATION` is not a failure.

#### `CODEBASE.md` schema contract

Required when the file is present:

| Check | Severity |
|---|---|
| `Analyzed revision:` metadata | required |
| `## System Summary` | required |
| `## Repository Map` | required |
| `## Runtime and Tooling` | required |
| `## Evidence Paths` | required |
| `## Unknowns` | required |

Advisory (the spec says "when discoverable", so absence is a warning, not a failure):
`## Architecture`, `## Entry Points`, `## Data and Persistence`,
`## External Integrations`, `## Authentication and Authorization`,
`## Existing Product Behavior`, `## Tests and Quality Gates`,
`## Common Commands`, `## Conventions`, `## Constraints and Technical Debt`.

A recorded revision of `unknown` or an empty value is a warning.

#### Context-consumption contract

Applies to both `PRD.md` and `SPECS.md`, in CLI and hook mode:

| Condition | Severity |
|---|---|
| `CODEBASE.md` absent, no marker in the artifact | pass |
| `CODEBASE.md` absent, marker is `absent` | pass |
| `CODEBASE.md` absent, but artifact declares `consumed`/`skipped` | warning |
| `CODEBASE.md` present, artifact has a marker | pass |
| `CODEBASE.md` present, marker records a skip | warning (verify intent) |
| `CODEBASE.md` present, no marker | **required failure** |

The marker is a single line near the top of the artifact:

```text
CODEBASE Context: consumed (0f1e2d3)      # CODEBASE.md existed and was read
CODEBASE Context: skipped (<reason>)      # deliberate Product Manager decision
CODEBASE Context: absent                  # no meaningful codebase present
```

This is the mechanical expression of `BR-006` and `FR-017`: when `CODEBASE.md` exists,
generation must demonstrably have consumed it.

### Examples

```bash
# Validate the repository's own artifacts
scripts/validate-product-artifacts.sh

# Validate an alternate artifact set
scripts/validate-product-artifacts.sh --specs path/to/SPECS.md --quiet

# Provisioned as a Claude Code PostToolUse hook
printf '%s' "$HOOK_JSON" | scripts/validate-product-artifacts.sh --hook
```

### Hook integration

`.claude/settings.json` registers the script as a `PostToolUse` hook matching
`Write|Edit|MultiEdit`:

```json
{
  "hooks": {
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
}
```

The wrapper exists for two reasons:

1. **Version tolerance.** `${CLAUDE_PROJECT_DIR}` is substituted by Claude Code, but
   hook `command` strings have always received it as an exported environment
   variable. Referencing it as `${CLAUDE_PROJECT_DIR:-$PWD}` works whether or not the
   variable is set, so the hook behaves identically on older and newer CLIs.
2. **Fail-open.** If the script is missing or not executable — for example when the
   harness is copied into a project without `scripts/` — the `test -x` guard exits `0`
   rather than blocking every write.

In hook mode the script resolves only the edited file, exits `0` for anything it does
not validate, and exits `2` with the findings on stderr so Claude Code blocks the write
and Claude sees what to fix.

> **Note** — `PostToolUse` fires after the write, so exit code 2 surfaces the findings
> and interrupts the workflow at that point; it does not roll the file back. The
> artifact is left on disk for correction. The hook is a guardrail, not a transaction.

### Fixtures

`scripts/fixtures/` holds artifact sets used to verify the validators themselves:

- `valid/` — a well-formed set; expects exit `0`.
- `invalid/` — a set seeded with every detectable defect; expects exit `1` and one
  reported failure per seeded defect (9, including the missing `SPECS.md` context
  marker).
- `plans/valid/`, `plans/invalid/` — the same idea for `implementation-plan.md`.

```bash
scripts/validate-product-artifacts.sh \
  --specs scripts/fixtures/valid/SPECS.md \
  --codebase scripts/fixtures/valid/CODEBASE.md \
  --prd scripts/fixtures/valid/PRD.md
```

---

## `validate-implementation-plan.sh`

Validates an `implementation-plan.md` against the **US-4.1** Planner-handoff contract.
Read-only: it reports, and never repairs a plan.

```bash
scripts/validate-implementation-plan.sh [options]
```

| Option | Default | Purpose |
|---|---|---|
| `--plan <file>` | `implementation-plan.md` | Path to the plan |
| `--story <id>` | — | Also assert the plan identifies this story |
| `--change <id>` | — | Also assert the plan names this change id |
| `--quiet` | off | Print only warnings and failures |
| `-h`, `--help` | — | Usage |

**Exit codes**

| Code | Meaning |
|---|---|
| `0` | All required checks passed (warnings may exist) |
| `1` | At least one required check failed |
| `2` | Usage error or unreadable input |

### The US-4.1 contract

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
| Maps ≥1 acceptance reference | required | A `Scenario:`/`Given`/`When`/`Then`/`AC-N` reference |
| Identifies ≥1 affected path | required | A path-like token |
| `## Dependencies`, `## Risks`, `## Open Questions`, `## Implementation Order` | advisory | Expected unless genuinely not applicable |

Two advisory smells are detected rather than enforced: definite language about file
scope (`exact`, `confirmed to be`) and `Modified`/`Changed`/`Implemented` language. Both
suggest the plan is describing work already done, which is not the Planner's role.

```bash
scripts/validate-implementation-plan.sh \
  --plan openspec/changes/add-planner/implementation-plan.md \
  --story US-4.1 --change add-planner
```

### Templates

`scripts/templates/implementation-plan.md` is the Planner handoff skeleton. A template
fails validation by design — its placeholders are unresolved — so validate the filled
plan, not the template.

---

## `check-write-scope.sh`

Enforces role write scope — the mechanical expression of `BR-002` separation of duties.
**The failure it prevents is an Implementer authoring its own approval**: writing
`review.md` (its verdict) or `test-report.md` (its acceptance evidence).

```bash
scripts/check-write-scope.sh --role <role> --file <path>
printf '%s' "$HOOK_JSON" | scripts/check-write-scope.sh --role <role> --hook
```

| Option | Purpose |
|---|---|
| `--role <role>` | `implementer`, `reviewer`, `tester`, `planner`, `product-manager` |
| `--file <path>` | Path being written (direct mode) |
| `--hook` | Read Claude Code hook JSON on stdin and use its `file_path` |
| `--quiet` | Suppress the allow message |

**Exit codes:** `0` allowed · `2` blocked · `3` usage error or unknown role

### The write-scope matrix

| Role | May write | Must not write |
|---|---|---|
| `implementer` | product code, implementation tests, `tasks.md` | `review.md`, `test-report.md`, `SPECS.md`, `status.md`, plan, specs |
| `reviewer` | `review.md` | product code, `test-report.md`, plan, tasks |
| `tester` | `test-report.md` | product code, `review.md`, tasks |
| `planner` | `implementation-plan.md` | product code, any other artifact |
| `product-manager` | `SPECS.md`, `status.md` | product code, `review.md`, `test-report.md` |

Harness control surface — `CLAUDE.md`, `.claude/`, `scripts/`, `openspec/` — is not
product code and is blocked for every role except the specific owner artifact above.

Hook mode fails **open** on empty or unparseable input, so a malformed hook payload
never blocks work.

### Regression suite

```bash
scripts/test-write-scope.sh
```

36 cases covering the full matrix, absolute-path normalisation, hook mode, and the
fail-open path. Run it after any change to the matrix.

> **Note on `--quiet`:** as with the other scripts, `--quiet` suppresses *passing*
> output only. A block or failure always prints.

---

## `validate-review.sh`

Validates `review.md` against the **US-6.1** contract and its internal consistency.
Read-only: it reports, and never edits a review.

```bash
scripts/validate-review.sh [options]
```

| Option | Default | Purpose |
|---|---|---|
| `--review <file>` | `review.md` | Path to the review |
| `--change <id>` | — | Also assert the review names this change |
| `--story <id>` | — | Also assert the review names this story |
| `--quiet` | off | Print only warnings and failures |
| `-h`, `--help` | — | Usage |

**Exit codes:** `0` all required checks passed · `1` at least one failed · `2` usage error

### The US-6.1 contract

| Check | Severity | Requirement |
|---|---|---|
| Names the change | advisory | `Change: <change-id>` |
| Names the story | advisory | `Story: US-n.m` |
| Verdict present and valid | required | `Verdict: pass \| changes-requested` |
| Blocking line present | required | `Blocking: None \| <n> finding(s)` |
| Findings documented | required when blocking | A section per finding |
| `Requirement` | required with findings | The criterion violated |
| `Observed` | required with findings | What the code does |
| `Expected` | required with findings | What the spec requires |
| `Remediation` | required with findings | The concrete change requested |
| Acceptance coverage | required | A coverage section, with ≥1 criterion evaluated |
| `OpenSpec verify:` line | advisory | The recorded `/opsx:verify` outcome |
| No repair claim | required | The Reviewer must not have fixed the code |

### Consistency rules

A review that contradicts itself is worse than a terse one, so these are failures:

| Verdict | Blocking | Result |
|---|---|---|
| `pass` | `None` | valid |
| `changes-requested` | `<n>`, n ≥ 1 | valid |
| `pass` | `<n>`, n ≥ 1 | **FAIL** — a review with blocking findings cannot pass |
| `changes-requested` | `None` | **FAIL** — name the finding or change the verdict |
| — | `<n>`, n ≥ 1, no findings documented | **FAIL** |

### Repair detection

The Reviewer must not modify the code it reviews. Detection matches natural phrasings
anywhere in the text — `"I fixed the two things"`, `"also updated the handler"`,
`"applied the fix while reviewing"` — rather than only a line-initial keyword, which
missed all of them.

### Fixtures

`scripts/fixtures/reviews/`:

| Fixture | Expects | Demonstrates |
|---|---|---|
| `valid/` | exit `0` | A passing review with full coverage |
| `blocking/` | exit `0` | Well-formed, but requests changes |
| `invalid/` | exit `1` | Missing lines, no coverage, and a repair claim |

Note that a **valid** review and a **blocking** review both exit `0`. The validator
checks whether the review is well formed, not whether it passed. Use
`workflow-status.sh` for the gate verdict.

```bash
scripts/validate-review.sh --review openspec/changes/<id>/review.md \
  --change <id> --story US-6.1
```

---

## `validate-test-report.sh`

Validates `test-report.md` against the **US-7.1** contract. Read-only.

```bash
scripts/validate-test-report.sh [options]
```

| Option | Default | Purpose |
|---|---|---|
| `--report <file>` | `test-report.md` | Path to the report |
| `--change <id>` | — | Also assert the report names this change |
| `--story <id>` | — | Also assert the report names this story |
| `--quiet` | off | Print only warnings and failures |
| `-h`, `--help` | — | Usage |

**Exit codes:** `0` all required checks passed · `1` at least one failed · `2` usage error

### The US-7.1 contract

| Check | Severity | Requirement |
|---|---|---|
| Names the change | advisory | `Change: <change-id>` |
| Names the story | advisory | `Story: US-n.m` |
| **Lists evaluated criteria** | **required** | ≥ 1 row with a PASS or FAIL result |
| Acceptance criteria section | required | `## Acceptance Criteria Evaluated` |
| Evidence present | required | A command, test, or explicit inspection |
| Verdict present and valid | required | `Verdict: pass \| fail` |
| Failures section | required when any FAIL | `## Failures` with observed vs expected |
| Routes back | advisory | States that a code change must be reviewed again |
| Coverage count | advisory | Declared count matches the rows listed |
| No repair claim | required | The Tester must not have fixed the behavior |

### Consistency rules

| Verdict | FAIL rows | Result |
|---|---|---|
| `pass` | 0 | valid |
| `fail` | ≥ 1 | valid |
| `pass` | ≥ 1 | **FAIL** — a failing criterion cannot pass |
| `fail` | 0 | **FAIL** — name the failing criterion or change the verdict |

### The fail-open defect this fixes

Gate 6's original check was negative: *"is there a FAIL row?"* An empty file has no
FAIL row, so it passed. Three reports that previously passed gate 6 now fail:

| Report | Before | After |
|---|---|---|
| empty file | PASS | `test report is empty`, exit 1 |
| `All criteria PASS.` | PASS | 4 failures, exit 1 |
| `Nothing was tested.` | PASS | 4 failures, exit 1 |

The fix is a **positive** requirement: the report must show that criteria were
evaluated. Absence of FAIL is not evidence of testing.

Inspection-based results are legitimate — for a documentation or prompt change, it may
be the only valid method — so the validator accepts stated evidence rather than
demanding an executable check. It does flag vague assurance language
(`looks fine`, `seems correct`) as a warning.

### Fixtures

`scripts/fixtures/test-reports/`:

| Fixture | Expects | Demonstrates |
|---|---|---|
| `valid/` | exit `0` | All criteria pass, with evidence |
| `failing/` | exit `0` | Well-formed, one criterion FAILs, routed back |
| `invalid/` | exit `1` | No criteria, no evidence, and a repair claim |

As with reviews, a **failing** report and a **valid** report both exit `0` — the
validator checks whether the report is well formed, not whether the change passed. Use
`workflow-status.sh` for the gate verdict.

```bash
scripts/validate-test-report.sh --report openspec/changes/<id>/test-report.md \
  --change <id> --story US-7.1
```

---

## `check-frontmatter.js`

Validates that every harness agent and skill definition loads.

```bash
node scripts/check-frontmatter.js
```

Claude Code **silently skips** a definition whose frontmatter is missing, whose opening
`---` is not the first line, whose YAML does not parse, or which lacks `name` or
`description`. A skipped agent does not error — it just never runs. So this is a real
check, not a formality, and it should be run after editing any definition.

```text
OK    agent  tester.md                tester  [hook]
OK    skill  test-feature             test-feature

RESULT: PASS — all definitions valid.
```

This is the only script here that needs Node, because it parses YAML. It is a
development check on the harness itself, not a runtime dependency of the workflow.

---

## `check-scope.sh`

Implements the US-5.1 scope-expansion check: it reports what a diff touched that the
change's plan did not predict. **It reports; it never reverts, stages, or edits.**

```bash
scripts/check-scope.sh --plan <implementation-plan.md> [--diff <file>] [--base <rev>]
git diff --name-only | scripts/check-scope.sh --plan <plan>
```

**Exit codes:** `0` all changed files predicted · `1` unpredicted files found · `2` usage error

A changed file counts as predicted when the plan names it exactly, names a directory
containing it, or names a parent path. Untracked files are included, since a brand-new
file is still a scope decision.

This is **not** the same check as `check-write-scope.sh`. That one asks *"is this role
allowed to write this?"* This one asks *"is this file part of this change?"* An
Implementer writing product code passes the first and can still fail the second.

```bash
scripts/check-scope.sh --plan "openspec/changes/<id>/implementation-plan.md"
```

```text
  Unpredicted change(s) — not necessarily wrong, but must be accounted for:

    docs/typo-fix.md
    src/unrelated-refactor.ts

  RESULT: OUT OF PLAN SCOPE — 2 file(s) unaccounted for.
```

---

## The US-8.2 guards

Four scripts enforce the workflow rules mechanically, so the critical gates do not
rest on prompt compliance alone. The first three are wired into
`.claude/settings.json` as `PreToolUse` hooks, which is what makes them gates rather
than advice: they run *before* the operation, so a blocked write never happens.

All four **fail open**. If the host repository does not use the harness, has no
active change, or has no `scripts/` directory, the operation is allowed. A copied
settings file therefore never bricks an unrelated project.

All four share the same interface:

| Option | Meaning |
|---|---|
| `--hook` | Read Claude Code hook JSON on stdin |
| `--file <path>` | Check a specific path (direct mode) |
| `--change <name>` | Check a specific change (`guard-archive.sh`) |
| `--json` | Machine-readable verdict (`guard-archive.sh`) |
| `--quiet` | Suppress the allow message |
| `-h`, `--help` | Usage |

**Exit codes:** `0` allow · `2` block · `3` usage error · (`run-project-validation.sh`: `1` validation failed)

### Hook wiring

The hook command pattern is version-tolerant, because `${CLAUDE_PROJECT_DIR}` is
only substituted into *skill bodies* by Claude Code 2.1.196+. Hook commands receive
it as an exported environment variable, so `${CLAUDE_PROJECT_DIR:-$PWD}` works on
both older and newer versions:

```json
"command": "sh -c 'd=\"${CLAUDE_PROJECT_DIR:-$PWD}\"; test -x \"$d/scripts/guard-archive.sh\" && exec \"$d/scripts/guard-archive.sh\" --hook --quiet; exit 0'"
```

The `test -x` guard is what produces the fail-open behaviour: when the script is
missing the `&&` short-circuits and `exit 0` allows the operation.

---

## `guard-planning-handoff.sh`

Implements US-8.2 scenario 1: implementation must not begin before the planning
handoff.

```bash
scripts/guard-planning-handoff.sh --file src/app.ts
printf '{"tool_input":{"file_path":"/repo/src/app.ts"}}' | scripts/guard-planning-handoff.sh --hook
```

Wired as `PreToolUse` on `Write|Edit|MultiEdit`. It blocks when an active change has
no `implementation-plan.md`.

**What counts as product code.** Defined by exclusion, not by an include-list of file
extensions: an include-list would silently miss whatever language the host project
happens to use, which is exactly the failure this guard exists to prevent. Everything
is product code except the harness's own control surface (`.claude/`, `scripts/`,
`openspec/`, `.git/`), the repository's own contracts (`CLAUDE.md`, `AGENTS.md`,
`CODEBASE.md`), and the change's artifacts (`proposal.md`, `tasks.md`, `spec.md`,
`design.md`, `implementation-plan.md`, `review.md`, `test-report.md`, `status.md`).

**When several changes are active** the write cannot be attributed to one of them, so
the guard warns and allows rather than blocking work on a guess.

**Relationship to EPIC-5.** `check-write-scope.sh` blocks product-code writes for
roles that are not the Implementer. This guard covers the complementary case: the
Implementer *is* allowed to write product code, but not before a plan exists.

`0` allow · `2` blocked.

---

## `guard-context-preflight.sh`

Implements US-8.2 scenarios 3, 4, and 5: `PRD.md` and `SPECS.md` must not be
generated from missing or stale CODEBASE context.

```bash
scripts/guard-context-preflight.sh --file PRD.md
printf '{"tool_input":{"file_path":"/repo/SPECS.md"}}' | scripts/guard-context-preflight.sh --hook
```

Wired as `PreToolUse` on `Write|Edit|MultiEdit`. It acts only on `PRD.md` and
`SPECS.md`, and performs three checks:

| Repository state | Result |
|---|---|
| No meaningful codebase detected (greenfield) | allow — there is no context to require |
| Meaningful codebase, no `CODEBASE.md`, no recorded skip | **block** (scenario 5) |
| Meaningful codebase, no `CODEBASE.md`, skip recorded | allow |
| `CODEBASE.md` present, `Analyzed revision:` matches `HEAD` | allow (scenarios 3 and 4) |
| `CODEBASE.md` present, `HEAD` has moved past the recorded revision | **block** |

A "meaningful codebase" is judged by a package manifest or any source file outside
the harness's own directories — not by counting files, so a docs-only repository is
treated as greenfield.

**What this guard cannot check.** A hook runs *before* the write, so the artifact's
new content does not exist yet and this guard cannot inspect it for the
`CODEBASE Context:` marker. That is a post-write concern, and it stays with
`validate-product-artifacts.sh` (US-2.7). This guard enforces the precondition that
makes the marker meaningful: the state of the repository when generation starts.

**Escape hatches.** To proceed deliberately, record the decision rather than
defeating the guard:

```text
CODEBASE Context: skipped (<reason>)
CODEBASE Context: consumed (<revision>, staleness accepted)
```

`0` allow · `2` blocked.

---

## `guard-archive.sh`

Implements US-8.2 scenario 2: a change with blocking review findings or failing
acceptance tests must not be archived.

```bash
scripts/guard-archive.sh --change my-change
scripts/guard-archive.sh --change my-change --json
printf '{"tool_input":{"command":"openspec archive my-change --yes"}}' | scripts/guard-archive.sh --hook
```

Wired as `PreToolUse` on `Bash`, matching commands that invoke `openspec archive`.
Archival reaches OpenSpec through the CLI, so intercepting the command is what
actually prevents the state change; rule text alone only says what an agent should do.

**The verdict is delegated, not recomputed.** The guard reads the `archiveEligible`
field from `workflow-status.sh --json` (US-3.1). Duplicating the gate logic would
create a second source of truth that could silently disagree with the first.

```json
{ "change": "my-change", "archiveEligible": false, "blocked": true, "firstIncompleteGate": "review" }
```

`openspec archive --help` and `-h` are passed through, since describing archival is
not performing it. They are matched as whole tokens, so `--hard` or `-hooks` do not count.

**Only the `command` string is judged.** A Claude Code Bash payload always carries
`description` after `command`:

```json
{"tool_input":{"command":"openspec archive c1 -y","description":"Archive the change"}}
```

A greedy parse used to run to the last quote in the payload, so the change name came out
as `change"}}`. That change does not exist, so archival was **allowed**. The guard now
reads exactly one JSON string, and it ignores the word "archive" when it appears only in
the description.

`0` allow · `2` blocked.

---

## `run-project-validation.sh`

Implements US-8.2 scenario 6: configured fast project validation should run before
implementation is handed to review.

```bash
scripts/run-project-validation.sh --file src/app.ts
```

Wired as `PostToolUse` on `Write|Edit|MultiEdit`. PostToolUse runs after the write, so
this reports rather than rejects — which matches the modal level: the scenario says
`SHOULD`, and a failed `SHOULD` is a finding to record, not a block.

**The adaptation strategy.** The harness is stack-neutral (NFR-001) and cannot know
how to build or test an arbitrary host project. Inventing a validation command would
produce a hook that either fails on every legitimate project or silently validates
nothing. So the harness supplies the hook point and the project supplies the command:

1. If the project provides an executable `scripts/fast-validate.sh`, it is run.
2. Otherwise the guard reports `SKIP` and allows. It never reports a pass for a
   validation that did not run.

This repository ships no `fast-validate.sh`, because it is Markdown-only with no build
or test runner. A host project adopts the scenario by adding that one file.

`0` passed or not configured · `1` validation failed · `3` usage error.

---

## Durable workflow state (US-9.1)

`status.md` records, for one active change, what stage the work reached, who owns it,
and what is blocked — so a fresh Claude session resumes from the correct gate without
hidden chat history (NFR-003, BR-004).

Two scripts manage it, and one property is central to both: **derived versus
authored.**

| Content | Kind | Owner |
|---|---|---|
| Gates table, Resume line, `State`, `Current owner` | **derived** from `workflow-status.sh` | `scripts/status.sh` rewrites it |
| `## Blockers` (between `BEGIN/END AUTHORED: blockers`) | **authored** | the Product Manager writes it |

A derived gate table that can be hand-edited is a second source of truth that can
silently disagree with the gate reporter, so it never is. An authored blocker that is
overwritten by a refresh destroys a human decision, so it never is. The markers are
what let one file hold both.

---

## `status.sh`

Writes `openspec/changes/<change>/status.md`, or reports where to resume.

```bash
scripts/status.sh --change my-change
scripts/status.sh --change my-change --blocker "waiting on CI runner"
scripts/status.sh --change my-change --clear-blockers
scripts/status.sh --change my-change --dry-run
scripts/status.sh --resume
```

| Option | Meaning |
|---|---|
| `--change <id>` | Change to record. Default: the sole active change |
| `--resume` | Print where to resume. Writes nothing |
| `--blocker <text>` | Add an authored blocker (repeatable) |
| `--clear-blockers` | Replace authored blockers with `None.` |
| `--dry-run` | Print the result; write nothing |
| `--quiet` | Suppress informational output |

**Exit codes:** `0` written or reported · `1` no active change, or the change does not exist · `2` usage error

```text
$ scripts/status.sh --change add-planner
Wrote openspec/changes/add-planner/status.md

  State:          IMPLEMENTING
  Current owner:  implementer
  Resume:         implementation

  Gates are derived from workflow-status.sh. Blockers are preserved.
```

`--resume` is the fastest read for a resuming session, and it surfaces a recorded
blocker rather than leaving it buried in the file:

```text
$ scripts/status.sh --resume --change add-planner

  PASS  selection        change 'add-planner' exists
  PASS  planning         proposal.md, specs/, tasks.md present
  PASS  plan-handoff     implementation-plan.md satisfies the Planner-handoff contract
  ----  implementation   1/2 tasks complete
  ----  review           review.md missing
  ----  testing          test-report.md missing
  ----  acceptance       artifact contracts not yet satisfied

  First incomplete gate: implementation
  Next owner:            implementer

  Recorded blocker(s):
    - waiting on CI runner

  Read-only. status.md was not written.
```

The `State` value is derived from the first incomplete gate and uses only the change
vocabulary defined in `CLAUDE.md`:

| First incomplete gate | `State` |
|---|---|
| `selection` | `SELECTED` |
| `planning` | `PROPOSED` |
| `plan-handoff` | `PLANNED` |
| `implementation` | `IMPLEMENTING` |
| `review` | `REVIEWING` |
| `testing` | `TESTING` |
| `acceptance` | `CHANGES_REQUESTED` |
| none — all gates pass | `ACCEPTED` |
| anything unmappable | `BLOCKED` |

`status.sh` only ever writes `status.md`. It never advances a gate, never edits
product code, and never touches `SPECS.md`.

---

## `validate-status.sh`

Validates a `status.md` against the US-9.1 contract.

```bash
scripts/validate-status.sh --change my-change
scripts/validate-status.sh --status openspec/changes/x/status.md --change x
```

| Option | Meaning |
|---|---|
| `--status <file>` | Path to `status.md`. Default: `openspec/changes/<id>/status.md` |
| `--change <id>` | Change id. Also enables the live freshness comparison |
| `--quiet` | Print only warnings and failures |

**Exit codes:** `0` contract satisfied · `1` a required check failed · `2` usage error

| Check | Enforces |
|---|---|
| Required sections | `## Gates`, `## Resume`, `## Blockers` at any heading depth |
| Identity and state | `Story` is a story id; `State` is in the defined vocabulary; owner recorded |
| Gates | exactly seven rows, in fixed order, each `pass` or `fail` |
| Resume coherence | the Resume line agrees with the gates table |
| Blockers | the AUTHORED markers are present and the section is not empty prose |
| Freshness | with `--change`, the recorded gates still match `workflow-status.sh` right now |

Two of these catch failures nothing else does.

**Resume coherence.** A Resume line that disagrees with the table above it is the most
dangerous `status.md` defect, because a resuming session reads that line and would redo
completed work while skipping the gate that actually blocks. The `incoherent` fixture
exists to prove it is caught:

```text
  FAIL  Resume says 'implementation' but the first failing gate is 'review'
```

**Freshness.** A `status.md` that was correct when written and is now stale is worse
than none, because a resuming session trusts it. Exit `1` on a stale file does **not**
mean the file is malformed:

```text
Freshness
  FAIL  gate 'implementation' recorded as 'fail' but is now 'pass'

  fix: this file is STALE, not malformed. Refresh it with:
    scripts/status.sh --change add-planner
```

### Fixtures

| Fixture | Exit | Demonstrates |
|---|---|---|
| `status/valid/` | `0` | A coherent file with an authored blocker |
| `status/incoherent/` | `1` | Resume line contradicts the gates table |
| `status/malformed/` | `1` | Invented state, six gate rows, no markers, no Resume line |

### Regression suite

```bash
scripts/test-status.sh
```

`46` cases covering the writer, the validator, blocker preservation across repeated
refreshes, staleness detection and resolution, resume reporting, the all-gates-passing
transition to `ACCEPTED`, and archived changes.

**Archived changes.** `openspec archive` renames a change to
`openspec/changes/archive/<YYYY-MM-DD>-<change-id>/`. `status.sh --resume` and
`workflow-status.sh` recognise both that form and a bare `<change-id>` and report the
change as archived (exit `0`). Refreshing an archived change's `status.md` is refused
(exit `1`): once archived, the record is final.

---

## Completion and archival (US-10.1)

The gate chain answers *"where is this change in the workflow?"* The completion gate
answers *"may this change be shipped?"* They are **not the same list**, and neither
contains the other.

| Check | Script | Question |
|---|---|---|
| Workflow gates | `workflow-status.sh` | where is this change? |
| Completion conditions | `completion-gate.sh` | may it be archived? |

That gap is not theoretical. Condition 4 — OpenSpec verification has no blocking
mismatch — has **no gate at all**, and the recorded `OpenSpec verify:` line in
`review.md` was previously only *recorded*, never *evaluated*. Before this epic, a
review declaring `MISMATCH — 4 blocking mismatches` passed its contract, and a change
carrying that declaration passed all seven gates:

```text
$ scripts/workflow-status.sh --change ok --json | grep archiveEligible
  "archiveEligible": true,          <- all seven gates pass

$ scripts/completion-gate.sh --change ok --json | grep -E '"eligible"|"firstFailing'
  "eligible": false,                <- but condition 4 fails
  "firstFailingCondition": "openspec-verification",

$ scripts/guard-archive.sh --change ok --json
{ "change": "ok", "archiveEligible": false, "blocked": true, "firstIncompleteGate": "openspec-verification" }
exit=2
```

---

## `completion-gate.sh`

Evaluates the four US-10.1 conditions and names the first that fails.

```bash
scripts/completion-gate.sh --change my-change
scripts/completion-gate.sh --change my-change --record
scripts/completion-gate.sh --json
```

| Option | Meaning |
|---|---|
| `--change <id>` | Change to evaluate. Default: the sole active change |
| `--record` | Also write `openspec/changes/<id>/completion.md` |
| `--json` | Machine-readable verdict |
| `--quiet` | Print only failures; the verdict always prints |

**Exit codes:** `0` eligible · `1` not eligible · `2` usage error

| # | Condition | Source |
|---|---|---|
| 1 | All required tasks complete | `tasks.md` |
| 2 | Review has no blocking findings | `review.md` |
| 3 | All required acceptance criteria pass | `test-report.md` |
| 4 | OpenSpec verification has no blocking mismatch | `openspec validate` + recorded `/opsx:verify` |

```text
$ scripts/completion-gate.sh --change add-planner

  PASS  tasks                    4/4 tasks complete
  PASS  review                   verdict 'pass', blocking: none
  PASS  acceptance               5 acceptance criterion/criteria PASS
  FAIL  openspec-verification    recorded /opsx:verify outcome reports a blocking mismatch

  NOT ELIGIBLE FOR ARCHIVE
  First failing condition: openspec-verification
  US-10.1: only a change that satisfies every condition may be archived.
exit=1
```

**Two parsing hazards, both fixed by running the code.**

*`openspec validate` exits `0` even on error*, and its JSON shape differs by failure
kind, sharing no key names:

| Failure | Shape |
|---|---|
| unknown item | `{ "status": [ { "severity": "error", ... } ] }` |
| invalid change | `{ "items": [ { "valid": false, "issues": [ { "level": "ERROR" } ] } ] }` |

Keying on `"severity"` alone matched **nothing** for a real change and reported 0
errors — condition 4 would have passed with blocking mismatches present. Both shapes
are now checked.

Also, `VAR=$(cmd) || VAR=""` **discards output when the command exits non-zero** — and
`openspec validate` exits non-zero precisely when the change is invalid. That turned
every invalid change into "CLI unavailable". Output and exit code are captured
separately.

Note on condition 3: a criterion scored `UNVERIFIED` does **not** block archival, but
it is reported in the evidence line. It is a finding to record, not a false pass.

---

## `validate-verification.sh`

Validates a `completion.md` against the US-10.1 record contract.

```bash
scripts/validate-verification.sh --change my-change
scripts/validate-verification.sh --verification openspec/changes/x/completion.md --change x
```

**Exit codes:** `0` contract satisfied · `1` a required check failed · `2` usage error

| Check | Enforces |
|---|---|
| Sections | `Conditions` and `Verdict` present |
| Identity | a story id, the change id, and a recognised verdict |
| Conditions | exactly four rows, in order, each `pass` or `fail` |
| Coherence | the Verdict agrees with the conditions table |
| Freshness | with `--change`, still matches the live evaluation |

Coherence is the check that matters. A **false certificate** — `Verdict: eligible` over
a failing condition — is the artifact a Product Manager trusts before archiving:

```text
  FAIL  Verdict 'eligible' while condition 'acceptance' fails
```

A record that no longer matches the repository exits `1` as **STALE, not malformed**,
and the message says so, because the two need different remedies.

### Fixtures

| Fixture | Exit | Demonstrates |
|---|---|---|
| `completion/valid/` | `0` | All four conditions passing, verdict eligible |
| `completion/incoherent/` | `1` | Verdict eligible over two failing conditions |
| `completion/malformed/` | `1` | Invented verdict, three condition rows, no Verdict section |

---

## `guard-story-done.sh`

Rejects a `SPECS.md` write that would mark the active story `DONE` while its change is
not archive-eligible. Wired as `PreToolUse` on `Write|Edit|MultiEdit`.

```bash
scripts/guard-story-done.sh --file SPECS.md --old "Status: READY" --content "Status: DONE"
printf '{"tool_input":{"file_path":"/repo/SPECS.md","old_string":"Status: READY","new_string":"Status: DONE"}}' | scripts/guard-story-done.sh --hook
```

US-10.1 task 3 states *"Update SPECS.md story state to DONE only after successful
completion."* Archival was already guarded; this transition was only prose, so it was
the last completion condition with no mechanical enforcement.

It reads the prospective content from the hook payload's `new_string` (or `content`),
so it judges the write **that is about to happen**. Checking the file on disk would
see the old state and always allow. It fires only when the write newly introduces
`Status: DONE` for the active change's story — re-writing an already-`DONE` story, or
`DONE` for a different story, is not the transition it polices.

**Locating the story.** In order:

1. Every `### US-x.y:` heading in the new text followed by `Status: DONE` whose story is
   not already `DONE` on disk. The active change's story is preferred. A full-file `Write`
   is therefore judged by the story it *changes*, not by the first old `DONE` story.
2. With no heading in the new text (the usual `Status: READY` → `Status: DONE` Edit), the
   story whose block contains Edit's `old_string` (`--old` in direct mode). This is used
   only when the text matches exactly once.
3. Otherwise, the story of the single active change.

Previously only rule 1 existed, and only its first match was checked. That meant a bare
DONE Edit, and a full-file Write whose first `DONE` story was already finished, were both
allowed without a check.

**Hook payload parsing.** `file_path`, `new_string`, `content` and `old_string` are each
read as exactly one JSON string, with `\n`, `\t`, `\"` and `\\` decoded. A greedy `sed`
capture used to run to the last quote in the payload. Real Claude Code Edit payloads list
`old_string` and `replace_all` after `new_string`, so those keys ended up in the captured
text and the guard allowed the edit.

`0` allow · `2` blocked · `3` usage error.

---

## `test-completion.sh`

```bash
scripts/test-completion.sh
```

`63` cases, including the bare-Edit, full-Write, and real-payload DONE transitions. The
load-bearing one asserts the gap US-10.1 closed: with a blocking
verify mismatch declared, the gate chain reports `archiveEligible: true` while the
completion gate rejects and `guard-archive.sh` blocks.

---

## Goal-driven delivery (US-12.1, US-12.2)

`/deliver <target>` (`.claude/skills/deliver/SKILL.md`) runs the workflow as a loop over
one `SPECS.md` target. The target is an epic, a story, or a task, and each story is
delivered as its own change. Rules: `.claude/rules/delivery-loop.md`. Handbook:
`README.md` §18.

## `delivery.sh`

```bash
scripts/delivery.sh resolve <target> [--json]   # list the stories a target delivers
scripts/delivery.sh start   <target>            # record goal.md, Status ACTIVE (resumes the same target)
scripts/delivery.sh next    [<target>] [--json] # derive the next action (recorded goal by default)
scripts/delivery.sh refresh                     # rewrite goal.md's derived sections
scripts/delivery.sh reopen  [--change <id>]     # preserve a failing verdict, append remediation tasks
scripts/delivery.sh stop    [--reason <text>]   # record STOPPED
scripts/delivery.sh block   [--reason <text>]   # record BLOCKED (used by the Stop hook)
```

Targets are `EPIC-N`, `US-N.M`, `US-N.M#k`, or `"task text"`. Task text must match
exactly one task. An epic resolves to its stories in `SPECS.md` order. A task resolves
to its parent story and is recorded as the goal's `Focus`.

`next` is **derived on every call**. It reads `SPECS.md` for story status and
dependencies, `workflow-status.sh` for the seven gates, and `completion-gate.sh` for the
four conditions. It never reads the action back from `goal.md`, so a hand-edited record
cannot steer the loop. It checks, in order:

1. readiness (`READY` or `IN PROGRESS`, else `escalate`);
2. dependencies (every named story must be `DONE`, else `escalate`);
3. an archived change (`mark-done`);
4. no change yet (`select`, or `escalate` while another change is active);
5. the first incomplete gate (`propose`, `plan`, `implement`, `review`, `reopen`, `test`,
   `escalate`);
6. the completion gate (`archive`, or `escalate`).

Once every story is `DONE`, `next` returns `complete`.

`goal.md` uses the `status.md` split. Its field table, Stories, and Next Action are
derived, and its Notes, between `BEGIN/END AUTHORED: notes`, are preserved across
refreshes. Goal status is `ACTIVE`, `BLOCKED`, `COMPLETE`, or `STOPPED`.

`reopen` **moves** `review.md` and `test-report.md` to `history/<artifact>-r<round>.md`,
byte-identical. It then appends one unticked `R<round>.<k>` task per finding or failure,
carrying the Reviewer's `Remediation:` or the Tester's `Expected:` text verbatim. It
never writes a verdict.

`0` success · `1` unknown/ambiguous target or refused · `2` usage error.

## `guard-delivery-loop.sh`

```bash
scripts/guard-delivery-loop.sh --hook [--quiet] [--max-stalls <n>]   # hook JSON on stdin
```

It dispatches on the payload's `hook_event_name`.

**`Stop`**, while `goal.md` is `ACTIVE`:

| Derived next action | Result |
|---|---|
| `complete` | records `COMPLETE`, allows the stop |
| `escalate` | records `BLOCKED` with the reason, allows the stop |
| unchanged across `--max-stalls` / `DELIVERY_MAX_STALLS` (default 3) blocked stop attempts | records `BLOCKED` "no progress", allows the stop after that many (the default allows it on the 4th) |
| goal cannot be derived | records `BLOCKED` "could not be derived", allows the stop |
| anything else | **exit 2**. stderr names the action, owner, command, and reason, and Claude continues |

Progress is the `cksum` of the full `next --json` line, stored with the target and a count
in `openspec/delivery/loop.state` (git-ignored). Every goal transition (`start`, `stop`,
`block`) clears it. `stop_hook_active` is deliberately ignored: it says whether this turn
continues a block, not whether the repository moved. When the guard allows a stop that
changed goal state, it prints a `systemMessage` for the user. When the halt could not be
recorded, it says so rather than claiming success.

**`PreToolUse`** (`Write|Edit|MultiEdit`), while a goal is `ACTIVE`, blocks with exit 2 a
**main-session** write to `openspec/changes/*/review.md` or `test-report.md`. The path
match is case-insensitive. Subagent writes carry `agent_id` and are left to that
subagent's own write-scope hook. An escaped `\"agent_id\"` inside file content does not
count. The guard does not see shell redirects or `product-manager` subagent writes; see
`.claude/rules/delivery-loop.md` for these limits.

It fails open, exiting `0`, when `delivery.sh` is absent, no goal exists, the goal is not
`ACTIVE`, the payload is empty, or the hook fires inside a subagent.

`0` allow · `2` block · `3` usage error.

## `test-delivery.sh`

```bash
scripts/test-delivery.sh
```

`179` cases, run in a throwaway copy with a stub `SPECS.md`, the review and test-report
fixtures, and realistic multi-key hook payloads. There is one section per acceptance
scenario of US-12.1 and US-12.2, plus fail-open and usage cases. The load-bearing
cases:

- a Stop is blocked while work remains, even with `stop_hook_active: true`;
- an escalation or a stall is allowed *and* recorded as `BLOCKED`;
- `guard-archive.sh` still rejects an ineligible archive during an ACTIVE goal;
- the orchestrator cannot write `review.md` (or `REVIEW.md`) while a subagent can.

## Themed HTML pages (US-14.1)

The `/generate-html-page` skill writes self-contained pages to `docs/pages/<slug>.html`
from `templates/html-page.html`. The template carries the shadcn Luma palette verbatim
(the US-14.1 `design.md` Appendix A, under `openspec/changes/archive/` once archived)
and every supported component, each
marked with a `data-component` attribute: `stats`, `table`, `list`, `svg-overlay`,
`svg-er`, `svg-infra`, and `sources`.

## `validate-html-page.sh`

```bash
scripts/validate-html-page.sh --page docs/pages/<slug>.html [--no-sources] [--quiet]
```

Checks one page against the page contract. Each rule prints `PASS` or `FAIL  <rule>: …`:

| Rule | Requires |
|---|---|
| `doctype` | the file starts with `<!doctype html>` |
| `lang` | `<html>` declares a `lang` |
| `tokens-light` | a `:root` block declaring all 32 Luma light tokens with their exact values |
| `tokens-dark` | a `.dark` block declaring all 31 Luma dark tokens with their exact values |
| `toggle` | `#theme-toggle`, a `classList.toggle`/`add` of `"dark"`, `localStorage`, and `prefers-color-scheme` |
| `toc` | a `nav.toc` before the first `<section>`, linking every `<section id>` |
| `toc-links` | every `href="#…"` resolves to an `id` on the page |
| `svg-a11y` | every `<svg>` has `role="img"` and an accessible name that resolves, or `aria-hidden="true"` |
| `self-contained` | no `<script src>`, `stylesheet` or `preload`/`modulepreload`/`preconnect`/`dns-prefetch` link, `@import`, remote `url()`, or `@font-face` |
| `csp` | the first element in `<head>`, after an optional `<meta charset>`, is `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data:">` |
| `sources` | a `section#sources` with at least one `<li>` or `<code>` (skipped by `--no-sources`) |

The token lists embedded in the script are the source of truth. Values are compared
exactly, after whitespace normalisation, so a one-line token block still passes.
`<script>` and `<link>` start tags are tokenized by HTML attribute rules, not matched
by regex. Whitespace or `/` separates attributes, `=` may be padded, values may be
double-quoted, single-quoted, or unquoted, and a quoted value may contain `>`. `rel` is
read as a token list, so `rel="alternate stylesheet"` counts and `rel="nostylesheet"`
does not.
The static `self-contained` reading cannot decode every spelling that HTML and CSS
accept: form feeds, character references, duplicate attributes, comment quirks, and
CSS escapes. It also cannot see a load made by an inline script. The `csp` rule is
the guarantee: under that policy the browser refuses every network load. The policy
is matched on the raw start of the file, before comments are stripped, so a
commented or late policy does not count. The `csp-bypass-*` fixtures each load a
resource that the static rule misses, and only `csp` rejects them.

The policy tag is read the way an HTML parser reads it, in the C locale whatever the
caller's locale. Only tab, LF, FF, CR, and space count as whitespace; a vertical tab
does not, so `<meta\vhttp-equiv` is not a `<meta>` tag. Only ASCII letters are
case-folded, so `http-equİv` does not match. Every byte before the end of the tag must
be printable ASCII or HTML whitespace. The `csp-vt-*`, `csp-dotted-i-*`, and `csp-nul-*` fixtures
cover these cases.

The token check confirms each expected token is declared in the `:root` and `.dark`
rules. It does not detect a later rule that overrides a token (a second `:root`, or
`html.dark`). `@font-face` is rejected outright, even with `local()` sources; the
page uses the system font stack.
HTML and CSS comments are stripped before checking, so a comment that mentions
`<section>` or `@import` is not a finding.

`0` pass · `1` a rule failed · `2` usage error (missing `--page`, missing file, unknown option).

## `test-html-page.sh`

```bash
scripts/test-html-page.sh
```

`151` cases across one section per acceptance scenario of US-14.1, plus the skill.
Fixtures live in `fixtures/html-pages/` and are regenerated by
`fixtures/html-pages/make-fixtures.py`. Each of the 55 invalid fixtures is the valid
page with exactly one mutation, named after the rule it breaks. The suite asserts
that each is rejected with exit 1, by that rule, and by no other. The three valid
fixtures guard against false positives: a comment mentioning markup, and a compact
token block. The suite also checks that the template passes with `--no-sources`,
ships every component, and uses no literal colour, and that the example page
`docs/pages/harness-overview.html` passes with its sources.
