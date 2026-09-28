#!/usr/bin/env bash
#
# validate-test-report.sh — OhMyOrch Harness test-report validator
#
# Implements the US-7.1 contract for test-report.md, plus the consistency rules
# gate 6 depends on.
#
# Gate 6 previously used a NEGATIVE check ("is there a FAIL row?"), which is
# fail-open: an empty report has no FAIL row, so it passed. This validator makes
# the requirement POSITIVE — the report must show that criteria were evaluated.
#
# Required structure:
#   Change:      the change validated
#   Story:       the story validated
#   Verdict:     pass | fail
#   Coverage:    <n>/<n> acceptance criteria evaluated
#   ## Acceptance Criteria Evaluated   with a Result of PASS or FAIL per row
#   Evidence per criterion (a command, test, or explicit inspection)
#   ## Failures  when any criterion FAILs
#
# Read-only. Reports; never edits test-report.md.
#
# Exit codes:
#   0  all required checks passed (warnings may exist)
#   1  at least one required check failed
#   2  usage error or unreadable input
#
# Dependencies: bash, grep, awk — no Node/Python (NFR-001).

set -uo pipefail

REPORT=""
CHANGE=""
STORY=""
QUIET=0

FAILURES=0
WARNINGS=0

c_reset=""; c_red=""; c_yellow=""; c_green=""; c_dim=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'
  c_green=$'\033[32m'; c_dim=$'\033[2m'
fi

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
pass() { say "  ${c_green}PASS${c_reset}  $*"; }
# Warnings and failures print even under --quiet: suppressing a failure would
# hide the reason a run failed.
warn() { WARNINGS=$((WARNINGS + 1)); printf '  %sWARN%s  %s\n' "$c_yellow" "$c_reset" "$*"; }
fail() { FAILURES=$((FAILURES + 1)); printf '  %sFAIL%s  %s\n' "$c_red" "$c_reset" "$*"; }
note() { printf '  %s%s%s\n' "$c_dim" "$*" "$c_reset"; }
section() { say ""; say "$*"; }

usage() {
  cat <<'EOF'
Usage: scripts/validate-test-report.sh [options]

Validates test-report.md against the US-7.1 contract.

Options:
  --report <file>   Path to the report (default: test-report.md)
  --change <id>     Also assert the report names this change
  --story <id>      Also assert the report names this story
  --quiet           Print only warnings and failures
  -h, --help        Show this help.

Exit codes:
  0  all required checks passed
  1  at least one required check failed
  2  usage error or unreadable input

Examples:
  scripts/validate-test-report.sh
  scripts/validate-test-report.sh --report openspec/changes/x/test-report.md \
    --change x --story US-7.1
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --report) [ $# -ge 2 ] || { echo "error: --report needs a value" >&2; exit 2; }; REPORT="$2"; shift 2 ;;
    --change) [ $# -ge 2 ] || { echo "error: --change needs a value" >&2; exit 2; }; CHANGE="$2"; shift 2 ;;
    --story)  [ $# -ge 2 ] || { echo "error: --story needs a value" >&2; exit 2; }; STORY="$2"; shift 2 ;;
    --quiet)  QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$REPORT" ] || REPORT="test-report.md"

say "OhMyOrch Harness — test report validation"
say "======================================="

section "Report — $REPORT"

if [ ! -f "$REPORT" ]; then
  fail "test report not found at '$REPORT'"
  note "fix: run /ohmyorch-test-feature <change-id> to produce it"
  printf '\n  %sRESULT: FAIL%s — report missing.\n' "$c_red" "$c_reset"
  exit 1
fi

if [ ! -s "$REPORT" ]; then
  fail "test report is empty"
  note "fix: an empty report is not acceptance evidence — and it previously passed gate 6 silently"
  printf '\n  %sRESULT: FAIL%s — report empty.\n' "$c_red" "$c_reset"
  exit 1
fi

# Portable field reader. awk, not sed: BSD sed has no `\?` in a BRE.
field() {
  awk -v key="$1" '
    {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(/^[-*][[:space:]]*/, "", line)
      lk = tolower(key) ":"
      if (index(tolower(line), lk) == 1) {
        sub(/^[^:]*:[[:space:]]*/, "", line)
        sub(/[[:space:]]*$/, "", line)
        print line
        exit
      }
    }
  ' "$REPORT"
}

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

R_CHANGE=$(field "Change")
if [ -n "$R_CHANGE" ]; then
  pass "names the change ($R_CHANGE)"
else
  warn "does not name the change id"
  note "add a 'Change: <change-id>' line"
fi

if [ -n "$CHANGE" ]; then
  if [ "$R_CHANGE" = "$CHANGE" ]; then
    pass "change matches the expected '$CHANGE'"
  else
    fail "expected change '$CHANGE' but the report names '${R_CHANGE:-nothing}'"
  fi
fi

