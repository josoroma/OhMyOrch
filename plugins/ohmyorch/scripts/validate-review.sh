#!/usr/bin/env bash
#
# validate-review.sh — OhMyOrch Harness review validator
#
# Implements the US-6.1 contract for review.md, plus the consistency rules that
# gate 5 depends on.
#
# Required structure:
#   Change:        the change reviewed
#   Story:         the selected story
#   Verdict:       pass | changes-requested
#   Blocking:      None | <n> finding(s)      (gate 5 reads this line)
#   Coverage:      <n>/<n> acceptance criteria evaluated
#   OpenSpec verify: the recorded /ohmyorch:opsx-verify outcome
#   ## Findings with per-finding Requirement / Observed / Expected / Remediation
#   ## Acceptance Criteria Evaluated
#
# Consistency rules (a review that contradicts itself is a defect):
#   Verdict: pass               => Blocking: None
#   Blocking: <n>, n > 0        => Verdict: changes-requested
#   every finding needs all four of Requirement / Observed / Expected / Remediation
#
# Read-only. Reports; never edits review.md.
#
# Exit codes:
#   0  all required checks passed (warnings may exist)
#   1  at least one required check failed
#   2  usage error or unreadable input
#
# Dependencies: bash, grep, sed — no Node/Python (NFR-001).

set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"
set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"

REVIEW=""
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
Usage: ohmyorch validate-review [options]

Validates review.md against the US-6.1 contract and its internal consistency.

Options:
  --review <file>   Path to the review (default: review.md)
  --change <id>     Also assert the review names this change
  --story <id>      Also assert the review names this story
  --quiet           Print only warnings and failures
  -h, --help        Show this help.

Exit codes:
  0  all required checks passed
  1  at least one required check failed
  2  usage error or unreadable input

Examples:
  "${OHMYORCH_CODE_ROOT}/scripts/validate-review.sh"
  "${OHMYORCH_CODE_ROOT}/scripts/validate-review.sh" --review openspec/changes/x/review.md --change x --story US-6.1
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --review) [ $# -ge 2 ] || { echo "error: --review needs a value" >&2; exit 2; }; REVIEW="$2"; shift 2 ;;
    --change) [ $# -ge 2 ] || { echo "error: --change needs a value" >&2; exit 2; }; CHANGE="$2"; shift 2 ;;
    --story)  [ $# -ge 2 ] || { echo "error: --story needs a value" >&2; exit 2; }; STORY="$2"; shift 2 ;;
    --quiet)  QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$REVIEW" ] || REVIEW="review.md"

say "OhMyOrch Harness — review validation"
say "=================================="

section "Review — $REVIEW"

if [ ! -f "$REVIEW" ]; then
  fail "review not found at '$REVIEW'"
  note "fix: run /ohmyorch:review-feature <change-id> to produce it"
  printf '\n  %sRESULT: FAIL%s — review missing.\n' "$c_red" "$c_reset"
  exit 1
fi

if [ ! -s "$REVIEW" ]; then
  fail "review is empty"
  note "fix: an empty review is not a review"
  printf '\n  %sRESULT: FAIL%s — review empty.\n' "$c_red" "$c_reset"
  exit 1
fi

# Helper: read the value of a "Key:" line, tolerating a leading markdown bullet.
# Uses awk rather than sed because BSD sed does not support `\?` in a BRE, and
# this script must work on macOS and Linux alike.
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
  ' "$REVIEW"
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
    fail "expected change '$CHANGE' but the review names '${R_CHANGE:-nothing}'"
    note "fix: a review must describe the change it reviews"
  fi
fi

R_STORY=$(field "Story")
if [ -n "$STORY" ]; then
  if [ "$R_STORY" = "$STORY" ]; then
    pass "story matches the expected '$STORY'"
  else
    fail "expected story '$STORY' but the review names '${R_STORY:-nothing}'"
  fi
elif [ -n "$R_STORY" ]; then
  pass "names the story ($R_STORY)"
else
  warn "does not name the story id"
fi

# ---------------------------------------------------------------------------
# Verdict and Blocking — the two lines gate 5 reads
# ---------------------------------------------------------------------------

R_VERDICT=$(field "Verdict")
case "$(printf '%s' "$R_VERDICT" | tr '[:upper:]' '[:lower:]')" in
  pass|passed|approved)
    VERDICT="pass" ;;
  changes-requested|changes_requested|"changes requested"|fail|failed|blocked)
    VERDICT="changes-requested" ;;
  "")
    VERDICT="missing" ;;
  *)
    VERDICT="invalid" ;;
