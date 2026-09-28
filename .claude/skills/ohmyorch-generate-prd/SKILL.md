---
name: ohmyorch-generate-prd
description: Generate or update PRD.md from product source documents, using CODEBASE.md as descriptive current-state context. Use when turning product material into a product requirements document. Also use when the user says "generate PRD", "create PRD", or "update PRD".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit, Agent
license: MIT
compatibility: Requires the product-specifier agent.
metadata:
  author: claude-harness
  version: "1.0"
  implements: "US-2.4"
---

Generate or update `PRD.md` from product source material while keeping desired
behavior strictly separate from the system's current state.

**This skill writes exactly one artifact: `PRD.md`.** It never modifies application
source code or `SPECS.md`.

## Step 1 — Resolve inputs

Identify the product source documents. These may be supplied as arguments, named by
the caller, or already present in the repository.

```bash
ls -la *.md 2>/dev/null
```

If no product source material is available, stop and report that PRD generation needs
a source. Do not generate a PRD from the existing codebase — that would turn current
implementation into product intent, which is exactly what this harness forbids.

## Step 2 — Preflight the codebase context

```bash
test -f CODEBASE.md && echo "present" || echo "absent"
```

Determine which case applies and act on it:

**Case A — `CODEBASE.md` exists.** Read it in full, then verify its freshness.

```bash
RECORDED=$(sed -n 's/^Analyzed revision:[[:space:]]*//p' CODEBASE.md | head -1)
git diff --stat "$RECORDED"..HEAD 2>/dev/null | tail -1
```

If material changes make it stale, surface that before continuing:

```text
Stale context: CODEBASE.md describes <rev>; HEAD is <rev> (<n> commits, <files> touched).
Options: (a) refresh with /ohmyorch-analyze-codebase, (b) continue with a recorded staleness note.
```

Do not treat a known-stale file as current without saying so. If the recorded revision
cannot be resolved, record that limitation instead of assuming freshness.

**Case B — a meaningful codebase exists but `CODEBASE.md` is absent.** Stop and
report:

```text
Codebase context missing: a codebase is present but CODEBASE.md does not exist.
Options: (a) run /ohmyorch-analyze-codebase first (recommended), (b) record an explicit skip decision.
```

Run `/ohmyorch-analyze-codebase` first, or require an explicit Product Manager decision to skip
before proceeding. Never proceed as though repository context were considered.

**Case C — no meaningful codebase (greenfield).** Proceed from product sources alone.
Do not describe a nonexistent architecture.

## Step 3 — Delegate to the Product Specifier

Delegate to the `product-specifier` agent with:

- the product source documents to read and their locations;
- whether `CODEBASE.md` was consumed, its revision, and any staleness finding;
- the existing `PRD.md` when this is an update, with instructions to preserve
  identifier stability and unaffected content;
- the requirement to return a `CODEBASE Context:` marker line.

## Step 4 — Write or merge PRD.md

If `PRD.md` does not exist, write the returned document.

If it exists, **update incrementally**: preserve unaffected requirements, keep existing
identifier values stable so other artifacts can still reference them, and change only
what the new source material supports. Never regenerate from scratch in a way that
renumbers or drops established requirements.

Confirm the `CODEBASE Context:` line is present and accurate.

## Step 5 — Validate

```bash
scripts/validate-product-artifacts.sh --prd PRD.md
```

When `CODEBASE.md` exists, validation fails unless `PRD.md` records that it was
consumed or explicitly skipped. That is the point of the check.

## Step 6 — Report

Return:

- whether `PRD.md` was created or updated;
- the codebase context outcome (consumed with revision, skipped with reason, or absent);
- whether a stale-context condition was surfaced;
- the sources read;
- open questions and conflicts requiring a Product Manager decision;
- the validator result.

## Boundaries

- Never invent product behavior a source does not state.
- Never infer desired behavior from existing implementation.
- When desired behavior conflicts with the current implementation, keep the desired
  behavior and record the difference as a gap, constraint, migration concern, or open
  question.
- Never edit application source code or `SPECS.md`.
