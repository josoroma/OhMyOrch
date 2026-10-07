---
name: post-install
description: Compatibility alias for explicit project adaptation.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
---

Invoke /ohmyorch:adapt-project with the same arguments. This is explicit adaptation, not an automatic installation callback.

Use the installed code root and explicit project root:

Read `${CLAUDE_PLUGIN_ROOT}/references/contract.md` before acting.

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" adapt-project --dry-run
```

The command is schematic. Parse $ARGUMENTS as data and shell-escape each actual value; never paste arbitrary user text into shell syntax. Inline placeholders are text substitutions, not Bash environment exports. Paths from doctor/config override literal artifact-name examples. Do not write the plugin cache, copy generic rules, change credentials or install prerequisites automatically.
