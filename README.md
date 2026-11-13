# OhMyOrch

[![Watch From Spec to Delivery: OpenSpec + OhMyOrch Workflow Explained on YouTube](https://img.youtube.com/vi/vLKeNAXPPd8/maxresdefault.jpg)](https://www.youtube.com/watch?v=vLKeNAXPPd8)

[**Watch the walkthrough: From Spec to Delivery**](https://www.youtube.com/watch?v=vLKeNAXPPd8)

The walkthrough was recorded for 0.0.1 and predates the simplified propose, apply, verify, archive flow described below.

![OhMyOrch](https://josoroma.github.io/OhMyOrch/docs/images/OhMyOrch.png)

<https://josoroma.github.io/OhMyOrch/docs/OhMyOrch.html>

[Plugin handbook](plugins/ohmyorch/README.md) · [Installation & updates](docs/distribution.md)

## How delivery works

OhMyOrch is a Claude Code plugin that delivers a `SPECS.md` backlog with OpenSpec. Each READY story becomes one OpenSpec change, and the main session takes it through four steps:

```text
SPECS.md READY story
   -> propose   /ohmyorch:opsx-propose   proposal.md, specs/, design.md (only when needed), tasks.md
   -> apply     /ohmyorch:opsx-apply     implement the tasks, tick them in tasks.md
   -> verify    /ohmyorch:opsx-verify    advisory check of the implementation against the change
   -> archive   openspec archive <id> -y merges the delta specs, moves the change to changes/archive/
   -> story marked DONE in SPECS.md
```

Run the whole loop with `/ohmyorch:deliver <target>`, where the target is an epic (`EPIC-1`), a story (`US-1.1`) or a task (`US-1.1#2`). The next action is derived from `SPECS.md` and the change directory on every call, so a new session resumes from the files, not from chat memory.

- A change's record is OpenSpec's own artifacts. `tasks.md` is the only progress tracker.
- Verify writes no file. A CRITICAL finding becomes a new unticked task, which returns the change to apply.
- Two guards are mechanical: `openspec archive` is refused while `tasks.md` has unticked tasks, and a story cannot become DONE while its change is still active.
- The plugin has 20 skills (19 public commands and one internal contract), three read-only authoring agents for the PRD, SPECS and CODEBASE documents, root hooks and a Bash/jq runtime. The [guide](docs/OhMyOrch.md) lists every skill.

![Local plugin workflow](docs/images/ohmyorch-local-plugin-workflow.png)

**0.1.0 is the current source version; it is not tagged. The last tagged release is 0.0.1.** For a local preview, run from this repository:

```bash
claude --plugin-dir ./plugins/ohmyorch
```

![Preparing and delivering approved work](docs/images/ready-intent-to-execution.png)

![Installation, prerequisites and release checks](docs/images/validate-first-publish-second.png)

![Contributing and project ownership](docs/images/publisher-repo-and-consumer-project.png)

## See your specification as a workspace

[SPECS-APP.hml](SPECS-APP.hml) turns your backlog into a Kanban board. Open a story to see its criteria, tasks, and dependencies, or switch to Document for the complete specification.

![SPECS workspace showing ready and blocked stories](docs/images/specs-backlog-board.png)

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

The sample includes a matching [PRD](docs/SPECS-EXAMPLE/PRD.md) and [codebase context](docs/SPECS-EXAMPLE/CODEBASE.md).
