#!/bin/bash
# Test-only compatibility launchers. Consumer projects never receive these files.
set -euo pipefail
repository=$(cd -- "$(dirname -- "$0")/../.." && pwd -P)
target="$1"
mkdir -p "$target/scripts/templates" "$target/.claude/rules"
cp -R "$repository/tests/fixtures" "$target/scripts/fixtures"
cp "$repository/plugins/ohmyorch/templates/artifacts/"*.md "$target/scripts/templates/"
cp "$repository/plugins/ohmyorch/templates/html-page.html" "$target/scripts/templates/"
cp "$repository/plugins/ohmyorch/README.md" "$target/README.md"
cp "$repository/plugins/ohmyorch/README.md" "$target/scripts/README.md"
cp "$repository/plugins/ohmyorch/references/rules/delivery-loop.md" "$target/.claude/rules/ohmyorch:delivery-loop.md"
cp "$repository/tests/fixtures/valid/SPECS.md" "$target/SPECS.md"
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
