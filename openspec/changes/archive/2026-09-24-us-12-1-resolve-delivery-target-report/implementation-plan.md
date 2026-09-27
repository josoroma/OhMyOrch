# Implementation Plan — us-12-1-resolve-delivery-target-report

Story: US-12.1
Change: us-12-1-resolve-delivery-target-report

## Selected Story

US-12.1 — Resolve a Delivery Target and Report the Next Action (Status: IN PROGRESS in `SPECS.md`, under `# EPIC-12: Goal-Driven Delivery Orchestration`).

This change delivers US-12.1 alone. It resolves an epic, story, or task into an ordered list of stories. It also works out the next action for a delivery goal from repository artifacts. It does not run that action. The goal loop (US-12.2) and its documentation (US-12.3) are out of scope according to `proposal.md` §Out of Scope.

Dependencies declared in `SPECS.md`: US-3.2, US-9.1, US-10.1. The `SPECS.md` awk probe shows `Status: DONE` for all three.

## OpenSpec Artifacts

- `proposal.md`: adds `scripts/delivery.sh` with the subcommands `resolve`, `start`, `next`, `refresh`, `reopen` and `stop`. Defines the `openspec/delivery/goal.md` format. Adds `scripts/test-delivery.sh`. Impact is limited to four files: `scripts/delivery.sh`, `scripts/test-delivery.sh`, `.claude/settings.json` (allow-list entries only) and `.gitignore`. No existing gate, validator or guard may change.
- `specs/delivery-target/spec.md`: the `delivery-target` capability, with six ADDED requirements and one scenario each: Resolve an epic into its stories; Resolve a task to its parent story; Reject an unknown target; Derive the next action from repository artifacts; Escalate a story that cannot proceed; Reopen a change after a failed review or acceptance test.
- `tasks.md`: 13 unticked tasks. 1.1–1.7 are the deliverables and 2.1–2.6 are the Implementer's regression cases, one per scenario. All are mapped below.
- `design.md`: records five decisions:
  1. The story is the unit of delivery.
  2. The next action is derived and never stored as truth.
  3. A gate/condition → action/owner table.
  4. `reopen` moves the failing artifact to `history/<artifact>-r<round>.md` and appends unticked `R<round>.<k>` tasks. A test failure also moves `review.md` aside.
  5. Only one change may be active at a time.

  It also defines the goal record format and the goal status set `ACTIVE | BLOCKED | COMPLETE | STOPPED`.

## Implementation Order

1. **SPECS.md parsing helpers in `scripts/delivery.sh`**: epic, story and task extraction, the `Status:` and `Dependencies:` readers, and the `Change:` reader. This unblocks `resolve` and every later subcommand.
2. **`resolve` (task 1.1)** for `EPIC-N`, `US-N.M`, `US-N.M#k` and task text, plus the unknown-target error path. Unblocks `start` and the goal story table.
3. **`goal.md` writer plus `start`, `refresh`, `stop` (task 1.2)**. The derived story table and Next Action block sit alongside `<!-- BEGIN/END AUTHORED: notes -->`, which is preserved using the `status.sh` awk pattern. Unblocks `next`, which writes its last computed action through `refresh`.
4. **`next` gate/condition mapping (task 1.3)**. Consumes `scripts/workflow-status.sh --change <id> --json` and `scripts/completion-gate.sh --change <id> --json`, and follows the `design.md` §3 table. Unblocks the escalation logic and the post-`reopen` assertion.
5. **Readiness and dependency escalation in `next` (task 1.4)**. Runs before any change is selected, so it must slot in ahead of the step-4 mapping for a story with no change directory.
6. **`reopen` (task 1.5)**. Parses `### Finding F-n` / `Remediation:` from `review.md` and `### Criterion n` / `Expected:` from `test-report.md`. Moves those artifacts into `history/` and appends tasks. Depends on step 4 to show that the next action returns to `implement`.
7. **`scripts/test-delivery.sh` (task 1.6, 2.1–2.6)**. Build it alongside steps 2–6, one section per scenario, and run it after each step.
8. **`.claude/settings.json` allow-list and `.gitignore` entry (task 1.7)**. Independent; can be done last.
9. **Full harness regression**: `scripts/test-write-scope.sh && scripts/test-guards.sh && scripts/test-status.sh && scripts/test-completion.sh && scripts/test-delivery.sh`, then `node scripts/check-frontmatter.js`, `scripts/validate-product-artifacts.sh`, `openspec validate --all`, and `scripts/check-scope.sh` against the recorded baseline (see Risks).

