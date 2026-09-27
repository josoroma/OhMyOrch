#!/usr/bin/env bash
#
# validate-implementation-plan.sh — OhMyOrch Harness Planner-handoff validator
#
# Implements the US-4.1 contract for implementation-plan.md:
#
#   identity        identifies the selected story
#   artifacts       references the relevant OpenSpec artifacts
#   mapping         maps tasks to acceptance criteria
#   scope           identifies likely affected files
#   tests           states the expected tests / verification approach
#   risks           records dependencies and risks
#
# This script is READ-ONLY. It reports; it never writes or repairs a plan.
#
# Exit codes:
#   0  all required checks passed (warnings may exist)
#   1  at least one required check failed
#   2  usage error or unreadable input
#
# Dependencies: bash, awk, grep, sed — no Node/Python (NFR-001).

set -uo pipefail

PLAN=""
QUIET=0
STORY=""
CHANGE=""

# Sections required for a usable Planner handoff.
REQUIRED_SECTIONS=(
  "Selected Story"
  "OpenSpec Artifacts"
  "Task to Acceptance Mapping"
  "Affected Files"
  "Test Strategy"
)

# Expected but not always applicable; absence warns rather than fails.
ADVISORY_SECTIONS=(
  "Dependencies"
  "Risks"
  "Open Questions"
  "Implementation Order"
)

FAILURES=0
WARNINGS=0

c_reset=""; c_red=""; c_yellow=""; c_green=""; c_dim=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'
  c_green=$'\033[32m'; c_dim=$'\033[2m'
fi

