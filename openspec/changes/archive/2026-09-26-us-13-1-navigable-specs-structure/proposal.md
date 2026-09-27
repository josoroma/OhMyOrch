# Proposal — US-13.1: Generate a Navigable SPECS.md Structure

Story: US-13.1
Epic: EPIC-13 — Backlog Navigation and Structure

## Why

`SPECS.md` is the harness's iterable backlog, and it grows. The current file is 24
stories and 99 tasks across 12 epics, and a reader has no way to see the shape of it:
there is no table of contents, no single view of what is done and what is not, and the
dependency edges are buried in per-story `Dependencies:` lists.

The Spec Ingestor defines what a generated `SPECS.md` looks like. If the structure is
not in that definition, every generated backlog will be as hard to navigate as this one.

## What Changes

- **`.claude/agents/spec-ingestor.md`** gains a required `SPECS.md` structure: the
  section order, and the three navigation sections — a table of contents, a work-item
  status table, and a Mermaid dependency diagram of epics, stories, and tasks as nested
  parents and children.
- **`.claude/skills/ingest-spec/SKILL.md`** requires those sections and reports them in
  its ingestion summary.
- **`SPECS.md`** is brought into that shape: a table of contents, a work-item status
  table, and a dependency diagram are added at the top.
- **`scripts/test-guards.sh`** gains a regression case for the new structure.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `spec-ingestor`: adds one requirement — the Spec Ingestor defines the SPECS.md
  structure, including the table of contents, the work-item status table, and the
  dependency diagram.

## Out of Scope

- Changing the story shape (`### US-N.M:` with `Status:`, `Source:`, Gherkin, `Tasks:`,
  `Open Questions:`). The validator and every existing story depend on it.
- Making the new sections mandatory in `scripts/validate-product-artifacts.sh`. The
  validator stays as it is, so a host repository's existing `SPECS.md` keeps passing.
- Generating the index with a script. The Spec Ingestor generates it, as it generates
  the rest of the file.

## Impact

- `.claude/agents/spec-ingestor.md`
- `.claude/skills/ingest-spec/SKILL.md`
- `SPECS.md` (new sections at the top)
- `scripts/test-guards.sh` (one regression case)

Source:
- Human Product Manager decision, 2026-09-26
