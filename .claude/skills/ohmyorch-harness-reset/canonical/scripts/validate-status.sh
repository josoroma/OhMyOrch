#!/usr/bin/env bash
#
# validate-status.sh — OhMyOrch Harness status.md validator (US-9.1)
#
# Implements the US-9.1 contract for status.md — the durable workflow state that
# lets a fresh Claude session resume without hidden chat history (NFR-003).
#
# What this validator enforces:
#
#   identity     names the story and change
#   state        State is one of the defined change states
#   gates        all seven gates present, in order, with pass/fail status
#   resume       names the first incomplete gate, or says none
#   blockers     records unresolved blockers explicitly
#   coherence    the Resume line agrees with the Gates table
#   freshness    with --change, agrees with workflow-status.sh right now
#
# The coherence check is the important one: it catches a Resume line that was
# hand-edited to disagree with the table above it, which is exactly how a fresh
# session gets sent to the wrong gate.
#
# The freshness check catches the opposite failure — a status.md that was correct
# when written and is now stale. Stale state is worse than no state, because a
# resuming session trusts it.
#
# This script is READ-ONLY. It reports; it never writes or repairs status.md.
#
# Exit codes:
#   0  all required checks passed (warnings may exist)
#   1  at least one required check failed
#   2  usage error or unreadable input
#
# Dependencies: bash, awk, grep, sed — no Node/Python (NFR-001).

set -uo pipefail

STATUS=""
QUIET=0
CHANGE=""

GATE_ORDER="selection planning plan-handoff implementation review testing acceptance"

# The change-state vocabulary from CLAUDE.md / PRD.md section 12.
CHANGE_STATES="PROJECT_DISCOVERY CODEBASE_ANALYSIS CODEBASE_READY SOURCE_DOCUMENTS PRD_GENERATION PRD_READY SPEC_INGESTION SPECS_READY SELECTED EXPLORING PROPOSED PLANNED IMPLEMENTING REVIEWING CHANGES_REQUESTED TESTING TEST_FAILED ACCEPTED ARCHIVED BLOCKED"

REQUIRED_SECTIONS=(Gates Resume Blockers)
REQUIRED_FIELDS=(Story Change State Owner Updated)

FAILURES=0
WARNINGS=0

c_reset=""; c_red=""; c_yellow=""; c_green=""; c_dim=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'
  c_green=$'\033[32m'; c_dim=$'\033[2m'
fi

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
pass() { say "  ${c_green}PASS${c_reset}  $*"; }
# Warnings and failures print even under --quiet: suppressing a failure hides why
# a run failed.
warn() { WARNINGS=$((WARNINGS + 1)); printf '  %sWARN%s  %s\n' "$c_yellow" "$c_reset" "$*"; }
fail() { FAILURES=$((FAILURES + 1)); printf '  %sFAIL%s  %s\n' "$c_red" "$c_reset" "$*"; }
note() { printf '  %s%s%s\n' "$c_dim" "$*" "$c_reset"; }
section() { say ""; say "$*"; }

usage() {
  cat <<'EOF'
Usage: scripts/validate-status.sh [options]

Validates a status.md against the US-9.1 durable-state contract.

Options:
  --status <file>  Path to status.md (default: openspec/changes/<id>/status.md)
  --change <id>    Change id. Also cross-checks the file against the live gate
                   report, detecting a stale status.md.
  --quiet          Print only warnings and failures
  -h, --help       Show this help.

Exit codes:
  0  all required checks passed (warnings may exist)
  1  at least one required check failed
  2  usage error or unreadable input

Examples:
  scripts/validate-status.sh --change add-ohmyorch-planner
  scripts/validate-status.sh --status openspec/changes/x/status.md --change x

Exit 1 on a stale file does NOT mean the file is malformed: it means the recorded
state no longer matches the repository. Refresh it with scripts/status.sh.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --status) [ $# -ge 2 ] || { echo "error: --status needs a value" >&2; exit 2; }; STATUS="$2"; shift 2 ;;
    --change) [ $# -ge 2 ] || { echo "error: --change needs a value" >&2; exit 2; }; CHANGE="$2"; shift 2 ;;
    --quiet)  QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$STATUS" ] || {
  if [ -n "$CHANGE" ]; then STATUS="openspec/changes/$CHANGE/status.md"
  else STATUS="status.md"; fi
}

