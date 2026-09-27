# Implementation Plan — us-13-1-navigable-specs-structure

Story: US-13.1
Change: us-13-1-navigable-specs-structure

## Selected Story

US-13.1 — Generate a Navigable SPECS.md Structure. `SPECS.md` line 1505 records it as
`Status: IN PROGRESS`, with `Change: openspec/changes/us-13-1-navigable-specs-structure/`,
under `# EPIC-13: Backlog Navigation and Structure` (line 1495). It is the only story of
EPIC-13. Its source is the human Product Manager decision of 2026-09-26.

This change makes the Spec Ingestor define a navigable `SPECS.md` structure — a table of
contents, a work-item status table, and a Mermaid dependency diagram — and brings the
current `SPECS.md` into that shape. It adds no new capability to the harness runtime; it
changes what a generated backlog looks like and how the existing one reads.

Its dependencies are US-2.5 (Create Spec Ingestor Agent) and US-2.6 (Create Ingest Spec
Skill), both `Status: DONE` and archived:

- `openspec/changes/archive/2026-09-24-us-2-5-spec-ingestor-agent/`
- `openspec/changes/archive/2026-09-24-us-2-6-ingest-spec-skill/`

`scripts/delivery.sh next` returns `Action: plan`, `Owner: planner`, `Reason: gate
plan-handoff: implementation-plan.md missing`. `scripts/workflow-status.sh --change
us-13-1-navigable-specs-structure` reports `First incomplete gate: plan-handoff` and
`0/9 tasks complete`.

`CODEBASE.md` is absent (greenfield), so nothing was consumed.

The four acceptance scenarios, verbatim from `SPECS.md`:

```gherkin
Scenario: SPECS.md opens with a table of contents
  Given the Spec Ingestor generates or updates SPECS.md
  When a reader opens the file
  Then it MUST contain a table of contents listing every epic and user story
  And each entry MUST link to that work item's heading
```

```gherkin
Scenario: SPECS.md carries a work-item status table
  Given SPECS.md contains epics, user stories, and tasks
  When a reader opens the file
  Then it MUST contain a table listing every epic, user story, and task
  And each row MUST show the work item's identifier, title, status, and parent
```

```gherkin
Scenario: SPECS.md carries a dependency diagram
  Given SPECS.md contains work items with declared dependencies
  When a reader opens the file
  Then it MUST contain a Mermaid diagram of the epics, user stories, and tasks as nested parents and children
  And the diagram MUST show the declared dependencies between them
```

```gherkin
Scenario: The Spec Ingestor defines the SPECS.md structure
  Given the Spec Ingestor agent definition
  When a reader inspects it
  Then it MUST require the table of contents, the work-item status table, and the dependency diagram
  And it MUST define the section order of a generated SPECS.md
```

## OpenSpec Artifacts

- `proposal.md` establishes the scope: the Spec Ingestor definition gains a required
  `SPECS.md` structure (section order plus the three navigation sections); the ingest
  skill requires and reports them; `SPECS.md` is brought into that shape; and
  `scripts/test-guards.sh` gains one regression case. Out of scope: changing the story
  shape (`### US-N.M:` with `Status:`, `Source:`, Gherkin, `Tasks:`, `Open Questions:`);
  making the new sections mandatory in `scripts/validate-product-artifacts.sh`; and
  generating the index with a script.
- `specs/spec-ingestor/spec.md` is a delta with one ADDED requirement, "The Spec Ingestor
  defines the SPECS.md structure", carrying the four scenarios above, matching `SPECS.md`
  word for word.
- `tasks.md` has 9 unticked tasks. Tasks 1.1–1.5 are deliverables; tasks 2.1–2.4 are
  Implementer regression cases. Each task already names a scenario.
- `design.md` is absent. The proposal does not call for one; the shape is fully specified
  by the delta spec and the guidance below.
