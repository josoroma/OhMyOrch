# Review — us-13-1-navigable-specs-structure

Change: us-13-1-navigable-specs-structure
Story: US-13.1
Verdict: pass
Blocking: None
Coverage: 4/4 acceptance criteria evaluated
OpenSpec verify: VERIFIED — delta spec, tasks, and implementation agree; no blocking mismatch

## Summary

The implementation satisfies all four acceptance criteria. `SPECS.md` opens with a
table of contents whose 38 entries (13 epics + 25 stories) each link to a heading, and
every anchor matches the heading it points at. The work-item status table has 141 data
rows (13 epics + 25 stories + 103 tasks) with the required `ID | Title | Status |
Parent` columns, and its status and parent cells agree with the stories below it. The
dependency diagram is valid Mermaid `flowchart TD` with 13 epic subgraphs, all 25
stories and 103 tasks nested, and exactly the 11 declared dependency edges and no
invented ones. The Spec Ingestor definition requires all three sections and states the
section order. No blocking findings.

## Blocking Issues

None.

## Observations

- **The cross-epic diagram does not itself contain task nodes.** The `## Dependency
  Diagram` section holds one cross-epic `flowchart TD` (epics as subgraphs, stories as
  nodes, dependency edges) followed by one diagram per epic (stories and their tasks).
  No single block shows epics, stories, and tasks together. The scenario says "a
  Mermaid diagram of the epics, user stories, and tasks as nested parents and
  children", which is ambiguous about whether that must be one block. The plan's
  `## Open Questions` pre-authorized the split ("permits splitting per epic if the
  renderer struggles"), and the section as a whole does show all three levels nested.
  Recorded as an open question, not a defect: if the Product Manager intends a strict
  single-block contract, that should be stated and the diagram reshaped.
- **`README.md` is outside the plan's `## Affected Files` prediction.** The plan's
  `## Risks` row "Stale `test-guards.sh` count" anticipated updating a cited count but
  named `scripts/README.md`; the citation actually lives in `README.md` (lines 1291 and
  1344). The Implementer updated the correct file to `64 cases`, which matches the
  suite's measured `passed: 64`. The unpredicted file is explained by the plan's own
  risk row, so it is not scope drift — but the plan named the wrong path.
- **The US-13.1 regression section adds more than the four cases the plan predicted.**
  The plan's `## Affected Files` says "four cases (tasks 2.1–2.4)"; the section adds 20
  assertions (17 `expect_contains` + 3 `check`). Each of the four scenarios is covered
  by several assertions, which is stronger than one case per scenario. Not a defect.
- **`expect_contains` is correct under `set -o pipefail`.** It captures output with
  `out=$("$@" 2>&1)` and matches with a `case` statement, so no pipeline is involved and
  `pipefail` cannot turn a present needle into a reported absence. The helper's comment
  documents exactly this reasoning.
- **`scripts/README.md` still describes `test-guards.sh` without a case count** ("Regression
  suite for the US-8.2 guards"). It is not stale, so no update was required; the plan's
  risk row named it, but the count is cited only in `README.md`.

## Acceptance Criteria Evaluated

| Scenario | Result | Evidence |
|---|---|---|
| SPECS.md opens with a table of contents | PASS | `SPECS.md` `## Table of Contents` (lines 5–44): 13 epic entries + 25 story entries = 38, matching `grep -cE '^# EPIC-[0-9]+:'` (13) + `grep -cE '^### US-[0-9]+\.[0-9]+:'` (25). All 38 anchors derived from their headings match, including `US-13.1: Generate a Navigable SPECS.md Structure` → `#us-131-generate-a-navigable-specsmd-structure` and `US-2.4: Create Generate PRD Skill` → `#us-24-create-generate-prd-skill`. |
| SPECS.md carries a work-item status table | PASS | `SPECS.md` `## Work Item Status` (lines 46–188): header `\| ID \| Title \| Status \| Parent \|`; 141 data rows = 13 epics + 25 stories + 103 tasks. Every story row's Status equals its `Status:` line and every task row's Parent names its story (0 mismatches over all 141 rows). Spot-checks: `US-13.1 … IN PROGRESS … EPIC-13`, `US-13.1#3 … TODO … US-13.1`, `US-1.1#1 … DONE … US-1.1`. |
| SPECS.md carries a dependency diagram | PASS | `SPECS.md` `## Dependency Diagram` (lines 190+): 14 `flowchart TD` blocks, all valid; 13 `subgraph` ids, one per epic; 25 story nodes and 103 task nodes nested across the per-epic diagrams; no node id contains a dot. The 11 distinct `-.->` edges equal the 11 declared `Dependencies:` entries exactly — none missing, none invented. |
| The Spec Ingestor defines the SPECS.md structure | PASS | `.claude/agents/spec-ingestor.md` `## Required SPECS.md structure` (line 125) states the section order and requires `## Table of Contents`, `## Work Item Status`, `## Dependency Diagram`; the `INGESTION SUMMARY` block reports them (lines 213–215). `.claude/skills/ingest-spec/SKILL.md` requires them in Step 4 (lines 93–95), checks them in Step 5 (line 114), and reports them in Step 6 (line 125). |

## Regression Evidence

- `bash -n scripts/test-guards.sh` — clean.
- `scripts/test-guards.sh` — 64 passed, 0 failed.
- `scripts/test-write-scope.sh` — 36 passed, 0 failed.
- `scripts/test-status.sh` — 46 passed, 0 failed.
- `scripts/test-completion.sh` — 63 passed, 0 failed.
- `scripts/test-delivery.sh` — 179 passed, 0 failed.
- `node scripts/check-frontmatter.js` — PASS, all definitions valid.
- `scripts/validate-product-artifacts.sh` — PASS, 0 failures, 0 warnings.
- `openspec validate us-13-1-navigable-specs-structure --strict` — valid.
- `openspec validate --all --strict` — 23 passed, 0 failed.
- `scripts/delivery.sh resolve EPIC-13` — resolves US-13.1; `scripts/delivery.sh next`
  — `Action: review`, `Owner: reviewer`. The new sections did not disturb the parsers.
- `scripts/status.sh` / `scripts/workflow-status.sh --change us-13-1-navigable-specs-structure`
  — gates 1–4 PASS, 9/9 tasks complete, first incomplete gate `review`.
- Mutation check (in a `mktemp -d` copy): renaming `## Table of Contents` to
  `## Contents` fails 3 cases; removing one TOC entry fails 2 cases. The suite detects
  both regressions.
- `scripts/check-scope.sh --plan …` reports 311 unpredicted files, but the repository
  has 354 untracked files (the harness is not committed), so the report reflects
  repository state, not this change's drift. The change's own files are the four the
  plan predicted plus `README.md` (see Observations).

## Handoff

No remediation requested. Control proceeds to acceptance testing (`/test-feature
us-13-1-navigable-specs-structure`).
