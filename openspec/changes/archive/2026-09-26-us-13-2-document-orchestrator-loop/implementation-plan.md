# Implementation Plan — us-13-2-document-orchestrator-loop

Story: US-13.2
Change: us-13-2-document-orchestrator-loop

## Selected Story

US-13.2 — Document the Orchestrator Loop and the Plan Handoff. `SPECS.md` line 2041
records it as `Status: IN PROGRESS`, with `Change:
openspec/changes/us-13-2-document-orchestrator-loop/`, under `# EPIC-13: Backlog
Navigation and Structure`. Its declared dependencies are US-11.1 and US-12.3, both
`Status: DONE` and archived:

- `openspec/changes/archive/2026-09-24-us-11-1-team-readme/`
- `openspec/changes/archive/2026-09-26-us-12-3-document-delivery-orchestrator/`

This change is documentation only. It adds a table of contents to `README.md`, adds a
section that explains the orchestrator loop and the plan-to-implement handoff with
diagrams, and adds regression cases to `scripts/test-guards.sh`. It changes no script,
agent, skill, or rule. If the documentation reveals a defect in the loop or the
handoff, that is a finding to record, not a file to change (proposal §Out of Scope).

`scripts/delivery.sh next` returns `Action: plan`, `Owner: planner`, `Reason: gate
plan-handoff: implementation-plan.md missing`. `scripts/workflow-status.sh --change
us-13-2-document-orchestrator-loop` reports `First incomplete gate: plan-handoff` and
`0/7 tasks complete`.

`CODEBASE.md` is absent (greenfield), so nothing was consumed.

The three acceptance scenarios, verbatim from `SPECS.md`:

```gherkin
Scenario: README opens with a table of contents
  Given a developer opens README.md
  When the developer looks for a section
  Then README.md MUST contain a table of contents near the top
  And every numbered section MUST be listed with a link to its heading
```

```gherkin
Scenario: README explains the orchestrator loop
  Given a developer opens README.md
  When the developer looks up how a delivery target is delivered
  Then it MUST name the agents and skills the loop uses at each step
  And it MUST show the loop as a diagram
```

```gherkin
Scenario: README explains the plan-to-implement handoff
  Given a developer opens README.md
  When the developer looks up how the plan reaches the Implementer
  Then it MUST explain that the Planner writes `implementation-plan.md` into the change directory
  And it MUST explain that the Implementer reads that file
  And it MUST explain the mechanical gate that blocks implementation until the plan exists
  And it MUST show the handoff as a diagram
```

## OpenSpec Artifacts

- `proposal.md` establishes the scope: `README.md` gains a table of contents and a
  section explaining the orchestrator loop and the plan handoff; `scripts/test-guards.sh`
  gains regression cases. Out of scope: changing the loop, the agents, the skills, or the
  handoff; a table of contents for any file other than `README.md`.
- `specs/harness-documentation/spec.md` is a delta with two ADDED requirements — "README
  opens with a table of contents" and "README explains the orchestrator loop and the plan
  handoff" — carrying the three scenarios above, matching `SPECS.md` word for word.
- `tasks.md` has 7 unticked tasks. Tasks 1.1–1.4 are deliverables; tasks 2.1–2.3 are
  Implementer regression cases. Each task already names a scenario.
- `design.md` is absent. The proposal does not call for one; the shape is fully specified
  by the delta spec and the guidance below.
- `status.md` is derived. It shows `State PLANNED` and `owner planner`, with gate 3
  (`plan-handoff`) failing because `implementation-plan.md` is missing. The Implementer
  does not write it.

## Implementation Order

1. **Task 1.1: add the table of contents to `README.md`.** Do this first. It enumerates
   every numbered section, so it fixes the final numbering that the new section (task 1.2)
   and the renumbering must agree with. Writing it first prevents the new section from
   being inserted at a number the TOC does not list.
