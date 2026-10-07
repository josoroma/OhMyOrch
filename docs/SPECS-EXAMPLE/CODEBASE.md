# CODEBASE — PocketTasks

Analyzed revision: pockettasks-docs-v1
Working tree: unknown — no separate PocketTasks Git checkout exists.

This is a documentation-only example of the `ohmyorch:codebase-analyst` report
format. It is not the result of an authenticated agent run or an audit of an
implemented application. A normal `/ohmyorch:analyze-codebase` run skips creating
CODEBASE.md when there is no meaningful application code; this file is included to
show the schema requested for the example.

## System Summary

PocketTasks currently consists of the three example documents in this folder.
The separate [SPECS viewer](../../SPECS-APP.hml) displays this backlog; it does not
implement PocketTasks.
There is no PocketTasks application source or user-facing implementation here.
[PRD.md](PRD.md) describes desired behavior; [SPECS.md](SPECS.md) records two
undelivered epics. Neither document is evidence that a feature exists.

## Repository Map

| Path | Kind | What it contains |
|---|---|---|
| [PRD.md](PRD.md) | Product document | Illustrative brief and desired requirements. |
| [CODEBASE.md](CODEBASE.md) | Context example | This description of the starting snapshot. |
| [SPECS.md](SPECS.md) | Backlog | Two epics, two stories, acceptance criteria, and four tasks. |
| [SPECS-APP.hml](../../SPECS-APP.hml) | Documentation viewer | Standalone HTML/JavaScript Kanban, epic hierarchy, and complete Markdown view. |

PocketTasks source, tests, and build output are absent from
this example folder. The surrounding repository contains the OhMyOrch plugin,
which is a separate product.

## Runtime and Tooling

No PocketTasks runtime, dependency manifest, lockfile, or build configuration is
present. The parent repository's Node/Python maintainer tools belong to OhMyOrch;
they do not establish a PocketTasks stack.

The documentation viewer embeds its CSS, JavaScript, and markdown-it 15.0.2
(with dependency license notices). It reads the root SPECS.md over HTTP, falling
back to this folder's SPECS.md when the root file is missing. A selector switches
between these two sources; a file picker also accepts a local Markdown file. It never writes backlog status or task checkboxes.
Only the viewer's theme preference is stored locally.

## Architecture

None identified. There are no implemented application modules to inspect.

## Entry Points

None identified for PocketTasks. The documentation utility's entry point is
[SPECS-APP.hml](../../SPECS-APP.hml). Its nonstandard extension must be served as
`text/html`; run this from the repository root, beside package.json:

```bash
python3 -c 'import http.server,mimetypes; mimetypes.add_type("text/html",".hml"); http.server.test(HandlerClass=http.server.SimpleHTTPRequestHandler,port=8000,bind="127.0.0.1")'
```

Then open `http://127.0.0.1:8000/SPECS-APP.hml`. The default is root SPECS.md;
if it does not exist, docs/SPECS-EXAMPLE/SPECS.md opens automatically. Use the
**Specification file** selector to switch between the two. **Open SPECS.md** and
file drop also accept a local Markdown file. Reload reads the selected source
again. Relative references resolve from the loaded specification's own folder.

## Data and Persistence

None identified. No task model, database, or storage implementation is present.
The session-only policy in PRD.md is desired behavior, not an observation of code.

## External Integrations

None identified in this sample. No application integration configuration exists.

## Authentication and Authorization

None identified in this sample. No application identity or authorization code exists.

## Existing Product Behavior

No task creation, task completion, or task reopening has been implemented.

## Tests and Quality Gates

No PocketTasks tests, test configuration, coverage results, or application CI are
present. Gherkin in SPECS.md specifies future acceptance checks; it is not a PASS
report. OhMyOrch's artifact validator checks document structure, not app behavior.

## Common Commands

No PocketTasks install, build, run, test, or lint commands are defined yet.

## Conventions

The example documents use stable requirement and story IDs, explicit context
markers, and links between product intent, current state, and planned work.
Application coding conventions are unknown because no source is present.

## Constraints and Technical Debt

The `pockettasks-docs-v1` identifier names this teaching snapshot; it is not a Git
SHA or a freshness proof for a consumer project. Do not reuse it as an analyzed
revision after implementing the app. No implementation debt can be established
without application code.

## Evidence Paths

- [PRD.md](PRD.md#example-product-brief) — explicit example intent, not current functionality.
- [SPECS.md](SPECS.md#work-item-status) — initial story states and unchecked tasks.
- [This folder](.) — contains the example documents, not PocketTasks source; the viewer lives in the repository root.

## Unknowns

- Application file layout and implementation stack: no application exists yet.
- Test framework and execution commands: no application tooling exists yet.
- PocketTasks browser compatibility and behavior: no PocketTasks browser test has run.

Resolve these through planning and real implementation evidence. Refresh CODEBASE.md
with `/ohmyorch:analyze-codebase` in the actual application checkout once code exists.