## Task to Acceptance Mapping

| Task | Acceptance criterion | Notes |
|---|---|---|
| 1.1 Create `scripts/delivery.sh` `resolve` for epic, story, and task targets | Scenario: Resolve an epic into its stories; Scenario: Resolve a task to its parent story; Scenario: Reject an unknown target | `resolve` is the entry point all three resolution scenarios exercise. |
| 1.2 Define the `openspec/delivery/goal.md` format and implement `start`, `refresh`, `stop` | Scenario: Resolve a task to its parent story; Scenario: Reject an unknown target | The `Focus` field in `goal.md` is where "the selected task MUST be recorded as the focus of the goal" is observed. "No delivery goal MUST be recorded" is checked by `goal.md` being absent after a rejected `start`. |
| 1.3 Implement `next`: map every gate and completion condition to one action and owner | Scenario: Derive the next action from repository artifacts | The Then/And require the action to be derived from both gate reporters and to name `Owner:` and `Command:`. |
| 1.4 Implement readiness and dependency escalation in `next` | Scenario: Escalate a story that cannot proceed | Covers a story that is not READY/IN PROGRESS and a dependency that is not DONE. `Reason:` must name the cause. No change directory may be created. |
| 1.5 Implement `reopen` (history, remediation tasks) | Scenario: Reopen a change after a failed review or acceptance test | Preserve under `history/`, append one unticked task per finding, return the next action to implementation. |
| 1.6 Add `scripts/test-delivery.sh` covering every scenario | Scenario: Resolve an epic into its stories; Scenario: Resolve a task to its parent story; Scenario: Reject an unknown target; Scenario: Derive the next action from repository artifacts; Scenario: Escalate a story that cannot proceed; Scenario: Reopen a change after a failed review or acceptance test | The suite container. The individual cases are tasks 2.1–2.6. |
| 1.7 Allow-list the new scripts in `.claude/settings.json`; ignore `openspec/delivery/loop.state` | Scenario: Derive the next action from repository artifacts | Supporting task. The allow-list lets the delivery commands run without a permission prompt. `loop.state` is a per-machine counter that US-12.2 will use, and ignoring it keeps derived state out of version control (design §2). The mapping is indirect: no Then clause names these files. |
| 2.1 Regression cases for Scenario: Resolve an epic into its stories | Scenario: Resolve an epic into its stories | See Test Strategy §A. |
| 2.2 Regression cases for Scenario: Resolve a task to its parent story | Scenario: Resolve a task to its parent story | See Test Strategy §B. |
| 2.3 Regression cases for Scenario: Reject an unknown target | Scenario: Reject an unknown target | See Test Strategy §C. |
| 2.4 Regression cases for Scenario: Derive the next action from repository artifacts | Scenario: Derive the next action from repository artifacts | See Test Strategy §D. |
| 2.5 Regression cases for Scenario: Escalate a story that cannot proceed | Scenario: Escalate a story that cannot proceed | See Test Strategy §E. |
| 2.6 Regression cases for Scenario: Reopen a change after a failed review or acceptance test | Scenario: Reopen a change after a failed review or acceptance test | See Test Strategy §F. |

All 13 tasks are mapped. Task 1.7 maps only indirectly and is flagged in Risks. It is not an unmapped task, because the proposal Impact list requires it.

## Affected Files

