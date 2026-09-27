#!/usr/bin/env bash
#
# scripts/harness-reset.sh — conventional entry point for the canonical reset.
#
# The engine lives at .claude/skills/harness-reset/harness-reset.sh, and that
# placement is deliberate: the reset replaces `scripts/` wholesale, and bash reads
# a script file incrementally, so an engine that lived here would be executing a
# different file halfway through its own run. This launcher is a separate process
# that finishes before the engine starts, so being replaced mid-reset is harmless.
#
# This file is part of the canonical baseline, so it is restored, not deleted, by
# a reset.
#
# Usage: scripts/harness-reset.sh [--root <dir>] [--dry-run] [--quiet]
# Exit codes: see the engine's own help.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd -P) || {
  echo "error: cannot resolve the repository root" >&2; exit 1; }

ENGINE="$ROOT/.claude/skills/harness-reset/harness-reset.sh"

if [ ! -x "$ENGINE" ]; then
  echo "error: reset engine not found at $ENGINE" >&2
  echo "       the installed .claude/ harness does not provide /harness-reset" >&2
  exit 1
fi

exec "$ENGINE" --root "$ROOT" "$@"
