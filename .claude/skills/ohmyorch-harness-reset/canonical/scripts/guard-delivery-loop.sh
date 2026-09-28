#!/usr/bin/env bash
#
# guard-delivery-loop.sh — US-12.2: keep a delivery goal running, and keep it honest
#
# A delivery goal (openspec/delivery/goal.md, written by scripts/delivery.sh) is one
# SPECS.md target — an epic, a story, or a task — that the main Claude Code session
# drives to completion one OpenSpec change at a time. A prompt can only *ask* the model
# to keep going; this hook makes the loop mechanical.
#
# Two modes, chosen from the payload's hook_event_name:
#
#   Stop        The main session is about to end its turn.
#                 complete         -> record COMPLETE, allow the stop
#                 escalate         -> record BLOCKED with the reason, allow the stop
#                 no progress x N  -> record BLOCKED "no progress", allow the stop
#                 anything else    -> exit 2: name the next action, owner, command
#
#   PreToolUse  (Write|Edit|MultiEdit) The main session — the orchestrator — may not
#               author review.md or test-report.md while a goal is ACTIVE. Writes
#               made inside a subagent carry `agent_id` and are left to that
#               subagent's own write-scope hook (check-write-scope.sh).
#
# "Progress" is the derived state: the full `delivery.sh next --json` line, which
# carries gate detail such as "3/10 tasks complete". It is fingerprinted per target in
# openspec/delivery/loop.state (per-machine, git-ignored). stop_hook_active is NOT
# used: it says whether this turn continues a block, not whether the repository moved.
#
# The default stall limit (3) sits below Claude Code's own cap of 8 consecutive Stop
# blocks, so the harness records WHY it stopped before Claude Code overrides the hook.
#
# Fails open (exit 0) when the harness is absent, no goal is recorded, the goal is not
# ACTIVE, or the hook fires inside a subagent — a copied settings.json must never trap
# an unrelated session.
#
# Usage:
#   guard-delivery-loop.sh --hook [--quiet] [--max-stalls <n>]   # hook JSON on stdin
#
# Environment: DELIVERY_MAX_STALLS (default 3) — unchanged stop attempts allowed.
#
# Exit codes: 0 allow, 2 block (Stop: keep working; PreToolUse: deny), 3 usage error.
#
# Dependencies: bash, awk, grep, sed, cksum — no Node/Python (NFR-001).

set -uo pipefail

HOOK_MODE=0
QUIET=0
MAX_STALLS="${DELIVERY_MAX_STALLS:-3}"

