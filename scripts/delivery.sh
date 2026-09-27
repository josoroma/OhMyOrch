#!/usr/bin/env bash
#
# delivery.sh — US-12.1: resolve a delivery target and derive the next action
#
# A delivery goal is one target from SPECS.md — an epic, a user story, or a task —
# that the harness drives to completion one bounded OpenSpec change at a time
# (PRD.md FR-019, BR-003). This script answers the only question a goal loop
# needs answered: "what is the next action, who owns it, and what command
# performs it?" — and it answers from repository artifacts alone (BR-004).
#
#   EPIC-N       every US-N.* story under "# EPIC-N:", in SPECS.md order
#   US-N.M       that story
#   US-N.M#k     task k of that story; the goal delivers the parent story and
#                records the task as its Focus (a task has no acceptance
#                criteria of its own, so it cannot be reviewed or accepted alone)
#   <task text>  a task found by case-insensitive substring; must be unique
#
# The next action is DERIVED on every call from SPECS.md, workflow-status.sh
# (the seven gates) and completion-gate.sh (the four US-10.1 conditions). It is
# never read back from goal.md: a stored action could silently disagree with the
# gates. goal.md records the last computed action for a human reader only.
#
# This script never writes review.md or test-report.md, and never ticks a task.
# `reopen` MOVES a failing verdict aside (preserving it verbatim) and appends
# unticked remediation tasks, which re-opens the implementation gate.
#
# Usage:
#   delivery.sh resolve <target> [--json]
#   delivery.sh start   <target>
#   delivery.sh next    [<target>] [--json]
#   delivery.sh refresh
#   delivery.sh reopen  [--change <id>]
#   delivery.sh stop    [--reason <text>]
#   delivery.sh block   [--reason <text>]     (US-12.2: the loop halts for a human)
#
# Exit codes: 0 success, 1 unknown/ambiguous target or refused, 2 usage error.
#
# Dependencies: bash, awk, grep, sed, find — no Node/Python (NFR-001).

set -uo pipefail

GOAL_DIR="openspec/delivery"
GOAL="$GOAL_DIR/goal.md"
# Per-machine stall counter owned by guard-delivery-loop.sh (US-12.2). Every goal
# status transition clears it, so a resumed goal counts stalls from zero.
LOOP_STATE="$GOAL_DIR/loop.state"
CHANGES_DIR="openspec/changes"
TODAY=$(date +%Y-%m-%d)

c_reset=""; c_red=""; c_dim=""; c_green=""; c_yellow=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_dim=$'\033[2m'
  c_green=$'\033[32m'; c_yellow=$'\033[33m'
fi

usage() {
  cat <<'EOF'
Usage: scripts/delivery.sh <command> [args]

Resolve a SPECS.md delivery target and derive the next action (US-12.1).

Commands:
  resolve <target> [--json]   List the stories a target delivers, with change ids
  start   <target>            Record openspec/delivery/goal.md (Status ACTIVE)
  next    [<target>] [--json] Derive the next action (goal target by default)
  refresh                     Rewrite goal.md's derived sections
  reopen  [--change <id>]     Move a failing review/test report to history/ and
                              append one unticked remediation task per finding
  stop    [--reason <text>]   Record the goal as STOPPED
  block   [--reason <text>]   Record the goal as BLOCKED (a human decision is
                              needed); `start <same target>` resumes it

Targets:  EPIC-N | US-N.M | US-N.M#k | "<task text>"

Actions:  select propose plan implement review reopen test archive
          mark-done escalate complete

Exit codes: 0 success, 1 unknown/ambiguous target or refused, 2 usage error
EOF
}

die()  { printf '%serror:%s %s\n' "$c_red" "$c_reset" "$1" >&2; exit "${2:-1}"; }

# One JSON string, escaped. Values here never contain control characters other
# than tabs (stripped by the parser), so backslash and quote are enough.
jstr() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }

# ---------------------------------------------------------------------------
# SPECS.md
# ---------------------------------------------------------------------------

SPECS="SPECS.md"
[ -f docs/SPECS.md ] && SPECS="docs/SPECS.md"

