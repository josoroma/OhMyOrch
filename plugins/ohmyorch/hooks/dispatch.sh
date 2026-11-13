#!/bin/bash
# One dispatcher for every plugin hook event (plugin agent frontmatter hooks are
# ignored, so role rules live here too).
#
#   session-context  one line of context for the session
#   pre-write        lease and role rules; then, only for the mapped PRD/SPECS, the
#                    CODEBASE-context preflight, judged on the document as the
#                    write would leave it (skipped for SPECS delivery
#                    bookkeeping); only for the mapped SPECS, the
#                    archive-before-DONE guard. Any other path spawns nothing.
#   post-write       product-artifact validation for the three mapped documents;
#                    the project's fast validation only when it is enabled
#   pre-bash         the unfinished-task guard for a literal `openspec archive <id>`
#                    run alone; any other command that invokes the archive is refused
#   stop             delivery-loop continuation for the session that owns the goal
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
case "$mode" in pre-write|pre-bash) expected=PreToolUse ;; post-write) expected=PostToolUse ;; stop) expected=Stop ;; session-context) expected=SessionStart ;; *) ohmyorch_error "unknown dispatcher mode: $mode"; exit 2 ;; esac
[ "$(jq -r .hook_event_name <<< "$payload")" = "$expected" ] || { ohmyorch_error 'hook event/mode mismatch'; exit 2; }
session=$(jq -r .session_id <<< "$payload")
# Keep a repair route for invalid config without permitting protected artifact edits.
# One initialization serves both the probe and the hook itself.
if ! ohmyorch_try_init --project-root "$root" --session-id "$session" >/dev/null 2>&1; then
  # A missing runtime-required script is a broken install, not a configuration
  # fault: name it and fail closed in every mode, as for the other bundled guards.
  if [ "${OHMYORCH_ENABLED:-false}" = true ]; then for executable in delivery validate-product-artifacts; do [ -x "$OHMYORCH_CODE_ROOT/scripts/$executable.sh" ] || { ohmyorch_error "missing bundled validator: $executable"; exit 2; }; done; fi
  file=$(jq -r '.tool_input.file_path // ""' <<< "$payload")
  case "$mode:$file" in pre-write:"$root/.claude/ohmyorch/project.json"|pre-write:.claude/ohmyorch/project.json) exit 0 ;; esac
  [ "$mode" != pre-write ] && [ "$mode" != pre-bash ] && exit 0
  ohmyorch_error 'invalid project configuration; repair project.json explicitly'; exit 2
fi
[ "$OHMYORCH_ENABLED" = true ] || exit 0
for executable in validate-product-artifacts delivery guard-archive guard-story-done guard-context-preflight guard-delivery-loop; do
  [ -x "$OHMYORCH_CODE_ROOT/scripts/$executable.sh" ] || { ohmyorch_error "missing bundled validator: $executable"; exit 2; }
