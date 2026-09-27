# Gherkin

Rules for writing acceptance criteria. Source: `PRD.md` FR-003 and section 7;
`SPECS.md` BR-005.

## The three keywords

Every acceptance criterion is written in Gherkin with all three keywords present:

```gherkin
Scenario: <name>
  Given <a starting condition>
  When <an action happens>
  Then <an observable outcome>
```

The keywords carry meaning, and dropping one usually hides a gap in the story.

- **Given** establishes the state before the action. Without it, the reader
  cannot tell what the scenario assumes.
- **When** is the single event that triggers the behavior. Without it, the
  scenario describes a state, not an action — and a state cannot be exercised.
- **Then** is what must be observable afterwards. It must be checkable by
  someone who did not write the code.

`And` may extend any of the three. It does not substitute for one of them.

> **A `Given`/`Then` pair with no `When` is not a testable scenario.**

Such a pair asserts that a condition holds without saying what produces it. It
cannot be turned into a test, because there is nothing to do. It must be given a
`When`, or the story must be marked `NEEDS CLARIFICATION`.

## Acceptance is mandatory

A story MUST NOT be `READY` unless its expected observable behavior is testable
(BR-005). "Testable" means: a Tester, given the scenario and the implementation,
can decide unambiguously whether it passes.

If you cannot write the `Then` as an assertion, the requirement is not yet
understood. That is a finding, not an obstacle to work around.

## What makes a `Then` testable

- It names something observable: output, a file, an exit code, an emitted event.
- It is specific enough to fail. "Works correctly" cannot fail.
- It does not reference internal implementation detail that the test should not
  depend on.

Prefer `Then the script exits 2 and prints a message naming the missing plan` over
`Then the guard works properly`.

## MUST, SHOULD, MAY

Modal verbs carry the acceptance bar, and they are not interchangeable:

- **MUST** — required for acceptance. A failure blocks the change.
- **SHOULD** — expected. A deviation is permitted but must be recorded and
  justified in the test report.
- **MAY** — optional. Absence is never a defect.

The Reviewer and Tester apply these levels literally. A failed `SHOULD` is a
finding to record, not a reason to block; a failed `MUST` blocks.

## One scenario, one behavior

A scenario asserts one thing. If the `Then` needs "and also", write a second
scenario. Composite scenarios fail ambiguously — when one half breaks, the whole
scenario fails and the report cannot say which requirement regressed.

## Traceability

Story identifiers (`US-8.2`) and requirement identifiers (`BR-002`, `NFR-001`)
appear in the artifacts that implement them. A reviewer should be able to start
at an acceptance criterion and follow it to the code, the test, and the evidence
(NFR-002).
