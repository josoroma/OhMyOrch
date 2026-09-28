#!/usr/bin/env bash
#
# check-write-scope.sh — OhMyOrch Harness role write-scope guard
#
# Enforces separation of duties (BR-002) mechanically. Each harness role may write
# only within its own boundary; the guard blocks the rest.
#
# The failure this prevents: an Implementer authoring its own approval.
# Concretely, an Implementer must never write review.md (its own verdict) or
# test-report.md (its own acceptance evidence) — that is self-approval.
#
# Roles and their permitted write scope:
#
#   ohmyorch-implementer   product code, implementation tests, tasks.md
#                 NOT review.md, NOT test-report.md
#   ohmyorch-reviewer      review.md
#                 NOT product code, NOT test-report.md
#   ohmyorch-tester        test-report.md
#                 NOT product code, NOT review.md
#   ohmyorch-planner       implementation-plan.md
#                 NOT product code, NOT any other role's artifact
#   ohmyorch-product-manager  SPECS.md, status.md
#                 NOT product code, NOT review.md, NOT test-report.md
#
# Usage:
#   check-write-scope.sh --role <role> --file <path>     # direct check
#   check-write-scope.sh --role <role> --hook            # read hook JSON on stdin
#
# Exit codes:
#   0  allowed
#   2  blocked (hook mode: block the write; direct mode: denied)
#   3  usage error / unknown role
#
# Dependencies: bash, grep, sed — no Node/Python (NFR-001).

set -uo pipefail

ROLE=""
FILE=""
HOOK_MODE=0
QUIET=0

c_reset=""; c_red=""; c_dim=""; c_green=""
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_green=$'\033[32m'
fi

usage() {
  cat <<'EOF'
Usage: scripts/check-write-scope.sh --role <role> (--file <path> | --hook)

Enforces harness role write scope (BR-002 separation of duties).

Options:
  --role <role>   One of: ohmyorch-implementer, ohmyorch-reviewer, ohmyorch-tester, ohmyorch-planner, ohmyorch-product-manager
  --file <path>   The path being written (direct-check mode)
  --hook          Read Claude Code hook JSON on stdin and use its file_path
  --quiet         Suppress the allow message
  -h, --help      Show this help

Exit codes:
  0  allowed
  2  blocked
  3  usage error or unknown role

Examples:
  scripts/check-write-scope.sh --role ohmyorch-implementer --file src/app.ts
  scripts/check-write-scope.sh --role ohmyorch-implementer --file openspec/changes/x/review.md
  printf '%s' "$HOOK_JSON" | scripts/check-write-scope.sh --role ohmyorch-reviewer --hook
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --role)  [ $# -ge 2 ] || { echo "error: --role needs a value" >&2; exit 3; }; ROLE="$2"; shift 2 ;;
    --file)  [ $# -ge 2 ] || { echo "error: --file needs a value" >&2; exit 3; }; FILE="$2"; shift 2 ;;
    --hook)  HOOK_MODE=1; shift ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 3 ;;
  esac
done

if [ "$HOOK_MODE" -eq 1 ]; then
  HOOK_INPUT=$(cat)
  if [ -z "$HOOK_INPUT" ]; then
    # Nothing to judge: allow, so a malformed hook payload never blocks work.
    exit 0
  fi
  FILE=$(printf '%s' "$HOOK_INPUT" \
    | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1)

  if [ -z "$FILE" ]; then
    exit 0
  fi
fi

if [ -z "$ROLE" ]; then
  echo "error: --role is required" >&2
  usage >&2
  exit 3
fi

case "$ROLE" in
  ohmyorch-implementer|ohmyorch-reviewer|ohmyorch-tester|ohmyorch-planner|ohmyorch-product-manager) ;;
  *) echo "error: unknown role '$ROLE'" >&2
     echo "known: ohmyorch-implementer, ohmyorch-reviewer, ohmyorch-tester, ohmyorch-planner, ohmyorch-product-manager" >&2
     exit 3 ;;
esac

if [ -z "$FILE" ]; then
  echo "error: a path is required (--file, or --hook with file_path)" >&2
  exit 3
fi

# Normalise to a repo-relative path so rules match regardless of how the caller
# spelled the path. Absolute paths under the project root are made relative.
FILE="${FILE#"$PWD"/}"
FILE="${FILE#./}"

BASE=$(basename -- "$FILE")

# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

# Which artifact is this, if any?
ARTIFACT=""
case "$BASE" in
  review.md)              ARTIFACT="review" ;;
  test-report.md)         ARTIFACT="test-report" ;;
  implementation-plan.md) ARTIFACT="implementation-plan" ;;
  status.md)              ARTIFACT="status" ;;
  spec.md)                ARTIFACT="delta-spec" ;;