- `status.md` is derived. It shows `State PLANNED` and `owner planner`, with gate 3
  (`plan-handoff`) failing because `implementation-plan.md` is missing. The Implementer
  does not write it.

## Implementation Order

1. **Task 1.1: define the structure in `.claude/agents/spec-ingestor.md`.** Do the
   normative definition first. It fixes the section order, the table columns, and the
   diagram shape that tasks 1.3–1.5 must produce, so writing it first prevents the
   `SPECS.md` edits from inventing a shape the definition does not require.
2. **Task 1.2: require and report the sections in `.claude/skills/ingest-spec/SKILL.md`.**
   The skill is the operational counterpart to the agent definition; it must name the
   same sections in Step 4 (write or merge), Step 5 (validate), and Step 6 (report).
3. **Task 1.3: add the table of contents to `SPECS.md`.** First of the three `SPECS.md`
   sections, because the status table and diagram are easier to check against a TOC that
   already enumerates every work item.
4. **Task 1.4: add the work-item status table to `SPECS.md`.** Uses the same enumeration
   as the TOC, plus each item's status and parent.
5. **Task 1.5: add the Mermaid dependency diagram to `SPECS.md`.** Last, because it
   depends on the dependency edges and the parent/child nesting the previous two steps
   made explicit.
6. **Tasks 2.1–2.4: the regression cases** in `scripts/test-guards.sh`. Add them after the
   deliverables so each asserts the final structure. Task 2.4 asserts on the agent
   definition; tasks 2.1–2.3 assert on `SPECS.md`.
7. **Run the full harness regression** (Test Strategy §E) and re-measure the
   `test-guards.sh` case count, which `scripts/README.md` cites.

## Task to Acceptance Mapping

| Task | Acceptance criterion | Notes |
|---|---|---|
| 1.1 Extend `.claude/agents/spec-ingestor.md` with the required SPECS.md structure and section order | Scenario: The Spec Ingestor defines the SPECS.md structure | The `Then` requires the definition to require all three sections; the `And` requires it to define the section order. Both clauses land in the agent definition. |
| 1.2 Extend `.claude/skills/ingest-spec/SKILL.md` to require the new sections and report them | Scenario: The Spec Ingestor defines the SPECS.md structure | The skill is the operational half of the same requirement: Step 4 must require the sections, Step 5 must validate them, Step 6 must report them. |
| 1.3 Add the table of contents to `SPECS.md` | Scenario: SPECS.md opens with a table of contents | The `Then` requires a TOC listing every epic and user story; the `And` requires each entry to link to that work item's heading. |
| 1.4 Add the work-item status table to `SPECS.md` | Scenario: SPECS.md carries a work-item status table | The `Then` requires a table listing every epic, user story, and task; the `And` requires identifier, title, status, and parent columns. |
| 1.5 Add the Mermaid dependency diagram to `SPECS.md` | Scenario: SPECS.md carries a dependency diagram | The `Then` requires a Mermaid diagram of epics, stories, and tasks as nested parents and children; the `And` requires the declared dependencies to appear as edges. |
| 2.1 Regression case for Scenario: SPECS.md opens with a table of contents | Scenario: SPECS.md opens with a table of contents | Implementer-owned. Asserts the TOC section exists, lists every epic and story, and that each entry is a link. |
| 2.2 Regression case for Scenario: SPECS.md carries a work-item status table | Scenario: SPECS.md carries a work-item status table | Implementer-owned. Asserts the table exists, has the four columns, and has a row per epic, story, and task. |
| 2.3 Regression case for Scenario: SPECS.md carries a dependency diagram | Scenario: SPECS.md carries a dependency diagram | Implementer-owned. Asserts a `mermaid` fenced block exists, contains the epic/story/task nesting, and contains the declared dependency edges. |
| 2.4 Regression case for Scenario: The Spec Ingestor defines the SPECS.md structure | Scenario: The Spec Ingestor defines the SPECS.md structure | Implementer-owned. Asserts the agent definition names all three sections and states the section order. |

