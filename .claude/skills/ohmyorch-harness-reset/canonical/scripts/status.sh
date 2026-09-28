#!/usr/bin/env bash
#
# status.sh — OhMyOrch Harness durable workflow state writer (US-9.1)
#
# Writes openspec/changes/<change>/status.md: the recorded state, current owner,
# and unresolved blockers that let a fresh Claude session resume from the correct
# gate without hidden chat history (NFR-003).
#
# Design rule — derived versus authored:
#
#   The Gates table and the Resume line are DERIVED from workflow-status.sh and
#   rewritten on every refresh. They are never hand-edited, because a hand-edited
#   gate table is a second source of truth that can silently disagree with the
#   gate reporter.
#
#   The Blockers section is AUTHORED by the Product Manager. It sits between
#   "BEGIN/END AUTHORED: blockers" markers and is preserved verbatim across
#   refreshes, so recording progress never destroys a human decision.
#
# This script only ever writes status.md. It never advances a gate, never edits
# product code, and never touches SPECS.md.
#
# Usage:
#   scripts/status.sh --change <id>              refresh status.md
#   scripts/status.sh --change <id> --dry-run    print it, write nothing
#   scripts/status.sh --change <id> --blocker "the CI runner is unavailable"
#   scripts/status.sh --change <id> --clear-blockers
#   scripts/status.sh --resume [--change <id>]   report where to resume
#
# Exit codes:
#   0  status written (or reported, for --resume / --dry-run)
#   1  no active change, or the change does not exist
#   2  usage error
#
# Dependencies: bash, awk, grep, sed — no Node/Python (NFR-001).

set -uo pipefail

CHANGE=""
DRY_RUN=0
RESUME_ONLY=0
QUIET=0
BLOCKERS_TO_ADD=""
CLEAR_BLOCKERS=0

c_reset=""; c_red=""; c_yellow=""; c_green=""; c_dim=""; c_bold=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'
  c_green=$'\033[32m'; c_dim=$'\033[2m'; c_bold=$'\033[1m'
fi

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: scripts/status.sh --change <id> [options]

Records durable workflow state for one OpenSpec change (US-9.1).

Options:
  --change <id>       Change id. Required unless exactly one change is active.
  --resume            Report where to resume. Writes nothing.
  --blocker <text>    Add an unresolved blocker (repeatable).
  --clear-blockers    Replace authored blockers with "None."
  --dry-run           Print the result; write nothing.
  --quiet             Suppress informational output.
  -h, --help          Show this help.

Exit codes:
  0  status written or reported
  1  no active change, or the change does not exist
  2  usage error

Examples:
  scripts/status.sh --change add-ohmyorch-planner
  scripts/status.sh --change add-ohmyorch-planner --blocker "waiting on CI runner"
  scripts/status.sh --resume
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --change) [ $# -ge 2 ] || { echo "error: --change needs a value" >&2; exit 2; }; CHANGE="$2"; shift 2 ;;
    --resume) RESUME_ONLY=1; shift ;;
    --blocker) [ $# -ge 2 ] || { echo "error: --blocker needs a value" >&2; exit 2; }
               BLOCKERS_TO_ADD="${BLOCKERS_TO_ADD}${BLOCKERS_TO_ADD:+
}$2"; shift 2 ;;
    --clear-blockers) CLEAR_BLOCKERS=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --quiet)   QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Locate the change
# ---------------------------------------------------------------------------

if [ -z "$CHANGE" ]; then
  CHANGE=$(find openspec/changes -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null \
    | sed 's|.*/||' | sort | head -1)
  COUNT=$(find openspec/changes -maxdepth 1 -mindepth 1 -type d -not -name archive 2>/dev/null \
    | grep -c . || true)
  COUNT=${COUNT:-0}
  if [ "$COUNT" -gt 1 ]; then
    echo "error: $COUNT active changes; pass --change <id>" >&2
    exit 1
  fi
fi

[ -n "$CHANGE" ] || { echo "error: no active change found" >&2; exit 1; }

