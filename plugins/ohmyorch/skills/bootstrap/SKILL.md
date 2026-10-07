---
name: bootstrap
description: Explicitly initialize or adopt a project for OhMyOrch without copying plugin code.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
---

Preview `bootstrap --dry-run` with the requested mappings and optional `--with-openspec`. Present changed paths/conflicts. Only apply the concrete requested plan. Existing PRD/SPECS are adopted unchanged. Use --mode merge only when managed CLAUDE guidance is requested. Never fabricate CODEBASE or READY stories.

Use the installed code root and explicit project root:

Read `${CLAUDE_PLUGIN_ROOT}/references/contract.md` before acting.

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" bootstrap --dry-run
```

The command is schematic. Parse $ARGUMENTS as data and shell-escape each actual value; never paste arbitrary user text into shell syntax. Inline placeholders are text substitutions, not Bash environment exports. Paths from doctor/config override literal artifact-name examples. Do not write the plugin cache, copy generic rules, change credentials or install prerequisites automatically.
