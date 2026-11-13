# OpenSpec Workflow

Rules for the OpenSpec change lifecycle. Each `SPECS.md` story is delivered as one
change that follows the upstream OpenSpec 1.13.2 flow.

## The lifecycle

```text
SPECS.md READY story
   -> propose   /ohmyorch:opsx-propose   proposal.md, specs/, design.md (only when needed), tasks.md
   -> apply     /ohmyorch:opsx-apply     implement tasks, tick tasks.md
   -> verify    /ohmyorch:opsx-verify    advisory check of the implementation against the change
   -> archive   openspec archive <id> -y merges delta specs, moves the change to changes/archive/
   -> story marked DONE in SPECS.md
```

`/ohmyorch:opsx-explore` is optional: use it only when a story or the affected code
is unclear. There are no other stages, and the main session performs every step.

One story, one change; one active change at a time. `SPECS.md` is a backlog, not one
large prompt.

## The change directory is the state

```text
openspec/changes/<change>/
  proposal.md   why, and what is in scope
  specs/        the delta specifications
  design.md     how, only when a design decision is needed
  tasks.md      the implementation checklist
```

These four are OpenSpec's own artifacts and the only record of a change. `tasks.md`
is the only progress tracker. Do not add plan, review, test-report, status or
completion files.

A fresh session resumes by reading this directory. State that exists only in a chat
transcript does not exist.

## Inspecting a change

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" delivery next   # derived next action of the recorded goal
openspec status --change <id>      # artifact state of one change
openspec list                      # active changes and their task progress
openspec validate <id> --strict    # structure of the change and its delta specs
```

All four only read. Run `openspec` from the project root.

## Verify

`/ohmyorch:opsx-verify` is advisory and writes no file. It reports completeness,
correctness and coherence of the implementation against the change's artifacts.

- Verification is evidence-based. Never call a scenario passing without having
  observed it: a test you ran, output you read, or code you inspected. A check you
  skipped is not a pass.
- In the delivery loop these are CRITICAL whatever rank `/ohmyorch:opsx-verify` gives
  them: an acceptance scenario of the story that is not implemented, whose observed
  result contradicts its `Then`, or for which there is no observed evidence; and a
  project test that fails because of this change. A test that was already failing
  for an unrelated reason is reported, not turned into a task.
- Each CRITICAL finding becomes an unticked task appended to `tasks.md`, describing
  the fix. That returns the change to apply. Nothing else records a finding.
- With no CRITICAL finding, archive.

## Archival

Archive with the CLI, as a standalone Bash call:

```bash
openspec archive <id> -y
```

- The archive guard refuses the command while `tasks.md` has an unfinished task,
  counted as OpenSpec counts them: any checkbox marker other than `x`. Finish the
  task (`/ohmyorch:opsx-apply <id>`), or remove a task that no longer applies, then
  archive.
- `openspec archive` itself validates the delta specs, merges them into
  `openspec/specs/` and moves the change to `openspec/changes/archive/`. Invalid delta
  specs stop it: fix them, do not skip validation.
- The command must stand alone with a literal change id, which may be quoted. A
  chained, multi-line or variable-built form, or one with global options, is refused.
- Never archive by hand. Moving or editing the files yourself skips the validation
  and the merge. `/ohmyorch:opsx-archive` is upstream's interactive archive workflow;
  the delivery loop does not use it.

## DONE only after archive

Set a story's `Status: DONE` in `SPECS.md` only after its change is archived, and
point the story's `Change:` line at the archived path. The story-done guard refuses a
`SPECS.md` write that introduces `Status: DONE` while the story's change is still
active under `openspec/changes/`.

## Story status vocabulary

```text
READY | NEEDS CLARIFICATION | BLOCKED | IN PROGRESS | DONE
```

Use these values exactly. Delivery works only on `READY` and `IN PROGRESS` stories and
sets `IN PROGRESS` and `DONE` itself. Any other status needs a human decision first.

## Generated files

The seven bundled `skills/opsx-*` prompts are the skills OpenSpec 1.13.2 generates.
They differ from upstream only by the plugin namespace and one boundary paragraph.
Regenerate them only in a maintainer scratch project, then reapply those two
adaptations; see `references/openspec-provenance.md`. Consumer `openspec update` does
not update installed plugin code and must not recreate standalone commands or skills.
