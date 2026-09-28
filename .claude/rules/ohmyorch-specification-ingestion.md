# Specification Ingestion

Rules for turning product intent into an iterable backlog. Source: `PRD.md`
section 7, `SPECS.md` BR-001, BR-003, BR-005.

## What ingestion is

The Spec Ingestor reads approved product sources (`PRD.md`, source material) and
produces `SPECS.md`: a backlog of epics and user stories, each with testable
acceptance criteria.

Ingestion is **decomposition**, not authoring. The behaviour already exists in
the product sources; the Ingestor makes it specific, bounded, and testable.

## No invented behavior

> **The Ingestor MUST NOT introduce externally observable behavior that the
> product sources do not support.** (BR-001)

If a story seems to need a decision the sources do not make, that is a finding.
Record it as `NEEDS CLARIFICATION` or `BLOCKED` and surface it. Do not choose an
interpretation privately and write it as though it were decided — a fabricated
requirement is indistinguishable from a real one once it is in the backlog, and
it will be implemented, reviewed, and tested as if someone had asked for it.

The only exception is a clarification from the human Product Manager, who is the
final product authority. When that happens, the source document should be updated
so the decision is durable rather than living in a transcript.

## Bounded stories

Each story is independently deliverable and independently verifiable (BR-003).
Do not collapse several stories into one project-sized deliverable: it cannot be
reviewed as a unit, and a partial success cannot be distinguished from a partial
failure.

A story is well-formed when:

- it is one deliverable
- its acceptance criteria are testable (BR-005)
- its dependencies are named
- it can be marked `DONE` without waiting on a different story

## Status values

```text
READY | NEEDS CLARIFICATION | BLOCKED | IN PROGRESS | DONE
```

- `READY` — scope and criteria are clear and testable. This is the only state
  from which work may be selected.
- `NEEDS CLARIFICATION` — a product decision is required. The question is written
  down, not left implicit.
- `BLOCKED` — an external dependency prevents progress.
- `IN PROGRESS` / `DONE` — delivery states.

> **`READY` asserts testability (BR-005).** A story whose acceptance criteria
> cannot be turned into a test is not `READY`, whatever else is complete about it.

A `Given`/`Then` pair with no `When` is the common way this goes wrong: the
criterion looks complete but describes no action, so nothing can be exercised.
See `gherkin.md`.

## Consuming codebase context

When `CODEBASE.md` exists, read it before generating or materially updating
`SPECS.md` (BR-006), and record that with a `CODEBASE Context:` line.

Existing implementation is evidence about feasibility and current state, not
automatic product intent. Do not turn "the code does X" into "the product must
do X" without a product decision supporting it.

## Story identity

Identifiers (`US-8.1`, `EPIC-8`) are assigned once and never reused or
renumbered. Review and test artifacts reference these identifiers, and
renumbering breaks the trail (NFR-002). A withdrawn story keeps its identifier
and is marked accordingly.