esac
case "$FILE" in
  openspec/*/proposal.md|*/proposal.md) ARTIFACT="proposal" ;;
  openspec/*/tasks.md|*/tasks.md)       ARTIFACT="tasks" ;;
  SPECS.md)                             ARTIFACT="specs" ;;
  PRD.md)                               ARTIFACT="prd" ;;
esac

# Product code = anything that is not a recognisable harness artifact and not
# harness control surface.
IS_PRODUCT_CODE=1
case "$ARTIFACT" in
  review|test-report|implementation-plan|status|proposal|tasks|specs|prd|delta-spec)
    IS_PRODUCT_CODE=0 ;;
esac
case "$FILE" in
  CLAUDE.md|AGENTS.md|CODEBASE.md|README*.md|.gitignore) IS_PRODUCT_CODE=0 ;;
  .claude/*)  IS_PRODUCT_CODE=0 ;;
  scripts/*)  IS_PRODUCT_CODE=0 ;;
  openspec/*) IS_PRODUCT_CODE=0 ;;
esac

# ---------------------------------------------------------------------------
# Decision
# ---------------------------------------------------------------------------

ALLOWED=0
REASON=""

case "$ROLE" in

  ohmyorch-implementer)
    # The core separation-of-duties rule: an Implementer may not author the
    # artifacts that constitute approval of its own work.
    if [ "$ARTIFACT" = "review" ]; then
      REASON="an Implementer must not author review.md — that is self-approval (BR-002, US-5.1)"
    elif [ "$ARTIFACT" = "test-report" ]; then
      REASON="an Implementer must not author test-report.md — acceptance evidence is the Tester's (BR-002, US-7.1)"
    elif [ "$ARTIFACT" = "status" ]; then
      REASON="status.md is the Product Manager's workflow state (US-9.1)"
    elif [ "$ARTIFACT" = "specs" ]; then
      REASON="SPECS.md story state is the Product Manager's to change"
    elif [ "$IS_PRODUCT_CODE" -eq 1 ] || [ "$ARTIFACT" = "tasks" ]; then
      ALLOWED=1
      REASON="implementation writes product code and may tick tasks.md"
    else
      REASON="an Implementer writes product code and implementation tests only"
    fi
    ;;

  ohmyorch-reviewer)
    if [ "$ARTIFACT" = "review" ]; then
      ALLOWED=1; REASON="the Reviewer authors review.md"
    elif [ "$IS_PRODUCT_CODE" -eq 1 ]; then
      REASON="the Reviewer must not modify product code it evaluates — return the finding instead (US-6.1)"
    elif [ "$ARTIFACT" = "test-report" ]; then
      REASON="test-report.md belongs to the Tester, not the Reviewer"
    else
      REASON="the Reviewer writes review.md and nothing else"
    fi
    ;;

  ohmyorch-tester)
    if [ "$ARTIFACT" = "test-report" ]; then
      ALLOWED=1; REASON="the Tester authors test-report.md"
    elif [ "$IS_PRODUCT_CODE" -eq 1 ]; then
      REASON="the Tester must not repair failing behavior — return the finding to the Implementer (US-7.1)"
    elif [ "$ARTIFACT" = "review" ]; then
      REASON="review.md belongs to the Reviewer, not the Tester"
    else
      REASON="the Tester writes test-report.md and nothing else"
    fi
    ;;

  ohmyorch-planner)
    if [ "$ARTIFACT" = "implementation-plan" ]; then
      ALLOWED=1; REASON="the Planner authors implementation-plan.md"
    elif [ "$IS_PRODUCT_CODE" -eq 1 ]; then
      REASON="the Planner must not modify application source code (US-4.1)"
    else
      REASON="the Planner writes implementation-plan.md only"
    fi
    ;;

  ohmyorch-product-manager)
    if [ "$ARTIFACT" = "specs" ] || [ "$ARTIFACT" = "status" ]; then
      ALLOWED=1; REASON="the Product Manager owns SPECS.md story state and status.md"
    elif [ "$IS_PRODUCT_CODE" -eq 1 ]; then
      REASON="the Product Manager orchestrates; it does not write product code (US-3.1)"
    elif [ "$ARTIFACT" = "review" ] || [ "$ARTIFACT" = "test-report" ]; then
      REASON="the Product Manager must not author review or acceptance evidence (BR-002)"
    else
      REASON="the Product Manager writes SPECS.md and status.md only"
    fi
    ;;
esac

if [ "$ALLOWED" -eq 1 ]; then
  [ "$QUIET" -eq 1 ] || printf '%sALLOW%s  [%s] %s — %s\n' "$c_green" "$c_reset" "$ROLE" "$FILE" "$REASON" >&2
  exit 0
fi

printf '%sBLOCKED%s  [%s] %s\n' "$c_red" "$c_reset" "$ROLE" "$FILE" >&2
printf '  %s%s%s\n' "$c_dim" "$REASON" "$c_reset" >&2
printf '  %sHand the artifact to the role that owns it; do not write it yourself.%s\n' "$c_dim" "$c_reset" >&2
exit 2
