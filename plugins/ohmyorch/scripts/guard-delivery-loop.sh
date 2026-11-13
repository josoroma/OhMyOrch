#!/usr/bin/env bash
#
# guard-delivery-loop.sh — keep a delivery goal running, and keep it honest
#
# A delivery goal (openspec/delivery/goal.md, written by ohmyorch delivery) is one
# SPECS.md target — an epic, a story, or a task — that the main Claude Code session
# delivers one OpenSpec change at a time: propose, apply, verify, archive. A prompt
# can only *ask* the model to keep going; this Stop hook makes the loop mechanical.
#
# When the main session is about to end its turn while the goal is ACTIVE:
#
#   complete         -> the goal is recorded COMPLETE, the stop is allowed
#   escalate         -> the goal is recorded BLOCKED with the reason, allowed
#   no progress x N  -> the goal is recorded BLOCKED "no progress", allowed
#   anything else    -> exit 2: name the next action, its command and the reason
#
# The goal is derived once per stop attempt with `delivery.sh refresh --json`,
# which also keeps goal.md's Next Action current. "Progress" is that derived JSON
# line, which carries detail such as "3/10 tasks complete". It is fingerprinted
# per target in .claude/ohmyorch/runtime/<session>/loop.state (per-machine,
# git-ignored). stop_hook_active is NOT used: it says whether this turn continues
# a block, not whether the repository moved.
#
# The default stall limit (3) sits below Claude Code's own cap of 8 consecutive Stop
# blocks, so the reason is recorded before Claude Code overrides the hook.
#
# Fails open (exit 0) when no goal is recorded, the goal is not ACTIVE, the event
# is not Stop, or the hook fires inside a subagent — a session that is not
# delivering must never be trapped. The plugin dispatcher (hooks/dispatch.sh,
# stop) runs it only for the main session that holds the delivery lease.
#
# Usage:
#   guard-delivery-loop.sh --hook [--quiet] [--max-stalls <n>]   # hook JSON on stdin
#
# Environment: DELIVERY_MAX_STALLS (default: project delivery.maxStalls, 3) —
# unchanged stop attempts allowed.
#
# Exit codes: 0 allow, 2 block (keep working), 3 usage error.
#
# Dependencies: bash, awk, grep, sed, cksum, jq — no Node/Python.

set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"
set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"

HOOK_MODE=0
QUIET=0
MAX_STALLS="${DELIVERY_MAX_STALLS:-$OHMYORCH_MAX_STALLS}"

usage() {
  cat <<'EOF'
Usage: guard-delivery-loop.sh --hook [--quiet] [--max-stalls <n>]

Keeps an ACTIVE delivery goal running. Reads a Claude Code Stop hook payload on
stdin: blocks the stop (exit 2) while the goal's derived next action is work
this session can do; records COMPLETE or BLOCKED and allows the stop when the
goal is complete, needs a human decision, or made no progress. It acts on the
Stop event of the main session only.

Options:
  --hook             Read the hook JSON payload on stdin (required)
  --max-stalls <n>   Unchanged stop attempts allowed before the goal is recorded
                     BLOCKED for lack of progress (default: $DELIVERY_MAX_STALLS or 3)
  --quiet            Accepted for the harness hook convention. This guard prints
                     nothing on a plain allow; block messages and goal-state
                     announcements (systemMessage) always print
  -h, --help         Show this help

Exit codes: 0 allow, 2 block, 3 usage error
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --hook)       HOOK_MODE=1; shift ;;
    --quiet)      QUIET=1; shift ;;
    --max-stalls) [ $# -ge 2 ] || { echo "error: --max-stalls needs a value" >&2; exit 3; }
                  MAX_STALLS="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 3 ;;
  esac
done

[ "$HOOK_MODE" -eq 1 ] || { usage >&2; exit 3; }
case "$MAX_STALLS" in
  ''|*[!0-9]*) echo "error: --max-stalls must be a non-negative integer" >&2; exit 3 ;;
esac

GOAL="openspec/delivery/goal.md"
STATE=".claude/ohmyorch/runtime/${OHMYORCH_SESSION_ID}/loop.state"
DELIVERY="${OHMYORCH_CODE_ROOT}/scripts/delivery.sh"

HOOK_INPUT=$(cat)
[ -n "$HOOK_INPUT" ] || exit 0

# Hook identity is top-level protocol data, never a substring of file content.
jq -e 'type=="object"' <<< "$HOOK_INPUT" >/dev/null 2>&1 || exit 2
json_str() { jq -r --arg key "$1" '.[$key] // ""' <<< "$HOOK_INPUT"; }
in_subagent() { jq -e '(.agent_id // "") != ""' <<< "$HOOK_INPUT" >/dev/null; }

goal_field() {
  [ -f "$GOAL" ] || return 0
  awk -F'|' -v k="$1" '{
    key = $2; gsub(/^[ ]+|[ ]+$/, "", key)
    if (key == k) { v = $3; gsub(/^[ ]+|[ ]+$/, "", v); print v; exit }
  }' "$GOAL"
}

jstr() { ohmyorch_json_string "$1"; }

# An allow that changed goal state is worth telling the user about. Claude Code shows
# `systemMessage` from a hook's JSON stdout; stderr on exit 0 reaches only the debug log.
announce() { printf '{ "systemMessage": %s }\n' "$(jstr "$1")"; }