| Path | Expected change | Evidence |
|---|---|---|
| `scripts/delivery.sh` | New file, likely 400–600 lines of bash. Subcommands `resolve`, `start`, `next`, `refresh`, `reopen`, `stop`, plus `-h/--help`. The header comment follows the existing script convention: purpose, exit codes, and "Dependencies: bash, awk, grep, sed — no Node/Python (NFR-001)". It reads `SPECS.md` (or `docs/SPECS.md`), `scripts/workflow-status.sh --json` and `scripts/completion-gate.sh --json`. It writes only `openspec/delivery/goal.md`, and during `reopen` it writes `openspec/changes/<id>/history/*` and appends to `openspec/changes/<id>/tasks.md`. | Listed in `proposal.md` Impact and `tasks.md` 1.1–1.5; the file does not exist yet (`ls` of the scripts directory). JSON shapes come from reading `scripts/workflow-status.sh` (one `{ "gate", "status", "detail", "owner" }` object per line; `firstIncompleteGate`; `archiveEligible`) and `scripts/completion-gate.sh` (`"eligible"`, `"firstFailingCondition"`; exits 1 when not eligible). The docs-dir fallback copies `SPECS_PATH`/`SPECS_DOC` in `workflow-status.sh` and `status.sh`. The AUTHORED-marker preservation copies the `status.sh` awk block at lines 213–217 and 300–304. |
| `scripts/test-delivery.sh` | New regression suite, based on `scripts/test-status.sh`. It stages a throwaway copy under `mktemp -d "${TMPDIR:-/tmp}/harness-delivery.XXXXXX"` with `trap 'rm -rf "$WORK"' EXIT`, uses the `check`, `expect_contains` and `expect_absent` helpers, and exits 0/1/2. | Listed in `proposal.md` Impact and `tasks.md` 1.6, 2.1–2.6. The pattern comes from reading `scripts/test-status.sh` lines 1–108 and the staging in `scripts/test-completion.sh` lines 70–89. |
| `.claude/settings.json` | Append four entries to `permissions.allow`: `"Bash(bash scripts/delivery.sh:*)"`, `"Bash(scripts/delivery.sh:*)"`, `"Bash(bash scripts/test-delivery.sh:*)"`, `"Bash(scripts/test-delivery.sh:*)"`. No hook changes, because the Stop hook belongs to US-12.2. | `tasks.md` 1.7. Grep of `.claude/settings.json` lines 20–59 shows the paired `bash scripts/X.sh` / `scripts/X.sh` convention for every harness script. |
| `.gitignore` | Add one entry, `openspec/delivery/loop.state`, probably under a new harness-runtime comment block. | `tasks.md` 1.7 and `proposal.md` Impact. Reading `.gitignore` shows no existing `openspec/` entry. |
| `openspec/changes/us-12-1-resolve-delivery-target-report/tasks.md` | Checkbox ticks only, done by the Implementer as each deliverable lands. | `check-write-scope.sh` lines 176–178 allow the implementer to tick `tasks.md`. Gate 4 counts `- [x]` in `workflow-status.sh`. |

No existing script, validator, guard, fixture, `scripts/README.md`, `CLAUDE.md` or `README.md` is expected to change. The proposal excludes changes to existing gates, and US-12.3 owns documentation.

## Test Strategy

Every acceptance scenario is checked by automated cases in `scripts/test-delivery.sh`. The Tester's acceptance evidence is separate and goes in `test-report.md`.

**Staging (shared by all cases):**

- Copy these into `$WORK/repo/scripts/`: `delivery.sh`, `workflow-status.sh`, `completion-gate.sh`, `validate-review.sh`, `validate-test-report.sh`, `validate-implementation-plan.sh`, `status.sh`, plus `scripts/fixtures` and `scripts/templates` (as `test-completion.sh` lines 72–77 do). Then `chmod +x` them and `cd` into the copy.
- Leave out `validate-product-artifacts.sh`, so gate 7 depends on the CODEBASE context marker alone and the stub `SPECS.md` does not have to meet the full artifact contract.
- Leave `openspec` off the path: `PATH="/usr/bin:/bin:/usr/sbin:/sbin"`. On this machine `openspec` lives under the nvm node directory, so this removes it. Add a guard assertion `check "openspec CLI absent in copy" 1 sh -c 'command -v openspec'`. With the CLI absent, completion condition 4 relies on the recorded `OpenSpec verify:` line in `review.md` (`completion-gate.sh` lines 326–335).
- The copy is not a git repository. `delivery.sh` must not depend on git.
- Write a stub `SPECS.md` with:
  - `# EPIC-1:` containing `### US-1.1` (READY, a `Tasks:` list of two `- [ ]` items), `### US-1.2` (READY) and `### US-1.3` (READY). This is the multi-story epic.
  - `# EPIC-2:` containing `### US-2.1` (NEEDS CLARIFICATION).
  - `# EPIC-3:` containing `### US-3.1` (READY, `Dependencies:` `- US-3.2`) and `### US-3.2` (READY, not DONE). This is the dependency on an unfinished story.
  - `# EPIC-4:` containing `### US-4.1` (DONE, `Change:` pointing at `openspec/changes/archive/2026-09-24-us-4-1-x/`) and `### US-4.2` (IN PROGRESS, `Change:` pointing at the active `openspec/changes/us-4-2-x/`). These cover the `mark-done`/`complete` and next-action paths.

