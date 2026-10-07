# OpenSpec Workflow

Rules for operating the OpenSpec change lifecycle. Source: `CLAUDE.md`,
`PRD.md` section 8, `SPECS.md` US-8.2.

## The lifecycle

```text
SPECS.md READY story
   -> /ohmyorch:opsx-explore     understand problem + repository (no implementation)
   -> /ohmyorch:opsx-propose     proposal.md, delta specs, design.md, tasks.md
   -> implementation-plan.md   (Planner handoff)
   -> /ohmyorch:opsx-apply       implement approved tasks
   -> review.md         (Reviewer findings)
   -> /ohmyorch:opsx-verify      verify implementation against specification
   -> test-report.md    (Tester acceptance evidence)
   -> /ohmyorch:opsx-archive     archive change, update canonical specs
   -> SPECS.md story marked DONE
```

One bounded change at a time. `SPECS.md` is a backlog, not one large prompt.

## Artifacts are the state

The change directory is the source of truth:

```text
openspec/changes/<change>/
  proposal.md             why, and what is in scope
  specs/                  the delta specifications
  design.md               how, when a design decision is needed
  tasks.md                the implementation checklist
  implementation-plan.md  the Planner handoff
  review.md               the Reviewer verdict
  test-report.md          the Tester evidence
```

A fresh session resumes by reading these files. State that exists only in a chat
transcript does not exist (BR-004, NFR-003).

## Durable state versus derived state

`status.md` records the stage a change reached, its owner, and its blockers. It holds
two kinds of content and the distinction matters:

- The **gates table, `State`, `Current owner`, and Resume line are derived** from
  `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" workflow-status`. Never hand-edit them; refresh with
  `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" status --change <name>`. An editable gate table is a second source of
  truth that can silently disagree with the reporter.
- The **`## Blockers` section is authored**, and sits between
  `BEGIN/END AUTHORED: blockers` so a refresh preserves it rather than replacing it.

Advancing a gate is a state change, so refresh `status.md` with it. A recorded state
that no longer matches the repository is worse than no state, because a resuming
session trusts it:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" status --resume --change <name>      # where to continue
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" validate-status --change <name>      # is the record still current?
```

## Archival

> **A change MUST NOT be archived while any completion condition is unmet.** (US-8.2, US-10.1)

Blocking review findings and failing acceptance tests are the two clearest
prohibitions, but the rule is general: archival requires every condition to pass.

Two checks apply, and they are **not the same list**:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" workflow-status --change <name>   # the seven workflow gates
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" --session-id "${CLAUDE_SESSION_ID}" completion-gate --change <name>   # the four completion conditions
```

The gate chain answers *"where is this change in the workflow?"* The completion gate
answers *"may this change be shipped?"* Neither contains the other — OpenSpec
verification is a completion condition with no corresponding gate — so run both.

The guard `"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" guard-archive` rejects archival mechanically, deferring to
`completion-gate.sh` when present and to the gate chain otherwise, so there is exactly
one source of truth for the verdict.

Do not archive by editing files directly. Archival is an OpenSpec operation that
updates the canonical specs; performing it by hand bypasses spec synchronisation.

Mark the story `DONE` in `SPECS.md` **only after** a successful archive, then refresh
the durable record. This transition is enforced, not merely documented:
`"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" guard-story-done` rejects a `SPECS.md` write that would introduce
`Status: DONE` while the change is not archive-eligible.

## Status vocabulary

Story states:

```text
READY | NEEDS CLARIFICATION | BLOCKED | IN PROGRESS | DONE
```

Change states:

```text
PROJECT_DISCOVERY | CODEBASE_ANALYSIS | CODEBASE_READY | SOURCE_DOCUMENTS
| PRD_GENERATION | PRD_READY | SPEC_INGESTION | SPECS_READY | SELECTED
| EXPLORING | PROPOSED | PLANNED | IMPLEMENTING | REVIEWING
| CHANGES_REQUESTED | TESTING | TEST_FAILED | ACCEPTED | ARCHIVED | BLOCKED
```

Use these values exactly. Do not invent intermediate states; if the correct state
is unclear, the change is `BLOCKED` and the Product Manager decides.

## Generated files

The seven bundled `skills/opsx-*` prompts derive from OpenSpec 1.13.2 and carry local plugin/role/path adaptations. Regenerate only in a maintainer scratch project and reapply/review those adaptations. Consumer `openspec update` does not update installed plugin code and must not recreate standalone commands or skills. Follow `references/openspec-provenance.md`.

## Scope discipline

The Planner predicts which files a change touches. That prediction is a contract,
not a suggestion. A file outside the prediction means either the plan was
incomplete or the work has drifted; in both cases, stop and re-plan rather than
expanding scope silently (BR-003).
