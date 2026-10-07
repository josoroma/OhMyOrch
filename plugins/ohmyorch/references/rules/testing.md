# Testing

Rules for the Tester role and acceptance evidence. Source: `PRD.md` section 7;
`SPECS.md` BR-002, BR-005, NFR-004.

## Independence

> **The Tester MUST NOT repair failed implementation behavior.**

The Tester validates; it does not fix. When an acceptance criterion fails, the
finding goes into `test-report.md` with evidence, and the change returns to the
Implementer. A Tester may write `test-report.md` and nothing else.

Repairing during testing converts a real failure into an apparent pass, and the
resulting report describes code that was never reviewed. A blocked verdict is a
successful outcome.

## A report is a record

`test-report.md` is durable evidence, not a status line (NFR-004). It states, per
acceptance criterion:

- the criterion under test, quoted
- the result: `PASS`, `FAIL`, or `UNVERIFIED`
- the evidence observed — the command and its actual output, or the observation
  made

Every result should be reproducible by someone reading the report.

## Unverified is not passed

> **A criterion that was not evaluated MUST NOT be scored `PASS`.**

Use `UNVERIFIED` when a criterion could not be exercised — no environment, a
missing fixture, an unrun command. `PASS` means the evidence was observed.
Inferring a pass from "the code looks right" is scoring an unverified criterion,
and it hides real failures behind an optimistic report.

The validator `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" validate-test-report` requires that criteria were
actually evaluated (US-7.1). An empty report and a report reading `All criteria
PASS.` with no evidence both fail that contract.

## Honouring the modal verb

Test against the level the requirement states:

| Criterion says | Failure means |
|---|---|
| `MUST` | Blocking. The change does not meet its acceptance criteria. |
| `SHOULD` | A finding to record and justify. Does not block by itself. |
| `MAY` | Not a defect when absent. |

Do not upgrade a failed `SHOULD` into a block, and never downgrade a failed
`MUST`.

## Test what the specification describes

Acceptance criteria are the test contract. A change that passes tests written
against the implementation, but not against the specification, has tested the
wrong thing. Start from the scenario text.

Where a criterion is ambiguous, say so in the report rather than choosing an
interpretation privately. An ambiguity discovered during testing is a
specification defect and belongs to the Spec Ingestor or the human Product
Manager — not to the Tester to resolve.

## The verdict

A test report that declares a `FAIL` is still a **well-formed** report: it
validates, and it exits 0. Well-formedness and passing are different questions.

Use `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" workflow-status --change <name>` for the gate verdict. That script
combines the report's own contract with whether failures were reported, so a
contract-valid report describing failures does not pass the gate.