2. **Task 1.2: add the orchestrator-loop section to `README.md`.** Insert it after §18
   (Goal-Driven Delivery) and before the current §19, then renumber the old §19–§26 to
   §20–§27. The section names the agent and skill at each step (the `Then` clause of
   Scenario: README explains the orchestrator loop).
3. **Task 1.3: add the loop diagram** inside the new section. It depends on task 1.2
   because the diagram's nodes are the actions and owners the prose names.
4. **Task 1.4: add the plan-to-implement handoff explanation and diagram** inside the new
   section, after the loop diagram. It depends on task 1.2 for its place in the section
   and on the verified facts in Test Strategy §C.
5. **Tasks 2.1–2.3: the regression cases** in `scripts/test-guards.sh`. Add them after the
   deliverables so each asserts the final README. Task 2.1 asserts the TOC; tasks 2.2 and
   2.3 assert the new section and its diagrams.
6. **Run the full harness regression** (Test Strategy §E) and re-measure the
   `test-guards.sh` case count, which `README.md` cites twice.

## Task to Acceptance Mapping

| Task | Acceptance criterion | Notes |
|---|---|---|
| 1.1 Add a table of contents to `README.md`, listing every numbered section with a link | Scenario: README opens with a table of contents | The `Then` requires a TOC near the top; the `And` requires every numbered section listed with a link to its heading. |
| 1.2 Add a section explaining the orchestrator loop, naming the agent and skill at each step | Scenario: README explains the orchestrator loop | The `Then` requires the agents and skills named at each step. The delegation table in `.claude/skills/deliver/SKILL.md` and the action→owner mapping in `scripts/delivery.sh` are the source of truth. |
| 1.3 Add the loop diagram | Scenario: README explains the orchestrator loop | The `And` requires the loop shown as a diagram. |
| 1.4 Add the plan-to-implement handoff explanation and diagram | Scenario: README explains the plan-to-implement handoff | The three `Then`/`And` clauses require: the Planner writes `implementation-plan.md` into the change directory; the Implementer reads that file; the mechanical gate that blocks implementation until the plan exists. The final `And` requires the handoff as a diagram. |
| 2.1 Regression case for Scenario: README opens with a table of contents | Scenario: README opens with a table of contents | Implementer-owned. Asserts the TOC section exists and that its entry count equals the numbered-heading count. |
| 2.2 Regression case for Scenario: README explains the orchestrator loop | Scenario: README explains the orchestrator loop | Implementer-owned. Asserts the new section exists, names the owners, and contains a `mermaid` block. |
| 2.3 Regression case for Scenario: README explains the plan-to-implement handoff | Scenario: README explains the plan-to-implement handoff | Implementer-owned. Asserts the section names `implementation-plan.md`, the guard, and contains the handoff diagram. |

All 7 tasks are mapped, and none is unmapped.

## Affected Files

| Path | Expected change | Evidence |
|---|---|---|
| `README.md` | **Insert a `## Table of Contents` section after the intro paragraph (line 5) and before `## Why this exists` (line 7).** It lists all 27 numbered sections (26 existing + the new one) as `- [N. Title](#anchor)` links. **Insert a new numbered section after §18 ends (line 861) and before `## 19. Resume Work in a New Claude Session` (line 862).** **Renumber the old §19–§26 to §20–§27** (headings at lines 862, 909, 1026, 1173, 1190, 1235, 1264, 1378). **Update the two cross-references that point at a renumbered section:** line 118 `(see §25)` → `(see §26)`. Lines 115, 727, and 907 point at §18, which does not move. **Update the two cited `test-guards.sh` case counts** (line 1291 `(65 cases)` and line 1344 `# 65 cases`) to the re-measured value. | Read lines 1–163, 560–640, 742–912, 1264–1386. Measured: 26 numbered `^## [0-9]+\. ` headings, no TOC. §18 has four `###` subsections and ends at line 861. §13 (line 574) and §14 (line 601) already describe the plan handoff in prose but do not name the guard or show a diagram. |
| `scripts/test-guards.sh` | **Add a new section** "US-13.2 — README navigation and the orchestrator loop" after the US-13.1 section (ends line ~300) and before the Summary block (line ~302), with three cases (tasks 2.1–2.3). Use the existing `check` and `expect_contains` helpers. | Read lines 1–120 and 180–340. Helpers: `check <label> <expected-exit> <command...>` (line 32), `expect_contains <label> <needle> <command...>` (line 45). The suite stages throwaway dirs under `$WORK` and never modifies the repository; the US-13.1 section reads `$ROOT/SPECS.md` directly, which is the pattern to follow for `$ROOT/README.md`. |
| `openspec/changes/us-13-2-document-orchestrator-loop/tasks.md` | Checkbox ticks only. | Gate 4 counts ticks (`0/7 tasks complete`). |

