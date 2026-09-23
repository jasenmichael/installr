DEFAULT_CONFIG=__Q_DEFAULT_CONFIG__
DEFAULT_CONFIG_BODY=__Q_DEFAULT_CONFIG_BODY__
CONFIG_EXT=__Q_CONFIG_EXT__
CONFIG_INSTALLED=no
CONFIG_DEST=
CONFIG_ACTION=skipped
if [[ -n $DEFAULT_CONFIG || -n $DEFAULT_CONFIG_BODY ]]; then
  CONFIG_DEST=__CONFIG_DEST__
  replace=no
  existed=no
  if [[ -e $CONFIG_DEST ]]; then
    existed=yes
  fi
  if [[ $existed == no ]]; then
    replace=yes
  elif [[ $ASSUME_YES == yes ]]; then
    replace=yes
  else
    read -r -p "Replace $CONFIG_DEST? [y/N] " ans || true
    if [[ ${ans:-} == y || ${ans:-} == Y || ${ans:-} == yes ]]; then
      replace=yes
    fi
  fi
  if [[ $replace == yes ]]; then
    mkdir -p -- "$(dirname -- "$CONFIG_DEST")"
    if [[ -n $DEFAULT_CONFIG_BODY ]]; then
      printf '%s\n' "$DEFAULT_CONFIG_BODY" > "$CONFIG_DEST"
    else
      cp -- "$STAGE/$DEFAULT_CONFIG" "$CONFIG_DEST"
    fi
    CONFIG_INSTALLED=yes
    if [[ $existed == yes ]]; then
      CONFIG_ACTION=replaced
    else
      CONFIG_ACTION=copied
    fi
  else
    CONFIG_ACTION=left
  fi
fi
