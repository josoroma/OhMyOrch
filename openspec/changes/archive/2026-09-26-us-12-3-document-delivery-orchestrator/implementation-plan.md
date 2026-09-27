# Implementation Plan — us-12-3-document-delivery-orchestrator

Story: US-12.3
Change: us-12-3-document-delivery-orchestrator

## Selected Story

US-12.3 — Document the Delivery Orchestrator. `SPECS.md` line 1385 records it as `Status: IN PROGRESS`, with `Change: openspec/changes/us-12-3-document-delivery-orchestrator/`, under `# EPIC-12: Goal-Driven Delivery Orchestration` (line 1217). It is the last story of EPIC-12. Its source is `PRD.md` FR-019 (line 265) and the human Product Manager decision of 2026-09-24.

This change documents US-12.1 and US-12.2. It adds no behaviour. Both dependencies are `Status: DONE`, and both are archived:

- `openspec/changes/archive/2026-09-24-us-12-1-resolve-delivery-target-report/`
- `openspec/changes/archive/2026-09-26-us-12-2-run-delivery-goal-loop/`

`scripts/delivery.sh resolve EPIC-12` confirms the state: US-12.1 DONE, US-12.2 DONE, US-12.3 IN PROGRESS. `scripts/delivery.sh next` returns `Action: plan`, `Owner: planner`.

`CODEBASE.md` is absent (greenfield), so nothing was consumed.

The two acceptance scenarios, verbatim from `SPECS.md`:

```gherkin
Scenario: README explains goal-driven delivery
  Given a developer opens README.md
  When the developer looks up how to deliver an epic, story, or task
  Then it MUST explain the delivery command for each target kind
  And it MUST explain every way the loop stops
  And it MUST explain how an interrupted goal resumes
```

```gherkin
Scenario: Contracts and indexes list the orchestrator
  Given CLAUDE.md, .claude/rules/README.md, and scripts/README.md
  When a developer inspects them
  Then each MUST reference the delivery skill, the delivery-loop rule, or the delivery scripts it indexes
```

## OpenSpec Artifacts

- `proposal.md` establishes the scope:
  - a goal-driven delivery section in `README.md`, plus updates to its cookbook, script inventory, guard table and suite listing;
  - references to the orchestrator in `CLAUDE.md`, `.claude/rules/README.md`, `.claude/agents/README.md` and `scripts/README.md`;
  - a new `SPEC-LOGS/README-EPIC-12.md`;
  - one tightened assertion in `scripts/test-delivery.sh`, carried over from US-12.2 review observation O-1.

  Out of scope: any behaviour change to `delivery.sh`, `guard-delivery-loop.sh` or any gate, and documentation of other epics beyond keeping the shared tables accurate.
- `specs/harness-documentation/spec.md` is a delta with two ADDED requirements, "README explains goal-driven delivery" and "Contracts and indexes list the orchestrator". Each has one scenario that matches `SPECS.md` word for word. The canonical `openspec/specs/harness-documentation/spec.md` currently holds three US-11.1 requirements (installation, brownfield flow, resumption). The delta adds to them and does not change them.
- `tasks.md` has 10 unticked tasks. Tasks 1.1–1.7 are deliverables. Tasks 2.1–2.3 are Implementer checks. Each task already names a scenario.
- `design.md` is absent. No external contract changes, and the proposal does not call for one.
- `status.md` is derived. It shows `State PLANNED` and `owner planner`, with gate 3 (`plan-handoff`) failing because `implementation-plan.md` is missing. The Implementer does not write it.

## Implementation Order

1. **Measure before writing (supports every task).** Re-run the counts listed under Test Strategy §C. Documentation that cites counts must cite measured ones. The Planner's measurements are recorded there as a baseline.
2. **Task 2.1: `scripts/test-delivery.sh` O-1 assertion.** Do this first because it changes the `test-delivery.sh` case count that the README and `scripts/README.md` will cite: 165 now, likely 166 afterwards.
3. **Task 1.5: `scripts/README.md`.** This is the reference for the three delivery scripts. The README inventory (task 1.2) summarises it, so it comes before the README.
4. **Task 1.4: `.claude/rules/README.md`.** Add the index row and the rule-to-gate rows. The README guard table (task 1.2) and `CLAUDE.md` (task 1.3) point to it.
5. **Task 1.6: `.claude/agents/README.md`.** Describe the `/deliver` orchestration.
6. **Tasks 1.1 and 1.2: `README.md`.**
   1. Add the new goal-driven delivery section and renumber the sections after it.
   2. Update §18 (Resume), §19 (Cookbook), §23, §24 (inventory, guards, suites, troubleshooting), the layout tree, and §17's stale counts.
   3. Finish with the cross-reference `see §24` on line 116.
