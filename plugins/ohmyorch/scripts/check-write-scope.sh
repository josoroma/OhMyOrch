#!/bin/bash
set -uo pipefail
source "$(cd -- "$(dirname -- "$0")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"; set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"
role=''; file=''; selected=''; quiet=0; hook=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --role|--file|--change) [ "$#" -gt 1 ] || ohmyorch_die "$1 needs a value"
      case "$1" in --role) role="$2" ;; --file) file="$2" ;; --change) selected="$2" ;; esac; shift 2 ;;
    --quiet) quiet=1; shift ;; --hook) hook=1; shift ;;
    -h|--help) echo 'check-write-scope --role ohmyorch:<role> --file <path> [--change <id>]'; exit 0 ;;
    *) ohmyorch_die "unknown scope flag: $1" ;;
  esac
done
if [ "$hook" -eq 1 ]; then file=$(jq -er '.tool_input.file_path | select(type=="string")') || exit 2; fi
[ -n "$file" ] && [ -n "$role" ] || ohmyorch_die '--file and --role are required'
file=$(ohmyorch_relative "$file") || exit 2
role=${role#ohmyorch:}; role=${role#ohmyorch-}
if [ -z "$selected" ]; then selected=$(ohmyorch_selected_change 2>/dev/null) || selected=''; fi
if [ -n "$selected" ]; then ohmyorch_change_id "$selected" || exit 2; fi
artifact_root="openspec/changes/$selected"
allow=0; reason='artifact belongs to another role or change'
case "$role" in
  reviewer) [ -n "$selected" ] && [ "$file" = "$artifact_root/review.md" ] && allow=1 ;;
  tester) [ -n "$selected" ] && [ "$file" = "$artifact_root/test-report.md" ] && allow=1 ;;
  implementer)
    case "$file" in
      "$OHMYORCH_DOC_PRD"|"$OHMYORCH_DOC_SPECS"|"$OHMYORCH_DOC_CODEBASE"|CLAUDE.md|AGENTS.md|.gitignore|.claude/*|openspec/*|README*.md) ;;
      *) allow=1 ;;
    esac
    [ -z "$selected" ] || [ "$file" != "$artifact_root/tasks.md" ] || allow=1
    reason='Implementer writes product code/tests and selected tasks; never verdicts or PM state' ;;
  product-manager)
    case "$file" in
      "$OHMYORCH_DOC_PRD"|"$OHMYORCH_DOC_SPECS"|"$OHMYORCH_DOC_CODEBASE"|openspec/delivery/goal.md|"$artifact_root/status.md"|"$artifact_root/completion.md") allow=1 ;;
    esac ;;
  planner|codebase-analyst|product-specifier|spec-ingestor) reason='read-only role returns authored content to the coordinator' ;;
  *) reason='unknown role cannot author protected workflow state' ;;
esac
if [ "$allow" -eq 1 ]; then
  [ "$quiet" -eq 1 ] || printf 'ALLOW [%s] %s\n' "$role" "$file" >&2
  exit 0
fi
printf 'BLOCKED [%s] %s — %s\n' "$role" "$file" "$reason" >&2
exit 2
