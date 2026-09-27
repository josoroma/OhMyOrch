# PRD — OhMyOrch Harness for Spec-Driven Product Delivery

CODEBASE Context: absent (greenfield — no meaningful application codebase)

## 1. Product Summary

The OhMyOrch Harness is a reusable, project-agnostic operating system for AI-assisted software delivery. It supports both greenfield projects and existing codebases. For an existing codebase, a Codebase Analyst first produces a durable `CODEBASE.md` describing the repository as it exists. Product-definition agents then use source documents plus `CODEBASE.md` when generating or updating `PRD.md` and `SPECS.md`. The harness selects one manageable unit of work at a time, plans it with OpenSpec, implements it, independently reviews it, tests it against explicit acceptance criteria, and archives the completed change.

The harness is designed for teams that want Claude Code to behave less like one unconstrained coding agent and more like a small product engineering team with clear responsibilities, handoffs, gates, and durable artifacts.

## 2. Problem

AI coding assistants are effective at generating code but often collapse product analysis, planning, implementation, review, and testing into one context. This creates predictable failure modes:

- requirements are inferred or silently invented;
- implementation begins before acceptance criteria are stable;
- the same agent writes and approves its own work;
- reviews optimize for the implementation rather than the requirement;
- tests verify code paths without proving product acceptance;
- large product documents are treated as one oversized implementation prompt;
- state is lost between sessions;
- completed work is difficult to trace back to its source requirement;
- brownfield projects are planned without a durable model of the existing architecture, commands, tests, conventions, integrations, and current behavior;
- product documents may accidentally conflict with what the repository already supports because codebase context is rediscovered ad hoc in every session.

The team needs a harness that makes the workflow explicit, resumable, testable, and auditable.

## 3. Goals

1. Detect whether a target project already contains a meaningful codebase and, when it does, create or refresh a durable `CODEBASE.md` before product specification generation.
2. Accept arbitrary source documents and normalize them into a project `PRD.md` and iterable `SPECS.md` backlog.
3. Require PRD and SPECS generation to consume `CODEBASE.md` whenever that file exists.
4. Preserve traceability from source material and relevant codebase evidence to product requirements and implementation changes.
5. Require observable acceptance criteria before a story is considered implementation-ready.
6. Use one manageable OpenSpec change per independently verifiable feature or user story.
7. Separate product management, specification ingestion, planning, implementation, review, and testing responsibilities.
8. Prevent agents from silently assuming missing product decisions.
9. Make every workflow resumable from repository artifacts rather than hidden chat state.
10. Use OpenSpec as the implementation-change protocol.
11. Make the harness reusable across arbitrary repositories and technology stacks.
12. Provide clear commands and conventions that a human Product Manager can understand and control.

## 4. Non-Goals

- Replacing the human Product Manager as final product authority.
- Automatically resolving contradictory or ambiguous product requirements.
- Treating existing implementation as authoritative product intent merely because it exists in the repository.
- Replacing repository exploration with `CODEBASE.md`; the file is a durable map and must be refreshed when material repository changes make it stale.
- Defining a project-specific target architecture before repository and requirement exploration.
- Forcing one testing framework, programming language, or application stack.
- Replacing CI/CD, source control, pull requests, or production observability.
- Treating every trivial edit as a full product change when the team explicitly exempts it.

## 5. Users

### Primary User — Product Manager / Product Owner

Needs to provide product material, review normalized requirements, select ready work, approve clarifications, and control the delivery lifecycle.

### Secondary User — Engineering Lead / Senior Engineer

Needs predictable planning artifacts, bounded implementation scope, independent review, and evidence that acceptance criteria were tested.

### AI Team Roles

- **Codebase Analyst** — inspects an existing repository and writes or refreshes `CODEBASE.md` as an evidence-backed description of the current system.
- **Product Specifier** — generates or updates `PRD.md` from product source material and, when present, `CODEBASE.md`, without turning current implementation into unstated product intent.
- **Spec Ingestor** — converts product source documents, `PRD.md`, and, when present, `CODEBASE.md` into an iterable `SPECS.md` without inventing requirements.
- **Product Manager Agent** — orchestrates the workflow and selects the next ready unit of work.
- **Planner** — explores the codebase and produces implementation planning artifacts.
- **Implementer** — modifies source code and implementation tests according to the approved specification.
- **Reviewer** — verifies the implementation against the specification and produces a review handoff.
- **Tester** — independently validates acceptance criteria and produces a test report.

## 6. Product Principles

### 6.1 Source before interpretation

