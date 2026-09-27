# Implementation Plan — us-12-4-delivery-loop-followups

Story: US-12.4
Change: us-12-4-delivery-loop-followups

## Selected Story

US-12.4 — Close the Delivery Loop Follow-Ups. `SPECS.md` line 1429 records it as
`Status: IN PROGRESS`, with `Change: openspec/changes/us-12-4-delivery-loop-followups/`,
under `# EPIC-12: Goal-Driven Delivery Orchestration`. It is the last story of EPIC-12.
Its source is the US-12.2 review observations O-1/O-2/O-3, the US-12.3 review
observations O-1–O-4, and the human Product Manager decision of 2026-09-26.

This change closes four follow-ups: three documentation-accuracy corrections and one
small behaviour gap. It adds no new capability. Its dependencies are US-12.1, US-12.2
and US-12.3, all `Status: DONE` and archived:

- `openspec/changes/archive/2026-09-24-us-12-1-resolve-delivery-target-report/`
- `openspec/changes/archive/2026-09-26-us-12-2-run-delivery-goal-loop/`
- `openspec/changes/archive/2026-09-26-us-12-3-document-delivery-orchestrator/`

`scripts/delivery.sh next` returns `Action: plan`, `Owner: planner`, `Reason: gate
plan-handoff: implementation-plan.md missing`. `scripts/workflow-status.sh --change
us-12-4-delivery-loop-followups` reports `First incomplete gate: plan-handoff`.

`CODEBASE.md` is absent (greenfield), so nothing was consumed.

The four acceptance scenarios, verbatim from `SPECS.md`:

```gherkin
Scenario: The stall limit is described accurately
  Given README.md and .claude/rules/delivery-loop.md describe the no-progress stop
  When a developer reads the stall limit
  Then the documentation MUST state that the stop is allowed after the configured number of blocked stop attempts
  And it MUST name the default and the override
```

```gherkin
Scenario: Every escalation cause is documented
  Given README.md lists the reasons the loop halts for a human decision
  When a developer reads that list
  Then it MUST include the gate reporter failing to report
  And it MUST include an unmapped gate
```

```gherkin
Scenario: Stop records a halt when the target no longer resolves
  Given a recorded goal whose target no longer resolves in SPECS.md
  When the goal is stopped
  Then the goal MUST be recorded as STOPPED
  And the command MUST exit zero
```

```gherkin
Scenario: The script index describes the archive guard accurately
  Given scripts/README.md indexes guard-archive.sh
  When a developer reads that row
  Then it MUST state that the guard checks the completion conditions
  And it MUST cite US-8.2 and US-10.1
```

## OpenSpec Artifacts

- `proposal.md` establishes the scope: four corrections — the stall-limit wording in
  `README.md` §18 and `.claude/rules/delivery-loop.md`; two missing escalation causes in
  `README.md` §18; the `delivery.sh stop` fallback; and the `guard-archive.sh` row in
  `scripts/README.md`. Out of scope: any change to the Stop hook's decision logic, the
  stall limit itself, the gate chain, or `guard-archive.sh` behaviour. Only its index row
  is corrected.
- `specs/delivery-target/spec.md` is a delta with one ADDED requirement, "Stop records a
  halt when the target no longer resolves", with one scenario matching `SPECS.md` word
  for word.
- `specs/harness-documentation/spec.md` is a delta with two ADDED requirements, "The
  stall limit is described accurately" and "Every escalation cause is documented", each
  with one scenario matching `SPECS.md` word for word.
- `tasks.md` has 8 unticked tasks. Tasks 1.1–1.4 are deliverables; tasks 2.1–2.4 are
  Implementer regression cases. Each task already names a scenario.
- `design.md` is absent. No external contract changes, and the proposal does not call for
  one.
- `status.md` is derived. It shows `State PLANNED` and `owner planner`, with gate 3
  (`plan-handoff`) failing because `implementation-plan.md` is missing. The Implementer
  does not write it.

## Implementation Order

1. **Task 1.3: `scripts/delivery.sh` `stop` fallback.** Do the behaviour change first.
   It is the only code change, and task 2.1's regression case depends on it. It also
   determines the wording the docs may claim about `stop`.
2. **Task 1.1: stall-limit wording** in `.claude/rules/delivery-loop.md` and `README.md`
   §18. The rule file is the normative statement; the README summarises it. Fix the rule
   first, then mirror it in the README.
3. **Task 1.2: the two missing escalation causes** in `README.md` §18. Same table as
   task 1.1, so do them together.
4. **Task 1.4: the `guard-archive.sh` row** in `scripts/README.md`. Independent of the
   others.
