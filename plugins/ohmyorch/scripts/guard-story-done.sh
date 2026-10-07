#!/usr/bin/env bash
#
# guard-story-done.sh — OhMyOrch Harness DONE-transition guard (US-10.1)
#
# Scenario implemented:
#   Given a story is not yet archived
#   When  a SPECS.md write would set that story's Status to DONE
#   Then  the transition MUST be rejected until the change is archive-eligible
#
# US-10.1 task 3 states: "Update SPECS.md story state to DONE only after successful
# completion." The Product Manager agent documents that rule, but a documented rule
# is not a gate. This was the last completion condition with no mechanical
# enforcement: archival itself was guarded by guard-archive.sh (EPIC-8/10), while
# the story-state transition that follows it was only prose.
#
# The guard reads the prospective content from the hook payload's `new_string`, so
# it judges the write that is about to happen rather than the file as it stands.
# That distinction is the whole point: checking the file on disk would see the old
# state and always allow.
#
# It fires only when the write would newly introduce `Status: DONE` for the active
# story. Editing an already-DONE story, or writing DONE for a different story, is
# not the transition this guard exists to police.
#
# Fails open when the harness is not in use or the situation cannot be determined.
#
# Usage:
#   guard-story-done.sh --hook                     # PreToolUse JSON on stdin
#   guard-story-done.sh --file <path> [--content <text>]
#
# Exit codes: 0 allow, 2 block, 3 usage error.

set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"
set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"

HOOK_MODE=0
FILE=""
CONTENT=""
OLD=""
QUIET=0

c_reset=""; c_red=""; c_dim=""; c_yellow=""
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_yellow=$'\033[33m'
fi

usage() {
  cat <<'EOF'
Usage: guard-story-done.sh (--hook | --file <path> [--content <text>])

Rejects a SPECS.md write that would mark the active story DONE while its change is
not archive-eligible (US-10.1). Fails open when the situation cannot be determined.

Options:
  --hook            Read Claude Code hook JSON on stdin (PreToolUse)
  --file <path>     Path being written (direct mode)
  --content <text>  The prospective new content to judge
  --old <text>      The text being replaced (Edit's old_string), used to locate
                    the story when --content carries no story heading
  --quiet           Suppress the allow message
  -h, --help        Show this help

Exit codes: 0 allow, 2 blocked, 3 usage error
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --hook)    HOOK_MODE=1; shift ;;
    --file)    [ $# -ge 2 ] || { echo "error: --file needs a value" >&2; exit 3; }; FILE="$2"; shift 2 ;;
    --old)     [ $# -ge 2 ] || { echo "error: --old needs a value" >&2; exit 3; }; OLD="$2"; shift 2 ;;
    --content) [ $# -ge 2 ] || { echo "error: --content needs a value" >&2; exit 3; }; CONTENT="$2"; shift 2 ;;
    --quiet)   QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 3 ;;
  esac
done

if [ "$HOOK_MODE" -eq 1 ]; then
  HOOK_INPUT=$(cat)
  [ -z "$HOOK_INPUT" ] && exit 0

  json_str() { jq -r --arg key "$1" '.tool_input[$key] // ""' <<< "$HOOK_INPUT"; }
  jq -e 'type=="object" and (.tool_input|type=="object")' <<< "$HOOK_INPUT" >/dev/null || exit 2

  FILE=$(json_str file_path)

  # The prospective content. `Edit` supplies `new_string`; `Write` supplies `content`.
  CONTENT=$(json_str new_string)
  [ -n "$CONTENT" ] || CONTENT=$(json_str content)

  # `Edit` also supplies `old_string`: the text being replaced. It locates the edit
  # in the file when `new_string` carries no story heading of its own.
  OLD=$(json_str old_string)
fi

[ -z "$FILE" ] || FILE=$(ohmyorch_relative "$FILE") || exit 2

[ -n "$FILE" ] || exit 0

# Only SPECS.md carries story state.
case "$FILE" in
  "$OHMYORCH_DOC_SPECS") ;;
  *) exit 0 ;;
esac

[ -n "$CONTENT" ] || exit 0

# Does the prospective content introduce a DONE transition at all?
printf '%s' "$CONTENT" | grep -qE '^[[:space:]]*Status:[[:space:]]*DONE[[:space:]]*$' || exit 0

