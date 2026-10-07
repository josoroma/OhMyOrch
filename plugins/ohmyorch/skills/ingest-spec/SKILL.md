---
name: ingest-spec
description: Convert PRD.md and product source documents into a structured, source-traceable SPECS.md backlog, consuming CODEBASE.md when present. Use when normalizing product artifacts into epics, stories, and acceptance criteria, or when merging a new source into an existing backlog. Also use when the user says "ingest spec", "generate SPECS", or "update SPECS".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Agent
license: MIT
compatibility: Requires the ohmyorch:spec-ingestor agent.
metadata:
  author: claude-harness
  version: "1.0"
  implements: "US-2.6"
---

## Installed plugin contract

Read `${CLAUDE_PLUGIN_ROOT}/references/contract.md` and the applicable bundled rules before acting. Run `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" doctor --json` and stop on FAIL/UNSUPPORTED checks. Resolve every PRD/SPECS/CODEBASE reference through its `documents` mapping. These artifact names never imply a root-only layout. Use concrete resolved paths in Read/Write/Edit/Bash calls; do not copy plugin code/rules into the project. Resolve project files from the explicit project root and bundled files from the plugin root.

Inline path substitution supplies text, not automatic Bash environment variables. Shell-escape each substituted path/argument as a literal argument; never evaluate user `$ARGUMENTS` as shell code. Essential rules also reach delegated agents directly through the `ohmyorch:contract` preload. Pass project root, change, story, configured artifacts and prior evidence explicitly when delegating. Reviewer/tester agents persist their own selected verdict; the caller reads and validates it.
Create or incrementally update `SPECS.md`: the iterable, source-traceable product
backlog the Product Manager selects work from.

**This skill writes exactly one artifact: `SPECS.md`.** It never modifies application
source code or `PRD.md`.

## Step 1 — Resolve inputs

Sources are typically `PRD.md`, but may include any product source document supplied
by the caller.

```bash
ls -la *.md 2>/dev/null
```

If no product source exists, stop and report that ingestion needs a source. Do not
derive requirements from the codebase.

## Step 2 — Preflight the codebase context

```bash
test -f CODEBASE.md && echo "present" || echo "absent"
```

**Case A — `CODEBASE.md` exists.** Read it before creating or materially updating
`SPECS.md`, and check freshness:

```bash
RECORDED=$(sed -n 's/^Analyzed revision:[[:space:]]*//p' CODEBASE.md | head -1)
git diff --stat "$RECORDED"..HEAD 2>/dev/null | tail -1
```

Use it for existing capabilities, integration points, constraints, likely
dependencies, and compatibility concerns. Acceptance criteria must still come from
product sources only — never from code.

If the recorded revision is materially behind HEAD, surface the staleness before
treating the file as current.

**Case B — a meaningful codebase exists but `CODEBASE.md` is absent.** Stop and report:

```text
Codebase context missing: a codebase is present but CODEBASE.md does not exist.
Options: (a) run /ohmyorch:analyze-codebase first (recommended), (b) record an explicit skip decision.
```

Run `/ohmyorch:analyze-codebase` first, or require an explicit skip decision.

**Case C — no meaningful codebase.** Proceed from product sources alone.

Record the outcome as a `CODEBASE Context:` line near the top of `SPECS.md`.

## Step 3 — Delegate to the Spec Ingestor

Delegate to the `ohmyorch:spec-ingestor` agent with:

- the source documents to read;
- the existing `SPECS.md` when this is an update, with explicit instructions not to
  duplicate equivalent requirements and to preserve existing identifiers;
- whether `CODEBASE.md` was consumed, its revision, and any staleness finding;
- the requirement to return an `INGESTION SUMMARY` block.

## Step 4 — Write or merge SPECS.md

**Create** when `SPECS.md` is absent.

**Merge incrementally** when it exists:

- do not duplicate equivalent requirements;
- preserve existing Epic and User Story identifiers;
- add only newly supported requirements;
- flag changed or conflicting requirements for Product Manager review rather than
  silently rewriting them;
- keep `CODEBASE.md`-derived constraints reflected where relevant.

Either way, the file MUST open with the three navigation sections, in this order,
before `## Product Context`:

| Section | Contains |
|---|---|
| `## Table of Contents` | a nested list of every epic and user story, each a link to its heading |
| `## Work Item Status` | one table of every epic, user story, and task: `ID`, `Title`, `Status`, `Parent` |
| `## Dependency Diagram` | a Mermaid `flowchart TD` of the work items as nested parents and children, with one dotted edge per declared dependency, then one diagram per epic |

Regenerate all three from the work items whenever the file changes, so they cannot
drift from the stories below them. The full structure is defined in
`${CLAUDE_PLUGIN_ROOT}/agents/spec-ingestor.md`.

## Step 5 — Validate

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" validate-product-artifacts --specs SPECS.md
```

This enforces the readiness contract: unique Epic and story identifiers, a valid
status on every story, and — for every `READY` story — at least one Gherkin scenario
with `Given`, `When`, and `Then`, plus a `Source:` reference.

Then confirm the navigation sections are present and agree with the stories:

```bash
grep -n '^## Table of Contents$\|^## Work Item Status$\|^## Dependency Diagram$' SPECS.md
```

All three MUST be present, before `## Product Context`. The status table MUST list
every epic, story, and task, and the diagram MUST draw one edge per declared
dependency. A section that disagrees with the stories is a defect, not a cosmetic
issue: a reader navigates by it.

A `READY` story failing these checks is the exact condition that must not reach
implementation. Fix the story, or move it to `NEEDS CLARIFICATION` / `BLOCKED`.

## Step 6 — Report

Return the ingestion summary: codebase context outcome, sources read, epics and
stories added, updated and skipped as duplicates, the status breakdown, the
navigation sections written and the work items they index, the dependency edges
drawn, changed or conflicting requirements flagged, any untraceable requirements
withheld, and the validator result.

## Boundaries

- Never invent acceptance criteria to satisfy a readiness check. If the source does
  not define success, mark the story `NEEDS CLARIFICATION`.
- Never create a story for a requirement with no traceable source. Withhold it and
  report it for a Product Manager decision.
- Never infer product intent from existing implementation.
- Never edit application source code or `PRD.md`.