All 9 tasks are mapped, and none is unmapped.

## Affected Files

| Path | Expected change | Evidence |
|---|---|---|
| `.claude/agents/spec-ingestor.md` | **Add a "SPECS.md structure" section** (after "Story shape", before "Ambiguity and conflict handling"). It MUST state the required section order and require the three navigation sections. Extend the `INGESTION SUMMARY` block with the three sections' presence. | Read the whole file. "Story shape" (line ~120) defines the per-story shape only; nothing defines the file-level order. The `INGESTION SUMMARY` block (line ~200) reports counts but not structure. |
| `.claude/skills/ingest-spec/SKILL.md` | **Step 4** (write or merge): require the three sections and the section order. **Step 5** (validate): add a check that the sections are present. **Step 6** (report): report them. | Read the whole file. Step 4 (line ~78) lists merge rules only; Step 5 (line ~92) runs `validate-product-artifacts.sh` only; Step 6 (line ~104) reports counts only. |
| `SPECS.md` | **Insert three sections after the `CODEBASE Context:` line (line 3) and before `## Product Context` (line 5):** `## Table of Contents`, `## Work Item Status`, `## Dependency Diagram`. No existing line changes. | Read lines 1–90 and 1495–1560. The head is title → `CODEBASE Context:` → `## Product Context` → `## Goals` → `## Non-Goals` → `## Actors` → `## Global Business Rules` → `## Non-Functional Requirements` → `# EPIC-1:` … `# EPIC-13:`. Measured: 13 epics, 25 stories, 103 task checkboxes. |
| `scripts/test-guards.sh` | **Add a new section** "US-13.1 — navigable SPECS.md structure" before "Usage errors" (line ~196), with four cases (tasks 2.1–2.4). Use the existing `check` helper and `section` helper. | Read lines 1–120 and 196–225. Helpers: `check <label> <expected-exit> <command...>` (line 32), `section` (line 45). The suite stages throwaway dirs under `$WORK` and never modifies the repository. |
| `openspec/changes/us-13-1-navigable-specs-structure/tasks.md` | Checkbox ticks only. | Gate 4 counts ticks (`0/9 tasks complete`). |

Expected to stay unchanged:

- `scripts/validate-product-artifacts.sh` — the proposal's §Out of Scope. The new sections
  are not made mandatory here, so a host repository's existing `SPECS.md` keeps passing.
- `scripts/delivery.sh` — its `parse_specs` awk is anchored on `^# EPIC-N:`,
  `^### US-N.M:`, `^Status:`, `^Change:`, `^Dependencies:`, `^Tasks:`, and
  `^[ ]*-[ ]*\[[ xX]\]` under `sect == "tasks"`. The new sections match none of these (see
  Test Strategy §F).
- `PRD.md`, `CLAUDE.md`, `.claude/rules/`, `.claude/settings.json`, and every other script
  and fixture.

## Test Strategy

There is no application test runner. The checks are shell commands run by the Implementer
(tasks 2.1–2.4) and repeated independently by the Tester. Two scenarios are partly judged
**by inspection**: whether the TOC and diagram are *navigable* needs a reader. The
mechanical checks below establish presence, completeness, and accuracy only.

**§A — Scenario: SPECS.md opens with a table of contents (tasks 1.3, 2.1)**

- `grep -n '^## Table of Contents' SPECS.md` returns a match.
- The section lists every epic and story: the count of TOC entries equals
  `grep -cE '^# EPIC-[0-9]+:' SPECS.md` + `grep -cE '^### US-[0-9]+\.[0-9]+:' SPECS.md`
  (13 + 25 = 38).
- Every entry is a link: each TOC line matches `^- \[.+\]\(#.+\)$`.
- Spot-check that a link resolves: the anchor for `### US-13.1: Generate a Navigable
  SPECS.md Structure` is `#us-131-generate-a-navigable-specsmd-structure` (lowercase, dots
  and spaces removed, spaces to hyphens).