Expected to stay unchanged:

- `.claude/skills/deliver/SKILL.md`, `.claude/rules/delivery-loop.md`, `scripts/delivery.sh`,
  `scripts/guard-planning-handoff.sh`, `scripts/workflow-status.sh`, `scripts/check-scope.sh`
  — the proposal's §Out of Scope. This change documents them; it does not change them.
- `scripts/README.md` — its `test-guards.sh` row (line 13) cites no case count, so the
  re-measured count does not touch it. Its `README.md §18` reference (line 1205) points at
  §18, which does not move.
- `PRD.md`, `CLAUDE.md`, `.claude/agents/`, `.claude/settings.json`, and every other script
  and fixture.

## Test Strategy

There is no application test runner. The checks are shell commands run by the Implementer
(tasks 2.1–2.3) and repeated independently by the Tester. Two clauses are partly judged
**by inspection**: whether the TOC is *navigable* and whether the diagrams *render* need a
reader. The mechanical checks below establish presence, completeness, and accuracy only.

**§A — Scenario: README opens with a table of contents (tasks 1.1, 2.1)**

- `grep -n '^## Table of Contents' README.md` returns a match, and it appears before the
  first numbered heading.
- The TOC lists every numbered section: the count of TOC entries equals
  `grep -cE '^## [0-9]+\. ' README.md` (27 after the new section is added).
- Every entry is a link: each TOC line matches `^- \[.+\]\(#.+\)$`.
- Spot-check that a link resolves: the anchor for `## 18. Goal-Driven Delivery` is
  `#18-goal-driven-delivery` (lowercase, `.` dropped, spaces to hyphens).

**§B — Scenario: README explains the orchestrator loop (tasks 1.2, 1.3, 2.2)**

- The new section exists and names each owner: `product-manager`, `planner`,
  `implementer`, `reviewer`, `tester`, and the human Product Manager.
- It names the skills: `/opsx:explore`, `/opsx:propose`, `/plan-feature`, `/opsx:apply`,
  `/review-feature`, `/test-feature`.
- It contains a `mermaid` fenced block, and the block is closed.
- The named owners match the delegation table in `.claude/skills/deliver/SKILL.md` Step 2
  and the `derive_next` mapping in `scripts/delivery.sh` (lines 385–425). A name that
  disagrees with either is a documentation defect.

**§C — Scenario: README explains the plan-to-implement handoff (tasks 1.4, 2.3)**

Every claim the section makes was verified against the code, not against prose:

