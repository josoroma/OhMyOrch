# README-EPIC-13 — Backlog Navigation and Structure

Implementation record for **EPIC-13** from `SPECS.md`.

| Field | Value |
|---|---|
| Epic | EPIC-13 — Backlog Navigation and Structure |
| Stories | US-13.1, US-13.2, US-13.3 |
| Status | Complete — all acceptance criteria verified; delivery goal `EPIC-13` COMPLETE |
| OpenSpec changes | `openspec/changes/archive/2026-09-26-us-13-1-navigable-specs-structure/`, `openspec/changes/archive/2026-09-26-us-13-2-document-orchestrator-loop/`, `openspec/changes/archive/2026-09-26-us-13-3-document-artifact-handoffs/` |
| SPECS.md status | US-13.1, US-13.2, US-13.3 DONE (archived; see each change's `completion.md`) |
| Repository | `/Users/josoroma/projects/claude-dev` |
| Starting revision | `ae11530` |
| Date | 2026-09-26 |
| Claude Code | 2.1.128 |
| OpenSpec | 1.13.2 |
| Spec source | Human Product Manager decision, 2026-09-26 |

---

## 1. Objective

Make a large `SPECS.md` navigable and its work-item structure explicit: a table of
contents, a status table of the nested work items, and a dependency diagram of epics,
user stories, and tasks. The Spec Ingestor generates these, and the harness's own
`SPECS.md` is brought into that shape.

## 2. What existed before

`SPECS.md` was 12 epics, 24 stories, and 99 tasks with no way to see the shape of it.
There was no table of contents, no single view of what was done and what was not, and
the dependency edges were buried in per-story `Dependencies:` lists. The Spec Ingestor
defined the story shape but not the file's structure, so every generated backlog would
have been as hard to navigate.

## 3. What was built

| Story | Deliverable | Change |
|---|---|---|
| US-13.1 | The required `SPECS.md` structure in `.claude/agents/spec-ingestor.md`; the same requirement in `.claude/skills/ingest-spec/SKILL.md`; the three navigation sections in `SPECS.md`; 21 regression cases in `scripts/test-guards.sh` | `2026-09-26-us-13-1-navigable-specs-structure` |
| US-13.2 | A table of contents in `README.md`; a new §19 explaining the orchestrator loop and the plan-to-implement handoff, with two Mermaid diagrams; 20 regression cases in `scripts/test-guards.sh` | `2026-09-26-us-13-2-document-orchestrator-loop` |
| US-13.3 | README §19 extended to every artifact handoff: a handoff table, a reader-confirms-gate table, a `flowchart LR` of the handoffs, and the return path on a failing verdict; 18 regression cases | `2026-09-26-us-13-3-document-artifact-handoffs` |

Canonical capability modified: `openspec/specs/spec-ingestor/`.

## 4. The required structure

```text
# <title>
CODEBASE Context: <consumed (rev) | skipped (reason) | absent>

## Table of Contents        nested list of every epic and story, each a link
## Work Item Status         one table: ID | Title | Status | Parent
## Dependency Diagram       Mermaid flowchart TD, nested, plus declared dependencies

## Product Context
## Goals
## Non-Goals
## Actors
## Global Business Rules
## Non-Functional Requirements

# EPIC-1: <title>
### US-1.1: <title>
```

The three sections are generated from the work items, so they cannot drift from the
stories below them. The status table lists every epic, story, and task — 141 rows at
the time of delivery. The diagram is one cross-epic `flowchart TD` (epics as
subgraphs, stories as nodes, one dotted edge per declared dependency) followed by one
diagram per epic showing that epic's stories and their tasks.

## 5. Key design decisions

1. **The Spec Ingestor owns the structure.** It generates the file, so the structure
   belongs in its definition. A script was rejected: the harness generates Markdown
   contracts, and a generator would be a second source of truth for the backlog.
2. **The sections are derived, not authored.** They are regenerated from the work
   items whenever the file changes, so a section that disagrees with the stories is a
   defect rather than a cosmetic issue.
3. **The validator was not changed.** `scripts/validate-product-artifacts.sh` still
   checks the story shape and readiness, not the navigation sections. A host
   repository's existing `SPECS.md` therefore keeps passing, and the new sections are
   enforced by the Spec Ingestor's definition and by the regression suite.
4. **The diagram is split.** One 141-node diagram was unreadable. The cross-epic
   diagram carries the dependency edges; the per-epic diagrams carry the tasks.

## 6. Review and acceptance

| Change | Rounds | Outcome |
|---|---|---|
| US-13.1 | 1 review (`review.md`) | Passed with no blocking findings. The Reviewer counted the TOC entries, table rows, and dependency edges independently, and mutation-checked the new cases. |
| US-13.2 | 2 reviews (`history/review-r1.md`, final `review.md`) | Round 1 passed with one observation: the README claimed the plan guard allows `SPECS.md`, but it does not while the plan is missing. The sentence was corrected and the change re-reviewed. Round 2 passed with no blocking findings. |
| US-13.3 | 2 reviews (`history/review-r1.md`, final `review.md`) | Round 1 passed with one observation: the illustrative `test-guards.sh` sample output still showed `passed: 38`. It was corrected to the current count and the change re-reviewed. Round 2 passed with no blocking findings. |

Acceptance, per the archived test reports:

- US-13.1: 4/4 scenarios PASS. The Tester wrote its own checks: 38 TOC entries with 0
  anchor mismatches, 141 table rows with 0 status or parent mismatches, and 11 distinct
  dependency edges equal to the 11 declared dependencies.
- US-13.2: 3/3 scenarios PASS. The Tester derived the 27 TOC anchors itself (0
  mismatches), cross-checked the loop table against `derive_next` (0 owner mismatches),
  and verified the plan guard's exit codes in a throwaway copy.
- US-13.3: 3/3 scenarios PASS. The Tester cross-checked every handoff writer and reader
  against the agent and skill definitions (0 mismatches), and verified the return path
  by running `delivery.sh reopen` in a throwaway copy.

## 7. Known limits

- **The scenario wording is ambiguous about the diagram.** It asks for "a Mermaid
  diagram of the epics, user stories, and tasks as nested parents and children". The
  section holds one cross-epic diagram plus one per epic; no single block shows all
  three levels. The Reviewer and the Tester both judged the section as a whole to
  satisfy the scenario. A strict single-block contract would be a specification
  clarification, not a defect.
- **The navigation sections are not validator-enforced.** They are enforced by the
  Spec Ingestor's definition and by `scripts/test-guards.sh`. A hand-edited `SPECS.md`
  could drift from them without a validator failure.

## 8. Verification

```bash
scripts/test-guards.sh           # 103 passed, 0 failed
scripts/test-delivery.sh         # 179 passed, 0 failed
scripts/test-write-scope.sh && scripts/test-status.sh && scripts/test-completion.sh
node scripts/check-frontmatter.js
scripts/validate-product-artifacts.sh
openspec validate --all --strict
```
