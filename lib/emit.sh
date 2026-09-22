q() {
  local s=$1
  s=${s//\'/\'\\\'\'}
  printf "'%s'" "$s"
}

replace_token() {
  local text=$1 token=$2 value=$3 pre post
  while [[ $text == *"$token"* ]]; do
    pre=${text%%"$token"*}
    post=${text#*"$token"}
    text=$pre$value$post
  done
  printf '%s' "$text"
}

render_fragment() {
  local name=$1 text bin_path=${CONF[GH_BIN_PATH]:-}
  if [[ -z $bin_path ]]; then
    bin_path='{{name}}'
  fi
  if [[ -n ${INSTALLR_EMBEDDED:-} ]]; then
    local var="FRAGMENT_${name}"
    text=${!var-}
  else
    text=$(< "$INSTALLR_ROOT/share/fragments/${name}.sh")
  fi
  local gh_version=${CONF[GH_VERSION]:-latest}
  if [[ -n $APP_VERSION_RESOLVED ]]; then
    gh_version=$APP_VERSION_RESOLVED
  fi
  local app_version=${APP_VERSION_RESOLVED:-unknown}
  text=$(replace_token "$text" __Q_APP_NAME__ "$(q "${CONF[APP_NAME]}")")
  text=$(replace_token "$text" __Q_APP_VERSION__ "$(q "$app_version")")
  text=$(replace_token "$text" __Q_GH_ASSET_URL__ "$(q "${CONF[GH_ASSET_URL]:-}")")
  text=$(replace_token "$text" __Q_GH_VERSION__ "$(q "$gh_version")")
  text=$(replace_token "$text" __Q_GH_EXT__ "$(q "${CONF[GH_EXT]:-}")")
  text=$(replace_token "$text" __Q_GH_REPO__ "$(q "${CONF[GH_REPO]:-}")")
  text=$(replace_token "$text" __Q_GH_ARCHIVE__ "$(q "${CONF[GH_ARCHIVE]:-}")")
  text=$(replace_token "$text" __Q_GH_BIN_PATH__ "$(q "$bin_path")")
  text=$(replace_token "$text" __Q_REPO_URL__ "$(q "${CONF[REPO_URL]:-}")")
  text=$(replace_token "$text" __Q_REPO_REF__ "$(q "${CONF[REPO_REF]:-main}")")
  text=$(replace_token "$text" __Q_BIN__ "$(q "${CONF[BIN]:-}")")
  text=$(replace_token "$text" __Q_BIN_linux_amd64__ "$(q "${CONF[BIN_linux_amd64]:-}")")
  text=$(replace_token "$text" __Q_BIN_linux_arm64__ "$(q "${CONF[BIN_linux_arm64]:-}")")
  text=$(replace_token "$text" __Q_BIN_darwin_amd64__ "$(q "${CONF[BIN_darwin_amd64]:-}")")
  text=$(replace_token "$text" __Q_BIN_darwin_arm64__ "$(q "${CONF[BIN_darwin_arm64]:-}")")
  text=$(replace_token "$text" __Q_GH_BIN_PATH_linux_amd64__ "$(q "${CONF[GH_BIN_PATH_linux_amd64]:-}")")
  text=$(replace_token "$text" __Q_GH_BIN_PATH_linux_arm64__ "$(q "${CONF[GH_BIN_PATH_linux_arm64]:-}")")
  text=$(replace_token "$text" __Q_GH_BIN_PATH_darwin_amd64__ "$(q "${CONF[GH_BIN_PATH_darwin_amd64]:-}")")
  text=$(replace_token "$text" __Q_GH_BIN_PATH_darwin_arm64__ "$(q "${CONF[GH_BIN_PATH_darwin_arm64]:-}")")
  text=$(replace_token "$text" __Q_BUILD__ "$(q "${CONF[BUILD]:-}")")
  text=$(replace_token "$text" __DEPS__ "$(deps_literal)")
  text=$(replace_token "$text" __Q_SCOPE_LOCK__ "$(q "${CONF[SCOPE]:-}")")
  if [[ -n ${CONF[LOCAL_PREFIX]:-} ]]; then
    text=$(replace_token "$text" __LOCAL_PREFIX__ "$(q "${CONF[LOCAL_PREFIX]}")")
  else
    text=$(replace_token "$text" __LOCAL_PREFIX__ '${HOME}/.local')
  fi
  if [[ -n ${CONF[GLOBAL_PREFIX]:-} ]]; then
    text=$(replace_token "$text" __GLOBAL_PREFIX__ "$(q "${CONF[GLOBAL_PREFIX]}")")
  else
    text=$(replace_token "$text" __GLOBAL_PREFIX__ '/usr/local')
  fi
  text=$(replace_token "$text" __Q_DEFAULT_CONFIG__ "$(q "${CONF[DEFAULT_CONFIG]:-}")")
  text=$(replace_token "$text" __Q_CONFIG_EXT__ "$(q "${CONF[CONFIG_EXT]:-toml}")")
  if [[ -n ${CONF[CONFIG_PATH]:-} ]]; then
    text=$(replace_token "$text" __CONFIG_DEST__ "$(q "${CONF[CONFIG_PATH]}")")
  else
    text=$(replace_token "$text" __CONFIG_DEST__ '$HOME/.config/$APP_NAME.$CONFIG_EXT')
  fi
  printf '%s\n' "$text"
}

deps_literal() {
  local w out=""
  # shellcheck disable=SC2086
  for w in ${CONF[DEPS]:-}; do
    out+="$w "
  done
  printf '%s' "${out% }"
}

emit_install_sh() {
  local out=$1
  {
    render_fragment header
    render_fragment os_arch
    if [[ -n ${CONF[DEPS]:-} ]]; then
      render_fragment deps
    fi
    if [[ ${CONF[SOURCE]} == github_release ]]; then
      render_fragment fetch_release
    else
      render_fragment fetch_repo
      if [[ -n ${CONF[BUILD]:-} ]]; then
        render_fragment build
      fi
    fi
    render_fragment install_bin
    render_fragment install_config
    render_fragment install_record
  } > "$out"
  chmod +x "$out"
}
