#!/bin/bash
set -uo pipefail
export OHMYORCH_ALLOW_UNCONFIGURED=1
source "$(cd -- "$(dirname -- "$0")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"; set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"
as_json=0
while [ "$#" -gt 0 ]; do
  case "$1" in --json) as_json=1 ;; -h|--help) echo 'doctor [--json]: read-only prerequisite and project diagnostics'; exit 0 ;;
    *) ohmyorch_die "unknown doctor flag: $1" ;; esac
  shift
done
checks='[]'; failures=0
check() {
  checks=$(jq --arg name "$1" --arg status "$2" --arg detail "$3" '. + [{name:$name,status:$status,detail:$detail}]' <<< "$checks")
  case "$2" in FAIL|UNSUPPORTED) failures=$((failures+1)) ;; esac
}
for executable in bash jq git shasum awk sed grep find mktemp; do
  if command -v "$executable" >/dev/null 2>&1; then check "$executable" PASS 'available'
  else check "$executable" FAIL 'install this prerequisite explicitly'; fi
done
for bundled in workflow-status completion-gate validate-product-artifacts validate-implementation-plan validate-review validate-test-report validate-status validate-verification delivery guard-archive guard-story-done guard-context-preflight guard-planning-handoff check-write-scope guard-delivery-loop; do
  if [ -x "$OHMYORCH_CODE_ROOT/scripts/$bundled.sh" ]; then check "bundled-$bundled" PASS 'available'
  else check "bundled-$bundled" FAIL 'installed payload incomplete; reinstall the plugin'; fi
done
jq_version=$(jq --version | sed 's/^jq-//')
case "$jq_version" in 1.[6-9]*|[2-9].*) check jq-version PASS "$jq_version" ;;
  *) check jq-version UNSUPPORTED 'requires jq >=1.6' ;; esac
if command -v openspec >/dev/null 2>&1; then
  openspec_version=$(openspec --version 2>/dev/null)
  case "$openspec_version" in 1.13.2) check openspec PASS "$openspec_version" ;;
    *) check openspec UNSUPPORTED "target is 1.13.2; found $openspec_version" ;; esac
else
  if [ "$OHMYORCH_ENABLED" = true ]; then check openspec FAIL 'missing; required for supported delivery'
  else check openspec SKIP 'missing; required for OpenSpec initialization and supported delivery'; fi
fi
if [ "$OHMYORCH_CONFIG_VALID" != 1 ]; then check project-config FAIL 'invalid or unsupported; repair explicitly'
elif [ "$OHMYORCH_ENABLED" = true ]; then check project-config PASS 'schema 1 activated'
else check project-config SKIP 'inactive; explicit /ohmyorch:bootstrap required'; fi
legacy=0
for f in .claude/agents/ohmyorch-*.md .claude/skills/ohmyorch-*/SKILL.md .claude/commands/ohmyorch/opsx/*.md; do
  [ ! -f "$f" ] || legacy=$((legacy+1))
done
hook_count=0
if [ -f .claude/settings.json ] && [ ! -L .claude/settings.json ]; then
  hook_count=$(jq '[.hooks // {} | .. | objects | .command? // empty | select(test("scripts/(guard-|validate-product-artifacts|run-project-validation)"))] | length' .claude/settings.json 2>/dev/null) || hook_count=0
fi
if [ "$legacy" -gt 0 ] || [ "$hook_count" -gt 0 ]; then
  if [ "$OHMYORCH_ENABLED" = true ]; then check legacy FAIL "$legacy legacy components, $hook_count hook registrations; explicit migration required"
  else check legacy SKIP "$legacy legacy components, $hook_count hooks; migrate before activation"; fi
else check legacy PASS 'no known standalone components/hooks'; fi
if [ -f openspec/config.yaml ]; then
  if grep -qE '^schema:[[:space:]]*spec-driven[[:space:]]*$' openspec/config.yaml; then check openspec-schema PASS 'local spec-driven'
  else check openspec-schema UNSUPPORTED 'custom/ambiguous schema needs an adapter'; fi
fi
if [ -d .claude/ohmyorch/runtime/operation.lock ]; then
  check transaction FAIL 'operation lock exists; inspect private journal, confirm process ended, then recover explicitly'
fi
if [ -d .claude/ohmyorch/runtime/delivery.owner ]; then
  if jq -e --arg root "$OHMYORCH_PROJECT_ROOT" '.schemaVersion==1 and .projectRoot==$root and (.sessionId|type=="string" and length>0)' .claude/ohmyorch/runtime/delivery.owner/owner.json >/dev/null 2>&1; then
    check delivery-owner PASS 'delivery lease present; only owner Stop events may continue'
  else check delivery-owner FAIL 'interrupted/invalid owner record; explicit takeover/recovery required'; fi
fi
for key in prd specs codebase; do
  case "$key" in prd) path="$OHMYORCH_DOC_PRD" ;; specs) path="$OHMYORCH_DOC_SPECS" ;; codebase) path="$OHMYORCH_DOC_CODEBASE" ;; esac
  if [ -f "$path" ]; then check "$key" PASS "$path"; else check "$key" SKIP "$path absent"; fi
done
if [ "$as_json" -eq 1 ]; then
  jq -n --argjson checks "$checks" --argjson enabled "$OHMYORCH_ENABLED" \
    --argjson valid "$OHMYORCH_CONFIG_VALID" --arg root "$OHMYORCH_PROJECT_ROOT" \
    --arg code "$OHMYORCH_CODE_ROOT" --arg version "$(jq -r .version "$OHMYORCH_CODE_ROOT/.claude-plugin/plugin.json")" \
    --arg prd "$OHMYORCH_DOC_PRD" --arg specs "$OHMYORCH_DOC_SPECS" --arg codebase "$OHMYORCH_DOC_CODEBASE" \
    --arg pages "$OHMYORCH_PAGES" --arg logs "$OHMYORCH_EPIC_LOGS" \
    '{pluginVersion:$version,projectRoot:$root,pluginRoot:$code,enabled:$enabled,configValid:($valid==1),documents:{prd:$prd,specs:$specs,codebase:$codebase},output:{pages:$pages,epicLogs:$logs},checks:$checks}'
else jq -r '.[] | "\(.status) \(.name): \(.detail)"' <<< "$checks"; fi
[ "$failures" -eq 0 ]
