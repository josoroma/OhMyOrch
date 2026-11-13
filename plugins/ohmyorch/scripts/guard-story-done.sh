#!/usr/bin/env bash
#
# guard-story-done.sh — archive before DONE
#
#   Given a story whose OpenSpec change is still active
#   When  a write to the mapped SPECS would newly set that story's Status to DONE
#   Then  the write MUST be rejected until the change has been archived
#
# The rule is structural: a change directory that still sits under
# openspec/changes/ has not been archived, so its story is not done. Nothing
# else is evaluated and no other script is spawned.
#
# The guard reads the prospective content — the file as it would be after the
# write — rather than the file as it stands. That distinction is the whole
# point: checking the file on disk would see the old state and always allow.
# The plugin dispatcher (hooks/dispatch.sh, pre-write) reconstructs the full
# prospective SPECS and passes it with `--content-file`: Linux refuses a single
# argument of 128 KiB or more, so a large SPECS cannot travel as `--content`.
#
# It fires only when the write newly introduces `Status: DONE`. Editing a story
# that is already DONE is not the transition this guard exists to police.
#
# Every change that could stand behind the story is judged, so a write cannot
# detach a story from its active change by rewording or deleting its `Change:`
# line: the `Change:` id in the prospective content, the `Change:` id in the
# file on disk, and every active `us-<n>-<m>-*` directory unless the `Change:`
# id on disk names an archived change.
#
# Allows when the harness is not in use or the story cannot be determined.
#
# Usage:
#   guard-story-done.sh --hook [--quiet]           # PreToolUse JSON on stdin
#   guard-story-done.sh --file <path> [--content <text> | --content-file <path>] [--old <text>] [--quiet]
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

c_reset=""; c_red=""
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'
fi

usage() {
  cat <<'EOF'
Usage: guard-story-done.sh (--hook | --file <path> [--content <text> | --content-file <path>] [--old <text>]) [--quiet]

Rejects a SPECS.md write that would newly mark a story DONE while that story's
OpenSpec change is still active. Archive the change first. Allows when the
story cannot be determined.

Options:
  --hook            Read Claude Code hook JSON on stdin (PreToolUse)
  --file <path>     Path being written (direct mode)
  --content <text>  The prospective new content to judge
  --content-file <path>
                    Read the prospective new content from a file instead
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
    --content-file)
      [ $# -ge 2 ] || { echo "error: --content-file needs a value" >&2; exit 3; }
      # An unreadable file must not read as "no content", which would allow.
      [ -f "$2" ] && [ -r "$2" ] || { echo "error: cannot read --content-file '$2'" >&2; exit 2; }
      CONTENT=$(cat -- "$2") || exit 2
      shift 2 ;;
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

# Only the mapped SPECS document carries story state.
case "$FILE" in
  "$OHMYORCH_DOC_SPECS") ;;
  *) exit 0 ;;
esac

[ -n "$CONTENT" ] || exit 0

# Does the prospective content introduce a DONE transition at all? The content is
# fed as a here-string, never through a pipe: under `pipefail` a `grep -q` that
# stops at the first match would break the writer of a large SPECS and the
# pipeline would read as "no match", allowing the very write this guard judges.
grep -qE '^[[:space:]]*Status:[[:space:]]*DONE[[:space:]]*$' <<< "$CONTENT" || exit 0

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