usage() {
  cat <<'EOF'
Usage: guard-delivery-loop.sh --hook [--quiet] [--max-stalls <n>]

Keeps an ACTIVE delivery goal running (US-12.2). Reads a Claude Code hook payload
on stdin and dispatches on hook_event_name:

  Stop        block the stop (exit 2) while the goal's next action is not
              "escalate"; record COMPLETE / BLOCKED and allow it otherwise
  PreToolUse  block a main-session write to review.md or test-report.md while
              a goal is ACTIVE (the orchestrator never authors a verdict)

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

# Run from the repository root: delivery.sh and the gate reporters use relative paths.
ROOT=$(cd -- "$(dirname -- "$0")/.." 2>/dev/null && pwd) || exit 0
cd "$ROOT" || exit 0

GOAL="openspec/delivery/goal.md"
STATE="openspec/delivery/loop.state"
DELIVERY="scripts/delivery.sh"

HOOK_INPUT=$(cat)
[ -n "$HOOK_INPUT" ] || exit 0

# Read one JSON string value by key, decoding escapes. A greedy sed capture runs to the
# LAST quote in the payload (see guard-story-done.sh), so this is an awk reader.
json_str() { # json_str <key>
  printf '%s' "$HOOK_INPUT" | awk -v key="\"$1\"" '
    { buf = buf $0 "\n" }
    END {
      i = index(buf, key); if (i == 0) exit
      rest = substr(buf, i + length(key))
      if (!match(rest, /^[[:space:]]*:[[:space:]]*"/)) exit
      rest = substr(rest, RLENGTH + 1)
      out = ""
      for (k = 1; k <= length(rest); k++) {
        c = substr(rest, k, 1)
        if (c == "\\") {
          k++; e = substr(rest, k, 1)
          if (e == "n") out = out "\n"; else if (e == "t") out = out "\t"
          else out = out e
        } else if (c == "\"") { break }
        else out = out c
      }
      printf "%s", out
    }'
}

# A real subagent payload carries a top-level "agent_id" key. The same text inside
# file content is JSON-escaped (\"agent_id\"), so require that the quote is not
# preceded by a backslash — a document that mentions agent_id is not a subagent.
in_subagent() {
  printf '%s' "$HOOK_INPUT" | grep -qE '(^|[^\\])"agent_id"[[:space:]]*:'
}

goal_field() {
  [ -f "$GOAL" ] || return 0
  awk -F'|' -v k="$1" '{
    key = $2; gsub(/^[ ]+|[ ]+$/, "", key)
    if (key == k) { v = $3; gsub(/^[ ]+|[ ]+$/, "", v); print v; exit }
  }' "$GOAL"
}

# Field from the one-line `delivery.sh next --json` object.
next_field() { # next_field <json> <key>
  printf '%s' "$1" | awk -v key="\"$2\"" '{
    i = index($0, key); if (i == 0) exit
    rest = substr($0, i + length(key))
    if (!match(rest, /^[[:space:]]*:[[:space:]]*"/)) exit
    rest = substr(rest, RLENGTH + 1); out = ""
    for (k = 1; k <= length(rest); k++) {
      c = substr(rest, k, 1)
      if (c == "\\") { k++; out = out substr(rest, k, 1) }
      else if (c == "\"") break
      else out = out c
    }
    print out
  }'
}

jstr() { printf '"%s"' "$(printf '%s' "$1" | tr '\n\t' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g')"; }

# An allow that changed goal state is worth telling the user about. Claude Code shows
# `systemMessage` from a hook's JSON stdout; stderr on exit 0 reaches only the debug log.
announce() { printf '{ "systemMessage": %s }\n' "$(jstr "$1")"; }

# record_block <reason> — record BLOCKED through delivery.sh and report what actually
# happened. The stop is allowed either way (fail open), but the message must not claim
# a state the goal record does not hold (review O-2).
record_block() {
  "$DELIVERY" block --reason "$1" >/dev/null 2>&1
  rm -f "$STATE"
  if [ "$(goal_field Status)" = "BLOCKED" ]; then
    RECORDED="recorded BLOCKED"
  else
    RECORDED="could NOT be recorded as BLOCKED (goal.md still says $(goal_field Status)) — run scripts/delivery.sh block"
  fi
}

plural() { [ "$1" -eq 1 ] && printf '%s %s' "$1" "$2" || printf '%s %ss' "$1" "$2"; }

EVENT=$(json_str hook_event_name)

# Nothing to enforce without the harness or an ACTIVE goal.
[ -x "$DELIVERY" ] || exit 0
[ -f "$GOAL" ] || exit 0
STATUS=$(goal_field Status)
TARGET=$(goal_field Target)
if [ "$STATUS" != "ACTIVE" ]; then
  rm -f "$STATE"
  exit 0
fi

# ---------------------------------------------------------------------------
# PreToolUse — the orchestrator never authors a verdict
# ---------------------------------------------------------------------------

if [ "$EVENT" = "PreToolUse" ]; then
  in_subagent && exit 0
  FILE=$(json_str file_path)
  [ -n "$FILE" ] || exit 0
  # Compare case-insensitively: on a case-insensitive filesystem (macOS default)
  # REVIEW.md is the same file as review.md (review O-3).
  FILE=$(printf '%s' "$FILE" | tr '[:upper:]' '[:lower:]')
  case "$FILE" in
    openspec/changes/*/review.md|*/openspec/changes/*/review.md)
      ART="review.md"; OWNER="ohmyorch-reviewer"; CMD="/ohmyorch-review-feature" ;;
    openspec/changes/*/test-report.md|*/openspec/changes/*/test-report.md)
      ART="test-report.md"; OWNER="ohmyorch-tester"; CMD="/ohmyorch-test-feature" ;;
    *) exit 0 ;;
  esac
  {
    printf 'BLOCKED  delivery goal %s is ACTIVE: the orchestrator must not author %s (BR-002).\n' "$TARGET" "$ART"
    printf '  Delegate to the %s subagent (%s <change-id>); it writes %s under its own write-scope hook.\n' "$OWNER" "$CMD" "$ART"
  } >&2
  exit 2
fi

# Only the Stop event drives the loop; any other event is not ours.
[ "$EVENT" = "Stop" ] || exit 0

# ---------------------------------------------------------------------------
# Stop — continue, escalate, stall, or complete
# ---------------------------------------------------------------------------

in_subagent && exit 0

NEXT=$("$DELIVERY" next --json 2>"${TMPDIR:-/tmp}/delivery-next.$$"); NRC=$?
NERR=$(cat "${TMPDIR:-/tmp}/delivery-next.$$" 2>/dev/null); rm -f "${TMPDIR:-/tmp}/delivery-next.$$"

if [ "$NRC" -ne 0 ] || [ -z "$NEXT" ]; then
  # The goal cannot be derived. Record the halt rather than trap the session.
  REASON="the goal could not be derived: $(printf '%s' "${NERR:-delivery.sh next exited $NRC}" | head -1 | sed 's/^error: //')"
  record_block "$REASON"
  announce "Delivery goal $TARGET $RECORDED — $REASON"
  exit 0
fi

ACTION=$(next_field "$NEXT" action)
STORY=$(next_field "$NEXT" story)
OWNER=$(next_field "$NEXT" owner)
COMMAND=$(next_field "$NEXT" command)
NREASON=$(next_field "$NEXT" reason)

case "$ACTION" in
  complete)
    "$DELIVERY" refresh >/dev/null 2>&1          # records Status COMPLETE
    rm -f "$STATE"
    announce "Delivery goal $TARGET is COMPLETE — every story is DONE."
    exit 0 ;;
  escalate)
    record_block "escalate: $NREASON"
    announce "Delivery goal $TARGET $RECORDED — a human Product Manager decision is required: $NREASON. Resolve it, then run /ohmyorch-deliver $TARGET to resume."
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
  announce "Delivery goal $TARGET $RECORDED — $REASON. Inspect scripts/delivery.sh next, then run /ohmyorch-deliver $TARGET to resume."
  exit 0
fi

mkdir -p "$(dirname "$STATE")"
printf 'target=%s\nfingerprint=%s\ncount=%s\n' "$TARGET" "$FP" "$COUNT" > "$STATE"
"$DELIVERY" refresh >/dev/null 2>&1              # keep goal.md's Next Action current

# The block message is the instruction Claude continues with. It always prints.
{
  printf 'Delivery goal %s is ACTIVE — do not stop yet.\n' "$TARGET"
  printf 'Next action: %s  (owner: %s, story: %s)\n' "$ACTION" "$OWNER" "$STORY"
  printf 'Command: %s\n' "$COMMAND"
  printf 'Reason: %s\n' "$NREASON"
  printf 'Delegate this action to the %s role (never perform a Reviewer or Tester action yourself),\n' "$OWNER"
  printf 'then run scripts/delivery.sh next again. Unchanged stop attempts: %s of %s allowed.\n' "$COUNT" "$MAX_STALLS"
} >&2
exit 2
