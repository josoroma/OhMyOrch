---
name: migrate-legacy
description: Explicitly adopt project state and retire proven standalone OhMyOrch components.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
---

Preview `migrate-legacy --dry-run`. Known unmodified component hashes are removed through verified affected-file recovery; product docs and local settings remain. Edited known components require a separate --include-edited preview and explicit review. Apply only with the exact --plan-id returned by preview. Never run the old uninstaller or remove whole .claude/scripts directories.

Use the installed code root and explicit project root:

Read `${CLAUDE_PLUGIN_ROOT}/references/contract.md` before acting.

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/ohmyorch" --project-root "${CLAUDE_PROJECT_DIR}" migrate-legacy --dry-run
```

The command is schematic. Parse $ARGUMENTS as data and shell-escape each actual value; never paste arbitrary user text into shell syntax. Inline placeholders are text substitutions, not Bash environment exports. Paths from doctor/config override literal artifact-name examples. Do not write the plugin cache, copy generic rules, change credentials or install prerequisites automatically.