5. **Tasks 2.1–2.4: the regression cases** in `scripts/test-delivery.sh`. Add them after
   the deliverables so each asserts the final wording and behaviour. Task 2.1 must be
   written against the fallback shape chosen in step 1.
6. **Run the full harness regression** (Test Strategy §D) and re-measure the
   `test-delivery.sh` case count, which `scripts/README.md` cites.

## Task to Acceptance Mapping

| Task | Acceptance criterion | Notes |
|---|---|---|
| 1.1 Correct the stall-limit wording in `README.md` §18 and `.claude/rules/delivery-loop.md`; name the default and the override | Scenario: The stall limit is described accurately | Carries all three clauses. The `Then` requires "after the configured number of blocked stop attempts"; the `And` requires the default (`3`) and the override (`--max-stalls <n>` / `DELIVERY_MAX_STALLS`). Both files are named in the `Given`, so both must change. |
| 1.2 Add the two missing escalation causes to `README.md` §18 | Scenario: Every escalation cause is documented | The `Then` requires "the gate reporter failing to report"; the `And` requires "an unmapped gate". Both are `derive_next` `escalate` branches in `scripts/delivery.sh` (lines ~404 and ~426). |
| 1.3 Make `delivery.sh stop` record the halt when the target no longer resolves | Scenario: Stop records a halt when the target no longer resolves | The `Then` requires `Status: STOPPED`; the `And` requires exit zero. Today `stop` calls `load_goal`, which `die`s (exit 1) when the target no longer resolves. |
| 1.4 Correct the `guard-archive.sh` row in `scripts/README.md` | Scenario: The script index describes the archive guard accurately | The `Then` requires "checks the completion conditions"; the `And` requires citing `US-8.2` and `US-10.1`. Today the row says "Reject archive while any workflow gate is incomplete" and cites only `US-8.2`. |
| 2.1 Regression case for Scenario: Stop records a halt when the target no longer resolves | Scenario: Stop records a halt when the target no longer resolves | Implementer-owned. Asserts `stop` exits 0 and records `STOPPED` when the recorded target no longer resolves. |
| 2.2 Regression case for Scenario: The stall limit is described accurately (the wording is asserted, not just present) | Scenario: The stall limit is described accurately | Implementer-owned. Asserts the corrected phrase and the default/override names appear in both files, and that the old "across N stop attempts" phrasing is gone. |
| 2.3 Regression case for Scenario: Every escalation cause is documented | Scenario: Every escalation cause is documented | Implementer-owned. Asserts the README §18 escalation row names both causes. |
| 2.4 Regression case for Scenario: The script index describes the archive guard accurately | Scenario: The script index describes the archive guard accurately | Implementer-owned. Asserts the `guard-archive.sh` row states the completion conditions and cites both story ids. |

All 8 tasks are mapped, and none is unmapped.

## Affected Files

| Path | Expected change | Evidence |
|---|---|---|
| `scripts/delivery.sh` | **`stop)` case (lines ~745–750).** Give it the same in-place fallback `block)` already has (lines ~760–782): when the recorded target no longer resolves, rewrite only the `Status`, `Reason`, and `Updated` rows of `goal.md` in place, with `Status` set to `STOPPED`, and exit 0. Keep `rm -f "$LOOP_STATE"` and the `--reason` default. | Read the whole file. `stop)` calls `load_goal` (line ~700), which calls `resolve_target "$TARGET" \|\| die "recorded target '$TARGET' no longer resolves"` — a non-zero exit. `block)` already solves this with a subshell probe `( resolve_target "$TARGET" ) >/dev/null 2>&1` and an `awk` rewrite of the three rows. The `stop` fallback mirrors that shape. |
| `.claude/rules/delivery-loop.md` | **Stop-condition table (line 53).** Change "derived state unchanged across `DELIVERY_MAX_STALLS` (default 3) stop attempts" to state the stop is allowed **after** the configured number of **blocked** stop attempts, naming the default and the override. | Read lines 40–60. Line 53 is the only stall-limit statement in the file. The guard allows the stop when `COUNT > MAX_STALLS` (`guard-delivery-loop.sh` line ~271), so the stop is allowed on attempt N+1, after N blocked attempts. |
| `README.md` | **§18 "Every way the loop stops" table (lines 820–833).** (a) The no-progress row (line 831): reword to "after `DELIVERY_MAX_STALLS` (default 3) blocked stop attempts", naming `--max-stalls` as the override. (b) The `escalate` row (line 830): add the two missing causes — the gate reporter could not report, and an unmapped gate. | Read lines 800–880. Line 831 is the only stall-limit statement; line 830 lists five causes but omits the two `derive_next` branches at `delivery.sh` lines ~404 ("the gate reporter could not report") and ~426 ("unmapped gate '$first'"). |
| `scripts/README.md` | **Top table, `guard-archive.sh` row (line 25).** Change the purpose to state it checks the completion conditions, and change the `Implements` cell from `US-8.2` to `US-8.2, US-10.1`. | Read lines 1–35. Line 25 reads "Reject archive while any workflow gate is incomplete \| US-8.2". `guard-archive.sh` defers to `completion-gate.sh` (the four US-10.1 conditions) and reports the gate chain alongside it; its own header cites US-8.2 and its body cites US-10.1. |
| `scripts/test-delivery.sh` | **US-12.2 sections.** Add the four regression cases (tasks 2.1–2.4). Task 2.1 belongs in "Halt for a human decision" (near the existing "an underivable goal allows the stop" case, line ~560). Tasks 2.2–2.4 are documentation assertions; add a small new section, for example "Documentation accuracy (US-12.4)". Update the suite total wherever it is cited. | Read lines 1–120, 405–620. Helpers: `check` (line 51), `expect_contains` (line 60), `expect_absent` (line 68), `expect_eq` (line 76), `stop_hook` (line 415). The existing "an underivable goal allows the stop" case drives the **Stop hook**, not `delivery.sh stop`; task 2.1 must call `scripts/delivery.sh stop` directly. |
| `openspec/changes/us-12-4-delivery-loop-followups/tasks.md` | Checkbox ticks only. | Gate 4 counts ticks (`0/8 tasks complete`). |

