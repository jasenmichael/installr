#!/usr/bin/env bash
set -euo pipefail

INSTALLR_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/config.sh
source "$INSTALLR_ROOT/lib/config.sh"
# shellcheck source=lib/validate.sh
source "$INSTALLR_ROOT/lib/validate.sh"
# shellcheck source=lib/emit.sh
source "$INSTALLR_ROOT/lib/emit.sh"
# shellcheck source=lib/main.sh
source "$INSTALLR_ROOT/lib/main.sh"

main "$@"
