---
name: ohmyorch-analyze-codebase
description: Analyze an existing repository and create or refresh CODEBASE.md as an evidence-backed current-state model. Use for brownfield projects before generating PRD.md or SPECS.md, and when CODEBASE.md is stale. Also use when the user says "analyze codebase", "create CODEBASE.md", or "refresh CODEBASE.md".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Agent
license: MIT
compatibility: Requires the codebase-analyst agent.
metadata:
  author: claude-harness
  version: "1.0"
  implements: "US-2.2"
---

Create or refresh `CODEBASE.md`: a durable, evidence-backed description of what a
repository currently is. This is the brownfield entry point of the harness.

`CODEBASE.md` is **descriptive**. It records the current system so later agents do
not rediscover it in every session. It is never a source of product intent.

**This skill writes exactly one artifact: `CODEBASE.md`.** It must not modify any
other file, and never application source code.

## Step 1 — Detect whether a meaningful codebase exists

Before delegating, establish whether there is an application to describe.

```bash
ls -la
git rev-parse --short HEAD 2>/dev/null || echo "not a git repository"
git status --short
git log -1 --format='%H %cI' 2>/dev/null
```

Look for evidence of a real system: source directories, a package manifest, build
configuration, tests, or runtime configuration.

**Stop here if there is no meaningful codebase.** When the repository contains only
documentation, specification, configuration, or scaffolding, do **not** delegate and
do **not** create a fabricated `CODEBASE.md`. Report:

```text
CODEBASE analysis: no meaningful codebase found
evidence: <what you inspected>
action: CODEBASE.md not created
```

A greenfield project legitimately has no `CODEBASE.md`. Fabricating an architecture
for one is a defect, not a helpful fallback.

## Step 2 — Delegate analysis to the Codebase Analyst

Delegate to the `codebase-analyst` agent. It is read-only by design and cannot edit
product code.

Give it an explicit scope:

- the repository root;
- the revision and working-tree state you captured in step 1;
- any directories the caller flagged as irrelevant;
- confirmation that it may read files but must not run commands that modify state.

Ask it to return the full `CODEBASE.md` Markdown plus its `ANALYSIS RESULT` block.

## Step 3 — Reconcile staleness

If `CODEBASE.md` already exists, compare its recorded snapshot against the current
repository before overwriting.

```bash
git diff --stat <recorded-revision>..HEAD 2>/dev/null | tail -1
git log --oneline <recorded-revision>..HEAD 2>/dev/null | wc -l
```

Assess material staleness — changes to entry points, dependencies, build or test
configuration, schemas, or public interfaces matter; comment or formatting churn
does not. Report the finding, then refresh using the current repository evidence.
State which revision the refreshed file describes.

If the recorded revision cannot be resolved, say so and refresh, noting the
limitation rather than guessing at the delta.

## Step 4 — Write CODEBASE.md

Write the analyst's Markdown to `CODEBASE.md`.

The result must satisfy the current-state contract:

- an `Analyzed revision:` line with the Git revision or another snapshot identifier;
- a `Working tree:` line;
- `## System Summary`, `## Repository Map`, `## Runtime and Tooling`,
  `## Evidence Paths`, and `## Unknowns`;
- architecture, entry points, data, integrations, authentication, existing
  behavior, tests, commands, conventions, and constraints when discoverable.

Verify what you wrote:

```bash
scripts/validate-product-artifacts.sh --codebase CODEBASE.md
```

Fix any required-section failure. Do not "fix" an advisory warning by inventing
content — confirm the section was genuinely not discoverable and record it under
`## Unknowns` instead.

## Step 5 — Report

Return a summary containing:

- the analyzed revision and working-tree state;
- the important evidence paths;
- the unknowns that could not be verified;
- whether this was a create, a refresh, or a no-op (no meaningful codebase);
- the validator result.

## Boundaries

- Never modify application source code, `PRD.md`, or `SPECS.md`.
- Never write a claim the repository does not support.
- Never promote existing behavior to a product requirement.
- Never invent architecture, integrations, commands, or behavior for a project that
  does not have them.