| Claim the section must make | Verified from |
|---|---|
| The Planner writes `openspec/changes/<change-id>/implementation-plan.md` | `.claude/skills/plan-feature/SKILL.md` Step 5 ("Write the returned Markdown to: `openspec/changes/<change-id>/implementation-plan.md`") and `.claude/agents/planner.md` "What you produce" ("One artifact: `implementation-plan.md` for the active change"). |
| The Implementer reads that file | `.claude/agents/implementer.md` "Required inputs" table, first row: `implementation-plan.md` — "The handoff: order, scope, tests". |
| The Implementer confirms gate 3 first | `.claude/agents/implementer.md` "Required inputs": "Gate 3 (`plan-handoff`) must be `pass`." |
| `guard-planning-handoff.sh` is a `PreToolUse` hook on `Write\|Edit\|MultiEdit` that blocks product-code writes until the plan exists | `scripts/guard-planning-handoff.sh` header (lines 1–20) and the block branch (lines ~150–165): exit `2`, message "Change `<id>` has no implementation plan. Expected: `openspec/changes/<id>/implementation-plan.md` … Run `/plan-feature <id>` first." |
| The guard allows harness control surface, change artifacts, and `CLAUDE.md` | `scripts/guard-planning-handoff.sh` allow-list (lines ~95–105): `.claude/*`, `scripts/*`, `openspec/*`, `.git/*`, `CLAUDE.md`, `AGENTS.md`, `CODEBASE.md`, `*/proposal.md`, `*/tasks.md`, `*/spec.md`, `*/design.md`, `*/review.md`, `*/test-report.md`, `*/implementation-plan.md`, `*/status.md`. |
| The guard fails open when the harness is not in use | `scripts/guard-planning-handoff.sh`: no `openspec/changes` dir → exit 0; no active change → exit 0; more than one active change → note and exit 0. |
| `workflow-status.sh` gate 3 is `plan-handoff` | `scripts/workflow-status.sh` gate-order comment (line 17) and `GATE_NAMES` (line 265); owner `planner (/plan-feature)` (line 297). |
| `check-scope.sh --plan` compares the changed files against the plan's predicted files | `scripts/check-scope.sh` header (lines 1–20) and usage (`--plan <implementation-plan.md>`); it exits `1` when a changed file was not predicted. The Implementer runs it in `.claude/agents/implementer.md` Method step 6. |

**The handoff is a file handoff plus a mechanical gate, not a message between agents.**
The Planner writes a file into the change directory; the Implementer reads that file; and
`guard-planning-handoff.sh` blocks a product-code write before it happens when the file is
absent. The section MUST say this explicitly, because a reader who assumes a conversational
handoff will not understand why an implementation write is rejected.

**§D — The regression cases (tasks 2.1–2.3)**

- Task 2.1: `expect_contains "README has a table of contents" "## Table of Contents" cat "$ROOT/README.md"`, plus a `check` that the TOC entry count equals the numbered-heading count.
- Task 2.2: `expect_contains` for the new section heading, for each owner name, and for a `mermaid` block.
- Task 2.3: `expect_contains` for `implementation-plan.md`, for `guard-planning-handoff.sh`, and for the handoff diagram.
- Mutation check: temporarily remove one owner name from the new section and confirm task 2.2's assertion fails; revert.

**§E — Full harness regression (after all edits)**

```bash
scripts/test-write-scope.sh && scripts/test-guards.sh && scripts/test-status.sh \
  && scripts/test-completion.sh && scripts/test-delivery.sh
node scripts/check-frontmatter.js
scripts/validate-product-artifacts.sh
openspec validate us-13-2-document-orchestrator-loop --strict   # read the printed result
openspec validate --all --strict
```

Also run `scripts/check-scope.sh --plan openspec/changes/us-13-2-document-orchestrator-loop/implementation-plan.md`
against the changed-file list, to catch edits outside the predicted files.

**§F — The README edits do not break the existing parsers (evidence, not a test)**

- `scripts/guard-context-preflight.sh` and `scripts/validate-product-artifacts.sh` react to
  `PRD.md`/`SPECS.md`/`CODEBASE.md`, not `README.md`. `test-guards.sh` already asserts
  `check "non-target artifact ignored" 0 "$SCRIPTS/guard-context-preflight.sh" --file README.md --quiet`.
- `scripts/delivery.sh` `parse_specs` reads `SPECS.md` only. A TOC line starting with `-`
  and a Mermaid line starting with a node id match none of its anchors.
- Confirm by running `scripts/delivery.sh next` after the edits and checking the story and
  task counts are unchanged.

## Dependencies

- **US-11.1 and US-12.3 (DONE, archived).** US-11.1 created the team README; US-12.3
  documented goal-driven delivery in §18. This change extends the same file and must not
  contradict §18.