Requirements must remain traceable to source documents. Unsupported requirements must not be marked ready.

### 6.2 Acceptance before implementation

Externally observable behavior requires acceptance criteria. A story without sufficient acceptance criteria is not ready to implement.

### 6.3 One role, one responsibility

Planning, implementation, review, testing, and product decisions must not collapse into one self-validating agent.

### 6.4 Repository state over chat state

Important decisions and workflow state must be persisted in files so work can resume in a new Claude session.

### 6.5 Small changes over project-sized prompts

A large `SPECS.md` is a backlog, not a single OpenSpec change. The Product Manager selects one independently verifiable unit at a time.

### 6.6 No silent assumptions

When a missing decision affects product behavior, the harness must surface an open question or block the story rather than invent an answer.

### 6.7 Codebase evidence is descriptive, not normative

`CODEBASE.md` describes what the repository currently contains: architecture, runtime, entry points, data flows, integrations, tests, commands, conventions, and observable existing behavior. It may constrain feasibility and reveal compatibility requirements, but existing code MUST NOT silently become the desired product requirement.

### 6.8 Context before specification generation

When `CODEBASE.md` exists, any agent or skill that creates or materially updates `PRD.md` or `SPECS.md` MUST read it first. When a meaningful codebase exists but `CODEBASE.md` does not, the harness SHOULD run codebase analysis before generating project product artifacts.

## 7. Core Workflow

```text
Existing codebase? ------------------------------+
      | yes                                      |
      v                                          |
Codebase Analyst                                 |
      |                                          |
      v                                          |
CODEBASE.md                                      |
      |                                          |
      +------------------+                       |
                         v                       |
Source documents ---> Product Specifier          |
                         |                       |
                         v                       |
                       PRD.md                     |
                         |                       |
                         v                       |
                    Spec Ingestor <--------------+
                         |
                         v
                      SPECS.md
                         |
                         v
Product Manager selects READY story
      |
      v
/opsx:explore
      |
      v
/opsx:propose
      |
      v
Planner handoff
      |
      v
/opsx:apply
      |
      v
Implementer
      |
      v
Reviewer
      |
      +---- changes requested ----> Implementer
      |
      v
Tester
      |
      +---- failure -------------> Implementer -> Reviewer -> Tester
      |
      v
Accepted
      |
      v
/opsx:archive
      |
      v
Next READY story
```

## 8. OpenSpec Integration

The harness uses OpenSpec as the per-change delivery protocol.

Required workflows:

- `/opsx:explore` — understand the problem and codebase without implementing.
- `/opsx:propose` — generate `proposal.md`, delta specs, optional `design.md`, and `tasks.md`.
- `/opsx:apply` — implement the approved tasks.
- `/opsx:verify` — verify implementation against the specification.
- `/opsx:archive` — archive the completed change and update canonical OpenSpec specs.

The harness SHOULD enable OpenSpec's optional `verify` workflow because independent verification is a required product gate.

## 9. Functional Requirements

### FR-001 — Source Document Ingestion

The harness SHALL accept one or more source documents and convert supported product information into `SPECS.md`.

### FR-002 — Structured Product Backlog

`SPECS.md` SHALL organize requirements into product context, goals, non-goals, actors, constraints, non-functional requirements, business rules, epics, user stories, acceptance criteria, dependencies, tasks, open questions, conflicts, and source references.

### FR-003 — Gherkin Acceptance Criteria

Ready user stories SHALL contain observable acceptance criteria expressed as Gherkin scenarios using `Given`, `When`, and `Then`.

### FR-004 — Readiness States

Every user story SHALL expose one of these states:

- `READY`
- `NEEDS CLARIFICATION`
- `BLOCKED`
- `IN PROGRESS`
- `DONE`

### FR-005 — Source Traceability

Generated requirements SHOULD record a source reference sufficient to locate the originating material when the source format makes such a locator available.

### FR-006 — Incremental Delivery

The Product Manager SHALL select one manageable `READY` user story or cohesive feature for each OpenSpec implementation change.

### FR-007 — Planner Handoff

The Planner SHALL produce an `implementation-plan.md` that maps tasks to requirements, likely files, dependencies, risks, and expected tests.

### FR-008 — Independent Review

The Reviewer SHALL not modify product implementation code while acting as Reviewer. Findings SHALL be written to `review.md` and returned to the Implementer.

### FR-009 — Independent Acceptance Testing

The Tester SHALL map acceptance criteria to executable evidence and record results in `test-report.md`.