CDIR="openspec/changes/$CHANGE"
if [ ! -d "$CDIR" ]; then
  # A resuming session asking about an archived change needs "done", not an error.
  # `openspec archive` names the directory `<YYYY-MM-DD>-<change>`.
  ARCHIVED=$(find openspec/changes/archive -maxdepth 1 -mindepth 1 -type d \
    \( -name "$CHANGE" -o -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-$CHANGE" \) \
    2>/dev/null | sort | tail -1)
  if [ -n "$ARCHIVED" ] && [ "$RESUME_ONLY" -eq 1 ]; then
    echo "change '$CHANGE' is ARCHIVED ($ARCHIVED) — nothing to resume."
    exit 0
  fi
  if [ -n "$ARCHIVED" ]; then
    echo "error: change '$CHANGE' is archived at $ARCHIVED; its status.md is final" >&2
    exit 1
  fi
  echo "error: change '$CHANGE' does not exist at $CDIR" >&2
  exit 1
fi

STATUS="$CDIR/status.md"

# ---------------------------------------------------------------------------
# Derive the gate state. workflow-status.sh owns this; we never recompute it.
# ---------------------------------------------------------------------------

if [ -x scripts/workflow-status.sh ]; then
  LIVE=$(scripts/workflow-status.sh --change "$CHANGE" --json 2>/dev/null) || LIVE=""
else
  LIVE=""
fi

if [ -z "$LIVE" ]; then
  echo "error: cannot read gate state; scripts/workflow-status.sh is required" >&2
  exit 1
fi

FIRST_INCOMPLETE=$(printf '%s' "$LIVE" \
  | sed -n 's/.*"firstIncompleteGate":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

GATE_NAMES=(selection planning plan-handoff implementation review testing acceptance)
GATE_OWNERS=(ohmyorch-product-manager ohmyorch-planner ohmyorch-planner ohmyorch-implementer ohmyorch-reviewer ohmyorch-tester ohmyorch-product-manager)

# workflow-status.sh --json emits exactly one gate object per line, so each field
# is extracted from a single line. Do NOT split on commas first: that separates
# "gate" from "status" onto different lines and every lookup silently misses.
gate_field() { # gate_field <gate-name> <field>
  printf '%s' "$LIVE" | awk -v want="$1" -v fld="$2" '
    index($0, "\"gate\":") && index($0, "\"" fld "\":") && index($0, "{") {
      g=$0
      sub(/.*"gate":[[:space:]]*"/, "", g); sub(/".*/, "", g)
      if (g != want) next
      v=$0
      sub(".*\"" fld "\":[[:space:]]*\"", "", v)
      sub(/".*/, "", v)
      print v; exit
    }
  '
}

gate_status() { gate_field "$1" status; }
gate_detail() { gate_field "$1" detail; }

# ---------------------------------------------------------------------------
# --resume: report, write nothing
# ---------------------------------------------------------------------------

if [ "$RESUME_ONLY" -eq 1 ]; then
  if [ "$QUIET" -eq 0 ]; then
    printf '%sResume report%s — change %s%s%s\n' "$c_bold" "$c_reset" "$c_bold" "$CHANGE" "$c_reset"
    printf '==============================\n\n'
  fi

  for i in "${!GATE_NAMES[@]}"; do
    g="${GATE_NAMES[$i]}"
    s=$(gate_status "$g")
    case "$s" in
      pass)
        printf '  %sPASS%s  %-16s %s\n' "$c_green" "$c_reset" "$g" "$(gate_detail "$g")" ;;
      *)
        printf '  %s----%s  %-16s %s\n' "$c_red" "$c_reset" "$g" "$(gate_detail "$g")" ;;
    esac
  done

  printf '\n'
  if [ -z "$FIRST_INCOMPLETE" ]; then
    printf '  %sAll gates passed — archive-eligible%s\n' "$c_green" "$c_reset"
    printf '  Next owner:            ohmyorch-product-manager\n'
  else
    printf '  First incomplete gate: %s%s%s\n' "$c_yellow" "$FIRST_INCOMPLETE" "$c_reset"
    for i in "${!GATE_NAMES[@]}"; do
      if [ "${GATE_NAMES[$i]}" = "$FIRST_INCOMPLETE" ]; then
        printf '  Next owner:            %s\n' "${GATE_OWNERS[$i]}"
      fi
    done
  fi

  # A recorded blocker is the reason a gate may be stuck for a non-technical
  # cause, so surface it here rather than hiding it in the file.
  if [ -f "$STATUS" ]; then
    B=$(awk '
      /<!-- BEGIN AUTHORED: blockers -->/ { inb=1; next }
      /<!-- END AUTHORED: blockers -->/   { inb=0; next }
      inb { print }
    ' "$STATUS" | sed '1d' | grep -v '^[[:space:]]*$' | grep -vE '^None\.?$' || true)
    if [ -n "$B" ]; then
      printf '\n  %sRecorded blocker(s):%s\n' "$c_yellow" "$c_reset"
      printf '%s\n' "$B" | sed 's/^/    /'
    fi
  fi

  printf '\n  %sRead-only. status.md was not written.%s\n' "$c_dim" "$c_reset"
  exit 0
fi

# ---------------------------------------------------------------------------
# Build the file
# ---------------------------------------------------------------------------

# Extract the story id from a DESIGNATING context, never from a bare mention.
#
# Two failure modes are avoided here:
#
#   1. An em-dash ("—") is three bytes in UTF-8 and BSD awk evaluates a bracket
#      expression byte-by-byte, so a class like [—-] becomes a byte RANGE that
#      matches far more than intended. An identifier is therefore extracted with
#      grep -oE and never with a multi-byte character class.
#
#   2. status.md is DERIVED state. Its own header comment names the story that
#      implements this script ("US-9.1"), so scanning the whole file finds that
#      mention rather than the change's story. The story is therefore read only
#      from a line that designates it — a "Story:" field or a "| Story |" row.
story_designated() { # story_designated <file>
  [ -f "$1" ] || return 1
  { grep -oE '^[[:space:]]*Story:[[:space:]]*US-[0-9]+\.[0-9]+' "$1" 2>/dev/null \
      | grep -oE 'US-[0-9]+\.[0-9]+'
    grep -oE '^[[:space:]]*\|[[:space:]]*Story[[:space:]]*\|[[:space:]]*US-[0-9]+\.[0-9]+' "$1" 2>/dev/null \
      | grep -oE 'US-[0-9]+\.[0-9]+'
  } | head -1
}

# Authoritative order: the plan, then the proposal, then status.md's own table.
# status.md is last because it is generated from these.
STORY=$(story_designated "$CDIR/implementation-plan.md")
[ -n "$STORY" ] || STORY=$(story_designated "$CDIR/proposal.md")
[ -n "$STORY" ] || STORY=$(story_designated "$STATUS")
[ -n "$STORY" ] || STORY="US-<n>.<m>"

# The story's state in SPECS.md is authoritative for the workflow state label.
# Product documents may live at the repository root or under docs/.
SPECS_STATE=""
SPECS_DOC="SPECS.md"
[ -f docs/SPECS.md ] && SPECS_DOC="docs/SPECS.md"
if [ -f "$SPECS_DOC" ]; then
  SPECS_STATE=$(awk -v id="$STORY" '
    $0 ~ "^### " id ":" { found=1; next }
    found && /^Status:/ { v=$0; sub(/^Status:[[:space:]]*/, "", v); gsub(/[[:space:]]+$/, "", v); print v; exit }
    found && /^### / { exit }
  ' "$SPECS_DOC" 2>/dev/null)
fi

# Map story status + gate position to a defined change state. Only the documented
# vocabulary is used; an unmappable position is BLOCKED, per the rules.
if [ -n "$FIRST_INCOMPLETE" ]; then
  case "$FIRST_INCOMPLETE" in
    selection)      STATE="SELECTED" ;;
    planning)       STATE="PROPOSED" ;;
    plan-handoff)   STATE="PLANNED" ;;
    implementation) STATE="IMPLEMENTING" ;;
    review)         STATE="REVIEWING" ;;
    testing)        STATE="TESTING" ;;
    acceptance)     STATE="CHANGES_REQUESTED" ;;
    *)              STATE="BLOCKED" ;;
  esac