# Emit one TSV row per story and per task. Empty fields are "-" so a consumer
# never has to reason about collapsed separators.
#   S  epic  story  status  change  deps(comma)  title
#   T  story index  done(0|1)  text
parse_specs() {
  [ -f "$SPECS" ] || die "SPECS.md not found (looked for docs/SPECS.md and SPECS.md)"
  awk '
    function flush() {
      if (story != "") {
        printf "S\t%s\t%s\t%s\t%s\t%s\t%s\n", (epic == "" ? "-" : epic), story,
               (status == "" ? "-" : status), (change == "" ? "-" : change),
               (deps == "" ? "-" : deps), (title == "" ? "-" : title)
      }
      story = ""; status = ""; change = ""; deps = ""; title = ""; sect = ""; ntask = 0
    }
    { gsub(/\t/, " ") }
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
      # ignoring the inline form made a dependent story selectable (review O-4).
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

# Title -> kebab slug: lowercase, drop stop words, first four words.
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' ' ' | awk '{
    n = 0; out = ""
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^(a|an|the|and|or|of|to|for|from|in|on|with|by|as|at|is|its)$/) continue
      out = out (out == "" ? "" : "-") $i
      if (++n == 4) break
    }
    print out
  }'
}

# change_for <story-id>: the Change: line wins, then an existing change directory
# for the story, then a derived id. `openspec archive` prefixes YYYY-MM-DD-.
change_for() {
  local id="$1" ch nm prefix found
  ch=$(story_field "$id" 5)
  if [ -n "$ch" ] && [ "$ch" != "-" ]; then
    ch="${ch%/}"; ch="${ch##*/}"
    printf '%s' "$ch" | sed 's/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-//'
    return
  fi
  nm=$(printf '%s' "$id" | sed 's/^US-//; s/\./-/')
  prefix="us-$nm-"
  found=$(find "$CHANGES_DIR" -maxdepth 1 -mindepth 1 -type d -name "${prefix}*" 2>/dev/null \
    | sed 's|.*/||' | sort | head -1)
  if [ -z "$found" ]; then
    found=$(find "$CHANGES_DIR/archive" -maxdepth 1 -mindepth 1 -type d \
      -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-${prefix}*" 2>/dev/null \
      | sed 's|.*/||; s/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-//' | sort | head -1)
  fi
  if [ -n "$found" ]; then printf '%s' "$found"; return; fi
  printf 'us-%s-%s' "$nm" "$(slugify "$(story_field "$id" 7)")"
}

change_archived() {
  find "$CHANGES_DIR/archive" -maxdepth 1 -mindepth 1 -type d \
    \( -name "$1" -o -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-$1" \) 2>/dev/null \
    | grep -q .
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

  # Task text. Fail closed on ambiguity rather than choose (NFR-005).
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

# set_action <action> <story> <change> <owner> <command> <reason>
set_action() {
  A_ACTION="$1"; A_STORY="$2"; A_CHANGE="$3"; A_OWNER="$4"; A_COMMAND="$5"; A_REASON="$6"
}

# Derive the next action for the stories in R_STORIES. Sets A_* variables.
derive_next() {
  local sid status deps dep dstatus change others ws wrc first detail cg elig ffc blocked=""
  load_specs

  sid=""
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    if [ "$(story_field "$s" 4)" != "DONE" ]; then sid="$s"; break; fi
  done <<EOF
$R_STORIES
EOF

  if [ -z "$sid" ]; then
    set_action complete - - product-manager "none — every story in the goal is DONE" \
      "all $(printf '%s\n' "$R_STORIES" | grep -c . || true) story/stories are DONE"
    return
  fi

  status=$(story_field "$sid" 4)
  change=$(change_for "$sid")

  # Readiness (BR-005) comes first: only READY or IN PROGRESS work may proceed.
  # Checking it after the archived branch let a story a human had put on hold
  # (NEEDS CLARIFICATION, BLOCKED) be steered to `mark-done` (review F-1, r1).
  case "$status" in
    READY|"IN PROGRESS") ;;
    *)
      set_action escalate "$sid" "$change" "human-product-manager" \
        "resolve $sid in $SPECS (a product decision is required)" \
        "$sid is $status, not READY"
      return ;;
  esac

  # Dependencies: every named story must already be DONE. Like readiness, this
  # runs before the archived branch, whatever state the story's own change is
  # in: an archived change must not steer a story with an undelivered
  # dependency into its DONE transition (review F-2, r2).
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
    set_action escalate "$sid" "$change" "human-product-manager" \
      "deliver or re-scope the dependency first" \
      "$sid depends on unfinished $blocked"
    return
  fi

  # Archived but not yet DONE: the only remaining step is the guarded DONE edit.
  if change_archived "$change"; then
    set_action mark-done "$sid" "$change" product-manager \
      "set 'Status: DONE' for $sid in $SPECS (guarded by scripts/guard-story-done.sh)" \
      "change $change is archived but $sid is $status"
    return
  fi

  # No change yet: select one, but never alongside another active change.
  if [ ! -d "$CHANGES_DIR/$change" ]; then
    others=$(active_changes | grep -vxF "$change" | tr '\n' ' ' | sed 's/ $//' || true)
    if [ -n "$others" ]; then
      set_action escalate "$sid" "$change" "human-product-manager" \
        "finish or archive the active change first" \
        "another change is active: $others (one active change at a time)"
      return
    fi
    set_action select "$sid" "$change" product-manager \
      "openspec new change $change; set $sid to IN PROGRESS with a Change: line; scripts/status.sh --change $change" \
      "$sid is $status and has no OpenSpec change"
    return
  fi

  # Active change: the gates decide. Capture output and exit code separately.
  ws=$(scripts/workflow-status.sh --change "$change" --json 2>/dev/null); wrc=$?
  if [ "$wrc" -ne 0 ] || [ -z "$ws" ]; then
    set_action escalate "$sid" "$change" "human-product-manager" \
      "inspect scripts/workflow-status.sh --change $change" \
      "the gate reporter could not report (exit $wrc)"
    return
  fi
  first=$(printf '%s\n' "$ws" | sed -n 's/.*"firstIncompleteGate": *"\([^"]*\)".*/\1/p' | head -1)
  detail=$(printf '%s\n' "$ws" | grep -F "\"gate\": \"$first\"" \
    | sed -n 's/.*"detail": *"\([^"]*\)".*/\1/p' | head -1)

  case "$first" in
    planning)
      set_action propose "$sid" "$change" planner \
        "/opsx:explore $sid then /opsx:propose $change" "gate planning: $detail" ;;
    plan-handoff)
      set_action plan "$sid" "$change" planner "/plan-feature $change" "gate plan-handoff: $detail" ;;
    implementation)
      set_action implement "$sid" "$change" implementer "/opsx:apply $change" "gate implementation: $detail" ;;
    review)
      if printf '%s' "$detail" | grep -q 'blocking findings'; then
        set_action reopen "$sid" "$change" product-manager \
          "scripts/delivery.sh reopen --change $change" "gate review: $detail"
      else
        set_action review "$sid" "$change" reviewer \
          "/review-feature $change (includes /opsx:verify)" "gate review: $detail"
      fi ;;
    testing)
      if printf '%s' "$detail" | grep -q 'reports FAIL'; then
        set_action reopen "$sid" "$change" product-manager \
          "scripts/delivery.sh reopen --change $change" "gate testing: $detail"
      else
        set_action test "$sid" "$change" tester "/test-feature $change" "gate testing: $detail"
      fi ;;
    acceptance)
      set_action escalate "$sid" "$change" "human-product-manager" \
        "fix the product-artifact contract (scripts/validate-product-artifacts.sh)" \
        "gate acceptance: $detail" ;;
    "")
      cg=$(scripts/completion-gate.sh --change "$change" --json 2>/dev/null)
      elig=$(printf '%s' "$cg" | grep -oE '"eligible": *(true|false)' | head -1 | grep -oE 'true|false')
      ffc=$(printf '%s' "$cg" | sed -n 's/.*"firstFailingCondition": *"\([^"]*\)".*/\1/p' | head -1)
      if [ "$elig" = "true" ]; then
        set_action archive "$sid" "$change" product-manager \
          "scripts/completion-gate.sh --change $change --record && openspec archive $change -y" \
          "all seven gates and all four completion conditions pass"
      else
        set_action escalate "$sid" "$change" "human-product-manager" \
          "inspect scripts/completion-gate.sh --change $change" \
          "gates pass but completion condition '${ffc:-unknown}' fails"
      fi ;;
    *)
      set_action escalate "$sid" "$change" "human-product-manager" \
        "inspect scripts/workflow-status.sh --change $change" "unmapped gate '$first'" ;;
  esac
}