### FR-010 — Archive Gate

A change SHALL NOT be archived while blocking review findings remain, acceptance criteria are failing, required tasks remain incomplete, or OpenSpec verification reports blocking mismatches.

### FR-011 — Session Resumption

The harness SHALL allow a new Claude session to determine the current change state and resume from repository artifacts.

### FR-012 — Project Agnosticism

The harness SHALL derive project-specific commands, frameworks, architecture, and test tooling from repository evidence rather than hardcoding a particular stack.

### FR-013 — Codebase Analysis

When a target project contains an existing codebase, the harness SHALL provide a Codebase Analyst capable of inspecting repository structure, runtime configuration, entry points, architecture, data flows, persistence, external integrations, tests, quality tooling, common commands, conventions, and material existing behavior, and persisting that understanding in `CODEBASE.md`.

### FR-014 — CODEBASE.md Contract

`CODEBASE.md` SHALL be evidence-backed and SHALL distinguish verified repository observations from unknowns. It SHOULD record the analyzed repository revision or other available snapshot identifier and the important paths that support its conclusions.

### FR-015 — CODEBASE-aware PRD Generation

When `CODEBASE.md` exists, the Product Specifier SHALL read it before creating or materially updating `PRD.md`. The Product Specifier MAY use codebase evidence to document current-state capabilities, compatibility constraints, technical boundaries, migration considerations, and identified gaps, but SHALL NOT infer desired product behavior solely from existing implementation.

### FR-016 — CODEBASE-aware SPECS Generation

When `CODEBASE.md` exists, the Spec Ingestor SHALL read it before creating or materially updating `SPECS.md`. Generated stories SHOULD identify relevant existing capabilities and constraints when supported by `CODEBASE.md`, while acceptance criteria SHALL remain grounded in explicit product requirements or Product Manager decisions.

### FR-017 — Context Generation Gate

When a meaningful existing codebase is detected and `CODEBASE.md` is absent, a PRD/SPECS generation workflow SHALL either run the Codebase Analyst first or explicitly record that codebase analysis was intentionally skipped. When `CODEBASE.md` exists but is known to be stale relative to material repository changes, generation SHALL surface the stale-context condition before treating the file as current.

### FR-018 — Product Artifact Generation

The harness SHALL expose reusable skills for analyzing the codebase, generating or updating `PRD.md`, and generating or updating `SPECS.md`, with explicit context ordering: product source material is normative for intent, `CODEBASE.md` is descriptive evidence of the current system, and the human Product Manager resolves conflicts between desired behavior and current implementation.

### FR-019 — Goal-Driven Delivery Orchestration

The harness SHALL accept a delivery target — an epic, a user story, or a task — from `SPECS.md` and drive it to completion as a goal loop. An epic SHALL be delivered as one bounded OpenSpec change per story, in `SPECS.md` order. A task SHALL resolve to its parent story, because the story is the smallest independently verifiable unit (BR-003). At each step the harness SHALL derive the next action from repository artifacts, delegate it to the owning role, and continue until the target is delivered, a human Product Manager decision is required, or the loop stops making progress. The orchestrator SHALL NOT bypass, weaken, or author the verdict of any existing gate.

Source: Human Product Manager decision, 2026-09-24 (request for an orchestrator that takes an epic, user story, or task from `SPECS.md` and plans, implements, and reviews it, including OpenSpec changes and specs).

## 10. Non-Functional Requirements

### NFR-001 — Auditability

Every shipped story should be traceable through:

`source documents + CODEBASE.md evidence -> PRD.md -> SPECS.md story -> acceptance criteria -> OpenSpec change -> tasks -> implementation -> review -> test evidence -> archive`.

### NFR-002 — Determinism

Workflow transitions and completion gates SHOULD be based on explicit repository artifacts and machine-checkable status where practical.

### NFR-003 — Portability

The harness SHOULD be installable into an existing Git repository without requiring application restructuring.

### NFR-004 — Minimal Hidden State

A session restart SHOULD not require reconstructing critical product or implementation decisions from chat history.

### NFR-005 — Fail Closed on Product Ambiguity

Missing or contradictory product behavior SHOULD result in `NEEDS CLARIFICATION` or `BLOCKED`, not fabricated requirements.

## 11. Repository Contract

