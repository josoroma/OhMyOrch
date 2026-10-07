#!/usr/bin/env bash
#
# check-scope.sh — OhMyOrch Harness scope-expansion checker
#
# Implements the US-5.1 scope-expansion scenario: an Implementer must not
# silently fold unrelated changes into the active change. It reports what a diff
# touched that the plan did not predict.
#
# It REPORTS; it never reverts, stages, or edits anything. Unpredicted changes
# are not automatically defects — the Implementer may legitimately have learned
# something — but they must be visible and accounted for.
#
# Distinct from `check-write-scope.sh`, which enforces role boundaries (BR-002).
# This checks change scope: one change's diff versus its own plan.
#
# Usage:
#   check-scope.sh --plan <implementation-plan.md> [--diff <file>]
#   git diff --name-only | check-scope.sh --plan <plan>
#
# Exit codes:
#   0  every changed file was predicted by the plan
#   1  at least one changed file was not predicted (report, not an error)
#   2  usage error or unreadable plan
#
# Dependencies: bash, grep, sed, sort, comm — no Node/Python (NFR-001).

set -uo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"
set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"

PLAN=""
DIFF_FILE=""
BASE=""
QUIET=0

c_reset=""; c_red=""; c_yellow=""; c_green=""; c_dim=""
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'
  c_green=$'\033[32m'; c_dim=$'\033[2m'
fi