**§A: Scenario: Resolve an epic into its stories (2.1)**

- `check "resolve epic exits 0" 0 scripts/delivery.sh resolve EPIC-1`
- `expect_contains` for each of `US-1.1`, `US-1.2`, `US-1.3`.
- An order assertion: `scripts/delivery.sh resolve EPIC-1 | grep -oE 'US-1\.[0-9]+' | tr '\n' ' '` equals `US-1.1 US-1.2 US-1.3 `.
- Distinct change ids: count the unique change-id column values and require 3.
- A negative check that no EPIC-2 story leaks into the EPIC-1 output.

**§B: Scenario: Resolve a task to its parent story (2.2)**

- `resolve 'US-1.1#2'` names `US-1.1`.
- `resolve '<text of US-1.1 task 1>'` names `US-1.1`.
- After `start 'US-1.1#2'`, `expect_contains "| Focus | <task 2 text> |" cat openspec/delivery/goal.md` and `expect_contains "| Kind | task |"`.
- `resolve 'US-1.1#9'` is an out-of-range task index and exits non-zero (overlaps with §C).

**§C: Scenario: Reject an unknown target (2.3)**

- `check "unknown epic" 1 scripts/delivery.sh resolve EPIC-99` and `expect_contains "names target" "EPIC-99"`.
- The same for `US-9.9` and for nonsense task text.
- `rm -f openspec/delivery/goal.md; scripts/delivery.sh start US-9.9` exits non-zero, then `check "no goal recorded" 1 test -e openspec/delivery/goal.md`.
- `start` over an existing goal with an unknown target leaves the previous `goal.md` byte-identical (`cmp`).

**§D: Scenario: Derive the next action from repository artifacts (2.4)**

Start a goal on `US-4.2`, stage the change directory step by step, and after each step use `expect_contains` on `scripts/delivery.sh next` for `Action:`, `Owner:` and `Command:`:

| Staged state | Expected action / owner |
|---|---|
| `specs/` missing | `propose` / planner |
| no `implementation-plan.md` (copy the `scripts/fixtures/plans/valid/` plan once proposal, specs and tasks exist) | `plan` / planner |
| an unticked task | `implement` / implementer |
| all tasks ticked, no `review.md` | `review` / reviewer |
| `scripts/fixtures/reviews/blocking/review.md` | `reopen` / product-manager |
| valid review, no `test-report.md` | `test` / tester |
| `scripts/fixtures/test-reports/failing/test-report.md` | `reopen` / product-manager |
| valid review with its `OpenSpec verify: VERIFIED` line, valid test report | `archive` / product-manager |
| the same with the `OpenSpec verify:` line deleted, so completion is not eligible without the CLI | `escalate` / human Product Manager |
| a `CODEBASE.md` added with no `CODEBASE Context:` marker, so gate 7 fails | `escalate` |

The "derived, never stored" check: hand-edit `goal.md`'s `Action:` line to `archive` while gates are failing, then assert `next` still reports the gate-derived action.

Terminal states:

- Move the change directory to `openspec/changes/archive/2026-09-24-us-4-2-x` while the story is still IN PROGRESS: expect `mark-done`.
- Set every EPIC-4 story to DONE: expect `complete`.
- With a second, unrelated active change directory present: expect `escalate` (design §5).

**§E: Scenario: Escalate a story that cannot proceed (2.5)**

- Goal `EPIC-2`: `next` reports `Action: escalate` and a `Reason:` containing `NEEDS CLARIFICATION`.
- Goal `US-3.1`: `next` reports `escalate` and a reason naming `US-3.2`.
- For both, snapshot `find openspec/changes -maxdepth 1 -mindepth 1 -type d | sort` before and after and compare with `cmp`, so no change directory was created.

**§F: Scenario: Reopen a change after a failed review or acceptance test (2.6)**