print_action() {
  if [ "${AS_JSON:-0}" -eq 1 ]; then
    printf '{ "target": %s, "action": %s, "story": %s, "change": %s, "owner": %s, "command": %s, "reason": %s }\n' \
      "$(jstr "$TARGET")" "$(jstr "$A_ACTION")" "$(jstr "$A_STORY")" "$(jstr "$A_CHANGE")" \
      "$(jstr "$A_OWNER")" "$(jstr "$A_COMMAND")" "$(jstr "$A_REASON")"
    return
  fi
  printf 'Action:  %s\n' "$A_ACTION"
  printf 'Story:   %s\n' "$A_STORY"
  printf 'Change:  %s\n' "$A_CHANGE"
  printf 'Owner:   %s\n' "$A_OWNER"
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
# Derived sections are rebuilt from SPECS.md and the gates; Notes are preserved.
write_goal() {
  local target="$1" kind="$2" focus="$3" gstatus="$4" reason="$5" started="$6"
  local notes tmp n s
  notes=$(goal_notes)
  mkdir -p "$GOAL_DIR"
  tmp=$(mktemp "${TMPDIR:-/tmp}/goal.XXXXXX") || die "cannot create temp file"
  {
    printf '# Delivery Goal\n\n'
    printf 'Written by `scripts/delivery.sh`. The field table, Stories, and Next Action are\n'
    printf '**derived** from SPECS.md and the gate reporters: refresh them with\n'
    printf '`scripts/delivery.sh refresh`, never hand-edit. Notes between the AUTHORED\n'
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
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      n=$((n + 1))
      printf '| %s | %s | %s | %s | %s |\n' "$n" "$s" "$(change_for "$s")" \
        "$(story_field "$s" 4)" "$(story_field "$s" 7 | tr '|' '/')"
    done <<EOF
$R_STORIES
EOF
    printf '\n## Next Action\n\n'
    printf 'Action: %s\n' "$A_ACTION"
    printf 'Story: %s\n' "$A_STORY"
    printf 'Change: %s\n' "$A_CHANGE"
    printf 'Owner: %s\n' "$A_OWNER"
    printf 'Command: %s\n' "$A_COMMAND"
    printf 'Reason: %s\n' "$A_REASON"
    printf '\nThis is the last computed action, for reading only. `scripts/delivery.sh next`\n'
    printf 'recomputes it from the repository on every call.\n\n'
    printf '## Notes\n\n'
    printf '<!-- BEGIN AUTHORED: notes -->\n%s\n<!-- END AUTHORED: notes -->\n' "$notes"
  } > "$tmp"
  mv "$tmp" "$GOAL"
}

# Load the recorded goal's target and resolve it again from SPECS.md.
load_goal() {
  [ -f "$GOAL" ] || die "no delivery goal recorded at $GOAL — run: scripts/delivery.sh start <target>"
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
# reopen
# ---------------------------------------------------------------------------

# Findings from a blocking review.md: "<finding id: title>\t<remediation>"
review_findings() {
  awk '
    function emit() {
      if (id != "") printf "%s\t%s\n", id, (rem == "" ? "see the preserved review" : rem)
      id = ""; rem = ""
    }
    /^### Finding / { emit(); id = $0; sub(/^### Finding[ ]*/, "", id); next }
    /^## /          { emit(); next }
    id != "" && /^Remediation:/ { rem = $0; sub(/^Remediation:[ ]*/, "", rem) }
    END { emit() }
  ' "$1" | tr -d '\r'
}

# Failures from a failing test-report.md: "<criterion>\t<expected>"
test_failures() {
  local out
  out=$(awk '
    function emit() {
      if (id != "") printf "%s\t%s\n", id, (ex == "" ? "see the preserved test report" : ex)
      id = ""; ex = ""
    }
    /^## Failures/ { inf = 1; next }
    inf && /^## /  { emit(); inf = 0; next }
    inf && /^### / { emit(); id = $0; sub(/^### [ ]*/, "", id); next }
    inf && id != "" && /^Expected:/ { ex = $0; sub(/^Expected:[ ]*/, "", ex) }
    END { emit() }
  ' "$1")
  if [ -z "$out" ]; then
    # No Failures section: fall back to the FAIL rows of the criteria table.
    out=$(awk -F'|' '{
      for (i = 2; i <= NF; i++) {
        c = $i; gsub(/^[ ]+|[ ]+$/, "", c)
        if (c == "FAIL" && i > 2) {
          p = $(i - 1); gsub(/^[ ]+|[ ]+$/, "", p)
          printf "%s\tsee the preserved test report\n", p; break
        }
      }
    }' "$1")
  fi
  printf '%s\n' "$out" | tr -d '\r' | grep . || true
}

do_reopen() {
  local change="$1" cdir ws first detail round kind findings k line id text preserved
  cdir="$CHANGES_DIR/$change"
  [ -d "$cdir" ] || die "change '$change' not found under $CHANGES_DIR"
  [ -f "$cdir/tasks.md" ] || die "$cdir/tasks.md not found"

  ws=$(scripts/workflow-status.sh --change "$change" --json 2>/dev/null)
  first=$(printf '%s\n' "$ws" | sed -n 's/.*"firstIncompleteGate": *"\([^"]*\)".*/\1/p' | head -1)
  detail=$(printf '%s\n' "$ws" | grep -F "\"gate\": \"$first\"" \
    | sed -n 's/.*"detail": *"\([^"]*\)".*/\1/p' | head -1)

  if [ "$first" = "review" ] && printf '%s' "$detail" | grep -q 'blocking findings'; then
    kind="review"
  elif [ "$first" = "testing" ] && printf '%s' "$detail" | grep -q 'reports FAIL'; then
    kind="test-report"
  else
    die "nothing to reopen: $change has no blocking review or failing test report (first incomplete gate: ${first:-none})"
  fi

  mkdir -p "$cdir/history"
  round=$(find "$cdir/history" -maxdepth 1 -type f -name '*-r[0-9]*.md' 2>/dev/null \
    | sed -n 's/.*-r\([0-9][0-9]*\)\.md$/\1/p' | sort -n | tail -1)
  round=$(( ${round:-0} + 1 ))

  if [ "$kind" = "review" ]; then
    findings=$(review_findings "$cdir/review.md")
    [ -n "$findings" ] || findings=$(printf 'blocking review\taddress every blocking finding in history/review-r%s.md' "$round")
  else
    findings=$(test_failures "$cdir/test-report.md")
    [ -n "$findings" ] || findings=$(printf 'failing acceptance\tmake every FAIL criterion in history/test-report-r%s.md pass' "$round")
  fi

  # Preserve verdicts verbatim. Every downstream verdict is re-opened: a test
  # report describes code that is about to change, and a change made after an
  # acceptance failure must be reviewed again before retesting (US-7.1).
  preserved=""
  if [ -f "$cdir/review.md" ]; then
    mv "$cdir/review.md" "$cdir/history/review-r$round.md"; preserved="history/review-r$round.md"
  fi
  if [ -f "$cdir/test-report.md" ]; then
    mv "$cdir/test-report.md" "$cdir/history/test-report-r$round.md"
    preserved="${preserved:+$preserved, }history/test-report-r$round.md"
  fi

  {
    printf '\n## R%s. Remediation — reopened %s from %s\n\n' "$round" "$TODAY" "$kind"
    printf 'Preserved: %s\n\n' "$preserved"
    k=0
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      k=$((k + 1))
      id=$(printf '%s' "$line" | awk -F'\t' '{ print $1 }')
      text=$(printf '%s' "$line" | awk -F'\t' '{ print $2 }')
      if [ "$kind" = "review" ]; then
        printf -- '- [ ] R%s.%s Resolve review finding %s — %s\n' "$round" "$k" "$id" "$text"
      else
        printf -- '- [ ] R%s.%s Make failing criterion pass: %s — expected: %s\n' "$round" "$k" "$id" "$text"
      fi
    done <<EOF
$findings
EOF
  } >> "$cdir/tasks.md"

  [ -x scripts/status.sh ] && scripts/status.sh --change "$change" --quiet >/dev/null 2>&1
  printf '%sREOPENED%s  %s — round %s from %s\n' "$c_yellow" "$c_reset" "$change" "$round" "$kind"
  printf '  preserved:   %s\n' "$preserved"
  printf '  appended:    %s remediation task(s) to %s/tasks.md\n' "$k" "$cdir"
  printf '  next owner:  implementer (/opsx:apply %s), then reviewer, then tester\n' "$change"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

[ $# -ge 1 ] || { usage >&2; exit 2; }
CMD="$1"; shift
AS_JSON=0
TARGET=""
CHANGE_ARG=""
REASON_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --json)   AS_JSON=1; shift ;;
    --change) [ $# -ge 2 ] || die "--change needs a value" 2; CHANGE_ARG="$2"; shift 2 ;;
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
        printf '%s { "story": %s, "status": %s, "change": %s }' "$sep" "$(jstr "$s")" \
          "$(jstr "$(story_field "$s" 4)")" "$(jstr "$(change_for "$s")")"
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
        printf '  %2s  %-8s %-20s %-40s %s\n' "$n" "$s" "$(story_field "$s" 4)" \
          "$(change_for "$s")" "$(story_field "$s" 7)"
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
        die "a different goal is $ostat ($old) — run scripts/delivery.sh stop first"
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
    load_goal
    refresh_goal
    printf 'Wrote %s (Status %s, next action %s)\n' "$GOAL" "$(goal_field Status)" "$A_ACTION"
    ;;

  reopen)
    if [ -z "$CHANGE_ARG" ]; then
      CHANGE_ARG=$(active_changes)
      [ "$(printf '%s' "$CHANGE_ARG" | grep -c . || true)" = "1" ] \
        || die "pass --change <id> (active changes: $(printf '%s' "$CHANGE_ARG" | tr '\n' ' '))"
    fi
    do_reopen "$CHANGE_ARG"
    if [ -f "$GOAL" ]; then load_goal; refresh_goal; fi
    ;;

  stop)
    # Like `block`, a halt must be recorded even when the recorded target no longer
    # resolves: load_goal would exit non-zero and leave the goal looking ACTIVE.
    [ -f "$GOAL" ] || die "no delivery goal recorded at $GOAL — run: scripts/delivery.sh start <target>"
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
      }' "$GOAL" > "$tmp" && mv "$tmp" "$GOAL"
    fi
    printf 'Goal %s recorded as %s\n' "${TARGET:-?}" "$(goal_field Status)"
    ;;

  block)
    # US-12.2: the delivery loop halts for a human decision. Target, Started, and
    # Notes are preserved, so `start <same target>` resumes the goal as ACTIVE.
    [ -f "$GOAL" ] || die "no delivery goal recorded at $GOAL"
    rm -f "$LOOP_STATE"
    REASON_ARG=$(printf '%s' "${REASON_ARG:-blocked: a Product Manager decision is required}" | tr '\n|' ' /')
    TARGET=$(goal_field Target)
    # A subshell probe: resolve_target exits (via load_specs/die) when SPECS.md is
    # missing, which would skip the in-place fallback below (review O-2).
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
      }' "$GOAL" > "$tmp" && mv "$tmp" "$GOAL"
    fi
    printf 'Goal %s recorded as %s — %s\n' "${TARGET:-?}" "$(goal_field Status)" "$(goal_field Reason)"
    ;;

  *) die "unknown command '$CMD'" 2 ;;
esac
exit 0
