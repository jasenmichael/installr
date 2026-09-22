#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$ROOT/bin"

{
  printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' 'INSTALLR_EMBEDDED=1'
  local_name=""
  for fragment in "$ROOT"/share/fragments/*.sh; do
    local_name=$(basename "$fragment" .sh)
    printf 'FRAGMENT_%s=$(cat <<'\''INSTALLR_FRAGMENT_END'\''\n' "$local_name"
    cat "$fragment"
    printf '\nINSTALLR_FRAGMENT_END\n)\n'
  done
  cat "$ROOT/lib/config.sh"
  cat "$ROOT/lib/validate.sh"
  cat "$ROOT/lib/emit.sh"
  cat "$ROOT/lib/main.sh"
  printf '%s\n' 'main "$@"'
} > "$ROOT/bin/installr"

chmod +x "$ROOT/bin/installr"