done
case "$mode" in
  session-context)
    jq -n --arg prd "$OHMYORCH_DOC_PRD" --arg specs "$OHMYORCH_DOC_SPECS" --arg cb "$OHMYORCH_DOC_CODEBASE" \
      '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:("OhMyOrch activated. Each SPECS story is delivered as one OpenSpec change: propose, apply, verify, archive. Document mapping: PRD="+$prd+", SPECS="+$specs+", CODEBASE="+$cb+". Derive the next action from artifacts; archive before DONE. Never write installed plugin code or silently initialize a project.")}}'
    ;;
  pre-write|post-write)
    # One jq process: tool_input must be an object, no target path may carry a
    # control character, and the distinct non-empty paths come back one per line.
    paths=$(jq -r '
      if (.tool_input|type=="object") then . else error("tool_input") end |
      [.tool_input.file_path?, .tool_input.edits[]?.file_path?, .tool_input.files[]?.file_path?] |
      if all(.==null or (type=="string" and (test("[\u0000-\u001f\u007f]")|not))) then . else error("path") end |
      map(select(type=="string" and length>0)) | unique[]' <<< "$payload" 2>/dev/null) || {
      ohmyorch_error 'malformed write payload: tool_input must be an object whose target paths are strings without control characters'; exit 2;
    }
    [ -n "$paths" ] || { ohmyorch_error 'write payload has no supported target paths'; exit 2; }
    if [ "$mode" = pre-write ]; then
      agent=$(jq -r '.agent_type // ""' <<< "$payload")
      agent_id=$(jq -r '.agent_id // ""' <<< "$payload")
    fi
    while IFS= read -r raw_path; do
      file=$(ohmyorch_relative "$raw_path") || exit 2
      if [ "$mode" = post-write ]; then
        case "$file" in "$OHMYORCH_DOC_PRD"|"$OHMYORCH_DOC_SPECS"|"$OHMYORCH_DOC_CODEBASE")
          "$OHMYORCH_CODE_ROOT/scripts/validate-product-artifacts.sh" --quiet >&2 || exit 2 ;; esac
        # Disabled fast validation only ever skips, so it is not spawned at all.
        if [ "$OHMYORCH_FAST_VALIDATION" = true ]; then
          "$OHMYORCH_CODE_ROOT/scripts/run-project-validation.sh" --file "$file" >&2 || exit 2
        fi
        continue
      fi
      # 1. Lease: delivery state belongs to the session that owns the goal.
      case "$file" in "$OHMYORCH_DOC_SPECS"|openspec/delivery/*)
        owner=$(ohmyorch_owner_session || true)
        [ -z "$owner" ] || [ "$owner" = "$session" ] || { ohmyorch_error "another session owns PM state"; exit 2; } ;;
      esac
      # 2. Role: the plugin's agents are read-only authoring roles; any other
      # subagent may write product code and change artifacts, never delivery state.
      case "$agent" in ohmyorch:*)
        printf 'BLOCKED [%s] %s — read-only role returns authored content to the coordinator\n' "${agent#ohmyorch:}" "$file" >&2
        exit 2 ;;
        *)
          case "$file" in "$OHMYORCH_DOC_SPECS"|openspec/delivery/*)
            [ -z "$agent_id" ] || { ohmyorch_error 'unknown subagent cannot write PM state'; exit 2; } ;;
          esac ;;
      esac
      # 3-4. Guards are path-gated: an ordinary file spawns nothing from here on.
      case "$file" in
        "$OHMYORCH_DOC_PRD")
          # The PRD as it would be after this write, so that a decision recorded
          # in it counts. A write that cannot be reconstructed is judged on the
          # file on disk instead: it is never refused here for that reason.
          prospective=0
          if scratch=$(mktemp -d "${TMPDIR:-/tmp}/ohmyorch-prospective.XXXXXX" 2>/dev/null); then
            trap 'rm -f "$scratch/current" "$scratch/next"; rmdir "$scratch" 2>/dev/null' EXIT
            if [ -f "$file" ]; then cat "$file" > "$scratch/current"; else : > "$scratch/current"; fi
            jq -j --rawfile current "$scratch/current" -f "$OHMYORCH_CODE_ROOT/lib/prospective.jq" <<< "$payload" > "$scratch/next" 2>/dev/null && prospective=1
          fi
          if [ "$prospective" -eq 1 ]; then
            "$OHMYORCH_CODE_ROOT/scripts/guard-context-preflight.sh" --file "$file" --content-file "$scratch/next" --quiet; guard_rc=$?
          else
            "$OHMYORCH_CODE_ROOT/scripts/guard-context-preflight.sh" --file "$file" --quiet; guard_rc=$?
          fi
          if [ -n "$scratch" ]; then
            rm -f "$scratch/current" "$scratch/next"; rmdir "$scratch" 2>/dev/null
            trap - EXIT
          fi
          [ "$guard_rc" -eq 0 ] || exit 2 ;;
        "$OHMYORCH_DOC_SPECS")
          # The SPECS as it would be after this write, byte for byte.
          scratch=$(mktemp -d "${TMPDIR:-/tmp}/ohmyorch-prospective.XXXXXX") || exit 2
          trap 'rm -f "$scratch/current" "$scratch/next" "$scratch/delta" "$scratch/lines" "$scratch/current.boxes" "$scratch/next.boxes"; rmdir "$scratch" 2>/dev/null' EXIT
          if [ -f "$file" ]; then cat "$file" > "$scratch/current"; else : > "$scratch/current"; fi
          jq -j --rawfile current "$scratch/current" -f "$OHMYORCH_CODE_ROOT/lib/prospective.jq" <<< "$payload" > "$scratch/next" || {
            ohmyorch_error 'cannot reconstruct prospective SPECS write'; exit 2;
          }
          # Delivery bookkeeping is not a material SPECS update, so it does not
          # need fresh CODEBASE context: Status: lines, Change: lines, ticking a
          # task checkbox, and the story/task rows of the Work Item Status table.
          # It qualifies only when the file exists and every line the write adds
          # or removes is such a line; blank lines carry no content and are
          # ignored. On a task line only the box, and the whitespace before the
          # dash and before the box, may change: adding, rewording, moving or
          # deleting a task line is material.
          bookkeeping=0
          if [ -f "$file" ]; then
            # Both sides are compared with every task box blanked, so a tick
            # leaves no difference at all and any other change to a task line
            # stays one, wherever the line sits. Each side gets one more
            # newline, so a final newline that comes or goes shows up as a
            # blank line. Everything is read byte-wise (C locale): sed then
            # never stops at a byte that is invalid in the session's encoding,
            # and grep and sed agree on what whitespace is.
            box='s/^[[:space:]]*-[[:space:]]*\[[ xX]\]/- [ ]/'
            delta_rc=2
            { LC_ALL=C sed "$box" "$scratch/current" && echo; } > "$scratch/current.boxes" &&
              { LC_ALL=C sed "$box" "$scratch/next" && echo; } > "$scratch/next.boxes" && {
                # -a keeps diff from calling a file with a NUL byte binary.
                diff -a "$scratch/current.boxes" "$scratch/next.boxes" > "$scratch/delta" 2>/dev/null; delta_rc=$?
              }
            if [ "$delta_rc" -eq 0 ]; then bookkeeping=1
            elif [ "$delta_rc" -eq 1 ]; then
              # The changed lines, with NUL made visible: grep would read a
              # line that starts with one as blank. A difference always leaves
              # at least one line here, so an empty list means the extraction
              # failed. grep exits 1 only when no changed line is material; any
              # other outcome keeps the preflight.
              if LC_ALL=C tr '\000' '?' < "$scratch/delta" | LC_ALL=C sed -n 's/^[<>] \{0,1\}//p' > "$scratch/lines" &&
                 [ -s "$scratch/lines" ]; then
                LC_ALL=C grep -aqvE '^([[:space:]]*$|Status:|Change:|[|][[:space:]]*US-[0-9]+\.[0-9]+(#[0-9]+)?[[:space:]]*[|])' "$scratch/lines"
                [ "$?" -ne 1 ] || bookkeeping=1
              fi
            fi
          fi
          if [ "$bookkeeping" -ne 1 ]; then
            "$OHMYORCH_CODE_ROOT/scripts/guard-context-preflight.sh" --file "$file" --content-file "$scratch/next" --quiet || exit 2
          fi
          # The content travels as a file: Linux refuses one argument of 128 KiB
          # or more, which would block every write to a large SPECS.
          old=$(jq -r '.tool_input.old_string // ""' <<< "$payload")
          "$OHMYORCH_CODE_ROOT/scripts/guard-story-done.sh" --file "$file" --content-file "$scratch/next" --old "$old" --quiet || exit 2
          rm -f "$scratch/current" "$scratch/next" "$scratch/delta" "$scratch/lines" "$scratch/current.boxes" "$scratch/next.boxes"; rmdir "$scratch" 2>/dev/null
          trap - EXIT ;;
      esac
    done <<< "$paths"
    ;;
  pre-bash)
    command_text=$(jq -er '.tool_input.command | select(type=="string")' <<< "$payload" 2>/dev/null) || {
      ohmyorch_error 'malformed Bash payload: tool_input.command must be a string'; exit 2;
    }
    # Here-strings, not pipes: under `pipefail` a `grep -q` that stops at the first
    # match would break the writer of a very long command and hide the archive.
    # Detection has no left anchor, so a global option (`openspec --no-color
    # archive`) and a versioned package (`openspec@1.13.2 archive`) reach the refusal.
    if grep -qE 'openspec(@[^[:space:]]+)?([[:space:]]+-[^[:space:]]+)*[[:space:]]+archive([[:space:]]|$)' <<< "$command_text"; then
      # Exactly one standalone literal invocation. Refuse chained/dynamic forms.
      archive_form='unsupported archive shell form; run it alone as: openspec archive <change-id> -y'
      # grep judges line by line, so a multi-line command is refused first: one
      # allowed line must never carry the others past the guard.
      case "$command_text" in *$'\n'*) ohmyorch_error "$archive_form"; exit 2 ;; esac
      if grep -qE '^openspec[[:space:]]+archive[[:space:]]+(-h|--help)[[:space:]]*$' <<< "$command_text"; then exit 0; fi
      # The id is bare or wrapped in one matching pair of quotes, and starts with
      # a letter or digit, so an option can never stand in its place.
      id_form='[a-zA-Z0-9][a-zA-Z0-9_-]*'
      grep -qE "^openspec[[:space:]]+archive[[:space:]]+(\"$id_form\"|'$id_form'|$id_form)([[:space:]]+(-y|--yes|--skip-specs))*[[:space:]]*\$" <<< "$command_text" || {
        ohmyorch_error "$archive_form"; exit 2;
      }
      change=$(printf '%s' "$command_text" | awk '{print $3}')
      case "$change" in
        \"*\") change=${change#\"}; change=${change%\"} ;;
        \'*\') change=${change#\'}; change=${change%\'} ;;
      esac
      ohmyorch_change_id "$change" || exit 2
      "$OHMYORCH_CODE_ROOT/scripts/guard-archive.sh" --change "$change" --quiet || exit 2
    fi
    ;;
  stop)
    agent_id=$(jq -r '.agent_id // ""' <<< "$payload")
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