else
  STATE="ACCEPTED"
fi

CURRENT_OWNER="ohmyorch-product-manager"
for i in "${!GATE_NAMES[@]}"; do
  [ "${GATE_NAMES[$i]}" = "$FIRST_INCOMPLETE" ] && CURRENT_OWNER="${GATE_OWNERS[$i]}"
done
[ -z "$FIRST_INCOMPLETE" ] && CURRENT_OWNER="ohmyorch-product-manager"

# Preserve authored blockers across a refresh.
BLOCKERS_BODY="None."
if [ "$CLEAR_BLOCKERS" -eq 0 ] && [ -f "$STATUS" ]; then
  PRESERVED=$(awk '
    /<!-- BEGIN AUTHORED: blockers -->/ { inb=1; next }
    /<!-- END AUTHORED: blockers -->/   { inb=0; next }
    inb { print }
  ' "$STATUS" 2>/dev/null | sed '1d' | grep -v '^[[:space:]]*$' || true)
  [ -n "$PRESERVED" ] && BLOCKERS_BODY="$PRESERVED"
fi

if [ -n "$BLOCKERS_TO_ADD" ]; then
  [ "$BLOCKERS_BODY" = "None." ] && BLOCKERS_BODY=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    BLOCKERS_BODY="${BLOCKERS_BODY}${BLOCKERS_BODY:+
}- $line"
  done <<EOF