- **The documented interfaces as they stand today:**
  - `.claude/skills/deliver/SKILL.md` — the Step 2 delegation table;
  - `scripts/delivery.sh` — `derive_next` (lines 296–425);
  - `.claude/rules/delivery-loop.md` — the role table;
  - `.claude/skills/plan-feature/SKILL.md` — Step 5;
  - `.claude/agents/planner.md` — "What you produce";
  - `.claude/agents/implementer.md` — "Required inputs" and Method step 6;
  - `scripts/guard-planning-handoff.sh` — the allow-list and the block branch;
  - `scripts/workflow-status.sh` — gate 3;
  - `scripts/check-scope.sh` — `--plan`;
  - `scripts/test-guards.sh` — the `check` and `expect_contains` helpers.
- **Task 1.1 comes before task 1.2**, because the TOC fixes the numbering the new section
  must use.
- **Tooling:** bash 3.2, BSD grep/awk, `node` (frontmatter), OpenSpec CLI 1.13.2.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Write scope.** `check-write-scope.sh --role implementer` returns exit 2 for `README.md` and `scripts/test-guards.sh`, which are harness control surface. The `implementer` subagent therefore cannot write either deliverable. | high | medium | As in US-12.1–US-12.4 and US-13.1, the main session implements and the Reviewer records it. Do not weaken `check-write-scope.sh`. |
| **Renumbering breaks a cross-reference.** Eight headings move, and four `§N` references exist in `README.md` (lines 115, 118, 727, 907) plus one in `scripts/README.md` (line 1205). | high | medium | Only line 118 (`§25` → `§26`) points at a moved section; the other four point at §18, which does not move. Grep `§[0-9]` across the repository after the edits and confirm every reference resolves. |
| **The TOC anchor drifts.** A hand-written anchor that does not match the heading breaks the "each entry MUST link to its heading" clause. | medium | medium | Derive each anchor mechanically: lowercase, drop `.` and `:`, spaces to hyphens. Spot-check at least one epic and one story link. |
| **The new section duplicates §18.** §18 already explains the loop in prose; a new section that repeats it without adding the diagram and the handoff adds noise. | medium | medium | The new section's job is the *diagram* and the *handoff*; cross-reference §18 for the stop reasons rather than restating them. |
| **Documenting behaviour that is not there.** For example, claiming the guard blocks *all* writes, or that the handoff is a message between agents. | medium | high | Every claim in the section is backed by the file and line in Test Strategy §C. The guard allows harness control surface and change artifacts; say so. |
| **Stale `test-guards.sh` count.** `README.md` cites the count twice (lines 1291, 1344). Adding three cases changes it. | medium | low | Re-measure after the edits and update both citations. Note that the sample output block (line 1352) already reads `passed: 38` while the prose says 65 — an existing inconsistency; align it or record it as a finding. |
| **`openspec validate` exit codes are unreliable.** | high | low | Read the printed totals. |

## Open Questions

- **The new section's number and title.** The plan assumes the section is inserted after
  §18 and titled "The Orchestrator Loop and the Plan Handoff", becoming §19, with the old
  §19–§26 renumbered to §20–§27. An alternative is to append it as §27 to avoid
  renumbering. The plan assumes insertion after §18 because the loop is the natural
  continuation of §18; if the Product Manager prefers no renumbering, that should be stated
  before implementation.
- **The sample `test-guards.sh` output block.** `README.md` line 1352 shows `passed: 38`
  while the prose cites 65 cases. The plan assumes the Implementer updates the cited counts
  to the re-measured value and aligns the sample block. If the sample is intended as
  illustrative rather than literal, that is a presentation decision for the Product Manager.
- **Diagram style.** The plan assumes `flowchart TD` for the loop and `flowchart LR` for
  the handoff. The scenario requires *a* diagram, not a specific type. If a
  `sequenceDiagram` is preferred for the handoff, that is a presentation decision.
