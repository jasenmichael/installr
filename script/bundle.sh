#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$ROOT/bin"

INSTALLR_VERSION=unknown
if [[ -f $ROOT/VERSION ]]; then
  INSTALLR_VERSION=$(< "$ROOT/VERSION")
  INSTALLR_VERSION=${INSTALLR_VERSION#"${INSTALLR_VERSION%%[![:space:]]*}"}
  INSTALLR_VERSION=${INSTALLR_VERSION%"${INSTALLR_VERSION##*[![:space:]]}"}
  [[ -n $INSTALLR_VERSION ]] || INSTALLR_VERSION=unknown
fi

{
  # Emit project header into bin/installr (same short # style as share/fragments/header.sh).
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    '# installr - reads installr.conf, validates it, writes install.sh for a CLI app.' \
    '# https://github.com/jasenmichael/installr' \
    '# Curl one-file: https://github.com/jasenmichael/installr/raw/main/bin/installr' \
    'set -euo pipefail' \
    'INSTALLR_EMBEDDED=1'
  printf "INSTALLR_VERSION=%q\n" "$INSTALLR_VERSION"
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
