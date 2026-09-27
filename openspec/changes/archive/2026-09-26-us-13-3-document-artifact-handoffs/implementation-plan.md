# Implementation Plan — us-13-3-document-artifact-handoffs

Story: US-13.3
Change: us-13-3-document-artifact-handoffs

## Selected Story

US-13.3 — Document Every Artifact Handoff Between Roles. `SPECS.md` line 2111 records
it as `Status: IN PROGRESS`, with `Change:
openspec/changes/us-13-3-document-artifact-handoffs/`, under `# EPIC-13: Backlog
Navigation and Structure`. Its declared dependency is US-13.2 (`SPECS.md` line 2125),
`Status: DONE` and archived at
`openspec/changes/archive/2026-09-26-us-13-2-document-orchestrator-loop/`.

This change is documentation only. It extends `README.md` §19 ("The Orchestrator Loop
and the Plan Handoff") with a subsection that covers **every** artifact handoff — the
proposal, the plan, the implementation, the review, and the acceptance evidence — plus
a diagram of the handoffs, and adds regression cases to `scripts/test-guards.sh`. It
changes no script, agent, skill, or rule. If the documentation reveals a defect in a
handoff or a gate, that is a finding to record, not a file to change (proposal
§Out of Scope).

`scripts/delivery.sh next` returns `Action: plan`, `Owner: planner`, `Reason: gate
plan-handoff: implementation-plan.md missing`. `scripts/workflow-status.sh --change
us-13-3-document-artifact-handoffs` reports `First incomplete gate: plan-handoff` and
`0/6 tasks complete`.

`CODEBASE.md` is absent (greenfield), so nothing was consumed.

The three acceptance scenarios, verbatim from `SPECS.md`:

```gherkin
Scenario: README explains every artifact handoff
  Given a developer opens README.md
  When the developer looks up how work passes between the roles
  Then it MUST explain the handoff for the proposal, the plan, the implementation, the review, and the acceptance evidence
  And for each handoff it MUST name the artifact, the role that writes it, and the role that reads it
```

```gherkin
Scenario: README shows the handoffs as a diagram
  Given a developer opens README.md
  When the developer looks up how work passes between the roles
  Then it MUST show the handoffs as a diagram
  And the diagram MUST show the change directory as the medium
```

```gherkin
Scenario: README explains the mechanical gate on each handoff
  Given a developer opens README.md
  When the developer reads how a handoff is enforced
  Then it MUST name the gate that blocks the next role until the artifact exists
  And it MUST explain that a failing verdict returns work to the Implementer
```

## OpenSpec Artifacts

- `proposal.md` establishes the scope: `README.md` §19 gains a subsection covering
  every artifact handoff and a diagram of the handoffs; `scripts/test-guards.sh` gains
  regression cases. Out of scope: changing any handoff, gate, or agent; replacing the
  plan-handoff subsection (it stays, and the new subsection generalises it).
- `specs/harness-documentation/spec.md` is a delta with one ADDED requirement — "README
  explains every artifact handoff between roles" — carrying the three scenarios above,
  matching `SPECS.md` word for word.
- `tasks.md` has 6 unticked tasks. Tasks 1.1–1.3 are deliverables; tasks 2.1–2.3 are
  Implementer regression cases. Each task already names a scenario.
- `design.md` is absent. The proposal does not call for one; the shape is fully
  specified by the delta spec and the guidance below.
- `status.md` is derived. It shows `State PLANNED` and `owner planner`, with gate 3
  (`plan-handoff`) failing because `implementation-plan.md` is missing. The Implementer
  does not write it.

## Implementation Order

1. **Task 1.1: extend `README.md` §19 with the handoff subsection.** Do this first. It
   is the prose the diagram (task 1.2) illustrates and the gate explanation (task 1.3)
   completes. Insert it at the end of §19, after the plan-handoff subsection and before
   §20. The subsection names, for each of the five handoffs, the artifact, the writer,
   and the reader (the `Then`/`And` of Scenario: README explains every artifact handoff).
2. **Task 1.2: add the handoff diagram** inside the new subsection. It depends on task
   1.1 because the diagram's nodes are the artifacts and roles the prose names, and the
   `And` requires the change directory shown as the medium.
3. **Task 1.3: explain the gate on each handoff and the return path** inside the new
   subsection, after the diagram. It depends on task 1.1 for its place and on the
   verified facts in Test Strategy §C.
4. **Tasks 2.1–2.3: the regression cases** in `scripts/test-guards.sh`. Add them after
   the deliverables so each asserts the final README. Add a new section after the
   US-13.2 section (ends line 335) and before the Summary block (line 337).
5. **Run the full harness regression** (Test Strategy §E) and re-measure the
   `test-guards.sh` case count, which `README.md` cites twice (lines 1443, 1496).

## Task to Acceptance Mapping

| Task | Acceptance criterion | Notes |
|---|---|---|
| 1.1 Extend README.md §19 with a subsection covering every artifact handoff: artifact, writer, reader, gate | Scenario: README explains every artifact handoff | The `Then` requires all five handoffs (proposal, plan, implementation, review, acceptance evidence); the `And` requires the artifact, writer, and reader named for each. |
| 1.2 Add a diagram of the artifact handoffs, showing the change directory as the medium | Scenario: README shows the handoffs as a diagram | The `Then` requires a diagram; the `And` requires the change directory shown as the medium. |
| 1.3 Explain the gate on each handoff and the return path on a failing verdict | Scenario: README explains the mechanical gate on each handoff | The `Then` requires the gate named per handoff; the `And` requires the failing-verdict return path to the Implementer. |
| 2.1 Regression case for Scenario: README explains every artifact handoff | Scenario: README explains every artifact handoff | Implementer-owned. Asserts the subsection exists and names each artifact, writer, and reader. |
| 2.2 Regression case for Scenario: README shows the handoffs as a diagram | Scenario: README shows the handoffs as a diagram | Implementer-owned. Asserts a `mermaid` block exists and names the change directory as the medium. |
| 2.3 Regression case for Scenario: README explains the mechanical gate on each handoff | Scenario: README explains the mechanical gate on each handoff | Implementer-owned. Asserts each gate name appears and the return path is explained. |

All 6 tasks are mapped, and none is unmapped.

## Affected Files

| Path | Expected change | Evidence |
|---|---|---|
| `README.md` | **Insert a new `###` subsection at the end of §19, after line 1012 and before `## 20. Resume Work in a New Claude Session` (line 1014).** It covers the five handoffs (artifact, writer, reader, gate), contains a `mermaid` handoff diagram showing `openspec/changes/<change-id>/` as the medium, and explains the return path. **Update the two cited `test-guards.sh` case counts** (line 1443 `(85 cases)` and line 1496 `# 85 cases`) to the re-measured value. | Read lines 7–200, 896–1015, 1426–1512. §19 spans lines 896–1012; its two existing `###` subsections are "The loop" (line 901) and "How the plan reaches the Implementer" (line 958). §20 begins at line 1014. The TOC (lines 7–45) lists numbered sections only, so a new `###` subsection needs no TOC change. |
| `scripts/test-guards.sh` | **Add a new section** "US-13.3 — README artifact handoffs" after the US-13.2 section (ends line 335) and before the Summary block (line 337), with three cases (tasks 2.1–2.3). Use the existing `check` and `expect_contains` helpers. | Read lines 1–120 and 225–345. Helpers: `check <label> <expected-exit> <command...>` (line 32), `expect_contains <label> <needle> <command...>` (line 50). The US-13.2 section sets `README="$ROOT/README.md"` (line 301) and reads it directly, which is the pattern to follow. |
| `openspec/changes/us-13-3-document-artifact-handoffs/tasks.md` | Checkbox ticks only. | Gate 4 counts ticks (`0/6 tasks complete`). |

Expected to stay unchanged:

- `.claude/agents/`, `.claude/skills/`, `.claude/rules/`, `scripts/workflow-status.sh`,
  `scripts/completion-gate.sh`, `scripts/guard-planning-handoff.sh`,
  `scripts/guard-archive.sh`, `scripts/delivery.sh` — the proposal's §Out of Scope. This
  change documents them; it does not change them.
- `scripts/README.md` — its `test-guards.sh` row (line 13) cites no case count, so the
  re-measured count does not touch it.
- `PRD.md`, `CLAUDE.md`, `.claude/settings.json`, and every other script and fixture.

## Test Strategy

There is no application test runner. The checks are shell commands run by the Implementer
(tasks 2.1–2.3) and repeated independently by the Tester. One clause is partly judged
**by inspection**: whether the diagram *renders* needs a reader. The mechanical checks
below establish presence, completeness, and accuracy only.

**§A — Scenario: README explains every artifact handoff (tasks 1.1, 2.1)**

- The new subsection exists: `grep -n '^### ' README.md` shows a heading between line
  958 and line 1014.
- It names all five artifacts: `proposal.md`, `implementation-plan.md`, the
  implementation (product code + ticked `tasks.md`), `review.md`, `test-report.md`.
- It names each writer and reader. The verified pairs are in §C below; a name that
  disagrees with the cited file and line is a documentation defect.

**§B — Scenario: README shows the handoffs as a diagram (tasks 1.2, 2.2)**

- The subsection contains a `mermaid` fenced block, and the block is closed.
- The diagram shows the change directory as the medium: the string
  `openspec/changes/<change-id>/` appears inside the diagram (as a `subgraph` label or
  node), matching the existing plan-handoff diagram at README line 963.
- The diagram's nodes are the five artifacts and the roles that write and read them.

**§C — Scenario: README explains the mechanical gate on each handoff (tasks 1.3, 2.3)**

Every claim the subsection makes was verified against the code, not against prose. The
verified handoff table the Implementer must reproduce:

| Handoff | Artifact | Writer | Reader | Gate that blocks the reader | Verified from |
|---|---|---|---|---|---|
| proposal → planner | `proposal.md`, `specs/`, `tasks.md`, `design.md` | planner (`/opsx:propose`) | planner (`/plan-feature`) | gate 2 `planning` | `.claude/skills/openspec-propose/SKILL.md` lines 18–21 (the artifact set); `.claude/agents/planner.md` lines 40–49 ("Required inputs"); `scripts/workflow-status.sh` line 16 (gate 2 comment), line 265 (`GATE_NAMES`), line 281 (`GATE_OWNER[1]="planner (via /opsx:propose)"`), lines 283–291 (gate 2 fails unless `proposal.md`, `specs/`, `tasks.md` exist) |
| plan → implementer | `implementation-plan.md` | planner (`/plan-feature`) | implementer (`/opsx:apply`) | gate 3 `plan-handoff` | `.claude/skills/plan-feature/SKILL.md` lines 14–18, 92 (writes `openspec/changes/<change-id>/implementation-plan.md`); `.claude/agents/implementer.md` lines 43–63 ("Required inputs", "Gate 3 (`plan-handoff`) must be `pass`"); `scripts/workflow-status.sh` line 17, line 297 (`GATE_OWNER[2]="planner (/plan-feature)"`); `scripts/guard-planning-handoff.sh` lines 11, 144, 150 (PreToolUse hook, exit 2) |
| implementation → reviewer | product code, tests, ticked `tasks.md` | implementer (`/opsx:apply`) | reviewer (`/review-feature`) | gate 4 `implementation` (every task ticked) | `.claude/agents/implementer.md` lines 22–40 (allowed write scope: product code, tests, `tasks.md` checkboxes); `.claude/agents/reviewer.md` lines 43–54 ("Required inputs": proposal, delta specs, design, tasks, implementation-plan, acceptance criteria, the diff); `scripts/workflow-status.sh` line 18, line 306 (`GATE_OWNER[3]="implementer (/opsx:apply)"`), lines 299–305 (gate 4 passes only when `TASKS_DONE = TASKS_TOTAL`) |
| review → tester | `review.md` | reviewer (`/review-feature`) | tester (`/test-feature`) | gate 5 `review` | `.claude/agents/reviewer.md` lines 33–35 ("You may write exactly one artifact — `review.md`"), line 83; `.claude/agents/tester.md` lines 91–101 ("Required preflight", "Gate 5 (`review`) must be passing"); `scripts/workflow-status.sh` line 19, line 321 (`GATE_OWNER[4]="reviewer (/review-feature)"`), lines 308–320 (gate 5 fails on missing/blocking/unknown review) |
| acceptance evidence → product manager | `test-report.md` | tester (`/test-feature`) | product-manager (archive decision) | gate 6 `testing`, and `guard-archive.sh` | `.claude/agents/tester.md` lines 3, 108 ("Exactly one artifact: `test-report.md`"); `scripts/completion-gate.sh` lines 8–11 and line 134 (`COND_SOURCE=(tasks.md review.md test-report.md "openspec validate")`) — the four conditions and their sources; `scripts/workflow-status.sh` line 20, line 335 (`GATE_OWNER[5]="tester (/test-feature)"`), lines 323–334 (gate 6 fails on missing/FAIL report); `scripts/guard-archive.sh` lines 1–20 (delegates the verdict to `workflow-status.sh`, rejects archival when not eligible) |
| return path | failing `review.md` / `test-report.md` → `history/<artifact>-r<round>.md` | product-manager (`scripts/delivery.sh reopen`) | implementer (remediation tasks) | — | `scripts/delivery.sh` `do_reopen` lines 578–650: line 615 `mv "$cdir/review.md" "$cdir/history/review-r$round.md"`, line 618 `mv "$cdir/test-report.md" "$cdir/history/test-report-r$round.md"`, lines 622–641 append one unticked remediation task per finding, line 649 `next owner: implementer (/opsx:apply ...), then reviewer, then tester` |

**The common mechanism.** Every artifact lives in `openspec/changes/<change-id>/`, and
`scripts/workflow-status.sh` reports the seven gates in order. The gate list and names
are authoritative at `scripts/workflow-status.sh` lines 15–21 (the gate-order comment)
and line 265 (`GATE_NAMES=(selection planning plan-handoff implementation review testing
acceptance)`). The subsection MUST say this explicitly, because a reader who assumes a
conversational handoff will not understand why a write is rejected.

**The handoff is a file handoff plus a mechanical gate, not a message between agents.**
Each role writes a file into the change directory; the next role reads that file; and a
gate blocks the next role until the artifact exists. The plan-handoff subsection already
states this for the plan (README lines 958–961); the new subsection generalises it.

**§D — The regression cases (tasks 2.1–2.3)**

- Task 2.1: `expect_contains` for the new subsection heading, for each of the five
  artifacts, and for each writer/reader role name.
- Task 2.2: `expect_contains` for a `mermaid` block and for `openspec/changes/<change-id>/`
  inside the subsection.
- Task 2.3: `expect_contains` for each gate name (`planning`, `plan-handoff`,
  `implementation`, `review`, `testing`), for `guard-archive.sh`, and for the return path
  (`history/`).
- Mutation check: temporarily remove one artifact name from the subsection and confirm
  task 2.1's assertion fails; revert.

**§E — Full harness regression (after all edits)**

```bash
scripts/test-write-scope.sh && scripts/test-guards.sh && scripts/test-status.sh \
  && scripts/test-completion.sh && scripts/test-delivery.sh
node scripts/check-frontmatter.js
scripts/validate-product-artifacts.sh
openspec validate us-13-3-document-artifact-handoffs --strict   # read the printed result
openspec validate --all --strict
```

Also run `scripts/check-scope.sh --plan openspec/changes/us-13-3-document-artifact-handoffs/implementation-plan.md`
against the changed-file list, to catch edits outside the predicted files.

**§F — The README edits do not break the existing parsers (evidence, not a test)**

- `scripts/guard-context-preflight.sh` and `scripts/validate-product-artifacts.sh` react to
  `PRD.md`/`SPECS.md`/`CODEBASE.md`, not `README.md`.
- `scripts/delivery.sh` `parse_specs` reads `SPECS.md` only. A Mermaid line starting with a
  node id matches none of its anchors.
- Confirm by running `scripts/delivery.sh next` after the edits and checking the story and
  task counts are unchanged.

## Dependencies

- **US-13.2 (DONE, archived).** It created §19 and its two subsections. This change
  extends the same section and must not contradict or duplicate them.
- **The documented interfaces as they stand today:**
  - `.claude/skills/openspec-propose/SKILL.md` — the artifact set (lines 18–21);
  - `.claude/agents/planner.md` — "Required inputs" (lines 40–49);
  - `.claude/skills/plan-feature/SKILL.md` — Step 5 (line 92);
  - `.claude/agents/implementer.md` — "Required inputs" (lines 43–63);
  - `.claude/agents/reviewer.md` — "Required inputs" (lines 43–54);
  - `.claude/agents/tester.md` — "Required preflight" (lines 91–101);
  - `scripts/workflow-status.sh` — the seven gates (lines 15–21, 265, 270–344);
  - `scripts/completion-gate.sh` — the four conditions and sources (lines 8–11, 134);
  - `scripts/guard-planning-handoff.sh` — the block branch (lines 144–150);
  - `scripts/guard-archive.sh` — the archival rejection (lines 1–20);
  - `scripts/delivery.sh` — `do_reopen` (lines 578–650);
  - `scripts/test-guards.sh` — the `check` and `expect_contains` helpers (lines 32, 50).
- **Task 1.1 comes before tasks 1.2 and 1.3**, because the prose names the artifacts and
  roles the diagram and the gate explanation depend on.
- **Tooling:** bash 3.2, BSD grep/awk, `node` (frontmatter), OpenSpec CLI 1.13.2.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Write scope.** `check-write-scope.sh --role implementer` returns exit 2 for `README.md` and `scripts/test-guards.sh`, which are harness control surface. The `implementer` subagent therefore cannot write either deliverable. | high | medium | As in US-12.1–US-12.4, US-13.1, and US-13.2, the main session implements and the Reviewer records it. Do not weaken `check-write-scope.sh`. |
| **Pre-existing `test-guards.sh` failures.** The suite currently reports `passed: 82, failed: 3` — the US-13.1 cases "the TOC lists every story", "the status table lists every work item", and "the diagram draws every declared dependency" fail because `SPECS.md` now contains US-13.3, which is not yet in the TOC, the status table, or the dependency diagram. | high | medium | These are **not** caused by this change's deliverables and are **not** in its scope to fix. Record them as a finding for the Product Manager (the US-13.1 navigation structure is stale for US-13.3). Do not edit `SPECS.md` — that is the Product Manager's file. The new US-13.3 cases must pass on their own; report the three pre-existing failures separately. |
| **The new subsection duplicates the plan-handoff subsection.** §19 already explains the plan handoff in prose and diagram (lines 958–1012). | medium | medium | The new subsection's job is the *other four* handoffs and the *general* mechanism; cross-reference the plan-handoff subsection rather than restating it. |
| **Documenting behaviour that is not there.** For example, claiming a gate blocks *all* writes, or that a handoff is a message between agents. | medium | high | Every claim in the subsection is backed by the file and line in Test Strategy §C. |
| **Stale `test-guards.sh` count.** `README.md` cites the count twice (lines 1443, 1496). Adding three cases changes it. | medium | low | Re-measure after the edits and update both citations. Note that the sample output block (line 1508) reads `passed: 38` while the prose cites 85 — an existing inconsistency; align it or record it as a finding. |
| **`openspec validate` exit codes are unreliable.** | high | low | Read the printed totals. |

## Open Questions

- **The three pre-existing `test-guards.sh` failures.** `SPECS.md` contains US-13.3 but
  its TOC, status table, and dependency diagram do not, so three US-13.1 cases fail. This
  is outside this change's scope (it is a `SPECS.md` edit, which belongs to the Product
  Manager). The plan assumes the Implementer records it as a finding and does not fix it.
  If the Product Manager wants it fixed within this change, that must be stated before
  implementation, because it would widen the affected files to `SPECS.md`.
- **The new subsection's title.** The plan assumes a `###` heading such as "Every artifact
  handoff" placed at the end of §19. The scenario requires the content, not a specific
  title. If a different title is preferred, that is a presentation decision.
- **Diagram style.** The plan assumes `flowchart LR` for the handoff diagram, matching the
  existing plan-handoff diagram (README line 963). The scenario requires *a* diagram, not a
  specific type. If a `sequenceDiagram` is preferred, that is a presentation decision.