strip() { printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }

# field <key> — the Value cell from the "| Field | Value |" table.
field() {
  awk -v want="$1" -F'|' '
    /^[[:space:]]*\|/ {
      k=$2; v=$3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (tolower(k) == tolower(want)) { print v; exit }
    }
  ' "$STATUS" 2>/dev/null
}

in_list() { # in_list <needle> <space-separated list>
  for item in $2; do [ "$item" = "$1" ] && return 0; done
  return 1
}

say "OhMyOrch Harness — status validation"
say "==================================="

section "Status — $STATUS"

if [ ! -f "$STATUS" ]; then
  fail "status file not found at '$STATUS'"
  note "fix: the Product Manager records durable state with scripts/status.sh --change <id>"
  printf '\n  %sRESULT: FAIL%s — status file missing.\n' "$c_red" "$c_reset"
  exit 1
fi

if [ ! -s "$STATUS" ]; then
  fail "status file is empty"
  note "fix: an empty file records no state and cannot resume anything"
  printf '\n  %sRESULT: FAIL%s — status file empty.\n' "$c_red" "$c_reset"
  exit 1
fi

pass "file exists and is non-empty ($(wc -l < "$STATUS" | tr -d ' ') lines)"

# ---------------------------------------------------------------------------
# 1. Required sections
# ---------------------------------------------------------------------------

section "Required sections"

for s in "${REQUIRED_SECTIONS[@]}"; do
  # Any heading level: the writer emits "##", but a hand-authored file may differ
  # and the section's presence is what matters, not its depth.
  if grep -qE "^#+[[:space:]]*$s[[:space:]]*$" "$STATUS" 2>/dev/null; then
    pass "## $s"
  else
    fail "## $s — missing"
    note "fix: every section is required; write 'None.' rather than deleting one"
  fi
done

# ---------------------------------------------------------------------------
# 2. Identity and state
# ---------------------------------------------------------------------------

section "Identity and state"

STORY=$(field Story)
CHANGE_IN_FILE=$(field Change)
STATE=$(field State)
OWNER=$(field "Current owner")
UPDATED=$(field Updated)

if [ -n "$STORY" ]; then
  if printf '%s' "$STORY" | grep -qE '^US-[0-9]+\.[0-9]+$'; then
    pass "Story: $STORY"
  else
    fail "Story '$STORY' is not a story identifier (expected US-<n>.<m>)"
    note "fix: the story id ties this state to SPECS.md (NFR-002)"
  fi
else
  fail "Story — missing"
fi

if [ -n "$CHANGE_IN_FILE" ]; then
  pass "Change: $CHANGE_IN_FILE"
  if [ -n "$CHANGE" ] && [ "$CHANGE_IN_FILE" != "$CHANGE" ]; then
    fail "Change '$CHANGE_IN_FILE' does not match --change '$CHANGE'"
  fi
else
  fail "Change — missing"
fi

if [ -n "$STATE" ]; then
  if in_list "$STATE" "$CHANGE_STATES"; then
    pass "State: $STATE"
  else
    fail "State '$STATE' is not a defined change state"
    note "fix: use the vocabulary in CLAUDE.md; do not invent intermediate states"
  fi
else
  fail "State — missing"
fi

if [ -n "$OWNER" ]; then
  pass "Current owner: $OWNER"
else
  fail "Current owner — missing"
  note "fix: US-9.1 requires the current owner to be recorded"
fi

if [ -n "$UPDATED" ]; then
  pass "Updated: $UPDATED"
else
  warn "Updated — missing (advisory)"
fi

# ---------------------------------------------------------------------------
# 3. Gates table
# ---------------------------------------------------------------------------

section "Gates"

GATE_ROWS_FILE=$(mktemp "${TMPDIR:-/tmp}/harness-status-gates.XXXXXX") || exit 2
trap 'rm -f "$GATE_ROWS_FILE"' EXIT