R_STORY=$(field "Story")
if [ -n "$STORY" ]; then
  if [ "$R_STORY" = "$STORY" ]; then
    pass "story matches the expected '$STORY'"
  else
    fail "expected story '$STORY' but the report names '${R_STORY:-nothing}'"
  fi
elif [ -n "$R_STORY" ]; then
  pass "names the story ($R_STORY)"
else
  warn "does not name the story id"
fi

# ---------------------------------------------------------------------------
# Criteria table — the positive evidence requirement
# ---------------------------------------------------------------------------
#
# Count table rows that carry a PASS or FAIL result. This is the core check
# gate 6 was missing: a report with zero evaluated criteria is not evidence,
# however few FAIL strings it contains.

section "Acceptance evidence"

PASS_ROWS=$(grep -cE '\|[[:space:]]*(PASS|Pass|pass)[[:space:]]*\|' "$REPORT" 2>/dev/null || true)
PASS_ROWS=${PASS_ROWS:-0}
FAIL_ROWS=$(grep -cE '\|[[:space:]]*(FAIL|Fail|fail)[[:space:]]*\|' "$REPORT" 2>/dev/null || true)
FAIL_ROWS=${FAIL_ROWS:-0}

# Also accept a "Result: PASS" / "Result: FAIL" per-item shape.
RESULT_LINES_P=$(grep -ciE '^[[:space:]]*([-*][[:space:]]*)?Result[[:space:]]*:[[:space:]]*PASS' "$REPORT" 2>/dev/null || true)
RESULT_LINES_P=${RESULT_LINES_P:-0}
RESULT_LINES_F=$(grep -ciE '^[[:space:]]*([-*][[:space:]]*)?Result[[:space:]]*:[[:space:]]*FAIL' "$REPORT" 2>/dev/null || true)
RESULT_LINES_F=${RESULT_LINES_F:-0}

EVALUATED_COUNT=$((PASS_ROWS + FAIL_ROWS + RESULT_LINES_P + RESULT_LINES_F))

if [ "$EVALUATED_COUNT" -eq 0 ]; then
  fail "lists no evaluated acceptance criterion"
  note "fix: add '## Acceptance Criteria Evaluated' with one row per criterion and its PASS/FAIL"
  note "US-7.1: test-report.md MUST list every evaluated acceptance criterion"
else
  pass "lists $EVALUATED_COUNT evaluated criterion/criteria ($((PASS_ROWS + RESULT_LINES_P)) PASS, $((FAIL_ROWS + RESULT_LINES_F)) FAIL)"
fi

# The section heading itself, so structure is checkable and greppable.
if grep -qiE '^#{1,4}[[:space:]].*Acceptance[[:space:]]+Criteria' "$REPORT" 2>/dev/null; then
  pass "has an acceptance criteria section"
else
  fail "no '## Acceptance Criteria Evaluated' section"
  note "fix: add the section; a report without it cannot be mapped to the story's criteria"
fi

# ---------------------------------------------------------------------------
# Evidence per criterion
# ---------------------------------------------------------------------------
#
# US-7.1 accepts an executable check OR explicit evidence, so an inspection-based
# criterion is legitimate. What is not legitimate is a vague assertion with no
# named check and no stated reasoning.

EVIDENCE_HITS=$(grep -ciE '(ran|executed|command|`[^`]+`|\$ |npm |pytest |make |bash |node |python |inspection|inspected|observed|read )' "$REPORT" 2>/dev/null || true)
EVIDENCE_HITS=${EVIDENCE_HITS:-0}

if [ "$EVIDENCE_HITS" -gt 0 ]; then
  pass "identifies a command, test, or evidence for its results"
else
  fail "identifies no command, test, or evidence"
  note "fix: US-7.1 requires each result to name the command, test, or evidence used"
fi

# Vague-evidence smell: assertions with no check and no reasoning.
if grep -qiE '(looks (fine|good|correct)|seems (fine|ok|correct)|appears correct|should be fine)' "$REPORT" 2>/dev/null; then
  warn "report uses vague assurance language"
  note "replace 'looks fine' with the check performed or the evidence inspected"
fi

# ---------------------------------------------------------------------------
# Verdict and FAIL consistency
# ---------------------------------------------------------------------------

R_VERDICT=$(field "Verdict")
case "$(printf '%s' "$R_VERDICT" | tr '[:upper:]' '[:lower:]')" in
  pass|passed|accepted)         VERDICT="pass" ;;
  fail|failed|rejected)         VERDICT="fail" ;;
  "")                           VERDICT="missing" ;;
  *)                            VERDICT="invalid" ;;
esac

case "$VERDICT" in
  pass)    pass "verdict declares acceptance" ;;
  fail)    pass "verdict declares failure" ;;
  missing)
    # Tolerate a missing verdict only when the report shows a FAIL, since a
    # failing report is not accepted regardless of how it is labelled.
    if [ "$FAIL_ROWS" -gt 0 ] || [ "$RESULT_LINES_F" -gt 0 ]; then
      warn "no 'Verdict:' line"
      note "add 'Verdict: fail' explicitly so the outcome is greppable"
    else
      fail "no 'Verdict:' line"
      note "fix: add 'Verdict: pass' or 'Verdict: fail'"
    fi
    ;;
  invalid)
    fail "unrecognised verdict '$R_VERDICT'"
    note "allowed: pass, fail"
    ;;
