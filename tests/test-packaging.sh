#!/bin/bash
set -uo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
exec python3 "$root/tests/test_packaging.py"