esac

case "$VERDICT" in
  pass)             pass "verdict declares a pass" ;;
  changes-requested) pass "verdict requests changes" ;;
  missing)
    fail "no 'Verdict:' line"
    note "fix: add 'Verdict: pass' or 'Verdict: changes-requested' — gate 5 reads this"
    ;;
  invalid)
    fail "unrecognised verdict '$R_VERDICT'"
    note "allowed: pass, changes-requested"
    ;;
esac

R_BLOCKING=$(field "Blocking")
BLOCKING_COUNT=""
case "$R_BLOCKING" in
  "")
    BLOCKING_STATE="missing" ;;
  [Nn]one*)
    BLOCKING_STATE="none"; BLOCKING_COUNT=0 ;;
  *)
    # Accept "3 finding(s)", "3", "2 blocking".
    BLOCKING_COUNT=$(printf '%s' "$R_BLOCKING" | grep -oE '[0-9]+' | head -1 || true)
    BLOCKING_COUNT=${BLOCKING_COUNT:-}
    if [ -n "$BLOCKING_COUNT" ]; then
      if [ "$BLOCKING_COUNT" -eq 0 ]; then BLOCKING_STATE="none"; else BLOCKING_STATE="some"; fi
    else
      BLOCKING_STATE="unclear"
    fi
    ;;
esac

case "$BLOCKING_STATE" in
  none)    pass "declares no blocking findings" ;;
  some)    pass "declares $BLOCKING_COUNT blocking finding(s)" ;;
  missing)
    fail "no 'Blocking:' line"
    note "fix: add 'Blocking: None' or 'Blocking: <n> finding(s)' — gate 5 reads this"
    ;;
  unclear)
    warn "cannot parse a count from 'Blocking: $R_BLOCKING'"
    note "prefer 'Blocking: None' or 'Blocking: 2 findings'"
    ;;
esac

# ---------------------------------------------------------------------------
# Internal consistency — the checks that catch a self-contradicting review
# ---------------------------------------------------------------------------

if [ "$VERDICT" = "pass" ] && [ "$BLOCKING_STATE" = "some" ]; then
  fail "verdict says pass but $BLOCKING_COUNT blocking finding(s) are declared"
  note "fix: a review with blocking findings cannot pass — use Verdict: changes-requested"
fi

if [ "$VERDICT" = "changes-requested" ] && [ "$BLOCKING_STATE" = "none" ]; then
  fail "verdict requests changes but declares no blocking findings"
  note "fix: name the blocking finding, or change the verdict to pass"
fi

# ---------------------------------------------------------------------------
# Findings schema — US-6.1 requires Requirement/Observed/Expected/Remediation
# ---------------------------------------------------------------------------

FINDING_COUNT=$(grep -cE '^#{2,4}[[:space:]]*(Finding|F-|BLOCK-|FIND-)[A-Za-z0-9-]*' "$REVIEW" 2>/dev/null || true)
FINDING_COUNT=${FINDING_COUNT:-0}

if [ "$FINDING_COUNT" -gt 0 ]; then
  pass "documents $FINDING_COUNT finding(s)"
else
  say "  ${c_dim}--${c_reset}    no individual findings documented"
fi

# Which required sub-fields are present for the findings as a whole?
has_field() { grep -qiE "^[[:space:]]*([-*][[:space:]]*)?$1[[:space:]]*:" "$REVIEW" 2>/dev/null; }

if [ "$FINDING_COUNT" -gt 0 ]; then
  if has_field "Requirement"; then
    pass "findings identify the affected requirement"
  else
    fail "findings do not identify the affected requirement"
    note "fix: each finding needs 'Requirement: <requirement or criterion>'"
  fi

  if has_field "Observed"; then
    pass "findings describe observed behavior"
  else
    fail "findings do not describe observed behavior"
    note "fix: each finding needs 'Observed: <what the code actually does>'"
  fi

  if has_field "Expected"; then
    pass "findings describe expected behavior"
  else
    fail "findings do not describe expected behavior"
    note "fix: each finding needs 'Expected: <what the specification requires>'"
  fi

  if has_field "Remediation"; then
    pass "findings request concrete remediation"
  else
    fail "findings request no concrete remediation"
    note "fix: each finding needs 'Remediation: <the specific change requested>'"
  fi
