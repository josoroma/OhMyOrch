#!/usr/bin/env bash
#
# guard-planning-handoff.sh — US-8.2 guard: no implementation before a plan
#
# Scenario implemented:
#   Given an active product change requires the harness workflow
#   And implementation-plan.md does not exist
#   When an Implementer attempts to modify product source code
#   Then the operation SHOULD be rejected by a deterministic guard
#
# Wired as a PreToolUse hook on Write|Edit|MultiEdit. It stops the write BEFORE
# it happens, which is the whole point: the earlier PostToolUse validator can only
# report a violation after the file has already changed.
#
# Fails open. If the repository does not use the harness, has no active change, or
# the guard scripts are missing, the write is allowed.
#
# Usage:
#   guard-planning-handoff.sh --hook        # read Claude Code hook JSON on stdin
#   guard-planning-handoff.sh --file <path> # direct check
#
# Exit codes:
#   0  allow
#   2  block (hook mode: the write is rejected)
#   3  usage error
#
# Dependencies: bash, grep, sed — no Node/Python (NFR-001).

set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"
set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"

HOOK_MODE=0
FILE=""
QUIET=0

c_reset=""; c_red=""; c_dim=""; c_yellow=""
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_yellow=$'\033[33m'
fi

usage() {
  cat <<'EOF'
Usage: guard-planning-handoff.sh (--hook | --file <path>)

Blocks product-code writes while the active change has no implementation plan
(US-8.2). Fails open when the harness is not in use.

Options:
  --hook          Read Claude Code hook JSON on stdin (PreToolUse)
  --file <path>   Check a specific path (direct mode)
  --quiet         Suppress the allow message
  -h, --help      Show this help

Exit codes:
  0  allow
  2  blocked
  3  usage error
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --hook)  HOOK_MODE=1; shift ;;
    --file)  [ $# -ge 2 ] || { echo "error: --file needs a value" >&2; exit 3; }; FILE="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 3 ;;
  esac
done

if [ "$HOOK_MODE" -eq 1 ]; then
  HOOK_INPUT=$(cat)
  [ -z "$HOOK_INPUT" ] && exit 0
  FILE=$(jq -er '.tool_input.file_path // "" | select(type=="string")' <<< "$HOOK_INPUT") || exit 2
  [ -z "$FILE" ] && exit 0
fi

[ -n "$FILE" ] || { echo "error: a path is required (--file, or --hook with file_path)" >&2; exit 3; }

[ -z "$FILE" ] || FILE=$(ohmyorch_relative "$FILE") || exit 2

# ---------------------------------------------------------------------------
# Only product code is guarded
# ---------------------------------------------------------------------------
#
# "Product code" is defined by exclusion: everything that is not the harness's own
# control surface. A broad include-list of extensions would silently miss whatever
# the host project happens to use, which is the failure mode this guard exists to
# prevent. Deliberately NOT excluded: documentation and configuration that belong
# to the product being changed.

case "$FILE" in
  # Harness control surface — always writable.
  .claude/*|openspec/*|.git/*) exit 0 ;;
  CLAUDE.md|AGENTS.md|CODEBASE.md) exit 0 ;;
  # The change's own artifacts are the harness's working files, not product code.
  */proposal.md|*/tasks.md|*/spec.md|*/design.md) exit 0 ;;
  */review.md|*/test-report.md|*/implementation-plan.md|*/status.md) exit 0 ;;
esac

# ---------------------------------------------------------------------------
# Fail open when the harness is not in use
# ---------------------------------------------------------------------------

[ -d "openspec/changes" ] || exit 0

# ---------------------------------------------------------------------------
# Find the active change and check its plan
# ---------------------------------------------------------------------------

ACTIVE=$(find openspec/changes -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null \
  | sed 's|.*/||' | sort)
ACTIVE_COUNT=$(printf '%s\n' "$ACTIVE" | grep -c . || true)
ACTIVE_COUNT=${ACTIVE_COUNT:-0}

# No active change means the workflow is not mid-flight; do not block.
[ "$ACTIVE_COUNT" -eq 0 ] && exit 0

# Several changes is ambiguous: report but do not block, since we cannot tell
# which one this write belongs to.
if [ "$ACTIVE_COUNT" -gt 1 ]; then
  printf '%sNOTE%s  %s active changes; cannot attribute this write to one of them.\n' \
    "$c_yellow" "$c_reset" "$ACTIVE_COUNT" >&2
  printf '  %sPass --file with a single active change to enforce this guard.%s\n' \
    "$c_dim" "$c_reset" >&2
  exit 0
fi

CHANGE=$(printf '%s' "$ACTIVE")
PLAN="openspec/changes/$CHANGE/implementation-plan.md"

[ -f "$PLAN" ] && {
  [ "$QUIET" -eq 1 ] || printf 'ALLOW  plan-handoff present for %s\n' "$CHANGE" >&2
  exit 0
}

# ---------------------------------------------------------------------------
# Block
# ---------------------------------------------------------------------------

printf '%sBLOCKED%s  %s\n' "$c_red" "$c_reset" "$FILE" >&2
printf '  %sChange %s has no implementation plan.%s\n' "$c_dim" "$CHANGE" "$c_reset" >&2
printf '  %sExpected: %s%s\n' "$c_dim" "$PLAN" "$c_reset" >&2
printf '\n' >&2
printf '  %sUS-8.2: implementation must not begin before the planning handoff.%s\n' \
  "$c_yellow" "$c_reset" >&2
printf '  Run /ohmyorch:plan-feature %s first, then retry the write.\n' "$CHANGE" >&2
exit 2