Review failure:

- Copy in the blocking review fixture and run `scripts/delivery.sh reopen --change us-4-2-x`.
- `check "review preserved" 0 test -f openspec/changes/us-4-2-x/history/review-r1.md`.
- `check "review moved" 1 test -e .../review.md`.
- `cmp` the history file against the fixture (preserved byte for byte).
- `grep -c '^- \[ \] R1\.'` on `tasks.md` equals 2, one per `### Finding F-n`.
- `expect_contains` for the text of each `Remediation:` line.
- `next` reports `implement` / implementer.

Test failure:

- Re-tick all tasks and add a valid review plus the failing test-report fixture, then `reopen`.
- `history/test-report-r2.md` exists, and `history/review-r2.md` exists because a test failure also moves `review.md`.
- `grep -c '^- \[ \] R2\.'` equals 1, for `### Criterion 1`.
- The task text contains the `Expected:` line.
- `next` reports `implement`.
- Round numbering does not overwrite r1.

Negative cases:

- `reopen` on a change whose review passes exits non-zero and modifies nothing, checked by `cmp` of `tasks.md`.
- `reopen` never creates `review.md` or `test-report.md`.

**Harness-wide checks:**

```bash
scripts/test-delivery.sh
scripts/test-write-scope.sh && scripts/test-guards.sh && scripts/test-status.sh && scripts/test-completion.sh
node scripts/check-frontmatter.js
scripts/validate-product-artifacts.sh
openspec validate us-12-1-resolve-delivery-target-report --strict
node -e 'JSON.parse(require("fs").readFileSync(".claude/settings.json","utf8"))'
bash -n scripts/delivery.sh && bash -n scripts/test-delivery.sh
```

For the `openspec validate` step, read the printed output rather than trusting the exit code (see Risks).

The `.gitignore` entry is checked by inspection and with `git check-ignore -v openspec/delivery/loop.state`.

Expected test artifacts: `scripts/test-delivery.sh`, and the stub `SPECS.md` generated inside it (not committed as a fixture).

## Dependencies

