FILES_MODE=__FILES_MODE__
FILES_SPEC=__Q_FILES__
if [[ $FILES_MODE == list ]]; then
  IFS=',' read -ra _files_items <<< "$FILES_SPEC"
  _files_rels=()
  for _files_raw in "${_files_items[@]}"; do
    item=${_files_raw#"${_files_raw%%[![:space:]]*}"}
    item=${item%"${item##*[![:space:]]}"}
    item=${item%/}
    if [[ $item == *'*'* || $item == *'?'* || $item == *'['* ]]; then
      _files_matches=()
      while IFS= read -r _files_match; do
        [[ -n $_files_match ]] || continue
        _files_matches+=("$_files_match")
      done < <(cd "$STAGE" && compgen -G "$item" || true)
      if [[ ${#_files_matches[@]} -eq 0 ]]; then
        printf 'install.sh: FILES missing: %s\n' "$item" >&2
        exit 1
      fi
      for _files_match in "${_files_matches[@]}"; do
        _files_rels+=("$_files_match")
      done
    else
      if [[ ! -e "$STAGE/$item" ]]; then
        printf 'install.sh: FILES missing: %s\n' "$item" >&2
        exit 1
      fi
      _files_rels+=("$item")
    fi
  done
  as_root mkdir -p -- "$APP_DIR"
  for rel in "${_files_rels[@]}"; do
    dest=$APP_DIR/$rel
    as_root mkdir -p -- "$(dirname -- "$dest")"
    if [[ -d $STAGE/$rel ]]; then
      as_root cp -a -- "$STAGE/$rel" "$APP_DIR/$(dirname -- "$rel")/"
    else
      as_root cp -a -- "$STAGE/$rel" "$dest"
    fi
  done
  FILES_SUMMARY=""
  for rel in "${_files_rels[@]}"; do
    if [[ -z $FILES_SUMMARY ]]; then
      FILES_SUMMARY=$rel
    else
      FILES_SUMMARY="$FILES_SUMMARY, $rel"
    fi
  done
fi
