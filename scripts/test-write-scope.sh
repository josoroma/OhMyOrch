#!/usr/bin/env bash
#
# test-write-scope.sh — regression suite for check-write-scope.sh
#
# Asserts the separation-of-duties matrix (BR-002 / US-5.1). Each case below
# states the role, the path, and whether the write must be allowed or blocked.
#
# Exit codes:
#   0  every case matched its expectation
#   1  at least one case failed
#   2  the guard script is missing
#
# Run: scripts/test-write-scope.sh

set -uo pipefail

GUARD="./scripts/check-write-scope.sh"
CHANGE="openspec/changes/some-change"

if [ ! -x "$GUARD" ]; then
  echo "error: $GUARD not found or not executable" >&2
  exit 2
fi

PASS=0
FAIL=0

c_reset=""; c_red=""; c_green=""; c_dim=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_green=$'\033[32m'; c_dim=$'\033[2m'
fi

# check <expect: allow|block> <role> <path>
check() {
  local expect="$1" role="$2" path="$3" want got
  case "$expect" in
    allow) want=0 ;;
    block) want=2 ;;
    *) echo "internal error: bad expectation '$expect'" >&2; exit 2 ;;
  esac

  "$GUARD" --role "$role" --file "$path" --quiet >/dev/null 2>&1
  got=$?

  if [ "$got" -eq "$want" ]; then
    PASS=$((PASS + 1))
    printf '  %sok%s    %-7s %-15s %s\n' "$c_green" "$c_reset" "$expect" "$role" "$path"
  else
    FAIL=$((FAIL + 1))
    printf '  %sFAIL%s  expected %s (exit %s), got exit %s  — %-15s %s\n' \
      "$c_red" "$c_reset" "$expect" "$want" "$got" "$role" "$path"
  fi
}

echo "OhMyOrch Harness — write-scope separation-of-duties matrix"
echo "======================================================="

echo ""
echo "BR-002: an Implementer must not author its own approval"
check block implementer "$CHANGE/review.md"
check block implementer "$CHANGE/test-report.md"

echo ""
echo "Implementer may write product code and tick tasks"
check allow implementer "src/app.ts"
check allow implementer "lib/util.py"
check allow implementer "tests/app.test.ts"
check allow implementer "$CHANGE/tasks.md"

echo ""
echo "Implementer may not write other roles' artifacts"
check block implementer "$CHANGE/implementation-plan.md"
check block implementer "SPECS.md"
check block implementer "$CHANGE/status.md"
check block implementer "$CHANGE/proposal.md"

echo ""
echo "US-6.1: a Reviewer must not repair the code it evaluates"
check block reviewer "src/app.ts"
check block reviewer "lib/util.py"
check allow reviewer "$CHANGE/review.md"
check block reviewer "$CHANGE/test-report.md"
check block reviewer "$CHANGE/implementation-plan.md"

echo ""
echo "US-7.1: a Tester must not repair failing behavior"
check block tester "src/app.ts"
check allow tester "$CHANGE/test-report.md"
check block tester "$CHANGE/review.md"
check block tester "$CHANGE/tasks.md"

echo ""
echo "US-4.1: a Planner must not modify source code"
check block planner "src/app.ts"
check allow planner "$CHANGE/implementation-plan.md"
check block planner "$CHANGE/review.md"
check block planner "$CHANGE/tasks.md"

echo ""
echo "US-3.1: a Product Manager orchestrates, and owns SPECS/status only"
check block product-manager "src/app.ts"
check allow product-manager "SPECS.md"
check allow product-manager "$CHANGE/status.md"
check block product-manager "$CHANGE/review.md"
check block product-manager "$CHANGE/test-report.md"

echo ""
echo "Harness control surface is not product code"
check block implementer "CLAUDE.md"
check block implementer ".claude/settings.json"
check block implementer "scripts/workflow-status.sh"

echo ""
echo "Absolute paths under the project root normalise correctly"
check block implementer "$PWD/$CHANGE/review.md"
check allow implementer "$PWD/src/app.ts"

echo ""
echo "Hook mode blocks on stdin and fails open on empty input"
if printf '%s' "{\"tool_input\":{\"file_path\":\"$CHANGE/review.md\"}}" \
     | "$GUARD" --role implementer --hook --quiet >/dev/null 2>&1; then
  FAIL=$((FAIL + 1)); printf '  %sFAIL%s  hook mode did not block review.md\n' "$c_red" "$c_reset"
else
  PASS=$((PASS + 1)); printf '  %sok%s    block   hook mode blocked review.md\n' "$c_green" "$c_reset"
fi

if printf '' | "$GUARD" --role implementer --hook --quiet >/dev/null 2>&1; then
  PASS=$((PASS + 1)); printf '  %sok%s    allow   hook mode fails open on empty stdin\n' "$c_green" "$c_reset"
else
  FAIL=$((FAIL + 1)); printf '  %sFAIL%s  hook mode blocked on empty stdin\n' "$c_red" "$c_reset"
fi

if printf '%s' '{"tool_input":{"file_path":"src/app.ts"}}' \
     | "$GUARD" --role implementer --hook --quiet >/dev/null 2>&1; then
  PASS=$((PASS + 1)); printf '  %sok%s    allow   hook mode allowed product code\n' "$c_green" "$c_reset"
else
  FAIL=$((FAIL + 1)); printf '  %sFAIL%s  hook mode blocked product code\n' "$c_red" "$c_reset"
fi

echo ""
echo "======================================================="
printf '  passed: %s\n' "$PASS"
printf '  failed: %s\n' "$FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  printf '  %sRESULT: FAIL%s — %s case(s) mismatched.\n' "$c_red" "$c_reset" "$FAIL"
  exit 1
fi

printf '  %sRESULT: PASS%s — separation of duties holds across all roles.\n' "$c_green" "$c_reset"
exit 0