esac

TOTAL_FAILS=$((FAIL_ROWS + RESULT_LINES_F))

if [ "$VERDICT" = "pass" ] && [ "$TOTAL_FAILS" -gt 0 ]; then
  fail "verdict says pass but $TOTAL_FAILS criterion/criteria are recorded FAIL"
  note "fix: a report with a failing criterion cannot pass — use Verdict: fail"
fi

if [ "$VERDICT" = "fail" ] && [ "$TOTAL_FAILS" -eq 0 ]; then
  fail "verdict says fail but no criterion is recorded FAIL"
  note "fix: name the failing criterion, or change the verdict to pass"
fi

# On failure, US-7.1 requires the change NOT be accepted and the work returned.
if [ "$TOTAL_FAILS" -gt 0 ]; then
  if grep -qiE '^#{1,4}[[:space:]].*(Failure|Failed)' "$REPORT" 2>/dev/null; then
    pass "documents the failure(s)"
  else
    fail "records FAIL but has no failures section"
    note "fix: add '## Failures' describing the criterion, observed, and expected"
  fi

  if grep -qiE '(return|back)[[:space:]]+to[[:space:]]+the[[:space:]]+Implementer|control[[:space:]]+returns|re-?review' "$REPORT" 2>/dev/null; then
    pass "routes the change back to the Implementer"
  else
    warn "does not state what happens next"
    note "US-7.1: a failed criterion returns control to the Implementer, and any code change must be reviewed again before retesting"
  fi
fi

# ---------------------------------------------------------------------------
# Coverage arithmetic
# ---------------------------------------------------------------------------

R_COVERAGE=$(field "Coverage")
if [ -n "$R_COVERAGE" ]; then
  COV_EVAL=$(printf '%s' "$R_COVERAGE" | grep -oE '^[0-9]+' | head -1 || true)
  COV_EVAL=${COV_EVAL:-}
  COV_TOTAL=$(printf '%s' "$R_COVERAGE" | grep -oE '/[0-9]+' | head -1 | tr -d '/' || true)
  COV_TOTAL=${COV_TOTAL:-}
  if [ -n "$COV_EVAL" ] && [ -n "$COV_TOTAL" ]; then
    if [ "$COV_EVAL" -eq 0 ] && [ "$COV_TOTAL" -gt 0 ]; then
      fail "coverage says 0 of $COV_TOTAL criteria evaluated"
      note "fix: a report that evaluated nothing is not acceptance evidence"
    elif [ "$COV_EVAL" -lt "$COV_TOTAL" ]; then
      warn "coverage is partial: $COV_EVAL of $COV_TOTAL"
      note "state why the remainder were not evaluated, or evaluate them"
    else
      pass "coverage is complete ($COV_EVAL/$COV_TOTAL)"
    fi

    # The declared count should match the rows actually present.
    if [ "$COV_EVAL" -gt 0 ] && [ "$EVALUATED_COUNT" -gt 0 ] && [ "$COV_EVAL" -ne "$EVALUATED_COUNT" ]; then
      warn "declared coverage ($COV_EVAL) does not match the $EVALUATED_COUNT row(s) listed"
      note "fix: the count and the table should agree"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Separation of duties — the Tester must not repair
# ---------------------------------------------------------------------------
#
# Matched anywhere in the text: the natural phrasings are "I fixed the failing
# test", "also updated the handler", "patched it while testing".

if grep -qiE '(^|[^a-z])(I|we)[[:space:]]+(have[[:space:]]+)?(fixed|repaired|corrected|patched|updated|changed)[[:space:]]' "$REPORT" 2>/dev/null; then
  fail "report claims to have fixed the behavior it tested"
  note "US-7.1: the Tester must not repair failed behavior — return the finding instead"
elif grep -qiE '(^|[^a-z])(fixed|repaired|patched)[[:space:]]+the[[:space:]]+(code|bug|defect|issue|implementation|handler|logic|test)' "$REPORT" 2>/dev/null; then
  fail "report claims to have fixed the code it tested"
  note "US-7.1: the Tester must not repair failed behavior — return the finding instead"
else
  pass "no claim of having repaired the tested behavior"
fi

section "Summary"
say "  failures: $FAILURES"
say "  warnings: $WARNINGS"
say ""

if [ "$FAILURES" -gt 0 ]; then
  printf '  %sRESULT: FAIL%s — %s required check(s) failed.\n' "$c_red" "$c_reset" "$FAILURES"
  exit 1
fi

say "  ${c_green}RESULT: PASS${c_reset} — all required checks passed${WARNINGS:+, $WARNINGS warning(s)}."
exit 0
