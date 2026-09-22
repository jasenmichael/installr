LOCAL_PREFIX=__LOCAL_PREFIX__
GLOBAL_PREFIX=__GLOBAL_PREFIX__

if [[ $SCOPE == global ]]; then
  PREFIX=$GLOBAL_PREFIX
else
  PREFIX=$LOCAL_PREFIX
fi

APP_DIR=$PREFIX/$APP_NAME
BIN_DIR=$PREFIX/bin
USED_SUDO=no
if [[ $SCOPE == global && $(id -u) -ne 0 ]]; then
  USED_SUDO=yes
fi

as_root() {
  if [[ $USED_SUDO == yes ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

as_root mkdir -p -- "$APP_DIR" "$BIN_DIR"
as_root cp -- "$FETCHED_BIN" "$APP_DIR/$APP_NAME"
as_root chmod +x "$APP_DIR/$APP_NAME"
as_root ln -sfn -- "$APP_DIR/$APP_NAME" "$BIN_DIR/$APP_NAME"

case :$PATH: in
  *:"$BIN_DIR":*) ;;
  *) printf 'export PATH="%s:$PATH"\n' "$BIN_DIR" ;;
esac
