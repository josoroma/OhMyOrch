#!/usr/bin/env bash
#
# guard-archive.sh — no archive while tasks.md has unfinished tasks
#
# Upstream `openspec archive` asks for confirmation when a change still has
# incomplete tasks. A non-interactive `openspec archive <id> -y` skips that
# question, so this guard makes the same check non-bypassable:
#
#   Given a change whose tasks.md has at least one unfinished task
#   When  `openspec archive <id>` is requested
#   Then  the archive MUST be refused until every task is ticked
#
# That is the whole predicate. tasks.md is the only tracking file of a change,
# so nothing else is consulted and no other script is spawned. `openspec archive`
# itself validates the delta specs (blocking) and merges them; this guard does
# not duplicate that.
#
# The plugin dispatcher (hooks/dispatch.sh, pre-bash) calls it with
# `--change <id> --quiet` for a standalone literal `openspec archive <id>`.
# `--hook` reads a raw PreToolUse Bash payload for direct use.
#
# Allows whenever there is nothing of ours to block: no change is active, the
# named change is not an active directory (archived or unknown — OpenSpec
# reports its own error), or the change has no task checklist.
#
# Usage:
#   guard-archive.sh --hook                     # PreToolUse JSON on stdin
#   guard-archive.sh --change <name>            # direct check
#   guard-archive.sh --change <name> --json     # machine-readable verdict
#
# Exit codes: 0 allow, 2 block, 3 usage error.

set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"
set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"

HOOK_MODE=0
CHANGE=""
AS_JSON=0
QUIET=0

c_reset=""; c_red=""; c_green=""
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_green=$'\033[32m'
fi

usage() {
  cat <<'EOF'
Usage: guard-archive.sh (--hook | --change <name>) [--json] [--quiet]

Rejects `openspec archive` while the change's tasks.md has unfinished tasks.
A change with every task ticked, or with no task checklist, may be archived.

Options:
  --hook            Read Claude Code hook JSON on stdin (PreToolUse)
  --change <name>   Check a specific change (direct mode)
  --json            Emit a machine-readable verdict
  --quiet           Suppress the allow message
  -h, --help        Show this help

Exit codes: 0 allow, 2 blocked, 3 usage error
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --hook)   HOOK_MODE=1; shift ;;
    --change) [ $# -ge 2 ] || { echo "error: --change needs a value" >&2; exit 3; }; CHANGE="$2"; shift 2 ;;
    --json)   AS_JSON=1; shift ;;
    --quiet)  QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 3 ;;
  esac
done

if [ "$HOOK_MODE" -eq 1 ]; then
  HOOK_INPUT=$(cat)
  [ -z "$HOOK_INPUT" ] && exit 0

  # Only Bash tool invocations that actually archive are of interest.
  case "$HOOK_INPUT" in
    *openspec*archive*) ;;
    *) exit 0 ;;
  esac

  # The command string alone, read as exactly one JSON string with its escapes
  # decoded. Claude Code's Bash payload carries a `description` after `command`;
  # parsing the payload as text would pick up words from that prose.
  CMD=$(jq -er '.tool_input.command // "" | select(type=="string")' <<< "$HOOK_INPUT") || exit 2

  # Judge the command, not the description: "archive" in prose is not archival.
  case "$CMD" in
    *openspec*archive*) ;;
    "") ;;   # unparseable payload: fall through to the raw-text check below
    *) exit 0 ;;
  esac

  # `--help` / `-h` describes archival; it does not perform it. Match whole
  # tokens: a `*archive*-h*` glob would also match `-hooks`, `--hard`, `-hello`.
  if printf ' %s ' "${CMD:-$HOOK_INPUT}" | grep -qE '[[:space:]](-h|--help)[[:space:]"]'; then
    exit 0
  fi

  # Recover the change name if one was given: the last bare token after
  # `archive`, skipping options and the value of --store.
  if [ -n "$CMD" ]; then
    CHANGE=$(printf '%s' "$CMD" | tr -d '\\' | awk '
      { for (i=1; i<=NF; i++) if ($i == "archive") { found=i; break } }
      found { for (i=found+1; i<=NF; i++) {
                 if ($i == "--store") { i++; continue }
                 if ($i ~ /^-/) continue
                 last=$i
               } }
      END { if (last) print last }
    ')
    case "$CHANGE" in *archive*|"") CHANGE="" ;; esac
  fi
fi

[ -n "$CHANGE" ] || CHANGE=$(find openspec/changes -maxdepth 1 -mindepth 1 -type d \
  -not -name archive 2>/dev/null | sed 's|.*/||' | sort | head -1)

# Nothing to archive: do not stand in the way of a no-op.
[ -n "$CHANGE" ] || exit 0

# The predicate. A change that is not an active directory (archived or unknown)
# is not ours to block: it counts as having no checklist, like an active change
# without tasks.md or without checkboxes.
TASKS="openspec/changes/$CHANGE/tasks.md"
TASKS_DONE=0; TASKS_TOTAL=0
if [ -d "openspec/changes/$CHANGE" ]; then
  PROGRESS=$(ohmyorch_tasks_progress "$TASKS")
  read -r TASKS_DONE TASKS_TOTAL <<< "$PROGRESS"
fi

if [ "$TASKS_TOTAL" -eq 0 ] || [ "$TASKS_DONE" -eq "$TASKS_TOTAL" ]; then
  if [ "$AS_JSON" -eq 1 ]; then
    jq -rn --arg change "$CHANGE" \
      '"{ \"change\": \($change|tojson), \"archiveEligible\": true, \"blocked\": false }"'
  elif [ "$QUIET" -ne 1 ]; then
    if [ "$TASKS_TOTAL" -eq 0 ]; then
      printf '%sALLOW%s  %s: no task checklist\n' "$c_green" "$c_reset" "$CHANGE" >&2
    else
      printf '%sALLOW%s  %s: %s/%s tasks complete\n' "$c_green" "$c_reset" "$CHANGE" "$TASKS_DONE" "$TASKS_TOTAL" >&2
    fi
  fi
  exit 0
fi

# The block message is the instruction the agent continues with. It always prints.
printf '%sBLOCKED%s  archive %s\n' "$c_red" "$c_reset" "$CHANGE" >&2
printf '  %s/%s tasks complete in %s.\n' "$TASKS_DONE" "$TASKS_TOTAL" "$TASKS" >&2
printf '  Finish the remaining tasks (/ohmyorch:opsx-apply %s) or remove tasks that no longer apply, then archive.\n' "$CHANGE" >&2
if [ "$AS_JSON" -eq 1 ]; then
  jq -rn --arg change "$CHANGE" --arg reason "$TASKS_DONE/$TASKS_TOTAL tasks complete" \
    '"{ \"change\": \($change|tojson), \"archiveEligible\": false, \"blocked\": true, \"reason\": \($reason|tojson) }"'
fi
exit 2
