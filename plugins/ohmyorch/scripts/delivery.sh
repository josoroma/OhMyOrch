#!/usr/bin/env bash
#
# delivery.sh — resolve a delivery target and derive the next action
#
# A delivery goal is one target from the mapped SPECS.md — an epic, a user story,
# or a task. Each story is delivered as one OpenSpec change that follows the
# upstream flow: propose -> apply -> verify -> archive, then the story is marked
# DONE. This script answers the only question the loop needs answered: "what is
# the next action and what command performs it?" — from repository artifacts
# alone.
#
#   EPIC-N       every US-N.* story under "# EPIC-N:", in SPECS.md order
#   US-N.M       that story
#   US-N.M#k     task k of that story; the goal delivers the parent story and
#                records the task as its Focus (a task has no acceptance
#                criteria of its own, so it cannot be accepted alone)
#   <task text>  a task found by case-insensitive substring; must be unique
#
# The next action is DERIVED on every call from SPECS.md and the change
# directory: which of OpenSpec's own artifacts exist (proposal.md, specs/,
# tasks.md) and how many task checkboxes are ticked. Nothing else is read, no
# other script is spawned and `openspec` is never invoked, so a call is cheap
# and deterministic. The action is never read back from goal.md: goal.md
# records the last computed action for a human reader only.
#
# tasks.md is the only tracking file. This script never writes inside a change
# directory and never ticks a task.
#
# Usage:
#   delivery.sh resolve <target> [--json]
#   delivery.sh start   <target>
#   delivery.sh next    [<target>] [--json]
#   delivery.sh refresh [--json]
#   delivery.sh stop    [--reason <text>]
#   delivery.sh block   [--reason <text>]     (the loop halts for a human)
#
# Exit codes: 0 success, 1 unknown/ambiguous target or refused, 2 usage error.
#
# Dependencies: bash, awk, grep, sed, find, jq — no Node/Python.

set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"
set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"

GOAL_DIR="openspec/delivery"
GOAL="$GOAL_DIR/goal.md"
# Per-machine stall counter owned by guard-delivery-loop.sh. Every goal status
# transition clears it, so a resumed goal counts stalls from zero.
LOOP_STATE=".claude/ohmyorch/runtime/${OHMYORCH_SESSION_ID:-direct}/loop.state"
CHANGES_DIR="openspec/changes"
TODAY=$(date +%Y-%m-%d)

c_reset=""; c_red=""; c_green=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_green=$'\033[32m'
fi

usage() {
  cat <<'EOF'
Usage: ohmyorch delivery <command> [args]

Resolve a SPECS.md delivery target and derive the next action. Each story is
one OpenSpec change: propose, apply, verify, archive, then the story is DONE.

Commands:
  resolve <target> [--json]   List the stories a target delivers, with change ids
  start   <target>            Record openspec/delivery/goal.md (Status ACTIVE)
  next    [<target>] [--json] Derive the next action (goal target by default)
  refresh [--json]            Rewrite goal.md's derived sections; with --json,
                              print the derived action as `next --json` does
  stop    [--reason <text>]   Record the goal as STOPPED
  block   [--reason <text>]   Record the goal as BLOCKED (a human decision is
                              needed); `start <same target>` resumes it

Targets:  EPIC-N | US-N.M | US-N.M#k | "<task text>"

Actions:  propose apply verify mark-done escalate complete

Exit codes: 0 success, 1 unknown/ambiguous target or refused, 2 usage error
EOF
}

die()  { printf '%serror:%s %s\n' "$c_red" "$c_reset" "$1" >&2; exit "${2:-1}"; }

# One JSON string, escaped. Values here never contain control characters other
# than tabs (stripped by the parser), so backslash and quote are enough.
jstr() { ohmyorch_json_string "$1"; }

# ---------------------------------------------------------------------------
# SPECS.md
# ---------------------------------------------------------------------------

SPECS="$OHMYORCH_DOC_SPECS"

