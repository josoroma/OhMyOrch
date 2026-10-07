#!/bin/bash
set -uo pipefail
source "$(cd -- "$(dirname -- "$0")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"; set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"
approve=0
while [ "$#" -gt 0 ]; do
  case "$1" in --approve-current) approve=1; shift ;;
    --file) [ "$#" -gt 1 ] || exit 2; shift 2 ;;
    --quiet) shift ;; -h|--help) echo 'run-project-validation [--approve-current]: explicit local hash approval; hooks only run an approved script'; exit 0 ;;
    *) ohmyorch_die "unknown project validation flag: $1" ;; esac
done
[ "$OHMYORCH_ENABLED" = true ] || { [ "$approve" -eq 0 ] || ohmyorch_die "activate project before approving code"; echo "SKIP: project inactive"; exit 0; }
script=$(jq -r .fastValidation.script "$OHMYORCH_CONFIG")
ohmyorch_path "$script" >/dev/null || exit 2
[ -f "$script" ] && [ -x "$script" ] || { echo "SKIP: $script missing or not executable"; exit 0; }
approval=.claude/ohmyorch/approvals.local.json
ohmyorch_path "$approval" >/dev/null || exit 2
hash=$(ohmyorch_hash "$script")
if [ "$approve" -eq 1 ]; then
  git check-ignore -q "$approval" 2>/dev/null || ohmyorch_die "approval must be Git-ignored before it can be written"
  umask 077
  mkdir -p .claude/ohmyorch
  jq -n --arg path "$script" --arg hash "$hash" '{schemaVersion:1,fastValidation:{path:$path,sha256:$hash}}' > "$approval"
  echo 'Approved current script hash locally; no script executed.'; exit 0
fi
[ "$(jq -r .fastValidation.enabled "$OHMYORCH_CONFIG")" = true ] || { echo 'SKIP: project fast validation disabled'; exit 0; }
jq -e --arg path "$script" --arg hash "$hash" '.schemaVersion==1 and .fastValidation.path==$path and .fastValidation.sha256==$hash' "$approval" >/dev/null 2>&1 || {
  echo 'SKIP: script has no current hash-bound local approval'; exit 0;
}
git check-ignore -q "$approval" 2>/dev/null || { echo 'SKIP: local approval is not Git-ignored'; exit 0; }
exec "$OHMYORCH_PROJECT_ROOT/$script"
