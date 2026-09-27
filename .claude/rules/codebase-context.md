# Codebase Context

Rules for using `CODEBASE.md` as context. Source: `PRD.md` sections 6 and 7;
`SPECS.md` BR-006 and NFR-005.

## The rule

> **Any workflow that creates or materially updates `PRD.md` or `SPECS.md` MUST
> read `CODEBASE.md` when that file exists.** (BR-006)

When no `CODEBASE.md` exists and the repository contains a meaningful existing
codebase, the workflow MUST either perform codebase analysis first or record an
explicit decision to skip it. Silence is not a decision.

## Evidence, not intent

`CODEBASE.md` is **descriptive**. It records what the repository currently does.

It may:

- constrain feasibility ("the current interface takes three arguments, so this
  change is breaking")
- reveal compatibility requirements ("two callers depend on the old name")
- document what already exists ("this behaviour is already implemented")

It MUST NOT silently become the desired product requirement. Existing behavior is
not automatically correct, wanted, or in scope. A Product Specifier that reads
`CODEBASE.md` and then writes a PRD that merely restates the current
implementation has confused evidence with intent.

When `CODEBASE.md` and a human product decision disagree, the decision wins.

## Recording consumption

`SPECS.md` records that context was considered, with one line:

```text
CODEBASE Context: consumed (<revision>)
```

or, when analysis is deliberately skipped:

```text
CODEBASE Context: skipped (<reason>)
```

The validator `scripts/validate-product-artifacts.sh` enforces the presence of
this marker (US-2.7), and `scripts/guard-context-preflight.sh` blocks generation
that would start from missing or stale context (US-8.2).

## Fidelity

`CODEBASE.md` MUST distinguish:

- **Repository-backed observations** — verified by reading code.
- **Unknowns** — not determined, stated as unknown rather than guessed.

It SHOULD record the repository revision or other snapshot used for analysis, so
a reader can tell whether the description has drifted from the code (NFR-005).

Every claim should be traceable to a file, and inference should be marked as
inference. A reader must be able to tell what was observed from what was assumed.

## Staleness

A `CODEBASE.md` describing a revision that `HEAD` has moved past is stale. Stale
context is still context, but it may describe an interface that no longer exists.

Before a material generation, check whether the recorded revision still matches
reality. When it does not, refresh the analysis or record an explicit decision to
proceed with the older description. The preflight guard performs this check when
`CODEBASE.md` contains an `Analyzed revision:` line.