**§B — Scenario: SPECS.md carries a work-item status table (tasks 1.4, 2.2)**

- `grep -n '^## Work Item Status' SPECS.md` returns a match.
- The header row MUST be `| ID | Title | Status | Parent |`.
- The table has one row per epic (13), per story (25), and per task (103) — 141 data rows.
- Every story row's `Status` cell matches that story's `Status:` line; every task row's
  `Parent` cell names its story; every story row's `Parent` cell names its epic.

**§C — Scenario: SPECS.md carries a dependency diagram (tasks 1.5, 2.3)**

- `grep -n '^```mermaid' SPECS.md` returns a match, and the block is closed.
- The diagram nests epics → stories → tasks (subgraphs or equivalent parent/child edges).
- The declared dependency edges appear. The real edges, measured from `SPECS.md`:

  | Story | Declared dependencies |
  |---|---|
  | US-12.1 | US-3.2, US-9.1 |
  | US-12.2 | US-12.1 |
  | US-12.3 | US-12.1, US-12.2 |
  | US-12.4 | US-12.1, US-12.2 |
  | US-13.1 | US-2.5, US-2.6 |

  Every other story declares `Dependencies: None.` (or `None`), so it has no edge. The
  diagram MUST contain these 8 edges and no invented ones.

**§D — Scenario: The Spec Ingestor defines the SPECS.md structure (tasks 1.1, 1.2, 2.4)**

- `.claude/agents/spec-ingestor.md` names all three sections (table of contents, work-item
  status table, dependency diagram) and states the section order.
- `.claude/skills/ingest-spec/SKILL.md` requires them in Step 4, checks them in Step 5, and
  reports them in Step 6.
- Mutation check: temporarily remove one section name from the agent definition and confirm
  task 2.4's assertion fails; revert.

**§E — Full harness regression (after all edits)**

```bash
scripts/test-write-scope.sh && scripts/test-guards.sh && scripts/test-status.sh \
  && scripts/test-completion.sh && scripts/test-delivery.sh
node scripts/check-frontmatter.js
scripts/validate-product-artifacts.sh
openspec validate us-13-1-navigable-specs-structure --strict   # read the printed result
openspec validate --all --strict
```

Also run `scripts/check-scope.sh` against this plan with the changed-file list, to catch
edits outside the predicted files.

**§F — The new sections do not break the existing parsers (evidence, not a test)**

- `scripts/validate-product-artifacts.sh` `parse_stories` resets on `^# EPIC-` and
  `^### US-` and reacts only to `^Status:`, `^Source:`, `^Scenario:`, `^Given/When/Then`.
  `check_specs` counts `^# EPIC-[0-9]+:` and `^### US-[0-9]+\.[0-9]+:`. TOC lines start
  with `-`, table rows with `|`, and Mermaid lines with a node id or keyword — none match.
- `scripts/delivery.sh` `parse_specs` is anchored the same way. A table row starting with
  `|` is not read as a task (the task pattern requires `- [x]`/`- [ ]` under
  `sect == "tasks"`), and a TOC line is not read as a heading (headings require `^#`).
  Confirm by running `scripts/delivery.sh next` after the edits and checking the story and
  task counts are unchanged (25 stories, 103 tasks).

## Dependencies

- **US-2.5 and US-2.6 (DONE, archived).** They created the Spec Ingestor agent and the
  ingest skill this change extends. They must not be altered here.
- **The documented interfaces as they stand today:**
  - `.claude/agents/spec-ingestor.md` — the "Story shape" section and the
    `INGESTION SUMMARY` block;
  - `.claude/skills/ingest-spec/SKILL.md` — Steps 4, 5, and 6;
  - `scripts/validate-product-artifacts.sh` — `check_specs` and `parse_stories`;
  - `scripts/delivery.sh` — `parse_specs`;
  - `scripts/test-guards.sh` — the `check` and `section` helpers.
