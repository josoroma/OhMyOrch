# OhMyOrch

![OhMyOrch](docs/images/OhMyOrch.png)

OhMyOrch is a Claude Code plugin that delivers a `SPECS.md` backlog with OpenSpec, one story at a time.

<https://josoroma.github.io/OhMyOrch/docs/OhMyOrch.html>

[Plugin handbook](plugins/ohmyorch/README.md) · [Installation & updates](docs/distribution.md)

**Tutorial.** Three short videos show OhMyOrch 0.1.0, from installing it to a delivered project.

**1. What it is, install and update.** What OhMyOrch is, the four-step delivery loop and the two rules enforced by code; then how to install it, check it with doctor, and update the plugin and your project. About 2 minutes.

[![Watch OhMyOrch 01: Spec-Driven Delivery for Claude Code (What It Is, Install, Update) on YouTube](https://img.youtube.com/vi/TSdnfTWUTus/maxresdefault.jpg)](https://www.youtube.com/watch?v=TSdnfTWUTus)

**2. Initialize a project and deliver a story.** From a real project to a delivered story: doctor, a previewed bootstrap, codebase analysis, approved intent turned into READY work, the four steps with their real commands, and the three authoring agents. About 3 minutes.

[![Watch OhMyOrch 02: Initialize a Project and Deliver a Story with Claude Code on YouTube](https://img.youtube.com/vi/f46U6owMHa0/maxresdefault.jpg)](https://www.youtube.com/watch?v=f46U6owMHa0)

**3. Spec-driven development with OpenSpec.** A currency converter delivered story by story: OpenSpec deltas and merged specs, tests against a stubbed API, a requirement that changes, the SPECS workspace before and after, and a stop for a human decision. About 3.5 minutes.

[![Watch OhMyOrch 03: Spec-Driven Development with OpenSpec, Building a Currency Converter on YouTube](https://img.youtube.com/vi/Bq3IIbin1Ow/maxresdefault.jpg)](https://www.youtube.com/watch?v=Bq3IIbin1Ow)

Give Claude a READY story. The main session proposes, applies, verifies and archives one OpenSpec change, then marks the story DONE.

![OhMyOrch overview: one OpenSpec change per READY story, delivered by the main session](docs/images/slide-01-overview.svg)

## How delivery works

Each READY story becomes one OpenSpec change, and the main session takes it through four steps:

```text
SPECS.md READY story
   -> propose   /ohmyorch:opsx-propose   proposal.md, specs/, design.md (only when needed), tasks.md
   -> apply     /ohmyorch:opsx-apply     implement the tasks, tick them in tasks.md
   -> verify    /ohmyorch:opsx-verify    advisory check of the implementation against the change
   -> archive   openspec archive <id> -y merges the delta specs, moves the change to changes/archive/
   -> story marked DONE in SPECS.md
```

Run the whole loop with `/ohmyorch:deliver <target>`, where the target is an epic (`EPIC-1`), a story (`US-1.1`) or a task (`US-1.1#2`). The slide shows the command behind each step and the six actions the loop can derive.

![The four delivery steps: propose, apply, verify, archive, then the story is DONE](docs/images/slide-02-four-steps.svg)

- A change's record is OpenSpec's own artifacts. `tasks.md` is the only progress tracker.
- Verify writes no file. A CRITICAL finding becomes a new unticked task, which returns the change to apply.
- Two guards are mechanical: `openspec archive` is refused while `tasks.md` has unticked tasks, and a story cannot become DONE while its change is still active.

The next action is derived from `SPECS.md` and the change directory on every call, so a new session resumes from the files, not from chat memory.

![Files, not chat memory: five properties that let a new session resume](docs/images/slide-03-files-not-chat-memory.svg)

## Try it locally

**0.1.0 is the current version and the last tagged release.** For a local preview, run from this repository:

```bash
claude --plugin-dir ./plugins/ohmyorch
```

Load the plugin from a checkout, check the project, and preview the bootstrap before you apply it.

![Try it locally: load the plugin from a checkout, then bootstrap with a dry run first](docs/images/slide-04-try-it-locally.svg)

## Prepare, then deliver

Analyze the code, write or ingest the intent, deliver a READY story, and resume the goal when a session ends.

![Prepare, then deliver: analyze the codebase, generate or ingest intent, deliver, resume](docs/images/slide-05-prepare-then-deliver.svg)

## Install and release status

The prerequisites, the marketplace commands, and the release gates that are still open. [Installation & updates](docs/distribution.md) has the details.

![Distribution: prerequisites, marketplace install and the open release gates](docs/images/slide-06-validate-then-publish.svg)

## What's included

The plugin has 18 skills (17 public commands and one internal contract), three read-only authoring agents for the PRD, SPECS and CODEBASE documents, root hooks and a Bash/jq runtime.

![Plugin contents: 18 skills, 3 authoring agents, 6 rule references, root hooks, and what stays in your project](docs/images/slide-07-plugin-contents.svg)

The 17 public skills, grouped by the job you need to do. The [guide](docs/OhMyOrch.md) describes each one.

![Skill map: the public skills grouped by job](docs/images/slide-08-skill-map.svg)

## Work on the plugin

The checks a maintainer runs in this repository, and what never reaches a packaged plugin.

![Publisher repository and consumer project: maintainer checks, tools and packaging exclusions](docs/images/slide-09-publisher-and-consumer.svg)

## What a delivered story leaves behind

A change leaves only OpenSpec's own artifacts: no plan, review, test-report or status files.

![The change is the record: story, proposal, delta specs, optional design, tasks, archive, DONE](docs/images/slide-10-change-record.svg)

## See your specification as a workspace

[SPECS-APP.hml](SPECS-APP.hml) turns your backlog into a Kanban board. Open a story to see its criteria, tasks, and dependencies, or switch to Document for the complete specification.

![SPECS workspace showing the currency converter example: four DONE stories and one that needs clarification](docs/images/specs-backlog-board.png)

### Setup and run

Requires **Python 3**. The viewer needs no build step or Claude session.

```bash
git clone https://github.com/josoroma/OhMyOrch.git
cd OhMyOrch
python3 -c 'import http.server,mimetypes; mimetypes.add_type("text/html",".hml"); http.server.test(HandlerClass=http.server.SimpleHTTPRequestHandler,port=8000,bind="127.0.0.1")'
```

Already cloned? Run the Python command beside `package.json`. It serves `.hml` as HTML.

Open **[localhost:8000/SPECS-APP.hml](http://127.0.0.1:8000/SPECS-APP.hml)**. The app starts with your root `SPECS.md`; when that file is missing, it opens [the example backlog](docs/SPECS-EXAMPLE/SPECS.md). Use the file selector to switch between them.

### Use it

Switch between Stories, Tasks, and Epics; search or filter to focus on the work that matters. Document keeps the context and acceptance criteria visible, with a Markdown source view and download.

![SPECS document view with its outline and work-item status table](docs/images/specs-document-view.png)

Edit the Markdown file, then click **Reload**. The workspace is read only: it never changes delivery status. **Open SPECS.md** also lets you inspect another local backlog.

The example is a small currency converter, with a matching [PRD](docs/SPECS-EXAMPLE/PRD.md) and [codebase context](docs/SPECS-EXAMPLE/CODEBASE.md). It was delivered with `/ohmyorch:deliver`, one OpenSpec change per story, in the [third how-to video](https://www.youtube.com/watch?v=Bq3IIbin1Ow); [its code and OpenSpec record](docs/SPECS-EXAMPLE/README.md) are kept beside it.