7. **Task 1.3: `CLAUDE.md`.** Update the workflow, the document map and the validation commands. It depends on the rule index and README section names chosen in steps 4 and 6.
8. **Task 1.7: `SPEC-LOGS/README-EPIC-12.md`.** Write the epic record last, because it cites the final counts, the deliverables of this change, and the archived US-12.1 and US-12.2 evidence.
9. **Tasks 2.2 and 2.3: run the checks** in Test Strategy §A and §B. Then run the full harness regression (§D).

## Task to Acceptance Mapping

| Task | Acceptance criterion | Notes |
|---|---|---|
| 1.1 Add a goal-driven delivery section to `README.md` (commands per target kind, every stop condition, resume) | Scenario: README explains goal-driven delivery | This task carries all three `Then`/`And` clauses. **Target kinds:** `EPIC-N`, `US-N.M`, `US-N.M#k`, and `"task text"`, taken from `delivery.sh --help` "Targets:" and the `deliver` SKILL Step 0 table. **Ways the loop stops:** the four halts in SKILL Step 3 and `delivery-loop.md` "The loop stops only for a reason it records", plus the Claude Code override after 8 blocks (see Test Strategy §A). **Resume:** `/deliver <same target>` or `scripts/delivery.sh start <same target>` resumes a BLOCKED or STOPPED goal, and completed stories are never redone. |
| 1.2 Update the `README.md` cookbook, resume section, script inventory, guard table and suite list | Scenario: README explains goal-driven delivery | "how an interrupted goal resumes" needs §18 Resume to mention the goal record. The other edits keep the shared tables accurate, which the proposal requires. |
| 1.3 Reference the orchestrator in `CLAUDE.md` (workflow, document map, validation commands) | Scenario: Contracts and indexes list the orchestrator | `CLAUDE.md` is named in the `Given`. Today it has 0 matches for `delivery.sh`, `guard-delivery-loop`, `test-delivery`, `/deliver`, `delivery-loop` and `goal.md`. |
| 1.4 Index `delivery-loop.md` in `.claude/rules/README.md` (index plus rule-to-gate mapping) | Scenario: Contracts and indexes list the orchestrator | `.claude/rules/README.md` is named in the `Given`. Today it has 0 matches for the same terms. |
| 1.5 Index `delivery.sh`, `guard-delivery-loop.sh` and `test-delivery.sh` in `scripts/README.md` | Scenario: Contracts and indexes list the orchestrator | `scripts/README.md` is named in the `Given`. Today it has 0 matches for the same terms. |
| 1.6 Add the `/deliver` orchestration to `.claude/agents/README.md` | Scenario: Contracts and indexes list the orchestrator | This file is **not** one of the three the scenario names. The task comes from the `SPECS.md` US-12.3 task list ("Update … `.claude/agents/README.md` …"), so the mapping is by task list and not by the `Then`. The Tester should score the scenario against the three named files only. |
| 1.7 Write `SPEC-LOGS/README-EPIC-12.md` | Scenario: README explains goal-driven delivery | This is a `SPECS.md` US-12.3 task. It is explanatory material and neither scenario checks it directly. `CLAUDE.md` lists `SPEC-LOGS/README-EPIC-N.md` as a document type, so its existence can be checked, but its content is judged by inspection (see Open Questions). |
| 2.1 Tighten "one attempt is singular" in `scripts/test-delivery.sh` so it also asserts that "1 stop attempts" is absent (US-12.2 review r2 O-1) | Scenario: README explains goal-driven delivery | `tasks.md` maps it this way, but no clause of either US-12.3 scenario requires it. The proposal carries it as a follow-up because US-12.2 was already archived. It is recorded under Open Questions, not treated as unmapped, because the proposal and `tasks.md` state it on purpose. |
| 2.2 Every command in the new README section runs as documented (`--help`, `resolve`, `next`) | Scenario: README explains goal-driven delivery | Keeps the documented "delivery command for each target kind" honest. See Test Strategy §A. |
| 2.3 `grep` evidence that each of the three indexes references the orchestrator | Scenario: Contracts and indexes list the orchestrator | This is the scenario's `Then`, checked mechanically. See Test Strategy §B. |

