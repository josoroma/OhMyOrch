#!/usr/bin/env bash
#
# validate-verification.sh — OhMyOrch Harness completion-record validator (US-10.1)
#
# Validates a completion.md produced by scripts/completion-gate.sh --record.
#
# What this enforces:
#
#   sections     the Conditions and Verdict sections exist
#   identity     names the change and the story
#   verdict      Verdict is eligible or not-eligible
#   conditions   all four conditions present, in order, each pass or fail
#   coherence    the Verdict agrees with the conditions table
#   freshness    with --change, the record still matches the live evaluation
#
# Coherence is the check that matters most: a completion record whose Verdict says
# "eligible" over a failing condition is a false certificate, and it is exactly the
# artifact a Product Manager would trust before archiving. The incoherent fixture
# exists to prove it is caught.
#
# Freshness catches the opposite failure — a record that was correct when written
# and no longer matches the repository.
#
# This script is READ-ONLY. It reports; it never writes or repairs a record.
#
# Exit codes:
#   0  all required checks passed (warnings may exist)
#   1  at least one required check failed
#   2  usage error or unreadable input
#
# Dependencies: bash, awk, grep, sed — no Node/Python (NFR-001).

set -uo pipefail

VERIFICATION=""
CHANGE=""
QUIET=0

# The four US-10.1 conditions, in their fixed order.
COND_ORDER="tasks review acceptance openspec-verification"

REQUIRED_SECTIONS=(Conditions Verdict)

FAILURES=0
WARNINGS=0

c_reset=""; c_red=""; c_yellow=""; c_green=""; c_dim=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'
  c_green=$'\033[32m'; c_dim=$'\033[2m'
fi

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
pass() { say "  ${c_green}PASS${c_reset}  $*"; }
# Warnings and failures print even under --quiet: suppressing a failure hides why.
warn() { WARNINGS=$((WARNINGS + 1)); printf '  %sWARN%s  %s\n' "$c_yellow" "$c_reset" "$*"; }
fail() { FAILURES=$((FAILURES + 1)); printf '  %sFAIL%s  %s\n' "$c_red" "$c_reset" "$*"; }
note() { printf '  %s%s%s\n' "$c_dim" "$*" "$c_reset"; }
section() { say ""; say "$*"; }

usage() {
  cat <<'EOF'
Usage: scripts/validate-verification.sh [options]

Validates a completion.md against the US-10.1 completion-record contract.

Options:
  --verification <file>  Path to completion.md
  --change <id>          Change id. Also cross-checks against the live evaluation.
  --quiet                Print only warnings and failures
  -h, --help             Show this help.

Exit codes:
  0  all required checks passed (warnings may exist)
  1  at least one required check failed
  2  usage error or unreadable input

Examples:
  scripts/validate-verification.sh --change add-ohmyorch-planner
  scripts/validate-verification.sh --verification openspec/changes/x/completion.md --change x

Exit 1 on a stale record does NOT mean it is malformed: it means the recorded
verdict no longer matches the repository. Re-evaluate with scripts/completion-gate.sh.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --verification) [ $# -ge 2 ] || { echo "error: --verification needs a value" >&2; exit 2; }; VERIFICATION="$2"; shift 2 ;;
    --change)       [ $# -ge 2 ] || { echo "error: --change needs a value" >&2; exit 2; }; CHANGE="$2"; shift 2 ;;
    --quiet)        QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$VERIFICATION" ] || {
  if [ -n "$CHANGE" ]; then VERIFICATION="openspec/changes/$CHANGE/completion.md"
  else VERIFICATION="completion.md"; fi
}

# field <key> — the Value cell from the identity table.
field() {
  awk -v want="$1" -F'|' '
    /^[[:space:]]*\|/ {
      k=$2; v=$3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (tolower(k) == tolower(want)) { print v; exit }
    }
  ' "$VERIFICATION" 2>/dev/null
}

say "OhMyOrch Harness — completion record validation"
say "=============================================="