usage() {
  cat <<'EOF'
Usage: check-scope.sh --plan <implementation-plan.md> [options]

Reports changed files that the implementation plan did not predict.

Options:
  --plan <file>   Path to the change's implementation-plan.md (required)
  --diff <file>   Read a diff listing instead of calling git. Accepts the output
                  of `git diff --name-only`. Use when the diff is already captured.
  --base <rev>    Diff against this revision (default: HEAD, plus untracked files)
  --quiet         Print only unpredicted files
  -h, --help      Show this help

Exit codes:
  0  every changed file was predicted
  1  at least one changed file was not predicted
  2  usage error or unreadable plan

Examples:
  "${OHMYORCH_CODE_ROOT}/scripts/check-scope.sh" --plan openspec/changes/x/implementation-plan.md
  git diff --name-only | ohmyorch check-scope --plan openspec/changes/x/implementation-plan.md
  "${OHMYORCH_CODE_ROOT}/scripts/check-scope.sh" --plan <plan> --diff /tmp/changed.txt
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --plan)  [ $# -ge 2 ] || { echo "error: --plan needs a value" >&2; exit 2; }; PLAN="$2"; shift 2 ;;
    --diff)  [ $# -ge 2 ] || { echo "error: --diff needs a value" >&2; exit 2; }; DIFF_FILE="$2"; shift 2 ;;
    --base)  [ $# -ge 2 ] || { echo "error: --base needs a value" >&2; exit 2; }; BASE="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

if [ -z "$PLAN" ]; then
  echo "error: --plan is required" >&2
  usage >&2
  exit 2
fi

if [ ! -f "$PLAN" ]; then
  echo "error: plan not found: $PLAN" >&2
  exit 2
fi

TMPDIR_S=$(mktemp -d)
trap 'rm -rf "$TMPDIR_S"' EXIT

# ---------------------------------------------------------------------------
# Collect the changed files
# ---------------------------------------------------------------------------

if [ -n "$DIFF_FILE" ]; then
  if [ ! -f "$DIFF_FILE" ]; then
    echo "error: --diff file not found: $DIFF_FILE" >&2
    exit 2
  fi
  cp "$DIFF_FILE" "$TMPDIR_S/changed.raw"
elif [ ! -t 0 ]; then
  # Piped input
  cat > "$TMPDIR_S/changed.raw"
else
  # Inspect the repository directly.
  if [ -z "$BASE" ]; then
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      BASE="HEAD"
    else
      BASE=""
    fi
  fi

  : > "$TMPDIR_S/changed.raw"
  if [ -n "$BASE" ]; then
    git diff --name-only "$BASE" >> "$TMPDIR_S/changed.raw" 2>/dev/null || true
  fi
  # Untracked files count too: a brand-new file is still a scope decision.
  git ls-files --others --exclude-standard >> "$TMPDIR_S/changed.raw" 2>/dev/null || true
fi

# Take the last whitespace-separated field of each line so both `--name-only`
# output and raw `--name-status` output work.
sed 's/^[[:space:]]*//; s/[[:space:]]*$//' "$TMPDIR_S/changed.raw" \
  | grep -v '^$' \
  | awk '{ print $NF }' \
  | sed 's|^\./||' \
  | sort -u > "$TMPDIR_S/changed.txt"

CHANGED_COUNT=$(grep -c . "$TMPDIR_S/changed.txt" || true)
CHANGED_COUNT=${CHANGED_COUNT:-0}

# ---------------------------------------------------------------------------
# Extract predicted paths from the plan
# ---------------------------------------------------------------------------
#
# The plan's `## Affected Files` section lists paths in a table. We take every
# path-like token from the whole plan, not only that section, because a plan may
# legitimately name a file in its Test Strategy or Task mapping too.

grep -oE '`[^`]+`' "$PLAN" 2>/dev/null \
  | tr -d '`' \
  | grep -E '(/|\.(md|sh|json|ya?ml|ts|tsx|js|jsx|py|go|rs|java|rb|tf|bicep|cs|php|ex|exs|sql|txt|cfg|toml))$' \
  | sed 's|^\./||' \
  | sed 's|[[:space:]]*$||' \
  | sort -u > "$TMPDIR_S/predicted.raw"

grep -oE '(^|[[:space:]|])([A-Za-z0-9_.-]+/)+[A-Za-z0-9_.*/-]*[A-Za-z0-9_*]' "$PLAN" 2>/dev/null \
  | sed 's/^[[:space:]|]*//' \
  | sed 's|^\./||' \
  | grep -v '^$' \
  | sort -u >> "$TMPDIR_S/predicted.raw"

sort -u "$TMPDIR_S/predicted.raw" > "$TMPDIR_S/predicted.txt"
PREDICTED_COUNT=$(grep -c . "$TMPDIR_S/predicted.txt" || true)
PREDICTED_COUNT=${PREDICTED_COUNT:-0}

# ---------------------------------------------------------------------------
# Compare
# ---------------------------------------------------------------------------
#
# A changed file counts as predicted when the plan names it exactly, or names a
# directory that contains it. That tolerates "likely files" being directional
# without letting a wholly unrelated module pass.

: > "$TMPDIR_S/unpredicted.txt"

while IFS= read -r changed; do
  [ -z "$changed" ] && continue
  found=0

  while IFS= read -r predicted; do
    [ -z "$predicted" ] && continue
    if [ "$changed" = "$predicted" ]; then
      found=1; break
    fi
    # Directory containment: the plan predicted `scripts/` and the change is
    # `ohmyorch thing`.
    case "$predicted" in
      */)
        case "$changed" in "$predicted"*) found=1; break ;; esac ;;
    esac
    # Reverse containment: the plan predicted `ohmyorch new` and the change
    # reporting is the file itself, already covered above. Also allow a plan
    # entry that is a prefix directory of the changed path without a slash.
    case "$changed" in
      "$predicted"/*) found=1; break ;;
    esac
  done < "$TMPDIR_S/predicted.txt"

  [ "$found" -eq 0 ] && printf '%s\n' "$changed" >> "$TMPDIR_S/unpredicted.txt"
done < "$TMPDIR_S/changed.txt"

UNPREDICTED_COUNT=$(grep -c . "$TMPDIR_S/unpredicted.txt" || true)
UNPREDICTED_COUNT=${UNPREDICTED_COUNT:-0}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

say "OhMyOrch Harness — change scope check"
say "===================================="
say ""
say "Plan:      $PLAN"
say "Changed:   $CHANGED_COUNT file(s)"
say "Predicted: $PREDICTED_COUNT path(s) named in the plan"
say ""

if [ "$CHANGED_COUNT" -eq 0 ]; then
  say "  No changed files detected. Nothing to compare."
  say ""
  say "  ${c_dim}Note: run this after the Implementer has made changes, or pass"
  say "  --diff <file> with a captured listing.${c_reset}"
  exit 0
fi

if [ "$UNPREDICTED_COUNT" -eq 0 ]; then
  say "  ${c_green}Every changed file was predicted by the plan.${c_reset}"
  say ""
  say "  RESULT: IN SCOPE"
  exit 0
fi

printf '  %sUnpredicted change(s) — not necessarily wrong, but must be accounted for:%s\n' \
  "$c_yellow" "$c_reset"
printf '\n'
while IFS= read -r f; do
  [ -n "$f" ] && printf '    %s\n' "$f"
done < "$TMPDIR_S/unpredicted.txt"
printf '\n'
printf '  %sFor each, either:%s\n' "$c_dim" "$c_reset"
printf '    - it is required by the change, and the plan should have named it; or\n'
printf '    - it is unrelated, and belongs in follow-up work, not this change (US-5.1).\n'
printf '\n'
printf '  RESULT: %s%sOUT OF PLAN SCOPE%s — %s file(s) unaccounted for.\n' \
  "$c_yellow" "" "$c_reset" "$UNPREDICTED_COUNT"
exit 1