# record_block <reason> — record BLOCKED through delivery.sh and report what actually
# happened. The stop is allowed either way (fail open), but the message must not claim
# a state the goal record does not hold.
record_block() {
  "$DELIVERY" block --reason "$1" >/dev/null 2>&1
  rm -f "$STATE"
  if [ "$(goal_field Status)" = "BLOCKED" ]; then
    RECORDED="recorded BLOCKED"
  else
    RECORDED="could NOT be recorded as BLOCKED (goal.md still says $(goal_field Status)) — run ohmyorch delivery block"
  fi
}

plural() { [ "$1" -eq 1 ] && printf '%s %s' "$1" "$2" || printf '%s %ss' "$1" "$2"; }

EVENT=$(json_str hook_event_name)

# Nothing to enforce without an ACTIVE goal.
[ -x "$DELIVERY" ] || exit 0
[ -f "$GOAL" ] || exit 0
STATUS=$(goal_field Status)
TARGET=$(goal_field Target)
if [ "$STATUS" != "ACTIVE" ]; then
  rm -f "$STATE"
  exit 0
fi

# Only the Stop event drives the loop; any other event is not ours.
[ "$EVENT" = "Stop" ] || exit 0

# ---------------------------------------------------------------------------
# Stop — continue, escalate, stall, or complete
# ---------------------------------------------------------------------------

in_subagent && exit 0

# Derive once: `refresh --json` rewrites goal.md's derived sections (recording
# COMPLETE when every story is DONE) and prints the action as `next --json` does.
ERRFILE=$(mktemp "${TMPDIR:-/tmp}/ohmyorch-next.XXXXXX") || exit 2
NEXT=$("$DELIVERY" refresh --json 2>"$ERRFILE"); NRC=$?
NERR=$(cat "$ERRFILE"); rm -f "$ERRFILE"

if [ "$NRC" -ne 0 ] || [ -z "$NEXT" ]; then
  # The goal cannot be derived. Record the halt rather than trap the session.
  REASON="the goal could not be derived: $(printf '%s' "${NERR:-delivery.sh refresh exited $NRC}" | head -1 | sed 's/^error: //')"
  record_block "$REASON"
  announce "Delivery goal $TARGET $RECORDED — $REASON"
  exit 0
fi

# One jq process, one field per line. The fields are derived from single SPECS
# lines and file names, so none of them spans a line.
FIELDS=$(jq -r '[.action, .story, .change, .command, .reason] | map((. // "") | tostring | gsub("[\\r\\n]"; " ")) | .[]' <<< "$NEXT" 2>/dev/null)
ACTION=""; STORY=""; CHANGE=""; COMMAND=""; NREASON=""; FIELD=0
while IFS= read -r VALUE; do
  case "$FIELD" in
    0) ACTION=$VALUE ;; 1) STORY=$VALUE ;; 2) CHANGE=$VALUE ;;
    3) COMMAND=$VALUE ;; 4) NREASON=$VALUE ;;
  esac
  FIELD=$((FIELD + 1))
done <<EOF
$FIELDS
EOF

case "$ACTION" in
  complete)
    rm -f "$STATE"                               # the refresh recorded Status COMPLETE
    announce "Delivery goal $TARGET is COMPLETE — every story is DONE."
    exit 0 ;;
  escalate)
    record_block "escalate: $NREASON"
    announce "Delivery goal $TARGET $RECORDED — a human decision is required: $NREASON. Resolve it, then run /ohmyorch:deliver $TARGET to resume."
    exit 0 ;;
esac

# Progress check: has the derived state changed since the last stop attempt?
FP=$(printf '%s' "$NEXT" | cksum | awk '{ print $1 "-" $2 }')
PREV_TARGET=""; PREV_FP=""; COUNT=0
if [ -f "$STATE" ]; then
  PREV_TARGET=$(sed -n 's/^target=//p' "$STATE" | head -1)
  PREV_FP=$(sed -n 's/^fingerprint=//p' "$STATE" | head -1)
  COUNT=$(sed -n 's/^count=//p' "$STATE" | head -1)
  case "$COUNT" in ''|*[!0-9]*) COUNT=0 ;; esac
fi
if [ "$PREV_TARGET" = "$TARGET" ] && [ "$PREV_FP" = "$FP" ]; then
  COUNT=$((COUNT + 1))
else
  COUNT=1
fi

if [ "$COUNT" -gt "$MAX_STALLS" ]; then
  REASON="no progress: next action '$ACTION' for $STORY unchanged across $(plural "$COUNT" "stop attempt")"
  record_block "$REASON"
  announce "Delivery goal $TARGET $RECORDED — $REASON. Inspect ohmyorch delivery next, then run /ohmyorch:deliver $TARGET to resume."
  exit 0
fi

mkdir -p "$(dirname "$STATE")"
printf 'target=%s\nfingerprint=%s\ncount=%s\n' "$TARGET" "$FP" "$COUNT" > "$STATE"

# The block message is the instruction Claude continues with. It always prints.
{
  printf 'Delivery goal %s is ACTIVE — do not stop yet.\n' "$TARGET"
  printf 'Next action: %s  (story: %s, change: %s)\n' "$ACTION" "$STORY" "$CHANGE"
  printf 'Command: %s\n' "$COMMAND"
  printf 'Reason: %s\n' "$NREASON"
  printf 'Do it in this session, then run ohmyorch delivery next again. Unchanged stop attempts: %s of %s allowed.\n' "$COUNT" "$MAX_STALLS"
} >&2
exit 2