All 10 tasks are mapped, and none is unmapped. Tasks 1.6, 1.7 and 2.1 support the story's task list and proposal, but neither scenario's `Then` requires them. They are raised under Open Questions so the Tester does not treat them as acceptance evidence.

## Affected Files

| Path | Expected change | Evidence |
|---|---|---|
| `README.md` | **New section.** Likely placed as `## 18. Goal-Driven Delivery — an Epic, Story, or Task`, inserted before the current `## 18. Resume Work in a New Claude Session` (line 736), right after §17 Archive's "What archival leaves behind" (ends line 734). Current §18–§25 are renumbered to §19–§26. The only in-file numeric cross-reference is line 116 (`# the executable harness (see §24)`), which becomes `§25`. **§17 (lines 718–729):** "every story in `SPECS.md` is `DONE`" is false today (22 of 23 stories are DONE), and "The 20 capabilities" is stale (22 specs). **§18 Resume (lines 736–772):** add the goal record (`openspec/delivery/goal.md`), `scripts/delivery.sh next`, and `/deliver <same target>`. **§19 Cookbook (lines 774–874):** add "Deliver an epic, story, or task" after "Start or resume one backlog story" (line 827). **§23 "This harness adds" (lines 1098–1111):** add a goal-driven delivery bullet. **§24 inventory (lines 1123–1147):** add `delivery.sh`, `guard-delivery-loop.sh` and `test-delivery.sh` (21 → 24 scripts). **§24 guards (lines 1166–1179):** "six hooks" becomes eight, with two new rows. **§24 suites (lines 1184–1203):** add `test-delivery.sh`, change `22 definitions` to 23, and change `openspec validate --all  # 20 archived-change specs` to the measured spec count. **§24 troubleshooting (lines 1205–1215):** add rows for delivery. **Layout tree (lines 106–143):** add `deliver/SKILL.md` under skills, `delivery-loop.md` under rules, and `openspec/delivery/goal.md`. | Read the full outline (`grep -n '^#' README.md`) and lines 1–160, 490–530 and 700–1225. `grep -c` for each delivery term returns 0. `grep -n '§'` finds only line 116. The inventory gap was checked by looping `ls scripts/*` against the table: `delivery.sh`, `guard-delivery-loop.sh` and `test-delivery.sh` are missing. The hook count was measured from `.claude/settings.json` with `node` (8). |
| `CLAUDE.md` | **Workflow (after line 67, "Deliver one bounded change at a time"):** a short "Goal-driven delivery" paragraph. `/deliver <EPIC-N \| US-N.M \| US-N.M#k \| "task text">` runs the per-story workflow above once per story, in `SPECS.md` order. The next action is derived by `scripts/delivery.sh next`. Rules are in `.claude/rules/delivery-loop.md`. **Document map (lines 22–34):** add an `openspec/delivery/goal.md` row (the durable delivery-goal record, derived by `scripts/delivery.sh`; normative for nothing, it is a record). **Validation commands (lines 113–119):** add `scripts/test-delivery.sh` to the `&&` chain. Consider `openspec validate --all --strict`, which is what the harness actually runs. | Read the whole file (141 lines). `grep` returns 0 delivery references. Line 29 "`README-OPENSPEC-COMMANDS.md` … the 20 stories" is **still accurate**: that file has 0 `US-12`/`EPIC-12` mentions, so it records only the 20 original stories. Leave it unless the Product Manager decides otherwise. |
| `.claude/rules/README.md` | **Index (lines 9–16):** add a row: `delivery-loop.md` \| goal-driven delivery: targets, derived next action, delegation by owner, recorded stop conditions \| FR-019, US-12.2, BR-002. **Rule-to-gate mapping (lines 29–36):** add rows. "Keep working while the goal is ACTIVE" maps to `scripts/guard-delivery-loop.sh` via `Stop`. "Orchestrator never authors a verdict" maps to `scripts/guard-delivery-loop.sh` via `PreToolUse`. "The next action is derived" maps to `scripts/delivery.sh next`. These three rows come from the `delivery-loop.md` "Enforcement" table. | Read the whole file (41 lines). `ls .claude/rules/` shows `delivery-loop.md` exists but is not indexed. |
| `scripts/README.md` | **Top table (lines 5–26):** add `delivery.sh` (US-12.1, US-12.2 for `block`), `guard-delivery-loop.sh` (US-12.2) and `test-delivery.sh` (US-12.1, US-12.2). `guard-story-done.sh` is **also missing** from this table and should be added (US-10.1). **Line 31**, "none modifies state", is stale: `status.sh`, `completion-gate.sh --record` and `delivery.sh start\|refresh\|reopen\|stop\|block` all write records. **New section** appended after `## test-completion.sh` (file ends line 1182), for example `## Goal-driven delivery (US-12.1, US-12.2)`, with `### delivery.sh`, `### guard-delivery-loop.sh` and `### test-delivery.sh`. Take the usage, targets, actions and exit codes from `--help`. Include the Stop and PreToolUse modes and their fail-open cases, and the `loop.state` stall counter (git-ignored, `.gitignore` line 20). | Read lines 1–35, 630–680 and 990–1182, and grepped the headings. The table-gap loop above found `guard-story-done.sh` present in `README.md` but absent here. Line 637, "Four scripts … The first three are wired", describes the US-8.2 set and stays correct if the delivery guard is documented in its own section. |
| `.claude/agents/README.md` | Add a `## Goal-driven delivery (/deliver)` section between "Hook-enforced separation of duties" (ends line 65) and `## Conventions` (line 67). It covers: `/deliver` runs as the Product Manager in the **main session**; it delegates `plan` to `planner`, `implement` to `implementer`, `review` to `reviewer` and `test` to `tester` subagents; `product-manager.md` holds the "Goal-driven delivery (US-12.2)" section (line 212); and a `product-manager` subagent has no write-scope hook, so PM actions are not delegated to it. | Read the whole file (76 lines). `grep -n '^## ' .claude/agents/product-manager.md` shows line 212. The limitation comes from `.claude/rules/delivery-loop.md` "Known limits of the verdict guard". |
| `SPEC-LOGS/README-EPIC-12.md` | New file following the `README-EPIC-11.md` structure. **Header table:** Epic, Stories, Status, OpenSpec changes, SPECS.md status, Repository, Starting revision `ae11530`, Date, Claude Code `2.1.128`, OpenSpec `1.13.2`, Spec source (`SPECS.md` lines 1217–1427; `PRD.md` FR-019). **Sections 1–11:** Objective, findings, …, Scope, Step-by-step execution, Deliverables, Acceptance verification, Deviations and decisions, Notes for reuse, Follow-ups. See the guidance below. | Read `README-EPIC-11.md` (469 lines). The EPIC-12 evidence comes from the archived `review.md`, `history/review-r*.md`, `test-report.md` and `completion.md` of US-12.1 and US-12.2 (details below). `check-write-scope.sh --role implementer --file SPEC-LOGS/README-EPIC-12.md` returns exit 0. |
| `scripts/test-delivery.sh` | At line 513, keep the `expect_contains "one attempt is singular" …` check and add an absence check for `1 stop attempts`. **Pitfall:** with `MAXS=0`, the first `stop_hook` call records the goal BLOCKED, so a second `stop_hook` call exits 0 **silently**, and an `expect_absent` on that call would pass vacuously. Either capture one output and assert on it twice, or re-run `scripts/delivery.sh start US-3.2` before the second call. Update the suite total wherever it is cited. | Read lines 1–120, 410–530 and the helpers `expect_contains` (60) and `expect_absent` (68). `plural()` is at `guard-delivery-loop.sh` line 177. `record_block` is at lines 167–175 and clears `loop.state`. The non-ACTIVE early exit is at lines 184–188. |
| `openspec/changes/us-12-3-document-delivery-orchestrator/tasks.md` | Checkbox ticks only. | Gate 4 counts ticks (`0/10 tasks complete`). |