elif [ "$BLOCKING_STATE" = "some" ]; then
  fail "declares $BLOCKING_COUNT blocking finding(s) but documents none"
  note "fix: every blocking finding needs a section with Requirement/Observed/Expected/Remediation"
fi

# ---------------------------------------------------------------------------
# Coverage — every relevant acceptance criterion must be evaluated
# ---------------------------------------------------------------------------

if grep -qiE '^#{1,4}[[:space:]].*(Acceptance|Criteria)[[:space:]]*(Evaluated|Coverage|Mapping)' "$REVIEW" 2>/dev/null \
   || has_field "Coverage"; then
  pass "documents acceptance criteria coverage"
else
  fail "no acceptance criteria coverage section"
  note "fix: add '## Acceptance Criteria Evaluated' listing each scenario and its result"
  note "US-6.1: the Reviewer must evaluate every relevant acceptance criterion"
fi

# A coverage line with zero scenarios evaluated is not coverage.
R_COVERAGE=$(field "Coverage")
if [ -n "$R_COVERAGE" ]; then
  COV_EVAL=$(printf '%s' "$R_COVERAGE" | grep -oE '^[0-9]+' | head -1 || true)
  COV_EVAL=${COV_EVAL:-}
  COV_TOTAL=$(printf '%s' "$R_COVERAGE" | grep -oE '/[0-9]+' | head -1 | tr -d '/' || true)
  COV_TOTAL=${COV_TOTAL:-}
  if [ -n "$COV_EVAL" ] && [ -n "$COV_TOTAL" ]; then
    if [ "$COV_EVAL" -eq 0 ]; then
      fail "coverage says 0 of $COV_TOTAL criteria evaluated"
      note "fix: a review that evaluated nothing is not a review"
    elif [ "$COV_EVAL" -lt "$COV_TOTAL" ]; then
      warn "coverage is partial: $COV_EVAL of $COV_TOTAL"
      note "state why the remainder were not evaluated, or evaluate them"
    else
      pass "coverage is complete ($COV_EVAL/$COV_TOTAL)"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# OpenSpec verification integration
# ---------------------------------------------------------------------------

if grep -qiE '^[[:space:]]*([-*][[:space:]]*)?OpenSpec verify[[:space:]]*:' "$REVIEW" 2>/dev/null; then
  VERIFY_LINE=$(field "OpenSpec verify")
  if [ -z "$VERIFY_LINE" ]; then
    warn "/ohmyorch:opsx-verify line present but empty"
    note "record the outcome, or state that verification was not run and why"
  else
    pass "records the /ohmyorch:opsx-verify outcome"
  fi
elif grep -qiE 'opsx:verify|openspec verify' "$REVIEW" 2>/dev/null; then
  warn "mentions verification but not in an 'OpenSpec verify:' line"
  note "add 'OpenSpec verify: <outcome>' so the result is greppable"
else
  warn "no record of /ohmyorch:opsx-verify"
  note "US-6.1 task: integrate /ohmyorch:opsx-verify into the review flow and record its outcome"
fi

# ---------------------------------------------------------------------------
# Separation of duties — the Reviewer must not repair
# ---------------------------------------------------------------------------
#
# Matched anywhere in the text, not only at line start: the natural phrasings are
# "I fixed the two things", "also updated the handler", "applied the fix while
# reviewing". An anchored pattern missed all of them.

if grep -qiE '(^|[^a-z])(I|we)[[:space:]]+(have[[:space:]]+)?(fixed|repaired|corrected|patched|updated|changed)[[:space:]]' "$REVIEW" 2>/dev/null; then
  fail "review claims to have fixed the code it reviewed"
  note "US-6.1: the Reviewer must not modify product code — return the finding instead"
elif grep -qiE '(^|[^a-z])(fixed|repaired|patched)[[:space:]]+the[[:space:]]+(code|bug|defect|issue|implementation|handler|logic)' "$REVIEW" 2>/dev/null; then
  fail "review claims to have fixed the code it reviewed"
  note "US-6.1: the Reviewer must not modify product code — return the finding instead"
elif grep -qiE '(^|[^a-z])(applied|made)[[:space:]]+the[[:space:]]+(fix|change|edit)' "$REVIEW" 2>/dev/null; then
  fail "review claims to have applied a fix"
  note "US-6.1: the Reviewer must not modify product code — return the finding instead"
else
  pass "no claim of having repaired the reviewed code"
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
