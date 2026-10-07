---
name: upgrade-project
description: Explicitly upgrade project state or recover a lifecycle transaction.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
---

Preview `upgrade-project --dry-run`. Schema 1 is current. Unsupported future schema has no guessed upgrade. Legacy counters are archived explicitly; goal/history remains. Use --apply after review. To recover use --rollback <operation-id> --dry-run, then --apply; rollback refuses concurrent edits.

Use the installed code root and explicit project root:

Read `${CLAUDE_PLUGIN_ROOT}/references/contract.md` before acting.

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" upgrade-project --dry-run
```

The command is schematic. Parse $ARGUMENTS as data and shell-escape each actual value; never paste arbitrary user text into shell syntax. Inline placeholders are text substitutions, not Bash environment exports. Paths from doctor/config override literal artifact-name examples. Do not write the plugin cache, copy generic rules, change credentials or install prerequisites automatically.