Expected to stay unchanged:

- `scripts/delivery.sh`, `scripts/guard-delivery-loop.sh`, every other script and fixture, `.claude/settings.json`, `.claude/skills/deliver/SKILL.md` and `.claude/rules/delivery-loop.md` (the proposal's §Out of Scope);
- `SPECS.md` (the Product Manager's);
- `README-OPENSPEC-COMMANDS.md`;
- every `SPEC-LOGS/README-EPIC-1..11.md`. Historical records cite the README section numbers of their own time, for example EPIC-11's "§24". Do not renumber them.

**`SPEC-LOGS/README-EPIC-12.md` content guidance (from the archived evidence):**

- **US-12.1** (`2026-09-24-us-12-1-resolve-delivery-target-report`):
  - review round 1 was `changes-requested` with 1 blocking finding (F-1, an archived change bypassing readiness escalation);
  - round 2 was `changes-requested` with 1 blocking finding (F-2, the dependency check running after `change_archived` in `derive_next`);
  - round 3 was `approved`;
  - acceptance 6/6 PASS (Resolve an epic; Resolve a task; Reject an unknown target; Derive the next action; Escalate; Reopen);
  - completion 15/15 tasks, 4/4 conditions pass.
- **US-12.2** (`2026-09-26-us-12-2-run-delivery-goal-loop`):
  - review round 1 `pass`, no blocking findings;
  - round 2 `pass`, with observations O-1 to O-5 (O-1 is carried into this change as task 2.1);
  - acceptance 6/6 PASS;
  - completion 17/17 tasks, 4/4 conditions pass;
  - suite 165/0.
- **Process note** (both reviews, O-1/O-5): `scripts/` and `.claude/` are harness control surface. The `implementer` subagent cannot write there, so the main session implemented, and the Reviewer was the independent check.
- **Carried observations worth listing under Follow-ups:**
  - US-12.1 O-5 to O-8 (empty `firstIncompleteGate` path, `Target` not sanitised, cwd message, `-` placeholder in the reason);
  - US-12.2 O-2 (wording) and O-4 (live-session hook evidence verified only by running the wired commands directly).
- **US-12.3's own row** must not claim review or test results the Implementer cannot know. See Open Questions.

## Test Strategy

There is no application test runner. The checks are shell commands run by the Implementer (tasks 2.2 and 2.3) and repeated independently by the Tester. A documentation scenario is partly judged **by inspection**: whether an explanation is clear needs a reader. The mechanical checks below establish presence and accuracy only.

**§A — Scenario: README explains goal-driven delivery (tasks 1.1, 1.2, 2.2)**

- **Section present.** `grep -nE '^## [0-9]+\. .*(Goal|Deliver)' README.md` returns one heading.
- **Delivery command for each target kind.** In that section, each of these appears:
  - `/deliver EPIC-`
  - `/deliver US-` (a story)
  - `#` inside a `/deliver US-N.M#k` example
  - a quoted task-text example
  - the underlying `scripts/delivery.sh resolve <target>` and `start <target>`

  Check by extracting the section with `awk '/^## 18\. /,/^## 19\. /' README.md` (adjust to the final number) and grepping.
- **Every way the loop stops.** The same extracted section names:
  - `COMPLETE` (every story `DONE`);
  - `BLOCKED` on `escalate`, for example NEEDS CLARIFICATION, BLOCKED, an unfinished dependency, or another active change (from `derive_next`'s `escalate` branches, `delivery.sh` lines 318–426);
  - `BLOCKED` "no progress" after `DELIVERY_MAX_STALLS` (default 3) unchanged stop attempts, with `--max-stalls`;
  - `STOPPED` through `scripts/delivery.sh stop`;
  - the failure to derive the goal, which is recorded BLOCKED ("the goal could not be derived", `guard-delivery-loop.sh` line 230).

  The section SHOULD also mention Claude Code's override after 8 consecutive Stop blocks. It is not a way the *loop* records a stop, but a reader must know it exists. It is listed in `delivery-loop.md`'s known limits. Record what is covered, and let the Tester judge completeness against `delivery-loop.md`'s stop table.
- **Resume.** The section, or §19 Resume, names `/deliver <same target>` or `scripts/delivery.sh start <same target>`, that `BLOCKED`/`STOPPED` resume to `ACTIVE`, that completed stories are not redone, and `scripts/delivery.sh next` as the read-only "where am I" command.
- **Commands run as documented (task 2.2).** Run these read-only commands in this repository:
  - `scripts/delivery.sh --help` (exit 0)
  - `scripts/delivery.sh resolve EPIC-12` (exit 0, three stories)
  - `scripts/delivery.sh resolve US-12.3` (exit 0)
  - `scripts/delivery.sh resolve 'US-12.3#1'` (exit 0, `Kind: task`)
  - `scripts/delivery.sh resolve EPIC-99` (exit 1, `unknown target`)
  - `scripts/delivery.sh next` (exit 0)
  - `scripts/guard-delivery-loop.sh --help` (exit 0)

  The Planner ran all seven and observed those results. **Do not run `start`, `stop` or `block` in this repository.** They rewrite `openspec/delivery/goal.md`, which is the live `ACTIVE` EPIC-12 goal. Show those commands in a throwaway copy (`mktemp -d`, as `test-delivery.sh` does), or rely on `test-delivery.sh`, which covers them.
- **Counts are accurate.** Every number the README cites matches §C when re-measured after task 2.1.

**§B — Scenario: Contracts and indexes list the orchestrator (tasks 1.3–1.6, 2.3)**

```bash
for f in CLAUDE.md .claude/rules/README.md scripts/README.md; do
  printf '%-26s %s\n' "$f" "$(grep -cE '/deliver|delivery-loop|delivery\.sh|guard-delivery-loop|test-delivery' "$f")"
done
```

Each count must be greater than 0. Before the change, all three are 0 (measured). Additional checks:

- `.claude/agents/README.md` for `/deliver` (task 1.6; not part of the scenario);
- `grep -F 'delivery-loop.md' .claude/rules/README.md` (index row);
- `grep -F 'guard-delivery-loop.sh' .claude/rules/README.md` (rule-to-gate row);
- `grep -cE '^\| \`(delivery|guard-delivery-loop|test-delivery)\.sh\`' scripts/README.md` equals 3 (top table).

**§C — Baseline counts measured by the Planner (2026-09-26, before any change)**

| Check | Measured |
|---|---|
| `scripts/test-delivery.sh` | passed 165, failed 0 (expect 166 if task 2.1 adds one case) |
| `scripts/test-write-scope.sh` | passed 36, failed 0 |
| `scripts/test-guards.sh` | passed 38, failed 0 |
| `scripts/test-status.sh` | passed 46, failed 0 |
| `scripts/test-completion.sh` | passed 63, failed 0 |
| `node scripts/check-frontmatter.js` | 23 definitions OK (8 agents, 15 skills), `RESULT: PASS` |
| `openspec validate --all --strict` | 23 passed, 0 failed (22 specs plus this active change). After archive: 22 specs |
| `ls openspec/specs \| wc -l` | 22 capability specs |
| `ls openspec/changes/archive \| wc -l` | 22 archived changes (23 after this one) |
| `.claude/settings.json` hooks | 8: PostToolUse ×2, PreToolUse `Write\|Edit\|MultiEdit` ×4, PreToolUse `Bash` ×1, `Stop` ×1 |
| `scripts/` executables | 24 (23 `.sh`, 1 `.js`) |
| `SPECS.md` stories | 23, of which 22 are `DONE` |
| `scripts/validate-product-artifacts.sh --quiet` | exit 0 |

**§D — Full harness regression (after all edits)**

```bash
scripts/test-write-scope.sh && scripts/test-guards.sh && scripts/test-status.sh \
  && scripts/test-completion.sh && scripts/test-delivery.sh
node scripts/check-frontmatter.js
scripts/validate-product-artifacts.sh
openspec validate us-12-3-document-delivery-orchestrator --strict   # read the printed result, not only the exit code
openspec validate --all --strict
```

Also run `scripts/check-scope.sh` against this plan with the changed-file list, to catch edits outside the predicted files.

## Dependencies

- **US-12.1 and US-12.2 (DONE, archived).** Their scripts, skill, rule and hook wiring are what this change documents. They must not be altered here.
- **The documented interfaces as they stand today:**
  - `scripts/delivery.sh --help` (commands `resolve`, `start`, `next`, `refresh`, `reopen`, `stop`, `block`; actions `select` … `complete`; exit codes 0/1/2);
  - `scripts/guard-delivery-loop.sh --help` (Stop and PreToolUse modes, `--max-stalls`, `DELIVERY_MAX_STALLS`; exit codes 0/2/3);
  - `.claude/skills/deliver/SKILL.md`;
  - `.claude/rules/delivery-loop.md`;
  - `.claude/settings.json` (`Stop` and the fourth `PreToolUse` entry).
- **Task 2.1 comes before any published `test-delivery.sh` count.**
- **Tooling:** bash 3.2, BSD grep/awk, `node` (frontmatter and hook counts), OpenSpec CLI 1.13.2.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Write scope.** `check-write-scope.sh --role implementer` returns exit 2 for `README.md`, `CLAUDE.md`, `.claude/rules/README.md`, `scripts/README.md` and `scripts/test-delivery.sh`, which are harness control surface (lines 151–155). Only `SPEC-LOGS/README-EPIC-12.md` is allowed (exit 0, measured). The `implementer` subagent therefore cannot write most deliverables. | high | medium | As in US-12.1 and US-12.2, the main session implements and the Reviewer records it. Do not weaken `check-write-scope.sh`. |
| **The live delivery goal.** `openspec/delivery/goal.md` is `ACTIVE` for EPIC-12, and the `Stop` hook is wired. Running `delivery.sh start`, `stop` or `block` to produce README examples would change the real goal. The Stop hook also keeps the session working. | high | medium | Take example output from `--help`, `resolve` and `next` only, or from a `mktemp -d` copy. The PreToolUse verdict guard blocks main-session writes to `review.md` and `test-report.md`, so review and test must run as `reviewer` and `tester` subagents. |
| **Renumbering breaks cross-references.** Inserting a section moves §18–§25. | medium | low | The only in-file reference is line 116 (`see §24`). Other harness docs have no README `§` references (grepped outside `archive/` and `SPEC-LOGS/`). Historical EPIC records keep their original numbers on purpose. An alternative that avoids renumbering is a `### Goal-driven delivery` subsection under §10, but a top-level section is easier for a reader looking it up. The Implementer chooses and records the choice. |
| **Stale or self-invalidating counts.** §17 says every story is `DONE` (false: 22/23). The README cites 20 specs (there are 22), 22 definitions (there are 23), six hooks (there are 8) and 21 scripts (there are 24). `test-delivery.sh` moves from 165 to 166 with task 2.1. | high | medium | Re-measure after task 2.1 and cite measured numbers. Word §17 so it stays true after US-12.3 is archived, for example "each DONE story links to its archived change", instead of a claim that holds only at one moment. |
| **Vacuous `expect_absent` in task 2.1.** With `MAXS=0` the first stop records BLOCKED, and a second `stop_hook` prints nothing, so the absence check passes whatever `plural()` does. | high | medium | Assert both needles on one captured output, or restart the goal before the second call. Mutation check: temporarily make `plural()` always append `s`. The new assertion must then fail. Revert the mutation. |
| **Documenting behaviour that is not there.** For example, calling `--quiet` a silencer (it is not; block messages always print), or giving `stop` a `--reason` requirement (it is optional). | medium | medium | Quote `--help` text and the SKILL tables. Tie each README claim to a file. Do not describe future features. |
| **Epic record overclaims.** `README-EPIC-12.md` is written before US-12.3 is reviewed and tested, so a "Complete" status or US-12.3 PASS rows would be unverified claims. | medium | medium | Mark US-12.3 as in delivery at the time of writing, and cite only the archived evidence for US-12.1 and US-12.2. See Open Questions. |
| **`openspec validate` exit codes are unreliable.** | high | low | Read the printed totals. |

## Open Questions

- **Tasks outside the scenarios.** Tasks 1.6 (`.claude/agents/README.md`), 1.7 (`README-EPIC-12.md`) and 2.1 (the O-1 assertion) are in the proposal, `tasks.md` and the `SPECS.md` task list, but no `Then` clause of either US-12.3 scenario requires them. The plan keeps them as the proposal states. The Product Manager should confirm the Tester will score them as supporting work, not as acceptance criteria.
- **Who finalises `README-EPIC-12.md` after archive?** Its header `Status` and the US-12.3 acceptance row can only be accurate after review, test and archive. Should the Implementer leave US-12.3 marked "in delivery", with the Product Manager updating the record after `mark-done`? Or should the record describe the epic only up to the start of US-12.3? The plan assumes the first option and needs a Product Manager decision.
- **`README-OPENSPEC-COMMANDS.md` scope.** It records 20 stories and never mentions EPIC-12, so `CLAUDE.md`'s "the 20 stories" is accurate for that file. Extending it to EPIC-12 is outside this proposal. Is that intended to stay out of scope?