section "Record — $VERIFICATION"

if [ ! -f "$VERIFICATION" ]; then
  fail "completion record not found at '$VERIFICATION'"
  note "fix: evaluate and record with scripts/completion-gate.sh --change <id> --record"
  printf '\n  %sRESULT: FAIL%s — record missing.\n' "$c_red" "$c_reset"
  exit 1
fi

if [ ! -s "$VERIFICATION" ]; then
  fail "completion record is empty"
  printf '\n  %sRESULT: FAIL%s — record empty.\n' "$c_red" "$c_reset"
  exit 1
fi

pass "file exists and is non-empty ($(wc -l < "$VERIFICATION" | tr -d ' ') lines)"

# ---------------------------------------------------------------------------
# 1. Required sections
# ---------------------------------------------------------------------------

section "Required sections"

for s in "${REQUIRED_SECTIONS[@]}"; do
  if grep -qE "^#+[[:space:]]*$s[[:space:]]*$" "$VERIFICATION" 2>/dev/null; then
    pass "## $s"
  else
    fail "## $s — missing"
    note "fix: every section is required; write 'None.' rather than deleting one"
  fi
done

# ---------------------------------------------------------------------------
# 2. Identity
# ---------------------------------------------------------------------------

section "Identity"

STORY=$(field Story)
CHANGE_IN_FILE=$(field Change)
VERDICT=$(field Verdict)

if [ -n "$STORY" ] && printf '%s' "$STORY" | grep -qE '^US-[0-9]+\.[0-9]+$'; then
  pass "Story: $STORY"
else
  fail "Story '${STORY:-<missing>}' is not a story identifier (expected US-<n>.<m>)"
fi

if [ -n "$CHANGE_IN_FILE" ]; then
  pass "Change: $CHANGE_IN_FILE"
  if [ -n "$CHANGE" ] && [ "$CHANGE_IN_FILE" != "$CHANGE" ]; then
    fail "Change '$CHANGE_IN_FILE' does not match --change '$CHANGE'"
  fi
else
  fail "Change — missing"
fi

case "$VERDICT" in
  eligible)     pass "Verdict: eligible" ;;
  not-eligible) pass "Verdict: not-eligible" ;;
  "")           fail "Verdict — missing" ;;
  *)            fail "Verdict '$VERDICT' is not eligible or not-eligible" ;;
esac

# ---------------------------------------------------------------------------
# 3. Conditions table
# ---------------------------------------------------------------------------

section "Conditions"

COND_ROWS=$(mktemp "${TMPDIR:-/tmp}/harness-cond.XXXXXX") || exit 2
trap 'rm -f "$COND_ROWS"' EXIT

awk -F'|' '
  /^[[:space:]]*\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
    c=$3; s=$4
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", c)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    if (c != "") print c " " s
  }
' "$VERIFICATION" > "$COND_ROWS" 2>/dev/null

COND_COUNT=$(grep -c . "$COND_ROWS" 2>/dev/null || true)
COND_COUNT=${COND_COUNT:-0}

if [ "$COND_COUNT" -eq 4 ]; then
  pass "four condition rows present"
else
  fail "expected 4 condition rows, found $COND_COUNT"
  note "fix: US-10.1 names four conditions; all four are recorded"
fi

EXPECTED_IDX=0
FIRST_FAILING=""
while read -r cname cstatus; do
  [ -n "$cname" ] || continue

  EXPECTED=$(printf '%s\n' $COND_ORDER | sed -n "$((EXPECTED_IDX + 1))p")
  if [ "$cname" != "$EXPECTED" ]; then
    fail "condition row $((EXPECTED_IDX + 1)) is '$cname', expected '$EXPECTED'"
  fi

  case "$cstatus" in
    pass) ;;
    fail) [ -z "$FIRST_FAILING" ] && FIRST_FAILING="$cname" ;;
    *) fail "condition '$cname' has status '$cstatus' (expected pass or fail)" ;;
  esac

  EXPECTED_IDX=$((EXPECTED_IDX + 1))