# Emit one TSV row per story and per task. Empty fields are "-" so a consumer
# never has to reason about collapsed separators.
#   S  epic  story  status  change  deps(comma)  title
#   T  story index  done(0|1)  text
parse_specs() {
  [ -f "$SPECS" ] || die "$SPECS not found (the mapped SPECS document)"
  awk '
    function flush() {
      if (story != "") {
        printf "S\t%s\t%s\t%s\t%s\t%s\t%s\n", (epic == "" ? "-" : epic), story,
               (status == "" ? "-" : status), (change == "" ? "-" : change),
               (deps == "" ? "-" : deps), (title == "" ? "-" : title)
      }
      story = ""; status = ""; change = ""; deps = ""; title = ""; sect = ""; ntask = 0
    }
    { sub(/\r$/, ""); gsub(/\t/, " ") }
    /^# EPIC-[0-9]+:/ {
      flush()
      epic = $0; sub(/^# /, "", epic); sub(/:.*$/, "", epic)
      next
    }
    /^### US-[0-9]+\.[0-9]+:/ {
      flush()
      story = $0; sub(/^### /, "", story)
      title = story; sub(/^[^:]*:[ ]*/, "", title)
      sub(/:.*$/, "", story)
      next
    }
    /^#/ { if (story != "") sect = ""; next }
    story == "" { next }
    /^Status:/ {
      status = $0; sub(/^Status:[ ]*/, "", status); sub(/[ ]+$/, "", status)
      sect = ""; next
    }
    /^Change:/ {
      change = $0; sub(/^Change:[ ]*/, "", change)
      gsub(/`/, "", change); sub(/[ ]+$/, "", change)
      sect = ""; next
    }
    /^Dependencies:/ {
      # Both the bulleted form and an inline "Dependencies: US-1.2" are read;
      # ignoring the inline form would make a dependent story selectable.
      sect = "deps"; line = $0
      while (match(line, /US-[0-9]+\.[0-9]+/)) {
        id = substr(line, RSTART, RLENGTH)
        deps = (deps == "" ? id : deps "," id)
        line = substr(line, RSTART + RLENGTH)
      }
      next
    }
    /^Tasks:/        { sect = "tasks"; next }
    /^[A-Za-z][A-Za-z ]*:/ { sect = ""; next }
    sect == "deps" && /^[ ]*-/ {
      line = $0
      while (match(line, /US-[0-9]+\.[0-9]+/)) {
        id = substr(line, RSTART, RLENGTH)
        deps = (deps == "" ? id : deps "," id)
        line = substr(line, RSTART + RLENGTH)
      }
      next
    }
    sect == "tasks" && /^[ ]*-[ ]*\[[ xX]\]/ {
      done = ($0 ~ /\[[xX]\]/) ? 1 : 0
      text = $0; sub(/^[ ]*-[ ]*\[[ xX]\][ ]*/, "", text)
      ntask++
      printf "T\t%s\t%d\t%d\t%s\n", story, ntask, done, text
      next
    }
    END { flush() }
  ' "$SPECS"
}

ROWS=""
load_specs() { [ -n "$ROWS" ] || ROWS=$(parse_specs) || exit 1; }

# story_field <story-id> <field-number>
story_field() {
  printf '%s\n' "$ROWS" | awk -F'\t' -v id="$1" -v f="$2" '$1 == "S" && $3 == id { print $f; exit }'
}

story_exists() { [ -n "$(story_field "$1" 3)" ]; }

# ---------------------------------------------------------------------------
# Change ids
# ---------------------------------------------------------------------------

# Title -> kebab slug: lowercase, ASCII letters and digits only, drop stop words,
# first four words. One awk function, shared by slugify and write_goal so both
# derive the same id; read byte-wise, so no locale changes what a letter is.
SLUG_AWK='
function slug(t,    w, n, i, k, out) {
  t = tolower(t); gsub(/[^a-z0-9]+/, " ", t)
  n = split(t, w, " "); k = 0; out = ""
  for (i = 1; i <= n; i++) {
    if (w[i] ~ /^(a|an|the|and|or|of|to|for|from|in|on|with|by|as|at|is|its)$/) continue
    out = out (out == "" ? "" : "-") w[i]
    if (++k == 4) break
  }
  return out
}'

slugify() {
  printf '%s\n' "$1" | LC_ALL=C awk "$SLUG_AWK"'{ print slug($0); exit }'
}

# change_id <Change: value>: sets CHANGE_ID to the id the value names. A trailing
# "/", the directory part and the YYYY-MM-DD- prefix that `openspec archive` adds
# are stripped. Shell built-ins only, so a caller in a loop spawns nothing.
change_id() {
  CHANGE_ID="${1%/}"; CHANGE_ID="${CHANGE_ID##*/}"
  CHANGE_ID="${CHANGE_ID#[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-}"
}

# The change directories, each listing read at most once per run:
#   ACTIVE_DIRS    the names of the active changes, sorted;
#   ARCHIVE_PATHS  every directory under the archive, as find prints it;
#   ARCHIVED_IDS   the archived ids without the YYYY-MM-DD- prefix that
#                  `openspec archive` adds, sorted. It is derived from
#                  ARCHIVE_PATHS only when a story has to be found by directory.
# find lists real directories only, never a symbolic link, and a name that
# holds a newline is never a change: the lists are read line by line.
ACTIVE_LOADED=0; ARCHIVE_LOADED=0; ARCHIVED_LOADED=0
ACTIVE_DIRS=""; ARCHIVE_PATHS=""; ARCHIVED_IDS=""
load_active_dirs() {
  [ "$ACTIVE_LOADED" -eq 0 ] || return 0
  ACTIVE_DIRS=$(find "$CHANGES_DIR" -maxdepth 1 -mindepth 1 -type d -not -name archive \
    -not -name $'*\n*' 2>/dev/null | sed 's|.*/||' | sort) || true
  ACTIVE_LOADED=1
}
load_archive_paths() {
  [ "$ARCHIVE_LOADED" -eq 0 ] || return 0
  ARCHIVE_PATHS=$(find "$CHANGES_DIR/archive" -maxdepth 1 -mindepth 1 -type d \
    -not -name $'*\n*' 2>/dev/null) || true
  ARCHIVE_LOADED=1
}
load_archived_ids() {
  [ "$ARCHIVED_LOADED" -eq 0 ] || return 0
  load_archive_paths
  ARCHIVED_IDS=$(printf '%s\n' "$ARCHIVE_PATHS" \
    | sed -n 's|^.*/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-||p' | sort) || true
  ARCHIVED_LOADED=1
}

# first_with_prefix <newline-separated list> <prefix>: sets CHANGE_ID to the
# first entry that starts with the prefix, or returns 1. Shell built-ins only.
# A miss costs one `case`; a hit walks the list line by line, because bash 3.2
# takes quadratic time to cut a long string at a pattern.
first_with_prefix() {
  local nl=$'\n' line
  case "$nl$1" in *"$nl$2"*) ;; *) return 1 ;; esac
  while IFS= read -r line; do
    case "$line" in "$2"*) CHANGE_ID="$line"; return 0 ;; esac
  done <<EOF
$1
EOF
  return 1
}

# change_from_dirs <story-id>: sets CHANGE_ID to the first existing change
# directory named for the story (us-<n>-<m>-*), active before archived, or
# returns 1. Once the directories are listed a caller in a loop spawns nothing.
change_from_dirs() {
  local prefix
  prefix="${1#US-}"; prefix="us-${prefix/./-}-"
  load_active_dirs
  first_with_prefix "$ACTIVE_DIRS" "$prefix" && return 0
  load_archived_ids
  first_with_prefix "$ARCHIVED_IDS" "$prefix"
}

# change_set <story-id>: sets CHANGE_ID. The Change: line wins, then an existing
# change directory for the story, then a derived id.
change_set() {
  local id="$1" ch nm slug
  ch=$(story_field "$id" 5)
  if [ -n "$ch" ] && [ "$ch" != "-" ]; then
    change_id "$ch"
    return
  fi
  change_from_dirs "$id" && return
  # A title with no ASCII letter or digit, or made of stop words only, has no
  # slug: OpenSpec refuses a change name that ends in a hyphen.
  nm="${id#US-}"; nm="${nm/./-}"
  slug=$(slugify "$(story_field "$id" 7)")
  CHANGE_ID="us-$nm-${slug:-story}"
}

# change_archived <id>: a directory with that name exists under the archive,
# with or without the date prefix. The id is compared with the listing as
# text: literally, never as a pattern, and without any pathname expansion.
# `-` and a dot name are not changes.
change_archived() {
  local nl=$'\n' a="$CHANGES_DIR/archive/"
  case "$1" in ''|-|.*) return 1 ;; esac
  load_archive_paths
  case "$nl$ARCHIVE_PATHS$nl" in
    *"$nl$a$1$nl"*|*"$nl$a"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-"$1$nl"*) return 0 ;;
  esac
  return 1
}

active_changes() {
  find "$CHANGES_DIR" -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null \
    | sed 's|.*/||' | sort
}

# ---------------------------------------------------------------------------
# Target resolution
# ---------------------------------------------------------------------------

# Sets R_KIND, R_FOCUS, R_STORIES (newline-separated ids). Returns 1 with a
# message on stderr for an unknown or ambiguous target.
resolve_target() {
  local t="$1" up sid idx matches count
  R_KIND=""; R_FOCUS="-"; R_STORIES=""
  # awk would expand an escape in the id it is handed.
  case "$t" in *\\*) echo "unknown target: $t" >&2; return 1 ;; esac
  load_specs
  up=$(printf '%s' "$t" | tr '[:lower:]' '[:upper:]')

  case "$up" in
    EPIC-[0-9]*)
      if ! grep -qE "^# $up:" "$SPECS"; then
        echo "unknown target: $t (no '# $up:' heading in $SPECS)" >&2; return 1
      fi
      R_KIND="epic"
      R_STORIES=$(printf '%s\n' "$ROWS" | awk -F'\t' -v e="$up" '$1 == "S" && $2 == e { print $3 }')
      if [ -z "$R_STORIES" ]; then
        echo "unknown target: $t has no user stories in $SPECS" >&2; return 1
      fi
      return 0 ;;
    US-[0-9]*.[0-9]*\#[0-9]*)
      sid="${up%%#*}"; idx="${up##*#}"
      story_exists "$sid" || { echo "unknown target: $t (no story $sid in $SPECS)" >&2; return 1; }
      R_FOCUS=$(printf '%s\n' "$ROWS" | awk -F'\t' -v s="$sid" -v k="$idx" \
        '$1 == "T" && $2 == s && $3 == k { print $5; exit }')
      if [ -z "$R_FOCUS" ]; then
        echo "unknown target: $t (story $sid has no task #$idx)" >&2; R_FOCUS="-"; return 1
      fi
      R_KIND="task"; R_STORIES="$sid"
      return 0 ;;
    US-[0-9]*.[0-9]*)
      story_exists "$up" || { echo "unknown target: $t (no story $up in $SPECS)" >&2; return 1; }
      R_KIND="story"; R_STORIES="$up"
      return 0 ;;
  esac

  # Task text. Fail closed on ambiguity rather than choose.
  matches=$(printf '%s\n' "$ROWS" | NEEDLE="$t" awk -F'\t' '
    $1 == "T" && index(tolower($5), tolower(ENVIRON["NEEDLE"])) > 0 { print $2 "\t" $3 "\t" $5 }')
  count=$(printf '%s' "$matches" | grep -c . || true); count=${count:-0}
  if [ "$count" -eq 0 ]; then
    echo "unknown target: $t (not an epic, story, or task in $SPECS)" >&2; return 1
  fi
  if [ "$count" -gt 1 ]; then
    echo "ambiguous target: '$t' matches $count tasks — use US-N.M#k:" >&2
    printf '%s\n' "$matches" | awk -F'\t' '{ printf "  %s#%s  %s\n", $1, $2, $3 }' >&2
    return 1
  fi
  R_KIND="task"
  R_STORIES=$(printf '%s' "$matches" | awk -F'\t' '{ print $1 }')
  R_FOCUS=$(printf '%s' "$matches" | awk -F'\t' '{ print $3 }')
  return 0
}

# ---------------------------------------------------------------------------
# Next action
# ---------------------------------------------------------------------------

# set_action <action> <story> <change> <command> <reason>
set_action() {
  A_ACTION="$1"; A_STORY="$2"; A_CHANGE="$3"; A_COMMAND="$4"; A_REASON="$5"
}

# True when at least one `*.md` file exists under the directory, recursively, as
# upstream's artifact glob `specs/**/*.md` requires. The listing is tested as
# text: under `pipefail` a reader that stops early would turn a long listing
# into a failed pipeline.
has_file_under() {
  [ -d "$1" ] && [ -n "$(find "$1" -type f -name '*.md' 2>/dev/null | head -1)" ]
}

# Derive the next action for the stories in R_STORIES. Sets A_* variables.
# First match wins; the order below is the contract.
derive_next() {
  local sid status deps dep dstatus change own others cdir missing progress tdone ttotal blocked=""
  load_specs

  # The first story of the goal that is not DONE, in one pass over the rows.
  sid=$(printf '%s\n' "$ROWS" | GOAL_STORIES="$R_STORIES" awk -F'\t' '
    $1 == "S" && !($3 in st) { st[$3] = $4 }
    END {
      n = split(ENVIRON["GOAL_STORIES"], want, "\n")
      for (i = 1; i <= n; i++) if (want[i] != "" && st[want[i]] != "DONE") { print want[i]; exit }
    }')

  # 1. Nothing left to deliver.
  if [ -z "$sid" ]; then
    set_action complete - - "none — every story in the goal is DONE" \
      "all $(printf '%s\n' "$R_STORIES" | grep -c . || true) story/stories are DONE"
    return
  fi

  status=$(story_field "$sid" 4)
  # Not in a subshell: the directory listing stays cached for write_goal.
  change_set "$sid"; change="$CHANGE_ID"

  # 2. Readiness comes first: only READY or IN PROGRESS work may proceed. Checking
  # it before the archived branch keeps a story a human put on hold (NEEDS
  # CLARIFICATION, BLOCKED) from being steered to `mark-done`.
  case "$status" in
    READY|"IN PROGRESS") ;;
    *)
      set_action escalate "$sid" "$change" \
        "resolve $sid in $SPECS (a product decision is required)" \
        "$sid is $status, not READY"
      return ;;
  esac

  # 3. Dependencies: every named story must already be DONE. Like readiness, this
  # runs before the archived branch, whatever state the story's own change is in:
  # an archived change must not steer a story with an undelivered dependency into
  # its DONE transition.
  deps=$(story_field "$sid" 6)
  if [ -n "$deps" ] && [ "$deps" != "-" ]; then
    for dep in $(printf '%s' "$deps" | tr ',' ' '); do
      dstatus=$(story_field "$dep" 4)
      if [ -z "$dstatus" ]; then blocked="${blocked:+$blocked, }$dep (not in $SPECS)"
      elif [ "$dstatus" != "DONE" ]; then blocked="${blocked:+$blocked, }$dep ($dstatus)"
      fi
    done
  fi
  if [ -n "$blocked" ]; then
    set_action escalate "$sid" "$change" \
      "deliver or re-scope the dependency first" \
      "$sid depends on unfinished $blocked"
    return
  fi

  # 4. Archived, no longer active, and not yet DONE: the only remaining step is
  # the DONE edit. An active directory with the same id wins over the archive.
  # So does an active directory named for the story: a `Change:` line that names
  # an archived change must not close a story whose own change is still open.
  # guard-story-done.sh judges the same directories, so the two always agree.
  if [ ! -d "$CHANGES_DIR/$change" ] && change_archived "$change"; then
    own="${sid#US-}"; own="us-${own/./-}-"
    load_active_dirs
    if first_with_prefix "$ACTIVE_DIRS" "$own"; then
      set_action escalate "$sid" "$change" \
        "point $sid's Change: line at $CHANGE_ID in $SPECS to continue it, or remove that directory if it is not this story's change" \
        "$sid names the archived change $change, but its own change $CHANGE_ID is still active"
      return
    fi
    set_action mark-done "$sid" "$change" \
      "set 'Status: DONE' for $sid in $SPECS and point its Change: line at the archived change" \
      "change $change is archived but $sid is $status"
    return
  fi

  # 5-6. No change yet: propose one, but never alongside another active change.
  cdir="$CHANGES_DIR/$change"
  if [ ! -d "$cdir" ]; then
    others=$(active_changes | grep -vxF "$change" | tr '\n' ' ' | sed 's/ $//' || true)
    if [ -n "$others" ]; then
      set_action escalate "$sid" "$change" \
        "finish or archive the active change first" \
        "another change is active: $others (one active change at a time)"
      return
    fi
    set_action propose "$sid" "$change" \
      "/ohmyorch:opsx-propose $change for $sid; then set $sid to IN PROGRESS with a Change: line in $SPECS" \
      "$sid is $status and has no OpenSpec change"
    return
  fi

  # 7. Active change: are OpenSpec's planning artifacts there? Plain file checks.
  # design.md is conditional upstream and is never required; specs/ must hold at
  # least one `.md` file unless the change records `skip_specs: true`, read as
  # YAML reads it: true, True or TRUE, with an optional trailing comment.
  missing=""
  [ -f "$cdir/proposal.md" ] || missing="proposal.md"
  if ! grep -qE '^skip_specs:[[:space:]]*(true|True|TRUE)([[:space:]]+#.*)?[[:space:]]*$' "$cdir/.openspec.yaml" 2>/dev/null; then
    has_file_under "$cdir/specs" || missing="${missing:+$missing, }specs/"
  fi
  [ -f "$cdir/tasks.md" ] || missing="${missing:+$missing, }tasks.md"
  if [ -n "$missing" ]; then
    set_action propose "$sid" "$change" \
      "/ohmyorch:opsx-propose $change for $sid (continue the existing change: author only what is missing)" \
      "planning incomplete: missing $missing"
    return
  fi
  progress=$(ohmyorch_tasks_progress "$cdir/tasks.md")
  read -r tdone ttotal <<< "$progress"
  if [ "$ttotal" -eq 0 ]; then
    set_action propose "$sid" "$change" \
      "/ohmyorch:opsx-propose $change for $sid (continue the existing change: author only what is missing)" \
      "planning incomplete: tasks.md has no task checkboxes"
    return
  fi

  # 8. tasks.md is the only tracking file: an unticked task means apply. A
  # CRITICAL verify finding is recorded as a new unticked task, which lands here.
  if [ "$tdone" -lt "$ttotal" ]; then
    set_action apply "$sid" "$change" "/ohmyorch:opsx-apply $change" "$tdone/$ttotal tasks complete"
    return
  fi

  # 9. Every task ticked: verify (advisory, writes no file), then archive. The
  # archived change is picked up by branch 4 on the next call.
  set_action verify "$sid" "$change" \
    "/ohmyorch:opsx-verify $change; with no CRITICAL issue, run a separate Bash call: openspec archive $change -y" \
    "$ttotal/$ttotal tasks complete; verify, then archive"
}

# One JSON line, or exactly five text lines. The JSON line is fingerprinted by
# the Stop hook for stall detection, so it carries nothing time-dependent.
print_action() {
  if [ "${AS_JSON:-0}" -eq 1 ]; then
    jq -rn --arg target "$TARGET" --arg action "$A_ACTION" --arg story "$A_STORY" \
      --arg change "$A_CHANGE" --arg command "$A_COMMAND" --arg reason "$A_REASON" \
      '"{ \"target\": \($target|tojson), \"action\": \($action|tojson), \"story\": \($story|tojson), \"change\": \($change|tojson), \"command\": \($command|tojson), \"reason\": \($reason|tojson) }"'
    return
  fi
  printf 'Action:  %s\n' "$A_ACTION"
  printf 'Story:   %s\n' "$A_STORY"
  printf 'Change:  %s\n' "$A_CHANGE"
  printf 'Command: %s\n' "$A_COMMAND"
  printf 'Reason:  %s\n' "$A_REASON"
}

# ---------------------------------------------------------------------------
# goal.md
# ---------------------------------------------------------------------------

goal_field() {
  [ -f "$GOAL" ] || return 0
  awk -F'|' -v k="$1" '{
    key = $2; gsub(/^[ ]+|[ ]+$/, "", key)
    if (key == k) { v = $3; gsub(/^[ ]+|[ ]+$/, "", v); print v; exit }
  }' "$GOAL"
}

goal_notes() {
  if [ -f "$GOAL" ] && grep -q 'BEGIN AUTHORED: notes' "$GOAL"; then
    awk '/<!-- BEGIN AUTHORED: notes -->/ { inb = 1; next }
         /<!-- END AUTHORED: notes -->/   { inb = 0; next }
         inb { print }' "$GOAL"
  else
    printf 'None.\n'
  fi
}

# write_goal <target> <kind> <focus> <status> <reason> <started>
# Derived sections are rebuilt from SPECS.md and the change artifacts; Notes are
# preserved.
write_goal() {
  local target="$1" kind="$2" focus="$3" gstatus="$4" reason="$5" started="$6"
  local notes tmp n s st ch sl ti rows
  notes=$(goal_notes)
  # One pass over the rows: "<story> <status> <Change: value> <slug> <title>" per
  # goal story, in goal order. The slug is never empty, so no field collapses.
  # A story without a Change: line is resolved below from the cached directory
  # listing and that slug, as change_set resolves it, without a process per story.
  # The awk reads bytes, so the title leaves it untouched; its `|` is replaced
  # below in the session's locale, where a multi-byte character stays whole.
  rows=$(printf '%s\n' "$ROWS" | GOAL_STORIES="$R_STORIES" LC_ALL=C awk -F'\t' "$SLUG_AWK"'
    $1 == "S" && !($3 in st) { st[$3] = $4; ch[$3] = $5; ti[$3] = $7 }
    END {
      n = split(ENVIRON["GOAL_STORIES"], want, "\n")
      for (i = 1; i <= n; i++) {
        s = want[i]; if (s == "") continue
        sl = slug(ti[s]); if (sl == "") sl = "story"
        printf "%s\t%s\t%s\t%s\t%s\n", s, st[s], ch[s], sl, ti[s]
      }
    }')
  mkdir -p "$GOAL_DIR"
  tmp=$(mktemp "${TMPDIR:-/tmp}/goal.XXXXXX") || die "cannot create temp file"
  {
    printf '# Delivery Goal\n\n'
    printf 'Written by `ohmyorch delivery`. The field table, Stories, and Next Action are\n'
    printf '**derived** from SPECS.md and the OpenSpec change artifacts: refresh them with\n'
    printf '`ohmyorch delivery refresh`, never hand-edit. Notes between the AUTHORED\n'
    printf 'markers are preserved across refreshes.\n\n'
    printf '| Field | Value |\n|---|---|\n'
    printf '| Target | %s |\n' "$target"
    printf '| Kind | %s |\n' "$kind"
    printf '| Focus | %s |\n' "$(printf '%s' "$focus" | tr '|' '/')"
    printf '| Status | %s |\n' "$gstatus"
    printf '| Reason | %s |\n' "$(printf '%s' "$reason" | tr '|' '/')"
    printf '| Started | %s |\n' "$started"
    printf '| Updated | %s |\n\n' "$TODAY"
    printf '## Stories\n\n'
    printf '| # | Story | Change | SPECS status | Title |\n|---|---|---|---|---|\n'
    n=0
    while IFS=$'\t' read -r s st ch sl ti; do
      [ -n "$s" ] || continue
      n=$((n + 1))
      if [ "$ch" != "-" ]; then change_id "$ch"
      elif ! change_from_dirs "$s"; then CHANGE_ID="${s#US-}"; CHANGE_ID="us-${CHANGE_ID/./-}-$sl"
      fi
      printf '| %s | %s | %s | %s | %s |\n' "$n" "$s" "$CHANGE_ID" "$st" "${ti//|//}"
    done <<EOF
$rows
EOF
    printf '\n## Next Action\n\n'
    printf 'Action: %s\n' "$A_ACTION"
    printf 'Story: %s\n' "$A_STORY"
    printf 'Change: %s\n' "$A_CHANGE"
    printf 'Command: %s\n' "$A_COMMAND"
    printf 'Reason: %s\n' "$A_REASON"
    printf '\nThis is the last computed action, for reading only. `ohmyorch delivery next`\n'
    printf 'recomputes it from the repository on every call.\n\n'
    printf '## Notes\n\n'
    printf '<!-- BEGIN AUTHORED: notes -->\n%s\n<!-- END AUTHORED: notes -->\n' "$notes"
  } > "$tmp"
  # An unwritable goal directory must not leave the staged copy behind.
  mv "$tmp" "$GOAL" || { rm -f "$tmp"; return 1; }
}

# Load the recorded goal's target and resolve it again from SPECS.md.
load_goal() {
  [ -f "$GOAL" ] || die "no delivery goal recorded at $GOAL — run: ohmyorch delivery start <target>"
  TARGET=$(goal_field Target)
  [ -n "$TARGET" ] || die "$GOAL has no Target field"
  G_STATUS=$(goal_field Status); G_REASON=$(goal_field Reason); G_STARTED=$(goal_field Started)
  resolve_target "$TARGET" || die "recorded target '$TARGET' no longer resolves"
}

# refresh_goal [status] [reason] — status/reason default to the recorded values.
refresh_goal() {
  local gs="${1:-$G_STATUS}" gr="${2:-$G_REASON}"
  derive_next
  [ "$A_ACTION" = "complete" ] && { gs="COMPLETE"; gr="-"; }
  write_goal "$TARGET" "$R_KIND" "$R_FOCUS" "${gs:-ACTIVE}" "${gr:--}" "${G_STARTED:-$TODAY}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

[ $# -ge 1 ] || { usage >&2; exit 2; }
CMD="$1"; shift
AS_JSON=0
TARGET=""
REASON_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --json)   AS_JSON=1; shift ;;
    --reason) [ $# -ge 2 ] || die "--reason needs a value" 2; REASON_ARG="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option '$1'" 2 ;;
    *)  [ -z "$TARGET" ] || die "unexpected argument '$1'" 2; TARGET="$1"; shift ;;
  esac
done

case "$CMD" in
  -h|--help|help) usage; exit 0 ;;

  resolve)
    [ -n "$TARGET" ] || die "resolve needs a target" 2
    resolve_target "$TARGET" || exit 1
    if [ "$AS_JSON" -eq 1 ]; then
      printf '{ "target": %s, "kind": %s, "focus": %s, "stories": [' \
        "$(jstr "$TARGET")" "$(jstr "$R_KIND")" "$(jstr "$R_FOCUS")"
      sep=""
      while IFS= read -r s; do
        [ -n "$s" ] || continue
        # Not in a subshell: the directory listing is read once for all stories.
        change_set "$s"
        printf '%s { "story": %s, "status": %s, "change": %s }' "$sep" "$(jstr "$s")" \
          "$(jstr "$(story_field "$s" 4)")" "$(jstr "$CHANGE_ID")"
        sep=","
      done <<EOF
$R_STORIES
EOF
      printf ' ] }\n'
    else
      printf 'Target: %s\nKind:   %s\nFocus:  %s\n\n' "$TARGET" "$R_KIND" "$R_FOCUS"
      n=0
      while IFS= read -r s; do
        [ -n "$s" ] || continue
        n=$((n + 1))
        change_set "$s"
        printf '  %2s  %-8s %-20s %-40s %s\n' "$n" "$s" "$(story_field "$s" 4)" \
          "$CHANGE_ID" "$(story_field "$s" 7)"
      done <<EOF
$R_STORIES
EOF
    fi
    ;;

  start)
    [ -n "$TARGET" ] || die "start needs a target" 2
    resolve_target "$TARGET" || { echo "no delivery goal recorded" >&2; exit 1; }
    if [ -f "$GOAL" ]; then
      old=$(goal_field Target); ostat=$(goal_field Status)
      if [ "$old" = "$TARGET" ]; then
        G_STARTED=$(goal_field Started)            # resume the same goal
      elif [ "$ostat" = "ACTIVE" ] || [ "$ostat" = "BLOCKED" ]; then
        die "a different goal is $ostat ($old) — run ohmyorch delivery stop first"
      else
        rm -f "$GOAL"; G_STARTED="$TODAY"          # previous goal finished
      fi
    else
      G_STARTED="$TODAY"
    fi
    G_STATUS="ACTIVE"; G_REASON="-"
    rm -f "$LOOP_STATE"
    refresh_goal ACTIVE -
    printf '%sGOAL%s  %s (%s) — %s\n' "$c_green" "$c_reset" "$TARGET" "$R_KIND" "$(goal_field Status)"
    print_action
    ;;

  next)
    if [ -n "$TARGET" ]; then
      resolve_target "$TARGET" || exit 1
    else
      load_goal
    fi
    derive_next
    print_action
    ;;

  refresh)
    # One derivation both rewrites goal.md and reports the action: the Stop hook
    # uses --json so a stop attempt derives the goal once, not twice.
    load_goal
    refresh_goal
    if [ "$AS_JSON" -eq 1 ]; then
      print_action
    else
      printf 'Wrote %s (Status %s, next action %s)\n' "$GOAL" "$(goal_field Status)" "$A_ACTION"
    fi
    ;;

  stop)
    # Like `block`, a halt must be recorded even when the recorded target no longer
    # resolves: load_goal would exit non-zero and leave the goal looking ACTIVE.
    [ -f "$GOAL" ] || die "no delivery goal recorded at $GOAL — run: ohmyorch delivery start <target>"
    rm -f "$LOOP_STATE"
    REASON_ARG=$(printf '%s' "${REASON_ARG:-stopped by the Product Manager}" | tr '\n|' ' /')
    TARGET=$(goal_field Target)
    if [ -n "$TARGET" ] && ( resolve_target "$TARGET" ) >/dev/null 2>&1 \
       && resolve_target "$TARGET" 2>/dev/null; then
      G_STATUS=$(goal_field Status); G_REASON=$(goal_field Reason); G_STARTED=$(goal_field Started)
      refresh_goal STOPPED "$REASON_ARG"
    else
      tmp=$(mktemp "${TMPDIR:-/tmp}/goal.XXXXXX") || die "cannot create temp file"
      REASON="$REASON_ARG" awk -F'|' -v today="$TODAY" '{
        key = $2; gsub(/^[ ]+|[ ]+$/, "", key)
        if (key == "Status")  { print "| Status | STOPPED |"; next }
        if (key == "Reason")  { print "| Reason | " ENVIRON["REASON"] " |"; next }
        if (key == "Updated") { print "| Updated | " today " |"; next }
        print
      }' "$GOAL" > "$tmp" && mv "$tmp" "$GOAL" || rm -f "$tmp"
    fi
    printf 'Goal %s recorded as %s\n' "${TARGET:-?}" "$(goal_field Status)"
    ;;

  block)
    # The delivery loop halts for a human decision. Target, Started, and Notes
    # are preserved, so `start <same target>` resumes the goal as ACTIVE.
    [ -f "$GOAL" ] || die "no delivery goal recorded at $GOAL"
    rm -f "$LOOP_STATE"
    REASON_ARG=$(printf '%s' "${REASON_ARG:-blocked: a Product Manager decision is required}" | tr '\n|' ' /')
    TARGET=$(goal_field Target)
    # A subshell probe: resolve_target exits (via load_specs/die) when SPECS.md is
    # missing, which would skip the in-place fallback below.
    if [ -n "$TARGET" ] && ( resolve_target "$TARGET" ) >/dev/null 2>&1 \
       && resolve_target "$TARGET" 2>/dev/null; then
      G_STATUS=$(goal_field Status); G_REASON=$(goal_field Reason); G_STARTED=$(goal_field Started)
      refresh_goal BLOCKED "$REASON_ARG"
    else
      # The recorded target no longer resolves, so nothing can be derived. Rewrite
      # only the Status, Reason, and Updated rows in place: the halt must still be
      # recorded, or a resuming session would believe the goal is ACTIVE.
      tmp=$(mktemp "${TMPDIR:-/tmp}/goal.XXXXXX") || die "cannot create temp file"
      REASON="$REASON_ARG" awk -F'|' -v today="$TODAY" '{
        key = $2; gsub(/^[ ]+|[ ]+$/, "", key)
        if (key == "Status")  { print "| Status | BLOCKED |"; next }
        if (key == "Reason")  { print "| Reason | " ENVIRON["REASON"] " |"; next }
        if (key == "Updated") { print "| Updated | " today " |"; next }
        print
      }' "$GOAL" > "$tmp" && mv "$tmp" "$GOAL" || rm -f "$tmp"
    fi
    printf 'Goal %s recorded as %s — %s\n' "${TARGET:-?}" "$(goal_field Status)" "$(goal_field Reason)"
    ;;

  *) die "unknown command '$CMD'" 2 ;;
esac
exit 0
