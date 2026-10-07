---
name: doctor
description: Read-only plugin and project diagnostics. Use before workflow operations.
allowed-tools: Read, Grep, Glob, Bash
---

Run the bundled doctor with `--json`. Report PASS/FAIL/UNSUPPORTED/SKIP distinctly and use its mapped documents. Never initialize or install prerequisites silently.

Use the installed code root and explicit project root:

Read `${CLAUDE_PLUGIN_ROOT}/references/contract.md` before acting.

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" doctor --json
```

The command is schematic. Parse $ARGUMENTS as data and shell-escape each actual value; never paste arbitrary user text into shell syntax. Inline placeholders are text substitutions, not Bash environment exports. Paths from doctor/config override literal artifact-name examples. Do not write the plugin cache, copy generic rules, change credentials or install prerequisites automatically.