done < "$COND_ROWS"

# ---------------------------------------------------------------------------
# 4. Verdict coherence
# ---------------------------------------------------------------------------

section "Verdict coherence"

if [ -z "$FIRST_FAILING" ]; then
  if [ "$VERDICT" = "eligible" ]; then
    pass "Verdict 'eligible' agrees with all conditions passing"
  elif [ "$VERDICT" = "not-eligible" ]; then
    fail "every condition passes, but Verdict says 'not-eligible'"
    note "fix: the record understates the change, or a condition was mis-evaluated"
  fi
  if grep -qiE '\| *Verdict *\|[[:space:]]*not-eligible' "$VERIFICATION" 2>/dev/null; then
    fail "the Verdict section contradicts the conditions table"
  fi
else
  if [ "$VERDICT" = "not-eligible" ]; then
    pass "Verdict 'not-eligible' agrees with a failing condition"
    if grep -qiE '\| *Verdict *\|[[:space:]]*eligible' "$VERIFICATION" 2>/dev/null \
       && ! grep -qiE '\| *Verdict *\|[[:space:]]*not-eligible' "$VERIFICATION" 2>/dev/null; then
      fail "Verdict table claims 'eligible' while condition '$FIRST_FAILING' fails"
    fi
  elif [ "$VERDICT" = "eligible" ]; then
    fail "Verdict 'eligible' while condition '$FIRST_FAILING' fails"
    note "fix: a false completion certificate is the defect this check exists to catch"
  fi

  # The prose verdict must name the condition that blocks.
  if grep -q "$FIRST_FAILING" "$VERIFICATION" 2>/dev/null; then
    pass "the blocking condition is named in the record"
  else
    warn "the record does not name the blocking condition '$FIRST_FAILING'"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Freshness
# ---------------------------------------------------------------------------

section "Freshness"

if [ -z "$CHANGE" ]; then
  warn "no --change given; skipped the live comparison"
  note "run with --change <id> to detect a stale record"
elif [ ! -x scripts/completion-gate.sh ]; then
  warn "scripts/completion-gate.sh unavailable; skipped the live comparison"
else
  LIVE=$(scripts/completion-gate.sh --change "$CHANGE" --json 2>/dev/null); LIVE_RC=$?
  if [ "$LIVE_RC" -ne 0 ] && [ -z "$LIVE" ]; then
    warn "could not read the live evaluation for '$CHANGE'"
  else
    LIVE_ELIGIBLE=$(printf '%s' "$LIVE" \
      | sed -n 's/.*"eligible":[[:space:]]*\(true\).*/\1/p; s/.*"eligible":[[:space:]]*\(false\).*/\1/p' | head -1)

    RECORDED_ELIGIBLE="false"
    [ "$VERDICT" = "eligible" ] && RECORDED_ELIGIBLE="true"

    if [ -z "$LIVE_ELIGIBLE" ]; then
      warn "could not read the live eligibility"
    elif [ "$LIVE_ELIGIBLE" = "$RECORDED_ELIGIBLE" ]; then
      pass "recorded verdict matches the live evaluation"
    else
      fail "recorded verdict '$VERDICT' but the live evaluation says eligible=$LIVE_ELIGIBLE"
      note ""
      note "fix: this record is STALE, not malformed. Re-evaluate with:"
      note "  scripts/completion-gate.sh --change $CHANGE --record"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '  %sRESULT: PASS%s — completion record satisfies the US-10.1 contract' "$c_green" "$c_reset"
  [ "$WARNINGS" -gt 0 ] && printf ' (%s warning(s))' "$WARNINGS"
  printf '.\n'
  exit 0
fi
printf '  %sRESULT: FAIL%s — %s failure(s), %s warning(s).\n' \
  "$c_red" "$c_reset" "$FAILURES" "$WARNINGS"
exit 1