# ---------------------------------------------------------------------------
# Which story, and is it already DONE on disk?
# ---------------------------------------------------------------------------

# Status of one story in the file on disk.
status_on_disk() {
  [ -f "$FILE" ] || return 0
  awk -v id="$1" '
    $0 ~ "^### " id ":" { f=1; next }
    f && /^Status:/ { v=$0; sub(/^Status:[[:space:]]*/, "", v); gsub(/[[:space:]]+$/, "", v); print v; exit }
    f && /^### / { exit }
  ' "$FILE" 2>/dev/null
}

# Every story set to DONE in the prospective content. A full-file `Write` carries
# all of them, including stories that are already DONE; only the first was checked,
# so a Write whose first DONE story was already DONE was allowed wholesale. Keep the
# stories that are *newly* DONE, and prefer the active change's story among them.
DONE_IN_CONTENT=$(printf '%s' "$CONTENT" | awk '
  /^###[[:space:]]+US-[0-9]+\.[0-9]+:/ {
    m=$0; sub(/^###[[:space:]]+/, "", m); sub(/:.*$/, "", m); current=m
  }
  /^[[:space:]]*Status:[[:space:]]*DONE[[:space:]]*$/ {
    if (current != "") print current
  }
')

NEWLY_DONE=""
for s in $DONE_IN_CONTENT; do
  [ "$(status_on_disk "$s")" = "DONE" ] || NEWLY_DONE="$NEWLY_DONE $s"
done

STORY=""
if [ -n "$DONE_IN_CONTENT" ] && [ -z "$NEWLY_DONE" ]; then
  [ "$QUIET" -eq 1 ] || printf 'ALLOW  every story set to DONE here is already DONE\n' >&2
  exit 0
fi
for s in $NEWLY_DONE; do STORY="$s"; break; done

# No heading in the new text: the common Edit is just `Status: READY` -> `Status: DONE`.
# Previously this exited 0 here, so the most natural DONE edit bypassed the guard.
# Locate the story on disk instead: the story whose block contains the replaced text
# (`old_string`); failing that, the story of the single active change.
if [ -z "$STORY" ] && [ -f "$FILE" ] && [ -n "$OLD" ]; then
  # Edit requires old_string to be unique in the file, so the whole text locates
  # exactly one position. The story is the last heading before it. Only a unique
  # match is trusted: `Status: READY` alone recurs in every READY story. The needle
  # travels through ENVIRON because `awk -v` would reinterpret its backslashes.
  STORY=$(GSD_NEEDLE="$OLD" awk '
    { buf = buf $0 "\n" }
    END {
      needle = ENVIRON["GSD_NEEDLE"]
      i = index(buf, needle)
      if (i == 0) exit
      rest = substr(buf, i + length(needle))
      if (index(rest, needle) > 0) exit
      n = split(substr(buf, 1, i - 1), lines, "\n")
      for (k = n; k >= 1; k--) {
        if (lines[k] ~ /^###[[:space:]]+US-[0-9]+\.[0-9]+:/) {
          m = lines[k]; sub(/^###[[:space:]]+/, "", m); sub(/:.*$/, "", m); print m; exit
        }
      }
    }' "$FILE" 2>/dev/null)
fi

if [ -z "$STORY" ] && [ -d openspec/changes ]; then
  ACTIVE=$(find openspec/changes -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null)
  if [ "$(printf '%s\n' "$ACTIVE" | grep -c .)" -eq 1 ]; then
    STORY=$(grep -oE '^[[:space:]]*Story:[[:space:]]*US-[0-9]+\.[0-9]+' "$ACTIVE/implementation-plan.md" "$ACTIVE/proposal.md" 2>/dev/null \
      | grep -oE 'US-[0-9]+\.[0-9]+' | head -1)
  fi
fi

[ -n "$STORY" ] || exit 0

# Already DONE on disk: this is not a new transition, so it is not this guard's
# concern. Re-reading the same state is harmless.
if [ -f "$FILE" ]; then
  ALREADY=$(awk -v id="$STORY" '
    $0 ~ "^### " id ":" { f=1; next }
    f && /^Status:/ { v=$0; sub(/^Status:[[:space:]]*/, "", v); gsub(/[[:space:]]+$/, "", v); print v; exit }
    f && /^### / { exit }
  ' "$FILE" 2>/dev/null)
  [ "$ALREADY" = "DONE" ] && {
    [ "$QUIET" -eq 1 ] || printf 'ALLOW  %s is already DONE\n' "$STORY" >&2
    exit 0
  }
fi

# ---------------------------------------------------------------------------
# Is there a change for this story, and is it archive-eligible?
# ---------------------------------------------------------------------------

[ -d openspec/changes ] || exit 0

CHANGE=$(find openspec/changes -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null \
  | sed 's|.*/||' | sort | head -1)
[ -n "$CHANGE" ] || exit 0

# The change must actually be this story's, or the guard has nothing to say.
ohmyorch_change_id "$CHANGE" || exit 2
CDIR="openspec/changes/$CHANGE"
STORY_OF_CHANGE=$(grep -oE '^[[:space:]]*Story:[[:space:]]*US-[0-9]+\.[0-9]+' "$CDIR/implementation-plan.md" 2>/dev/null \
  | grep -oE 'US-[0-9]+\.[0-9]+' | head -1)
[ -n "$STORY_OF_CHANGE" ] || STORY_OF_CHANGE=$(grep -oE '^[[:space:]]*\|[[:space:]]*Story[[:space:]]*\|[[:space:]]*US-[0-9]+\.[0-9]+' "$CDIR/completion.md" 2>/dev/null \
  | grep -oE 'US-[0-9]+\.[0-9]+' | head -1)

# A multi-story Write may newly mark several stories DONE; judge the active one.
case " $NEWLY_DONE " in
  *" $STORY_OF_CHANGE "*) [ -n "$STORY_OF_CHANGE" ] && STORY="$STORY_OF_CHANGE" ;;
esac

if [ -n "$STORY_OF_CHANGE" ] && [ "$STORY_OF_CHANGE" != "$STORY" ]; then
  [ "$QUIET" -eq 1 ] || printf 'ALLOW  %s is not the active change (%s)\n' "$STORY" "$STORY_OF_CHANGE" >&2
  exit 0
fi

# Prefer the completion gate; fall back to the gate chain when absent.
ELIGIBLE=""
FIRST=""
if [ -x "${OHMYORCH_CODE_ROOT}/scripts/completion-gate.sh" ]; then
  OUT=$("${OHMYORCH_CODE_ROOT}/scripts/completion-gate.sh" --change "$CHANGE" --json 2>/dev/null)
  ELIGIBLE=$(printf '%s' "$OUT" \
    | sed -n 's/.*"eligible":[[:space:]]*\(true\).*/\1/p; s/.*"eligible":[[:space:]]*\(false\).*/\1/p' | head -1)
  FIRST=$(printf '%s' "$OUT" \
    | sed -n 's/.*"firstFailingCondition":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

if [ -z "$ELIGIBLE" ] && [ -x "${OHMYORCH_CODE_ROOT}/scripts/guard-archive.sh" ]; then
  OUT=$("${OHMYORCH_CODE_ROOT}/scripts/guard-archive.sh" --change "$CHANGE" --json 2>/dev/null)
  BLOCKED=$(printf '%s' "$OUT" | sed -n 's/.*"blocked":[[:space:]]*\(true\).*/\1/p' | head -1)
  [ "$BLOCKED" = "true" ] && ELIGIBLE="false" || ELIGIBLE="true"
  FIRST=$(printf '%s' "$OUT" | sed -n 's/.*"firstIncompleteGate":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# Cannot determine: do not block on a guess.
[ -n "$ELIGIBLE" ] || exit 0

[ "$ELIGIBLE" = "true" ] && {
  [ "$QUIET" -eq 1 ] || printf 'ALLOW  %s: change %s is archive-eligible\n' "$STORY" "$CHANGE" >&2
  exit 0
}

printf '%sBLOCKED%s  SPECS.md — %s to DONE\n' "$c_red" "$c_reset" "$STORY" >&2
printf '  %sChange %s is not archive-eligible.%s\n' "$c_dim" "$CHANGE" "$c_reset" >&2
[ -n "$FIRST" ] && printf '  First failing condition: %s\n' "$FIRST" >&2
printf '\n' >&2
printf '  %sUS-10.1: a story is marked DONE only after a successful archive.%s\n' \
  "$c_yellow" "$c_reset" >&2
printf '  Archive the change first, then set the story to DONE.\n' >&2
exit 2
