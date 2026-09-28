---
name: "OhMyOrch: Post Install"
description: "Back up current guidance and adapt the OhMyOrch harness to this repository"
allowed-tools: Bash(.claude/skills/ohmyorch-post-install/ohmyorch-post-install.sh:*)
category: "OhMyOrch"
tags: ["ohmyorch", "post-install", "adaptation"]
---

Run the OhMyOrch post-install adapter.

Use this after installing the harness into a repository that already has
`PRD.md`, `CODEBASE.md`, or `SPECS.md`.

Dry-run first:

```bash
.claude/skills/ohmyorch-post-install/ohmyorch-post-install.sh --dry-run $ARGUMENTS
```

Then run:

```bash
.claude/skills/ohmyorch-post-install/ohmyorch-post-install.sh $ARGUMENTS
```

Common arguments:

```text
--mode merge
--mode create-only
--mode override
--nested
```

Report the backup path, generated files, skipped files, and restore command.
