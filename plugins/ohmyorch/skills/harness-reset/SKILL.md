---
name: harness-reset
description: Explicit ownership-based reset with bounded workflow reset and recovery.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
---

Default to `harness-reset --dry-run --scope managed`. Filled/edited product content and host scripts remain. Full workflow reset requires an explicit --scope workflow request: enumerate all data loss, verify backups, and apply only with the reviewed --plan-id. Never reset on install/update or delete unowned nested CLAUDE files.

Use the installed code root and explicit project root:

Read `${CLAUDE_PLUGIN_ROOT}/references/contract.md` before acting.

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" harness-reset --dry-run
```

The command is schematic. Parse $ARGUMENTS as data and shell-escape each actual value; never paste arbitrary user text into shell syntax. Inline placeholders are text substitutions, not Bash environment exports. Paths from doctor/config override literal artifact-name examples. Do not write the plugin cache, copy generic rules, change credentials or install prerequisites automatically.
