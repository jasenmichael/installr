LOCAL_PREFIX=__LOCAL_PREFIX__
GLOBAL_PREFIX=__GLOBAL_PREFIX__

if [[ $SCOPE == global ]]; then
  PREFIX=$GLOBAL_PREFIX
  APP_DIR=$PREFIX/$APP_NAME
  BIN_DIR=$PREFIX/bin
else
  PREFIX=$LOCAL_PREFIX
  APP_DIR=$PREFIX/share/$APP_NAME
  BIN_DIR=$PREFIX/bin
fi
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