- US-3.2, US-9.1 and US-10.1 are DONE (awk probe of `SPECS.md`). They provide the `workflow-status.sh` gate JSON, the `status.sh` AUTHORED-marker pattern, and the `completion-gate.sh` JSON and condition 4.
- `scripts/workflow-status.sh --json` output shape: gate detail strings `review.md reports blocking findings`, `review.md missing`, `test-report.md reports FAIL` and `test-report.md missing` (lines 318–338). `delivery.sh` branches on these.
- `scripts/completion-gate.sh --json` output shape (`"eligible"`, `"firstFailingCondition"`). It exits 1 when not eligible, which `delivery.sh` must tolerate.
- The review and test-report fixture shapes (`### Finding F-n:` … `Remediation:`; `### Criterion n —` … `Expected:`), read from `scripts/fixtures/reviews/blocking/review.md` and `scripts/fixtures/test-reports/failing/test-report.md`.
- No external dependencies beyond bash, awk, grep, sed and POSIX coreutils (NFR-001). `node` is used only for the JSON sanity check, which the harness already relies on via `check-frontmatter.js`.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| The scripts directory is harness control surface. `scripts/check-write-scope.sh` sets `IS_PRODUCT_CODE=0` for anything under it (line 154), so the implementer role is BLOCKED from writing `scripts/delivery.sh` and `scripts/test-delivery.sh` in this repository. `README-OPENSPEC-COMMANDS.md` §4.5 documents the same block for `scripts/status.sh`. | high | medium | Do the implementation in the main session and record that fact in `review.md` handoff context and `SPEC-LOGS/`, as EPIC-2…EPIC-10 did. Do not weaken `check-write-scope.sh`. Confirm the diff with `scripts/check-scope.sh --plan openspec/changes/us-12-1-resolve-delivery-target-report/implementation-plan.md`. |
| `check-scope.sh` diffs against `HEAD` plus untracked files. The working tree already has many uncommitted or untracked files (`git status`: `PRD.md`, `README.md`, `SPECS.md`, `.claude/agents/`, `CLAUDE.md`, …), so they would be reported as unpredicted. | high | medium | Before implementing, capture a baseline: `{ git diff --name-only HEAD; git ls-files --others --exclude-standard; } \| sort -u > "$TMPDIR/baseline.txt"`. Afterwards pass only the new entries (`comm -13`) via `--diff`. Workflow artifacts in the change directory (`status.md`, `review.md`, `test-report.md`) are other roles' outputs and should be excluded from the Implementer's delta. |
| BSD sed has no `\|` alternation or `\?` in BRE. | high | medium | Use `awk` or `grep -E` for alternation and optional matches. Keep sed to simple `s///`. |
| Bash 3.2 on macOS lacks `mapfile`/`readarray`, associative arrays and `${v^^}`. Under `set -u`, `"${arr[@]}"` on an empty array raises "unbound variable". | high | medium | Use newline-delimited strings with `while IFS= read -r`, indexed arrays only, and `tr '[:lower:]' '[:upper:]'`. Guard empty arrays with `${arr[@]+"${arr[@]}"}` or avoid arrays. |
| `grep -c` exits 1 on zero matches, which breaks `set -e` pipelines and conditionals. | high | low | Always write `V=$(grep -c … \|\| true); V=${V:-0}`, as `workflow-status.sh` and `completion-gate.sh` do. |
| Multi-byte characters such as the em-dash (`—`) in awk/sed bracket expressions turn into byte ranges. The failing test-report fixture heading is `### Criterion 1 — Analyze …`. | high | medium | Extract identifiers with `grep -oE '^### Criterion [0-9]+'` and `grep -oE '^### Finding F-[0-9]+'`. Split on literal strings with `index()` or awk `sub()` without bracket classes, following the note at `status.sh` lines 236–240. |
| `openspec validate` exit codes are unreliable: it exits 0 even when it reports errors (`completion-gate.sh` lines 277–279). | high | medium | In the harness-wide checks, read the printed result or `--json` output instead of the exit code. In the suite, keep `openspec` off `PATH` so the result does not depend on the CLI. |
| `delivery.sh` depends on `workflow-status.sh` detail wording to tell "missing" from "blocking/FAIL" at the review and testing gates. A later wording change would silently change the mapping. | medium | medium | Match stable substrings (`blocking findings`, `reports FAIL`) in one helper function. §D in `test-delivery.sh` exercises every branch, so a wording change fails the suite. |
| `completion-gate.sh --json` exits 1 when not eligible. Wrapping it in `$(…) \|\| …` would discard the JSON, the fail-open trap described at `completion-gate.sh` lines 268–272. | medium | high | Capture the output and exit code separately (`OUT=$(…); RC=$?`) and parse `"eligible"` from `OUT`. |
| The design does not say how to derive a change id for a story with no `Change:` line. | medium | low | Use the `Change:` line when present, taking the basename and stripping any `YYYY-MM-DD-` archive prefix. Otherwise derive `us-<n>-<m>-<slug-of-title>`, the convention seen in all 20 archived changes. The scenario only requires that each story maps to its own id, which §A asserts. |
| Task-text targets may match several tasks, or the same text in two stories. | low | medium | Fail closed: exit non-zero and name the ambiguity instead of picking one (NFR-005 default in `design.md` §3). Record this choice in the script's usage text so the Product Manager can override it. |
| The exit codes of `delivery.sh` are an external contract, but `design.md` does not list them. | medium | low | Follow the harness convention seen in `workflow-status.sh` and `test-status.sh`: 0 success, 1 unknown target / not found / refused, 2 usage error. Document them in the header and `--help`. |
| Task 1.7 maps to a scenario only indirectly: no Then clause names `.claude/settings.json` or `.gitignore`. | low | low | Keep the change to allow-list entries and one ignore line, as `proposal.md` Impact requires. Check it by inspection and `git check-ignore`. |
| Gate 7 in the throwaway copy calls `validate-product-artifacts.sh` if present, and the stub `SPECS.md` would fail its full contract, so every "archive" case would become "escalate". | medium | medium | Leave that validator out of the copy (see Test Strategy). Drive the acceptance-failure case through a `CODEBASE.md` without the context marker. |
| Scope creep into `scripts/README.md`, `CLAUDE.md` or `README.md` to document the new scripts. | medium | low | Documentation belongs to US-12.3. Leave those files alone; `check-scope.sh` would flag them. |

## Open Questions

- None.