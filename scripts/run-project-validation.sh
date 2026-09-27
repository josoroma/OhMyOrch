#!/usr/bin/env bash
#
# run-project-validation.sh — US-8.2 adaptation point for scenario 6
#
# Scenario implemented:
#   Given the Implementer modifies application source code
#   When  the modification phase completes
#   Then  configured fast project validation SHOULD run before implementation is
#         handed to review
#
# This is a SHOULD, and the key word is "configured". The harness is stack-neutral
# (NFR-001) and therefore cannot know how to build or test an arbitrary host
# project. It must not guess: inventing a validation command would produce a hook
# that either fails on every legitimate project or silently validates nothing.
#
# So the harness supplies the HOOK POINT and the host project supplies the
# COMMAND. The strategy is:
#
#   1. If the project provides scripts/fast-validate.sh (executable), run it.
#      That script is the project's own definition of "fast validation" —
#      typically the formatter/linter/unit subset that completes in seconds.
#   2. Otherwise, do nothing and say so. No silent no-op that looks like a pass.
#
# The harness ships no fast-validate.sh, because this is a Markdown-only project
# with no build or test runner.
#
# Wired as a PostToolUse hook on Write|Edit|MultiEdit. PostToolUse runs after the
# write, so this cannot reject the change; it reports. That matches the modal
# level: a SHOULD is a finding to record, not a block.
#
# Usage:
#   run-project-validation.sh --hook
#   run-project-validation.sh --file <path>
#
# Exit codes: 0 validation passed or not configured, 1 validation failed, 3 usage.

set -uo pipefail

HOOK_MODE=0
FILE=""
QUIET=0

c_reset=""; c_red=""; c_dim=""; c_yellow=""; c_green=""
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  c_reset=$'\033[0m'; c_red=$'\033[31m'; c_dim=$'\033[2m'
  c_yellow=$'\033[33m'; c_green=$'\033[32m'
fi

usage() {
  cat <<'EOF'
Usage: run-project-validation.sh (--hook | --file <path>) [--quiet]

Runs the project's configured fast validation (scripts/fast-validate.sh) after a
source modification (US-8.2, scenario 6). A no-op when the project has not
configured one.

Options:
  --hook          Read Claude Code hook JSON on stdin (PostToolUse)
  --file <path>   Check a specific path (direct mode)
  --quiet         Suppress informational output
  -h, --help      Show this help

Exit codes: 0 passed or not configured, 1 validation failed, 3 usage error
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --hook)  HOOK_MODE=1; shift ;;
    --file)  [ $# -ge 2 ] || { echo "error: --file needs a value" >&2; exit 3; }; FILE="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; usage >&2; exit 3 ;;
  esac
done

if [ "$HOOK_MODE" -eq 1 ]; then
  HOOK_INPUT=$(cat)
  [ -z "$HOOK_INPUT" ] && exit 0
  FILE=$(printf '%s' "$HOOK_INPUT" \
    | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -1)
fi

FILE="${FILE#"$PWD"/}"
FILE="${FILE#./}"

# Only source modifications trigger validation. Rules, specs and artifacts are
# covered by their own validators, which are cheaper and more precise.
if [ -n "$FILE" ]; then
  case "$FILE" in
    .claude/*|openspec/*|scripts/*|*.md|*.json|*.yaml|*.yml|*.toml) exit 0 ;;
  esac
fi

VALIDATOR="scripts/fast-validate.sh"

if [ ! -x "$VALIDATOR" ]; then
  # Not configured. Say so plainly rather than reporting a pass that never ran.
  [ "$QUIET" -eq 1 ] || printf 'SKIP   no %s configured for this project\n' "$VALIDATOR" >&2
  exit 0
fi

[ "$QUIET" -eq 1 ] || printf 'Running project fast validation: %s\n' "$VALIDATOR" >&2

if "$VALIDATOR"; then
  [ "$QUIET" -eq 1 ] || printf '%sPASS%s   %s\n' "$c_green" "$c_reset" "$VALIDATOR" >&2
  exit 0
fi

printf '%sWARN%s   fast validation failed: %s\n' "$c_yellow" "$c_reset" "$VALIDATOR" >&2
printf '  %sUS-8.2 scenario 6 is a SHOULD. Record this in test-report.md; the%s\n' \
  "$c_dim" "$c_reset" >&2
printf '  %sbackend must not treat implementation as handed off until it is resolved.%s\n' \
  "$c_dim" "$c_reset" >&2
exit 1