```text
.
├── CODEBASE.md              # generated when an existing codebase is analyzed
├── PRD.md
├── SPECS.md
├── README.md
├── CLAUDE.md
├── openspec/
│   ├── config.yaml
│   ├── specs/
│   └── changes/
└── .claude/
    ├── agents/
    │   ├── codebase-analyst.md
    │   ├── product-specifier.md
    │   ├── spec-ingestor.md
    │   ├── product-manager.md
    │   ├── planner.md
    │   ├── implementer.md
    │   ├── reviewer.md
    │   └── tester.md
    ├── skills/
    │   ├── analyze-codebase/SKILL.md
    │   ├── generate-prd/SKILL.md
    │   ├── ingest-spec/SKILL.md
    │   ├── product-iteration/SKILL.md
    │   ├── deliver/SKILL.md
    │   ├── plan-feature/SKILL.md
    │   ├── review-feature/SKILL.md
    │   └── test-feature/SKILL.md
    ├── rules/
    │   ├── codebase-context.md
    │   ├── specification-ingestion.md
    │   ├── openspec.md
    │   ├── gherkin.md
    │   ├── testing.md
    │   ├── delivery-loop.md
    │   └── team-responsibilities.md
    └── settings.json
```

An active delivery goal (FR-019) is recorded outside any single change, because it may
span several:

```text
openspec/delivery/
├── goal.md                  # target, stories, status — the goal loop's durable state
└── loop.state               # iteration and stall counters written by the Stop hook
```

Each active change MAY add harness-owned handoff artifacts:

```text
openspec/changes/<change-id>/
├── proposal.md
├── specs/
├── design.md
├── tasks.md
├── implementation-plan.md
├── review.md
├── test-report.md
└── status.md
```

## 12. State Model

```text
PROJECT_DISCOVERY
CODEBASE_ANALYSIS
CODEBASE_READY
SOURCE_DOCUMENTS
PRD_GENERATION
PRD_READY
SPEC_INGESTION
SPECS_READY
SELECTED
EXPLORING
PROPOSED
PLANNED
IMPLEMENTING
REVIEWING
CHANGES_REQUESTED
TESTING
TEST_FAILED
ACCEPTED
ARCHIVED
BLOCKED
```

The active project-definition or change-delivery workflow should have one current state at a time.

## 13. Definition of Ready

A story is `READY` when:

- `CODEBASE.md` has been considered when it exists and is relevant to the story;
- its intended behavior is sufficiently defined;
- blocking product ambiguities are resolved;
- dependencies required before implementation are satisfied or explicitly handled;
- at least one observable acceptance scenario exists;
- the story is small enough to be implemented and verified as one manageable change.

## 14. Definition of Done

A story is `DONE` when:

- OpenSpec planning artifacts exist and reflect the accepted scope;
- implementation tasks are complete;
- review has no blocking findings;
- acceptance criteria pass;
- required project validation passes;
- OpenSpec verification has no blocking mismatch;
- the change is archived;
- `SPECS.md` reflects the story's completed state.

## 15. Success Metrics

The harness is successful when the team can demonstrate:

1. A new project can adopt the harness without project-specific rewrites to the core workflow.
2. An existing repository can be analyzed once into a durable `CODEBASE.md` that later agents can consume.
3. A raw product document can be transformed into `PRD.md` and an iterable backlog without unsupported requirements being silently added.
4. When `CODEBASE.md` exists, generated PRD/SPECS artifacts demonstrably account for relevant existing architecture, commands, constraints, integrations, tests, and behavior without treating implementation as product intent.
5. Any `READY` story can be traced to its source material and acceptance criteria.
6. A new Claude session can resume an active change using repository artifacts.
7. Implementers cannot approve their own work through the intended workflow.
8. Failed review or acceptance gates return work to implementation instead of allowing archival.
9. OpenSpec changes remain bounded to manageable units rather than the full project backlog.

## 16. Initial Delivery Scope

The first version of the harness SHALL deliver:

- all eight agent definitions, including Codebase Analyst and Product Specifier;
- seven reusable skills, including codebase analysis and PRD generation;
- repository-level rules;
- workflow hooks/gates;
- OpenSpec initialization/configuration guidance;
- validation for `SPECS.md` identifiers and Gherkin readiness;
- workflow state persistence;
- README documentation;
- example brownfield codebase-analysis flow;
- example PRD and document-ingestion flow;
- example story lifecycle from selection through archive.

## 17. References

- OpenSpec: https://openspec.dev/
- OpenSpec Quickstart: https://openspec.dev/docs/quickstart
- OpenSpec CLI: https://openspec.dev/docs/cli
- OpenSpec Skills: https://openspec.dev/docs/skills
- Claude Code documentation: https://code.claude.com/docs/
