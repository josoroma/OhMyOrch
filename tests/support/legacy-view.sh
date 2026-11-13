#!/bin/bash
# Test-only compatibility launchers. Consumer projects never receive these files.
set -euo pipefail
repository=$(cd -- "$(dirname -- "$0")/../.." && pwd -P)
target="$1"
mkdir -p "$target/scripts"
cp -R "$repository/tests/fixtures" "$target/scripts/fixtures"
for script in "$repository/plugins/ohmyorch/scripts/"*.sh; do
  name=${script##*/}
  cat > "$target/scripts/$name" <<'EOF'
#!/bin/bash
export OHMYORCH_PROJECT_ROOT="$(pwd -P)"
export OHMYORCH_SESSION_ID=regression
exec /bin/bash "$OHMYORCH_TEST_PLUGIN_ROOT/scripts/${0##*/}" "$@"
EOF
  chmod +x "$target/scripts/$name"
done