awk -F'|' '
  /^[[:space:]]*\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
    g=$3; s=$4
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", g)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    if (g != "") print g " " s
  }
' "$STATUS" > "$GATE_ROWS_FILE" 2>/dev/null

GATE_COUNT=$(grep -c . "$GATE_ROWS_FILE" 2>/dev/null || true)
GATE_COUNT=${GATE_COUNT:-0}

if [ "$GATE_COUNT" -eq 7 ]; then
  pass "seven gate rows present"
else
  fail "expected 7 gate rows, found $GATE_COUNT"
  note "fix: refresh with scripts/status.sh; the table is derived, not hand-written"
fi

EXPECTED_IDX=0
FIRST_FAILING=""
while read -r gname gstatus; do
  [ -n "$gname" ] || continue

  EXPECTED=$(printf '%s\n' $GATE_ORDER | sed -n "$((EXPECTED_IDX + 1))p")
  if [ "$gname" != "$EXPECTED" ]; then
    fail "gate row $((EXPECTED_IDX + 1)) is '$gname', expected '$EXPECTED'"
    note "fix: gates are reported in fixed order; do not reorder or omit"
  fi

  case "$gstatus" in
    pass) ;;
    fail) [ -z "$FIRST_FAILING" ] && FIRST_FAILING="$gname" ;;
    *) fail "gate '$gname' has status '$gstatus' (expected pass or fail)" ;;
  esac

  EXPECTED_IDX=$((EXPECTED_IDX + 1))
done < "$GATE_ROWS_FILE"

[ "$FAILURES" -eq 0 ] && pass "all gate statuses are pass or fail"

# ---------------------------------------------------------------------------
# 4. Resume coherence
# ---------------------------------------------------------------------------

section "Resume coherence"

