#!/bin/bash
set -uo pipefail
repository=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/ohmyorch-regression.XXXXXX") || exit 2
trap 'rm -rf "$work"' EXIT
cp -R "$repository/plugins/ohmyorch" "$work/plugin"
export OHMYORCH_TEST_PLUGIN_ROOT="$work/plugin"
export TEST_HARNESS_ROOT="$work/legacy-view"
# jq is now a runtime dependency; preserve it when a golden suite restricts PATH.
mkdir -p "$work/utilities"
ln -s "$(command -v jq)" "$work/utilities/jq"
export OHMYORCH_TEST_UTILITIES="$work/utilities"
bash "$repository/tests/support/legacy-view.sh" "$TEST_HARNESS_ROOT" || exit 2
failed=0
if [ "$#" -eq 0 ]; then set -- guards status completion delivery html-page plugin packaging specs-app; fi
for suite in "$@"; do
  bash "$repository/tests/test-$suite.sh" > "$work/$suite.log" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then cat "$work/$suite.log"; failed=1
  else tail -6 "$work/$suite.log"; fi
done
exit "$failed"
