CONFIG_DEST=${CONFIG_DEST:-}
CONFIG_INSTALLED=${CONFIG_INSTALLED:-no}
USED_SUDO=${USED_SUDO:-no}

write_root() {
  local dest=$1
  if [[ $USED_SUDO == yes ]]; then
    sudo tee "$dest" >/dev/null
  else
    cat > "$dest"
  fi
}

write_root "$APP_DIR/install.log" <<EOF
APP_NAME=$APP_NAME
APP_DIR=$APP_DIR
BIN=$APP_DIR/$APP_NAME
SYMLINK=$BIN_DIR/$APP_NAME
CONFIG=$CONFIG_DEST
CONFIG_INSTALLED=$CONFIG_INSTALLED
SUDO=$USED_SUDO
EOF

write_root "$APP_DIR/uninstall.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LOG=$HERE/install.log
if [[ ! -f $LOG ]]; then
  printf 'uninstall: missing install.log\n' >&2
  exit 1
fi

log_get() {
  local key=$1 line k v
  while IFS= read -r line || [[ -n $line ]]; do
    [[ -z $line || $line == \#* ]] && continue
    k=${line%%=*}
    v=${line#*=}
    if [[ $k == "$key" ]]; then
      printf '%s' "$v"
      return 0
    fi
  done < "$LOG"
  return 1
}

APP_DIR=$(log_get APP_DIR || true)
if [[ -z ${APP_DIR:-} || $APP_DIR != "$HERE" ]]; then
  printf 'uninstall: APP_DIR mismatch\n' >&2
  exit 1
fi
if [[ $APP_DIR == / || $APP_DIR == "${HOME:-}" ]]; then
  printf 'uninstall: refusing %s\n' "$APP_DIR" >&2
  exit 1
fi

SUDO_NEEDED=$(log_get SUDO || true)
SYMLINK=$(log_get SYMLINK || true)
CONFIG=$(log_get CONFIG || true)
CONFIG_INSTALLED=$(log_get CONFIG_INSTALLED || true)

run_rm() {
  if [[ ${SUDO_NEEDED:-} == yes ]]; then
    sudo rm -rf -- "$@"
  else
    rm -rf -- "$@"
  fi
}

if [[ -n ${SYMLINK:-} ]]; then
  run_rm "$SYMLINK"
fi
if [[ ${CONFIG_INSTALLED:-} == yes && -n ${CONFIG:-} ]]; then
  run_rm "$CONFIG"
fi
run_rm "$APP_DIR"
EOF
as_root chmod +x "$APP_DIR/uninstall.sh"
