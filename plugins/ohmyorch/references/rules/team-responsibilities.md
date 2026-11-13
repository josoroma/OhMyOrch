# Team Responsibilities

Who decides, who delivers and who authors. These rules bind every session and agent.

## Authority

The **human Product Manager** is the final product authority. Product intent comes
from the human's decisions and the approved source documents. Nothing else decides
what the product should do, including existing code. An open product question goes
to the human; it is never settled by a guess.

The **main session** coordinates and delivers. It persists what the authoring agents
return. It takes each `READY` story through propose, apply, verify and archive
itself, then marks the story `DONE`. There are no per-stage delivery agents.

## The three authoring agents

| Agent | Authors | Writes files? |
|---|---|---:|
| `ohmyorch:codebase-analyst` | `CODEBASE.md`, the current state of the repository | No |
| `ohmyorch:product-specifier` | `PRD.md`, the product intent | No |
| `ohmyorch:spec-ingestor` | `SPECS.md`, the backlog of stories | No |

Each agent returns its document as Markdown, and the invoking skill writes the file.

**Codebase Analyst** describes what exists. It never states what should be built,
and it never lets an observation in `CODEBASE.md` become a product requirement.
Unknowns are recorded as unknowns.

**Product Specifier** writes down product intent from the approved sources. It
treats `CODEBASE.md` as evidence about feasibility and current state, never as
intent. It must not invent externally observable behavior.

**Spec Ingestor** decomposes intent into stories with testable acceptance criteria.
It does not add behavior the PRD does not support, and it must not mark a story
`READY` unless its expected behavior is testable.

## Enforcement

The hook dispatcher blocks every `Write`, `Edit` and `MultiEdit` call made by an
`ohmyorch:*` agent, so an authoring agent cannot write a file. See `openspec.md` and
`delivery-loop.md` for the rules of delivery.