say()  { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
pass() { say "  ${c_green}PASS${c_reset}  $*"; }
# Warnings, failures and their guidance print even under --quiet: suppressing a
# failure would hide the reason a run failed.
warn() { WARNINGS=$((WARNINGS + 1)); printf '  %sWARN%s  %s\n' "$c_yellow" "$c_reset" "$*"; }
fail() { FAILURES=$((FAILURES + 1)); printf '  %sFAIL%s  %s\n' "$c_red" "$c_reset" "$*"; }
note() { printf '  %s%s%s\n' "$c_dim" "$*" "$c_reset"; }
section() { say ""; say "$*"; }

usage() {
  cat <<'EOF'
Usage: scripts/validate-implementation-plan.sh [options]

Validates an implementation-plan.md against the US-4.1 Planner-handoff contract.

Options:
  --plan <file>    Path to the plan (default: implementation-plan.md)
  --story <id>     Also assert the plan identifies this story, e.g. US-2.3
  --change <id>    Also assert the plan names this OpenSpec change id
  --quiet          Print only warnings and failures
  -h, --help       Show this help.

Exit codes:
  0  all required checks passed
  1  at least one required check failed
  2  usage error or unreadable input

Examples:
  scripts/validate-implementation-plan.sh
  scripts/validate-implementation-plan.sh --plan openspec/changes/x/implementation-plan.md
  scripts/validate-implementation-plan.sh --story US-4.1 --change add-planner
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --plan)   [ $# -ge 2 ] || { echo "error: --plan needs a value" >&2; exit 2; }; PLAN="$2"; shift 2 ;;
    --story)  [ $# -ge 2 ] || { echo "error: --story needs a value" >&2; exit 2; }; STORY="$2"; shift 2 ;;
    --change) [ $# -ge 2 ] || { echo "error: --change needs a value" >&2; exit 2; }; CHANGE="$2"; shift 2 ;;
    --quiet)  QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$PLAN" ] || PLAN="implementation-plan.md"

say "OhMyOrch Harness — implementation plan validation"
say "==============================================="

section "Plan — $PLAN"

if [ ! -f "$PLAN" ]; then
  fail "plan not found at '$PLAN'"
  note "fix: the Planner must produce implementation-plan.md for the active change"
  printf '\n  %sRESULT: FAIL%s — plan missing.\n' "$c_red" "$c_reset"
  exit 1
fi

if [ ! -s "$PLAN" ]; then
  fail "plan is empty"
  note "fix: an empty plan is not a Planner handoff"
  printf '\n  %sRESULT: FAIL%s — plan empty.\n' "$c_red" "$c_reset"
  exit 1
fi

# ---------------------------------------------------------------------------
# Identity — the selected story
# ---------------------------------------------------------------------------

PLAN_STORY=$(grep -oE '^[[:space:]]*[-*]?[[:space:]]*Story:[[:space:]]*US-[0-9]+\.[0-9]+' "$PLAN" 2>/dev/null \
  | head -1 | grep -oE 'US-[0-9]+\.[0-9]+')
if [ -z "$PLAN_STORY" ]; then
  # Accept a bare story id appearing in a "Selected Story" heading context.
  PLAN_STORY=$(grep -oE '^#[#]*[[:space:]]*Selected Story[[:space:]]*:?[[:space:]]*US-[0-9]+\.[0-9]+' "$PLAN" 2>/dev/null \
    | head -1 | grep -oE 'US-[0-9]+\.[0-9]+')
fi

if [ -n "$PLAN_STORY" ]; then
  pass "identifies the selected story ($PLAN_STORY)"
else
  fail "does not identify the selected story"
  note "fix: add a 'Story: US-N.M' line naming the selected story"
fi

if [ -n "$STORY" ]; then
  if [ "$PLAN_STORY" = "$STORY" ]; then
    pass "story matches the expected '$STORY'"
  elif [ -z "$PLAN_STORY" ]; then
    fail "expected story '$STORY' but the plan names no story"
  else
    fail "plan names '$PLAN_STORY' but '$STORY' was expected"
    note "fix: the plan must describe the change's own story, not another story"
  fi
fi

# ---------------------------------------------------------------------------
# Identity — the OpenSpec change
# ---------------------------------------------------------------------------

PLAN_CHANGE=$(grep -oE '^[[:space:]]*[-*]?[[:space:]]*Change:[[:space:]]*[A-Za-z0-9._-]+' "$PLAN" 2>/dev/null \
  | head -1 | sed 's/.*Change:[[:space:]]*//')
if [ -n "$PLAN_CHANGE" ]; then
  pass "names the OpenSpec change ($PLAN_CHANGE)"
else
  warn "does not name the OpenSpec change id"
  note "add a 'Change: <change-id>' line so the handoff is unambiguously scoped"
fi

if [ -n "$CHANGE" ]; then
  if [ "$PLAN_CHANGE" = "$CHANGE" ]; then
    pass "change matches the expected '$CHANGE'"
  else
    fail "expected change '$CHANGE' but the plan names '${PLAN_CHANGE:-nothing}'"
  fi
fi

# ---------------------------------------------------------------------------
# Required sections
# ---------------------------------------------------------------------------

missing_required=0
for s in "${REQUIRED_SECTIONS[@]}"; do
  if grep -qiE "^#{1,4}[[:space:]]+${s}[[:space:]]*$" "$PLAN"; then
    pass "has required section: $s"
  else
    fail "missing required section: $s"
    missing_required=$((missing_required + 1))
  fi
done
[ "$missing_required" -gt 0 ] && note "fix: add the missing sections listed above"

# ---------------------------------------------------------------------------
# OpenSpec artifact references
# ---------------------------------------------------------------------------

if grep -qiE '(proposal\.md|tasks\.md|design\.md|specs/)' "$PLAN"; then
  pass "references OpenSpec artifacts"
else
  fail "references no OpenSpec artifact"
  note "fix: cite proposal.md, specs/, design.md, or tasks.md so the plan is traceable"
fi

# ---------------------------------------------------------------------------
# Task to acceptance mapping — needs at least one acceptance-shaped reference
# ---------------------------------------------------------------------------

AC_REFS=$(grep -coE 'Scenario:|Given |When |Then |AC-[0-9]+' "$PLAN" 2>/dev/null || true)
AC_REFS=${AC_REFS:-0}
if [ "$AC_REFS" -gt 0 ]; then
  pass "maps tasks to acceptance criteria ($AC_REFS acceptance reference(s))"
else
  fail "maps no task to an acceptance criterion"
  note "fix: map each task to the acceptance scenario it satisfies"
fi

# ---------------------------------------------------------------------------
# Scope — affected files
# ---------------------------------------------------------------------------

# A path-like token: contains a slash, or a filename with a known-ish extension.
FILE_REFS=$(grep -coE '([A-Za-z0-9_.-]+/)+[A-Za-z0-9_.*-]+|[A-Za-z0-9_-]+\.(md|sh|json|ya?ml|ts|js|py|go|rs|java|rb|tf|bicep|cs|php|ex|sql)' "$PLAN" 2>/dev/null || true)
FILE_REFS=${FILE_REFS:-0}
if [ "$FILE_REFS" -gt 0 ]; then
  pass "identifies likely affected files ($FILE_REFS path-like reference(s))"
else
  fail "identifies no affected file or module"
  note "fix: list the files or modules the change is expected to touch"
fi

# A plan that claims files without qualifying uncertainty is a smell, not a failure.
if grep -qiE 'exact|definitiv|will certainly|confirmed to be' "$PLAN"; then
  warn "plan uses definite language about file scope"
  note "repository evidence supports 'likely' scope, not certainty — see US-4.1"
fi

# ---------------------------------------------------------------------------
# Test strategy
# ---------------------------------------------------------------------------

if grep -qiE '(test|verification|check|validate)' "$PLAN"; then
  pass "states a test or verification approach"
else
  fail "states no test or verification approach"
  note "fix: describe the expected tests or checks for this change"
fi

# ---------------------------------------------------------------------------
# Advisory sections
# ---------------------------------------------------------------------------

missing_advisory=""
for s in "${ADVISORY_SECTIONS[@]}"; do
  grep -qiE "^#{1,4}[[:space:]]+${s}[[:space:]]*$" "$PLAN" || missing_advisory="${missing_advisory:+$missing_advisory, }$s"
done
if [ -n "$missing_advisory" ]; then
  warn "no section for: $missing_advisory"
  note "these are expected unless genuinely not applicable"
else
  pass "all advisory sections present"
fi

# ---------------------------------------------------------------------------
# Scope boundary — the Planner must not claim to have modified product code
# ---------------------------------------------------------------------------

if grep -qiE '^[[:space:]]*(-|\*)?[[:space:]]*(Modified|Changed|Implemented)[[:space:]]' "$PLAN"; then
  warn "plan uses 'Modified/Changed/Implemented' language"
  note "the Planner explores and plans; it does not modify product code (US-4.1)"
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
