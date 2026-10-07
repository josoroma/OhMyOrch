---
name: adapt-project
description: Explicitly generate evidence-provenanced local guidance and managed blocks.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
---

Read configured CODEBASE/PRD/SPECS first. Preview `adapt-project --dry-run --mode merge`, optionally --nested only on request. Generated rules record evidence hashes and unknowns. Apply the reviewed changes; edited managed guidance conflicts rather than being overwritten.

Use the installed code root and explicit project root:

Read `${CLAUDE_PLUGIN_ROOT}/references/contract.md` before acting.

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" adapt-project --dry-run
```

The command is schematic. Parse $ARGUMENTS as data and shell-escape each actual value; never paste arbitrary user text into shell syntax. Inline placeholders are text substitutions, not Bash environment exports. Paths from doctor/config override literal artifact-name examples. Do not write the plugin cache, copy generic rules, change credentials or install prerequisites automatically.
