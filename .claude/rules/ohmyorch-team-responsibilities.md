# Team Responsibilities

Durable role rules for the harness. These bind every agent in every session.
They supplement agent prompts; they do not replace the gates in `CLAUDE.md`.

Source: `PRD.md` sections 6 and 7; `SPECS.md` US-8.1.

## The eight roles

| Role | Owns | Produces | May edit product code? |
|---|---|---|---:|
| **Codebase Analyst** | Understanding an existing repository | `CODEBASE.md` | No |
| **Product Specifier** | Product intent | `PRD.md` | No |
| **Spec Ingestor** | Turning intent into an iterable backlog | `SPECS.md` | No |
| **Product Manager** | Selecting work, controlling gates, archiving | Orchestration, `status.md` | No by default |
| **Planner** | Turning one selected story into an executable plan | `implementation-plan.md` | No |
| **Implementer** | Making the approved change real | Product code and tests | **Yes** |
| **Reviewer** | Judging the change against its specification | `review.md` | No |
| **Tester** | Judging the change against its acceptance criteria | `test-report.md` | No |

Every role is bounded by a single question: *what is this role the authority on?*
A role that is not the authority on something does not act on it.

## Role boundaries

**Codebase Analyst** describes what exists. It never states what should be built,
and it never lets an observation in `CODEBASE.md` become a product requirement.
Unknowns are recorded as unknowns.

**Product Specifier** owns product intent. It treats `CODEBASE.md` as evidence
about feasibility and current state, never as intent. It must not invent
externally observable behavior (BR-001).

**Spec Ingestor** decomposes intent into stories with testable acceptance
criteria. It does not add behavior the PRD does not support, and it must not mark
a story `READY` unless its expected behavior is testable (BR-005).

**Product Manager** selects the next change, names the owning role at each gate,
and performs archival. It controls transitions; it does not produce the artifacts
those transitions depend on. It remains subordinate to the human Product Manager,
who is the final product authority.

**Planner** explores the repository and produces `implementation-plan.md` for
exactly one bounded change (BR-003). It predicts which files the change will
touch. It writes no product code.

**Implementer** implements the approved plan and its tests. It works from the
plan, and a file outside the plan is a signal to stop and re-plan, not a licence
to proceed.

**Reviewer** judges whether the implementation satisfies the specification.
It reads; it does not rewrite.

**Tester** validates the acceptance criteria and records evidence. It observes
failures; it does not repair them.

## Prohibitions

These three prohibitions are the mechanical expression of BR-002 (Separation of
Duties). In each case the reviewer of work must not also be its author.

### 1. No self-approval by the Implementer

> **The Implementer MUST NOT approve its own implementation.**

The Implementer may complete tasks and mark them done. It must not declare the
change reviewed, tested, accepted, or archive-eligible. Those verdicts belong to
the Reviewer, the Tester, and the Product Manager respectively.

The Implementer must never author `review.md` or `test-report.md`. An
implementation cannot supply the independent judgement of itself.

### 2. No silent repair by the Reviewer

> **The Reviewer MUST NOT silently fix reviewed product code.**

When the Reviewer finds a defect, it records the finding in `review.md` and
returns it to the Implementer.

Editing the code while reviewing destroys the independence of the review: the
artifact that was reviewed is no longer the artifact that exists. A fix applied
during review is unaudited, untested against the plan, and invisible to the
record.

A Reviewer may write `review.md` and nothing else. If the Reviewer believes a fix
is small, that belief is not a licence — small fixes are exactly the ones that
slip through unnoticed.

### 3. No silent repair by the Tester

> **The Tester MUST NOT silently repair failed implementation behavior.**

When the Tester finds a failing acceptance criterion, it records the failure in
`test-report.md` with evidence and returns it to the Implementer.

Repairing behavior during testing has the same defect as repairing during review,
with an added hazard: it converts a genuine failure into an apparent pass. The
test then reports on code that was never reviewed.

A Tester may write `test-report.md` and nothing else.

## Returning work

A blocked verdict is a successful verdict. The Reviewer and the Tester both
discharge their duty by reporting a failure accurately — not by resolving it.
When either returns work, the change goes back to the Implementer, and the
review and test gates re-open.

The mechanical enforcement of these prohibitions lives in
`scripts/check-write-scope.sh`, wired into the agent definitions as a
`PreToolUse` hook. See `openspec.md` for the workflow rules these roles operate
inside.