# "<story>\t<change id>" for every story block of a SPECS document (stdin) that
# records a `Change:` line. The value is normalised the way delivery.sh reads
# it: backticks, a trailing `/`, the directory part and the `YYYY-MM-DD-` prefix
# that `openspec archive` adds are stripped. The last Change: line of a block wins.
story_changes() {
  awk '
    function flush() {
      if (story != "" && change != "") printf "%s\t%s\n", story, change
      story = ""; change = ""
    }
    { gsub(/\t/, " ") }
    /^# EPIC-[0-9]+:/ { flush(); next }
    /^###[[:space:]]+US-[0-9]+\.[0-9]+:/ {
      flush()
      story = $0; sub(/^###[[:space:]]+/, "", story); sub(/:.*$/, "", story)
      next
    }
    story != "" && /^Change:/ {
      v = $0; sub(/^Change:[[:space:]]*/, "", v); gsub(/`/, "", v)
      sub(/[[:space:]]+$/, "", v); sub(/\/$/, "", v); sub(/^.*\//, "", v)
      sub(/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-/, "", v)
      change = v
    }
    END { flush() }
  '
}

active_changes() {
  find openspec/changes -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null \
    | sed 's|.*/||' | sort
}

# Every story set to DONE in the prospective content. A full-file `Write` carries
# all of them, including stories that are already DONE, so keep only the stories
# that are *newly* DONE: each of them is judged below.
DONE_IN_CONTENT=$(printf '%s' "$CONTENT" | awk '
  /^###[[:space:]]+US-[0-9]+\.[0-9]+:/ {
    m=$0; sub(/^###[[:space:]]+/, "", m); sub(/:.*$/, "", m); current=m
  }
  /^[[:space:]]*Status:[[:space:]]*DONE[[:space:]]*$/ {
    if (current != "") print current
  }
')

# The stories that are DONE on disk, in one pass. Each story is read the way
# status_on_disk reads it: its first block, the first `Status:` line, and the
# block ends at the next `### ` heading.
DONE_ON_DISK=""
if [ -n "$DONE_IN_CONTENT" ] && [ -f "$FILE" ]; then
  DONE_ON_DISK=$(awk '
    /^### / {
      cur = ""
      if (match($0, /^### US-[0-9]+\.[0-9]+:/)) {
        id = substr($0, 5, RLENGTH - 5)
        if (!(id in seen)) { seen[id] = 1; cur = id }
      }
      next
    }
    cur != "" && /^Status:/ {
      v = $0; sub(/^Status:[[:space:]]*/, "", v); gsub(/[[:space:]]+$/, "", v)
      if (v == "DONE") printf "%s ", cur
      cur = ""
    }
  ' "$FILE" 2>/dev/null)
fi

NEWLY_DONE=""
for s in $DONE_IN_CONTENT; do
  case " $DONE_ON_DISK" in *" $s "*) ;; *) NEWLY_DONE="$NEWLY_DONE $s" ;; esac
done

if [ -n "$DONE_IN_CONTENT" ] && [ -z "$NEWLY_DONE" ]; then
  [ "$QUIET" -eq 1 ] || printf 'ALLOW  every story set to DONE here is already DONE\n' >&2
  exit 0
fi

STORIES="$NEWLY_DONE"

if [ -z "$STORIES" ]; then
  STORY=""

  # No heading in the new text: the common Edit is just `Status: READY` -> `Status: DONE`.
  # Locate the story on disk instead: the story whose block contains the replaced
  # text (`old_string`).
  if [ -f "$FILE" ] && [ -n "$OLD" ]; then
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

  # Still unknown: with exactly one active change, the story is the one whose
  # `Change:` line on disk names that change, else the story the change id itself
  # names (`us-<n>-<m>-...` is US-<n>.<m>).
  if [ -z "$STORY" ]; then
    ACTIVE=$(active_changes)
    if [ "$(printf '%s\n' "$ACTIVE" | grep -c .)" -eq 1 ]; then
      if [ -f "$FILE" ]; then
        STORY=$(story_changes < "$FILE" | awk -F'\t' -v c="$ACTIVE" '$2 == c { print $1; exit }')
      fi
      if [ -z "$STORY" ]; then
        STORY=$(printf '%s\n' "$ACTIVE" | sed -n 's/^us-\([0-9][0-9]*\)-\([0-9][0-9]*\)-.*$/US-\1.\2/p')
      fi
    fi
  fi

  [ -n "$STORY" ] || exit 0

  # Already DONE on disk: this is not a new transition, so it is not this guard's
  # concern. Re-writing the same state is harmless.
  if [ "$(status_on_disk "$STORY")" = "DONE" ]; then
    [ "$QUIET" -eq 1 ] || printf 'ALLOW  %s is already DONE\n' "$STORY" >&2
    exit 0
  fi
  STORIES="$STORY"
fi

# ---------------------------------------------------------------------------
# Is the story's change still active?
# ---------------------------------------------------------------------------

# change_candidates <story>: every id that could stand behind the story, one
# per line:
#   - the story's `Change:` id in the prospective content, when the content
#     carries that story's heading;
#   - the story's `Change:` id in the file on disk;
#   - every active change directory named for the story (us-<n>-<m>-*), unless
#     the `Change:` id on disk names an archived change. That is the one state
#     in which delivery.sh derives mark-done from the `Change:` line, so a stray
#     directory must not block it there.
# A write cannot detach a story from its active change by rewording or deleting
# the `Change:` line in the same write. After an earlier write the directories
# still stand in, unless the reworded line names an archived change or the
# change is not named us-<n>-<m>-*.
change_candidates() {
  local story="$1" disk="" nm nl=$'\n' archive
  if grep -qE "^###[[:space:]]+${story//./\\.}:" <<< "$CONTENT"; then
    printf '%s\n' "$CONTENT" | story_changes | awk -F'\t' -v s="$story" '$1 == s { v = $2 } END { print v }'
  fi
  if [ -f "$FILE" ]; then
    disk=$(story_changes < "$FILE" | awk -F'\t' -v s="$story" '$1 == s { v = $2 } END { print v }')
    printf '%s\n' "$disk"
  fi
  # Archived as change_archived in delivery.sh reads it: a real directory with
  # that name under the archive, with or without the date prefix. The value is
  # compared with the listing as text: literally, never as a pattern, and
  # without any pathname expansion. An empty value, `-` (no change at all for
  # delivery.sh) and a dot name never name an archived change.
  case "$disk" in
    ''|-|.*) ;;
    *)
      archive=$(find openspec/changes/archive -maxdepth 1 -mindepth 1 -type d \
        -not -name $'*\n*' 2>/dev/null) || true
      case "$nl$archive$nl" in
        *"${nl}openspec/changes/archive/$disk$nl"*) return 0 ;;
        *"${nl}openspec/changes/archive/"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-"$disk$nl"*) return 0 ;;
      esac ;;
  esac
  nm=${story#US-}; nm=${nm/./-}
  find openspec/changes -maxdepth 1 -mindepth 1 -type d -name "us-$nm-*" 2>/dev/null \
    | sed 's|.*/||' | sort
}

# The loop reads a here-document, not a pipe, so `exit 2` leaves the script.
for STORY in $STORIES; do
  while IFS= read -r CHANGE; do
    # Any directory name can be an active change, compared literally; a dot
    # name or a path cannot, and `archive` is the archive itself.
    case "$CHANGE" in ''|.*|*/*|archive) continue ;; esac
    [ -d "openspec/changes/$CHANGE" ] || continue

    printf '%sBLOCKED%s  %s — %s to DONE\n' "$c_red" "$c_reset" "$FILE" "$STORY" >&2
    printf '  Change %s is still active (openspec/changes/%s).\n' "$CHANGE" "$CHANGE" >&2
    printf '  Archive it first (openspec archive %s -y), then set the story to DONE.\n' "$CHANGE" >&2
    exit 2
  done <<CANDIDATES
$(change_candidates "$STORY")
CANDIDATES
done

[ "$QUIET" -eq 1 ] || printf 'ALLOW  %s: no active change stands behind the DONE transition\n' "${STORIES# }" >&2
exit 0
