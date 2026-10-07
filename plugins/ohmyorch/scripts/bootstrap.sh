#!/bin/bash
set -uo pipefail
export OHMYORCH_ALLOW_UNCONFIGURED=1
source "$(cd -- "$(dirname -- "$0")/../lib" && pwd -P)/runtime.sh"
ohmyorch_init "$@"; set -- "${OHMYORCH_ARGS[@]+"${OHMYORCH_ARGS[@]}"}"
OHMYORCH_OPERATION=bootstrap
source "$OHMYORCH_CODE_ROOT/lib/lifecycle.sh"
ohmyorch_lifecycle_main "$@"