$BLOCKERS_TO_ADD
EOF
  [ -n "$BLOCKERS_BODY" ] || BLOCKERS_BODY="None."
fi

TODAY=$(date +%Y-%m-%d)

emit() {
  printf '# Change Status — %s\n\n' "$CHANGE"
  printf '<!--\nDurable workflow state for one active OpenSpec change (US-9.1).\n\n'
  printf 'Written by scripts/status.sh. The gates table is DERIVED from\n'
  printf 'scripts/workflow-status.sh and must not be hand-edited — refresh it instead.\n'
  printf 'The Blockers section between the AUTHORED markers is hand-written by the\n'
  printf 'Product Manager and is preserved verbatim across refreshes.\n\n'
  printf 'Validate before relying on it:\n'
  printf '  scripts/validate-status.sh --status %s --change %s\n-->\n\n' "$STATUS" "$CHANGE"

  printf '| Field | Value |\n|---|---|\n'
  printf '| Story | %s |\n' "$STORY"
  printf '| Change | %s |\n' "$CHANGE"
  printf '| State | %s |\n' "$STATE"
  printf '| Current owner | %s |\n' "$CURRENT_OWNER"
  printf '| Updated | %s |\n' "$TODAY"
  printf '| Derived from | `scripts/workflow-status.sh` |\n'

  [ -n "$SPECS_STATE" ] && printf '| SPECS status | %s |\n' "$SPECS_STATE"

  printf '\n## Gates\n\n'
  printf '| # | Gate | Status | Detail | Owner |\n|---|---|---|---|---|\n'
  for i in "${!GATE_NAMES[@]}"; do
    g="${GATE_NAMES[$i]}"
    s=$(gate_status "$g"); s=${s:-fail}
    d=$(gate_detail "$g"); d=${d:-unknown}
    printf '| %s | %s | %s | %s | %s |\n' \
      "$((i + 1))" "$g" "$s" "$d" "${GATE_OWNERS[$i]}"
  done

  printf '\n## Resume\n\n'
  if [ -z "$FIRST_INCOMPLETE" ]; then
    printf 'First incomplete gate: none (archive-eligible)\n'
  else
    printf 'First incomplete gate: %s\n' "$FIRST_INCOMPLETE"
  fi
  printf 'Next owner: %s\n' "$CURRENT_OWNER"

  printf '\n<!-- BEGIN AUTHORED: blockers -->\n## Blockers\n\n%s\n<!-- END AUTHORED: blockers -->\n' \
    "$BLOCKERS_BODY"
}

if [ "$DRY_RUN" -eq 1 ]; then
  emit
  printf '\n%s(dry run — nothing written)%s\n' "$c_dim" "$c_reset" >&2
  exit 0
fi

emit > "$STATUS"

say "Wrote $STATUS"
say ""
say "  State:          $STATE"
say "  Current owner:  $CURRENT_OWNER"
if [ -z "$FIRST_INCOMPLETE" ]; then
  say "  Resume:         all gates passed — archive-eligible"
else
  say "  Resume:         $FIRST_INCOMPLETE"
fi
say ""
say "  ${c_dim}Gates are derived from workflow-status.sh. Blockers are preserved.${c_reset}"

exit 0
