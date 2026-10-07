#!/bin/bash
set -euo pipefail
repository=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
node --test "$repository/tests/test-specs-app.mjs"
