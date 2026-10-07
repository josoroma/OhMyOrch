#!/bin/bash
set -uo pipefail
source "$(cd -- "$(dirname -- "$0")/../lib" && pwd -P)/runtime.sh"
source "$OHMYORCH_CODE_ROOT/lib/session.sh"
# Inactive projects are a no-op even without jq. Never bootstrap from an event.
root="${CLAUDE_PROJECT_DIR:-}"
mode=''
while [ "$#" -gt 0 ]; do
  case "$1" in --project-root) root="$2"; shift 2 ;; --mode) mode="$2"; shift 2 ;;
    *) ohmyorch_die "unknown dispatcher flag: $1" ;; esac
done
case "$root" in /*) ;; *) exit 0 ;; esac
[ -e "$root/.claude/ohmyorch/project.json" ] || exit 0
command -v jq >/dev/null 2>&1 || { ohmyorch_error 'activated plugin needs jq; enforcement could not run'; exit 2; }
payload=$(cat)
jq -e 'type=="object" and (.hook_event_name|type=="string") and (.session_id|type=="string" and length>0) and ([.agent_type?,.agent_id?]|all(.==null or type=="string"))' >/dev/null 2>&1 <<< "$payload" || {
  ohmyorch_error 'malformed hook input in activated project'; exit 2;
}
case "$mode" in pre-write|pre-bash) expected=PreToolUse ;; post-write) expected=PostToolUse ;; stop) expected=Stop ;; session-context) expected=SessionStart ;; *) exit 2 ;; esac
[ "$(jq -r .hook_event_name <<< "$payload")" = "$expected" ] || { ohmyorch_error 'hook event/mode mismatch'; exit 2; }
session=$(jq -r .session_id <<< "$payload")
# Keep a repair route for invalid config without permitting protected artifact edits.
if ! (ohmyorch_init --project-root "$root" --session-id "$session") >/dev/null 2>&1; then
  file=$(jq -r '.tool_input.file_path // ""' <<< "$payload")
  case "$mode:$file" in pre-write:"$root/.claude/ohmyorch/project.json"|pre-write:.claude/ohmyorch/project.json) exit 0 ;; esac
  [ "$mode" != pre-write ] && [ "$mode" != pre-bash ] && exit 0
  ohmyorch_error 'invalid project configuration; repair project.json explicitly'; exit 2
fi
ohmyorch_init --project-root "$root" --session-id "$session"
[ "$OHMYORCH_ENABLED" = true ] || exit 0
for executable in validate-product-artifacts validate-implementation-plan validate-review validate-test-report validate-status validate-verification workflow-status completion-gate delivery guard-archive guard-story-done guard-context-preflight guard-planning-handoff check-write-scope guard-delivery-loop; do
  [ -x "$OHMYORCH_CODE_ROOT/scripts/$executable.sh" ] || { ohmyorch_error "missing bundled validator: $executable"; exit 2; }
done
agent=$(jq -r '.agent_type // ""' <<< "$payload")
agent_id=$(jq -r '.agent_id // ""' <<< "$payload")
case "$mode" in
  session-context)
    jq -n --arg prd "$OHMYORCH_DOC_PRD" --arg specs "$OHMYORCH_DOC_SPECS" --arg cb "$OHMYORCH_DOC_CODEBASE" \
      '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:("OhMyOrch activated. Read the bundled contract. Main session coordinates one change; implementer never writes verdicts; reviewer/tester persist their own artifacts and never repair. Document mapping: PRD="+$prd+", SPECS="+$specs+", CODEBASE="+$cb+". Derive next action from artifacts; archive before DONE. Never write installed plugin code or silently initialize a project.")}}'
    ;;
  pre-write|post-write)
    jq -e '.tool_input|type=="object"' >/dev/null <<< "$payload" || exit 2
    jq -e '[.tool_input.file_path?, .tool_input.edits[]?.file_path?, .tool_input.files[]?.file_path?] | all(.==null or (type=="string" and (test("[\u0000-\u001f\u007f]")|not)))' <<< "$payload" >/dev/null || exit 2
    paths=$(jq -r '[.tool_input.file_path?, .tool_input.edits[]?.file_path?, .tool_input.files[]?.file_path?] | map(select(type=="string" and length>0)) | unique[]' <<< "$payload") || exit 2
    [ -n "$paths" ] || { ohmyorch_error 'write payload has no supported target paths'; exit 2; }
    while IFS= read -r raw_path; do
      file=$(ohmyorch_relative "$raw_path") || exit 2
      if [ "$mode" = post-write ]; then
        case "$file" in "$OHMYORCH_DOC_PRD"|"$OHMYORCH_DOC_SPECS"|"$OHMYORCH_DOC_CODEBASE")
          "$OHMYORCH_CODE_ROOT/scripts/validate-product-artifacts.sh" --quiet >&2 || exit 2 ;; esac
        "$OHMYORCH_CODE_ROOT/scripts/run-project-validation.sh" --file "$file" >&2 || exit 2
        continue
      fi
      owner=$(ohmyorch_owner_session || true)
      case "$file" in "$OHMYORCH_DOC_SPECS"|openspec/delivery/*|openspec/changes/*/status.md|openspec/changes/*/completion.md)
        [ -z "$owner" ] || [ "$owner" = "$session" ] || { ohmyorch_error "another session owns PM state"; exit 2; } ;;
      esac
      case "$agent" in ohmyorch:*)
        "$OHMYORCH_CODE_ROOT/scripts/check-write-scope.sh" --role "$agent" --file "$file" --quiet || exit 2 ;;
        *)
          case "$file" in openspec/*/review.md|openspec/*/test-report.md)
            ohmyorch_error 'only the scoped reviewer/tester may author verdicts'; exit 2 ;;
            "$OHMYORCH_DOC_SPECS"|openspec/*/status.md|openspec/*/completion.md|openspec/delivery/*)
              [ -z "$agent_id" ] || { ohmyorch_error 'unknown subagent cannot write PM state'; exit 2; } ;;
          esac ;;
      esac
      "$OHMYORCH_CODE_ROOT/scripts/guard-planning-handoff.sh" --file "$file" --quiet || exit 2
      "$OHMYORCH_CODE_ROOT/scripts/guard-context-preflight.sh" --file "$file" --quiet || exit 2
      if [ "$file" = "$OHMYORCH_DOC_SPECS" ]; then
        current=$(mktemp "${TMPDIR:-/tmp}/ohmyorch-prospective.XXXXXX") || exit 2
        if [ -f "$file" ]; then cat "$file" > "$current"; else : > "$current"; fi
        content=$(jq -r --rawfile current "$current" -f "$OHMYORCH_CODE_ROOT/lib/prospective.jq" <<< "$payload"); rc=$?
        rm -f "$current"
        [ "$rc" -eq 0 ] || { ohmyorch_error 'cannot reconstruct prospective SPECS write'; exit 2; }
      else
        content=$(jq -r '.tool_input.content // .tool_input.new_string // ""' <<< "$payload")
      fi
      old=$(jq -r '.tool_input.old_string // ""' <<< "$payload")
      "$OHMYORCH_CODE_ROOT/scripts/guard-story-done.sh" --file "$file" --content "$content" --old "$old" --quiet || exit 2
    done <<< "$paths"
    ;;
  pre-bash)
    command_text=$(jq -er '.tool_input.command | select(type=="string")' <<< "$payload") || exit 2
    if printf '%s' "$command_text" | grep -qE 'openspec[[:space:]]+archive([[:space:]]|$)'; then
      # Exactly one standalone literal invocation. Refuse chained/dynamic forms.
      if printf '%s' "$command_text" | grep -qE '^openspec[[:space:]]+archive[[:space:]]+(-h|--help)[[:space:]]*$'; then exit 0; fi
      printf '%s' "$command_text" | grep -qE '^openspec[[:space:]]+archive[[:space:]]+[a-zA-Z0-9_-]+([[:space:]]+(-y|--yes|--skip-specs))*[[:space:]]*$' || {
        ohmyorch_error 'unsupported archive shell form; use a standalone openspec archive <literal-id> -y'; exit 2;
      }
      change=$(printf '%s' "$command_text" | awk '{print $3}')
      ohmyorch_change_id "$change" || exit 2
      "$OHMYORCH_CODE_ROOT/scripts/guard-archive.sh" --change "$change" --quiet || exit 2
    fi
    ;;
  stop)
    [ -z "$agent_id" ] || exit 0
    owner=$(ohmyorch_owner_session || true)
    [ "$owner" = "$session" ] || exit 0
    ohmyorch_operation_lock || exit 2
    trap 'ohmyorch_unlock' EXIT
    umask 077
    ohmyorch_path ".claude/ohmyorch/runtime/$session/loop.state" >/dev/null || exit 2
    mkdir -p ".claude/ohmyorch/runtime/$session"
    printf '%s' "$payload" | "$OHMYORCH_CODE_ROOT/scripts/guard-delivery-loop.sh" --hook
    result=$?
    ohmyorch_touch_owner || exit 2
    if [ "$result" -eq 0 ]; then ohmyorch_release_owner; fi
    exit "$result" ;;
  *) ohmyorch_die "unknown dispatcher mode: $mode" ;;
esac