RESUME=$(awk '
  /\|.*First incomplete gate:/ {
    v=$0
    sub(/.*First incomplete gate:[[:space:]]*/, "", v)
    gsub(/^[[:space:]]*/, "", v); gsub(/[[:space:]]*$/, "", v)
    print v; exit
  }
  /^First incomplete gate:/ {
    v=$0
    sub(/^First incomplete gate:[[:space:]]*/, "", v)
    gsub(/^[[:space:]]*/, "", v); gsub(/[[:space:]]*$/, "", v)
    print v; exit
  }
' "$STATUS" 2>/dev/null)

if [ -z "$RESUME" ]; then
  fail "no 'First incomplete gate:' line found"
  note "fix: this line is what a resuming session reads first"
else
  # Strip any trailing parenthetical and backticks with awk. BSD sed's interval
  # expression \{0,1\} is not portable and silently deleted the whole value.
  RESUME_GATE=$(printf '%s' "$RESUME" | awk '{
    v = $0
    sub(/[[:space:]]*\(.*$/, "", v)
    gsub(/`/, "", v)
    sub(/[[:space:]]+$/, "", v)
    print v
  }')

  if [ -z "$FIRST_FAILING" ]; then
    # Every gate passed, so the resume line must say so.
    case "$RESUME" in
      *none*|*None*|*archive-eligible*|*archiveEligible*)
        pass "Resume: $RESUME"
        ;;
      *)
        fail "every gate passed, but Resume says '$RESUME'"
        note "fix: all seven gates pass, so the first incomplete gate is none"
        ;;
    esac
  else
    if [ "$RESUME_GATE" = "$FIRST_FAILING" ]; then
      pass "Resume: $RESUME (matches first failing gate)"
    else
      fail "Resume says '$RESUME_GATE' but the first failing gate is '$FIRST_FAILING'"
      note "fix: coherence between the table and the summary is what a resuming session trusts"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 5. Blockers
# ---------------------------------------------------------------------------

section "Blockers"

BLOCKER_BODY=$(awk '
  /<!-- BEGIN AUTHORED: blockers -->/ { inb=1; next }
  /<!-- END AUTHORED: blockers -->/   { inb=0; next }
  inb { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if ($0 != "") print }
' "$STATUS" 2>/dev/null)

if grep -q 'BEGIN AUTHORED: blockers' "$STATUS" 2>/dev/null \
   && grep -q 'END AUTHORED: blockers' "$STATUS" 2>/dev/null; then
  pass "authored blocker section delimited"
else
  fail "authored blocker section markers missing"
  note "fix: keep 'BEGIN/END AUTHORED: blockers' so refreshes preserve what you wrote"
fi

if printf '%s' "$BLOCKER_BODY" | grep -qE '^## Blockers'; then
  BODY_AFTER=$(printf '%s\n' "$BLOCKER_BODY" | sed '1d' | grep -c . || true)
  BODY_AFTER=${BODY_AFTER:-0}
  if [ "$BODY_AFTER" -eq 0 ]; then
    warn "## Blockers is an empty section"
    note "fix: write 'None.' so a reader can tell 'checked, found nothing' from 'not considered'"
  elif printf '%s' "$BLOCKER_BODY" | grep -qE '^None\.?$'; then
    pass "Blockers: none recorded"
  else
    pass "Blockers: recorded"
  fi
else
  if grep -qE '^#+[[:space:]]*Blockers' "$STATUS" 2>/dev/null; then
    fail "## Blockers exists but is outside the AUTHORED markers"
    note "fix: wrap it so a refresh preserves what you wrote rather than replacing it"
  else
    fail "## Blockers heading missing"
  fi
fi

# ---------------------------------------------------------------------------
# 6. Freshness — does the recorded state still match the repository?
# ---------------------------------------------------------------------------

section "Freshness"

if [ -z "$CHANGE" ]; then
  warn "no --change given; skipped the live comparison"
  note "run with --change <id> to detect a stale status.md"
elif [ ! -x scripts/workflow-status.sh ]; then
  warn "scripts/workflow-status.sh unavailable; skipped the live comparison"
else
  LIVE=$(scripts/workflow-status.sh --change "$CHANGE" --json 2>/dev/null); LIVE_RC=$?
  if [ "$LIVE_RC" -ne 0 ] || [ -z "$LIVE" ]; then
    warn "could not read the live gate report for '$CHANGE'"
  else
    LIVE_FILE=$(mktemp "${TMPDIR:-/tmp}/harness-status-live.XXXXXX") || exit 2
    printf '%s' "$LIVE" | awk '
      /"gate":/ {
        match($0, /"gate": *"[^"]*"/);   g=substr($0, RSTART, RLENGTH)
        sub(/"gate": *"/, "", g); sub(/"$/, "", g)
        match($0, /"status": *"[^"]*"/); s=substr($0, RSTART, RLENGTH)
        sub(/"status": *"/, "", s); sub(/"$/, "", s)
        print g " " s
      }
    ' > "$LIVE_FILE"

    STALE=0
    while read -r gname gstatus; do
      [ -n "$gname" ] || continue
      RECORDED=$(grep "^$gname " "$GATE_ROWS_FILE" 2>/dev/null | awk '{print $2}' | head -1)
      if [ -n "$RECORDED" ] && [ "$RECORDED" != "$gstatus" ]; then
        fail "gate '$gname' recorded as '$RECORDED' but is now '$gstatus'"
        STALE=$((STALE + 1))
      fi
    done < "$LIVE_FILE"

    if [ "$STALE" -eq 0 ]; then
      pass "recorded gate state matches the live report"
    else
      note ""
      note "fix: this file is STALE, not malformed. Refresh it with:"
      note "  scripts/status.sh --change $CHANGE"
    fi
    rm -f "$LIVE_FILE"
  fi
fi

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '  %sRESULT: PASS%s — status.md satisfies the US-9.1 contract' "$c_green" "$c_reset"
  [ "$WARNINGS" -gt 0 ] && printf ' (%s warning(s))' "$WARNINGS"
  printf '.\n'
  exit 0
fi
printf '  %sRESULT: FAIL%s — %s failure(s), %s warning(s).\n' \
  "$c_red" "$c_reset" "$FAILURES" "$WARNINGS"
exit 1