- **Task 1.1 comes before tasks 1.3–1.5**, because it fixes the shape they produce.
- **Tooling:** bash 3.2, BSD grep/awk, `node` (frontmatter), OpenSpec CLI 1.13.2.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **Write scope.** `check-write-scope.sh --role implementer` returns exit 2 for all four affected files (`.claude/agents/spec-ingestor.md`, `.claude/skills/ingest-spec/SKILL.md`, `SPECS.md`, `scripts/test-guards.sh`), which are harness control surface. The `implementer` subagent therefore cannot write any deliverable. | high | medium | As in US-12.1–US-12.4, the main session implements and the Reviewer records it. Do not weaken `check-write-scope.sh`. |
| **The diagram is large.** The scenario requires tasks as nested children, and there are 103 tasks. A single Mermaid diagram with 141 nodes is hard to read and may exceed renderer limits. | high | medium | Keep node labels short (identifier plus a truncated title), use `flowchart TD` with one `subgraph` per epic, and keep task nodes as leaf children. If the renderer struggles, split into one diagram per epic under the same `## Dependency Diagram` heading — the scenario requires *a* diagram of the work items, not a single block. Record the choice in the plan's Open Questions if it changes the shape. |
| **Mermaid node ids cannot contain dots.** `US-13.1` is not a valid Mermaid node id. | high | low | Use `US_13_1` as the node id and `US-13.1: <title>` as the label, e.g. `US_13_1["US-13.1: Generate a Navigable SPECS.md Structure"]`. |
| **The TOC anchors drift.** A hand-written anchor that does not match the heading breaks the "each entry MUST link to that work item's heading" clause. | medium | medium | Derive each anchor mechanically from the heading: lowercase, drop `.` and `:`, spaces to hyphens. Spot-check at least one epic and one story link. |
| **The proposal's counts are stale.** `proposal.md` says "24 stories and 99 tasks across 12 epics"; the file now has 25 stories, 103 tasks, and 13 epics (US-13.1 and EPIC-13 were added after the proposal was written). | high | low | Use the measured numbers (13/25/103) in the plan and in any new prose. Do not copy the proposal's counts. |
| **Documenting behaviour that is not there.** For example, claiming the validator now enforces the sections, or that a script generates the index. | medium | medium | The proposal's §Out of Scope forbids both. State that the sections are required by the Spec Ingestor, not by `validate-product-artifacts.sh`. |
| **Stale `test-guards.sh` count.** `scripts/README.md` cites suite counts; adding four cases changes `test-guards.sh`'s. | medium | low | Re-measure after the edits and update any cited count in `scripts/README.md`. |
| **`openspec validate` exit codes are unreliable.** | high | low | Read the printed totals. |

## Open Questions

- **Diagram granularity.** The scenario says the diagram shows "epics, user stories, and
  tasks as nested parents and children". With 103 tasks, one diagram is large. The plan
  assumes a single `flowchart TD` with one `subgraph` per epic and task leaf nodes, and
  permits splitting per epic if the renderer struggles. If the Product Manager intends a
  stricter single-block contract, that should be stated before implementation.
- **Task titles in the status table.** The scenario requires a `Title` column for every
  work item, including tasks. Task text in `SPECS.md` is a full sentence (for example
  "Extend `.claude/agents/spec-ingestor.md` with the required SPECS.md structure and
  section order."). The plan assumes the full task text is used verbatim. If a shortened
  form is preferred, that is a presentation decision for the Product Manager.
- **Where the regression cases live.** The proposal lists `scripts/test-guards.sh` as the
  only test file affected, and the plan adds a "US-13.1" section there. An alternative is a
  separate suite. The plan assumes the former, since the proposal names `test-guards.sh`.