Expected to stay unchanged:

- `scripts/guard-delivery-loop.sh` — the proposal's §Out of Scope. Only its wording is
  described in the docs; its logic and the stall limit do not change.
- `scripts/guard-archive.sh` — only its index row is corrected.
- `SPECS.md` (the Product Manager's), `CLAUDE.md`, `.claude/settings.json`, and every
  other script and fixture.

## Test Strategy

There is no application test runner. The checks are shell commands run by the
Implementer (tasks 2.1–2.4) and repeated independently by the Tester. Two scenarios are
partly judged **by inspection**: whether the corrected wording is clear needs a reader.
The mechanical checks below establish presence and accuracy only.

**§A — Scenario: Stop records a halt when the target no longer resolves (tasks 1.3, 2.1)**

In a throwaway copy (as `test-delivery.sh` stages), record a goal, then rewrite its
`Target` to a story that does not exist and set `Status: ACTIVE`:

```bash
scripts/delivery.sh start US-3.2
sed 's/^| Target | .*/| Target | US-9.9 |/; s/^| Status | .*/| Status | ACTIVE |/' \
  openspec/delivery/goal.md > g && cp g openspec/delivery/goal.md
scripts/delivery.sh stop; echo "exit=$?"
grep '^| Status |' openspec/delivery/goal.md
```

Expected: exit `0`, and `| Status | STOPPED |`. Also assert the `Target` row is preserved
(`| Target | US-9.9 |`) and the `Reason` row is written. **Do not run `stop` in this
repository**: `openspec/delivery/goal.md` is the live `ACTIVE` EPIC-12 goal. Use a
`mktemp -d` copy, or rely on `test-delivery.sh`.

**§B — Scenario: The stall limit is described accurately (tasks 1.1, 2.2)**

- `grep -n 'blocked stop attempt' README.md .claude/rules/delivery-loop.md` returns a
  match in each file.
- Each file names the default (`3`) and the override (`--max-stalls` and/or
  `DELIVERY_MAX_STALLS`).
- `grep -n 'across .* stop attempts' README.md .claude/rules/delivery-loop.md` returns
  nothing (the old phrasing is gone).
- The wording is asserted, not merely present: the case must fail if the phrase reverts.
  Mutation check: temporarily restore "across `DELIVERY_MAX_STALLS` (default 3) stop
  attempts" and confirm the new assertion fails; revert.

**§C — Scenario: Every escalation cause is documented (tasks 1.2, 2.3)**

- In the README §18 `escalate` row, `grep -F 'gate reporter' README.md` and
  `grep -Fi 'unmapped gate' README.md` each return a match.
- Cross-check against `scripts/delivery.sh`: the two `escalate` branches are "the gate
  reporter could not report (exit $wrc)" and "unmapped gate '$first'". The README wording
  must correspond to both.

**§D — Scenario: The script index describes the archive guard accurately (tasks 1.4, 2.4)**

- `grep -n 'guard-archive.sh' scripts/README.md` shows the top-table row (line 25).
- The row's purpose states it checks the completion conditions.
- The row's `Implements` cell cites both `US-8.2` and `US-10.1`.

**§E — Full harness regression (after all edits)**

```bash
scripts/test-write-scope.sh && scripts/test-guards.sh && scripts/test-status.sh \
  && scripts/test-completion.sh && scripts/test-delivery.sh
node scripts/check-frontmatter.js
scripts/validate-product-artifacts.sh
openspec validate us-12-4-delivery-loop-followups --strict   # read the printed result
openspec validate --all --strict
```

Also run `scripts/check-scope.sh` against this plan with the changed-file list, to catch
edits outside the predicted files.

## Dependencies

- **US-12.1, US-12.2 and US-12.3 (DONE, archived).** Their scripts, skill, rule and hook
  wiring are what this change corrects. They must not be altered here.
- **The documented interfaces as they stand today:**
  - `scripts/delivery.sh --help` (commands `resolve`, `start`, `next`, `refresh`,
    `reopen`, `stop`, `block`; exit codes 0/1/2);
  - `scripts/guard-delivery-loop.sh --help` (Stop and PreToolUse modes, `--max-stalls`,
    `DELIVERY_MAX_STALLS`; exit codes 0/2/3);
  - `scripts/guard-archive.sh` (defers to `completion-gate.sh`; cites US-8.2 and US-10.1);
  - `.claude/rules/delivery-loop.md`.
- **Task 1.3 comes before task 2.1**, and before any doc claim about `stop`'s fallback.
- **Tooling:** bash 3.2, BSD grep/awk, `node` (frontmatter), OpenSpec CLI 1.13.2.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Write scope.** `check-write-scope.sh --role implementer` returns exit 2 for `README.md`, `.claude/rules/delivery-loop.md`, `scripts/README.md` and `scripts/test-delivery.sh`, which are harness control surface. The `implementer` subagent therefore cannot write most deliverables. | high | medium | As in US-12.1, US-12.2 and US-12.3, the main session implements and the Reviewer records it. Do not weaken `check-write-scope.sh`. |
| **The live delivery goal.** `openspec/delivery/goal.md` is `ACTIVE` for EPIC-12, and the `Stop` hook is wired. Running `delivery.sh stop` to produce evidence would change the real goal. | high | medium | Exercise `stop` only in a `mktemp -d` copy, or rely on `test-delivery.sh`. The PreToolUse verdict guard blocks main-session writes to `review.md` and `test-report.md`, so review and test must run as `reviewer` and `tester` subagents. |
| **The `stop` fallback diverges from `block`.** A hand-rolled rewrite could drop the `Target`/`Started`/`Notes` rows or mis-handle a missing `goal.md`. | medium | medium | Mirror `block`'s shape: a subshell probe, then an `awk` rewrite of only `Status`, `Reason`, `Updated`. Keep the `[ -f "$GOAL" ]` guard so a missing goal still `die`s. Assert the `Target` row survives in task 2.1. |
| **Stall-limit wording is still wrong.** "after N blocked stop attempts" must match the guard: the stop is allowed on attempt N+1. | medium | medium | State it as "the stop is allowed after N blocked stop attempts" and name the default (3) and the override (`--max-stalls <n>` / `DELIVERY_MAX_STALLS`). Do not restate the old "across N stop attempts". |
| **Documenting behaviour that is not there.** For example, claiming `stop` now derives a next action, or that the escalation list is exhaustive beyond the two added causes. | medium | medium | Quote `--help` and the `derive_next` branches. Add only the two causes the scenario names. |
| **Stale `test-delivery.sh` count.** `scripts/README.md` cites `166` cases; adding four cases changes it. | high | low | Re-measure after the edits and update the cited count in `scripts/README.md`. |
| **`openspec validate` exit codes are unreliable.** | high | low | Read the printed totals. |

## Open Questions

- **Task 2.2's assertion strength.** The scenario says the wording is "asserted, not just
  present". The plan reads this as: the case must fail if the phrase reverts, and must
  also assert the old phrasing is absent. If the Product Manager intends a stronger
  contract (for example a shared constant), that is a larger change than this proposal
  describes. The plan assumes the mutation-check reading.
- **Where the documentation regression cases live.** Tasks 2.2–2.4 assert on `README.md`,
  `.claude/rules/delivery-loop.md` and `scripts/README.md`, which `test-delivery.sh` does
  not currently read. The plan adds a small "Documentation accuracy (US-12.4)" section to
  `test-delivery.sh`. An alternative is a separate suite. The plan assumes the former,
  since the proposal lists `scripts/test-delivery.sh` as the only test file affected.
