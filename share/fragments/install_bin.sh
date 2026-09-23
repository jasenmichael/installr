FILES_MODE=__FILES_MODE__
if [[ $FILES_MODE == star ]]; then
  as_root mkdir -p -- "$BIN_DIR"
  as_root chmod +x "$FETCHED_BIN"
  as_root ln -sfn -- "$FETCHED_BIN" "$BIN_DIR/$APP_NAME"
  INSTALLED_BIN=$FETCHED_BIN
  FILES_SUMMARY='*'
else
  as_root mkdir -p -- "$APP_DIR" "$BIN_DIR"
  as_root cp -- "$FETCHED_BIN" "$APP_DIR/$APP_NAME"
  as_root chmod +x "$APP_DIR/$APP_NAME"
  as_root ln -sfn -- "$APP_DIR/$APP_NAME" "$BIN_DIR/$APP_NAME"
  INSTALLED_BIN=$APP_DIR/$APP_NAME
  if [[ $FILES_MODE != list ]]; then
    FILES_SUMMARY=binary
  fi
fi
