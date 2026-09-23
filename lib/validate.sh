validate_config() {
  if [[ -z ${CONF[APP_NAME]:-} ]]; then
    printf 'installr: APP_NAME is required\n' >&2
    exit 1
  fi
  case ${CONF[SOURCE]:-} in
    repo | github_release) ;;
    *)
      printf 'installr: SOURCE must be repo or github_release\n' >&2
      exit 1
      ;;
  esac
  if [[ -n ${CONF[SCOPE]:-} ]]; then
    case ${CONF[SCOPE]} in
      local | global) ;;
      *)
        printf 'installr: SCOPE must be local or global\n' >&2
        exit 1
        ;;
    esac
  fi
  if [[ ${CONF[SOURCE]} == github_release && -z ${CONF[GH_ASSET_URL]:-} ]]; then
    printf 'installr: GH_ASSET_URL is required\n' >&2
    exit 1
  fi
  if [[ ${CONF[SOURCE]} == repo ]]; then
    if [[ -z ${CONF[REPO_URL]:-} ]]; then
      printf 'installr: REPO_URL is required\n' >&2
      exit 1
    fi
    if [[ -z ${CONF[BIN]:-} && -z ${CONF[BIN_linux_amd64]:-} && -z ${CONF[BIN_linux_arm64]:-} && \
      -z ${CONF[BIN_darwin_amd64]:-} && -z ${CONF[BIN_darwin_arm64]:-} ]]; then
      printf 'installr: BIN is required\n' >&2
      exit 1
    fi
  fi
  validate_files
}

files_archive_kind() {
  local archive=${CONF[GH_ARCHIVE]:-} url=${CONF[GH_ASSET_URL]:-}
  if [[ -n $archive ]]; then
    printf '%s' "$archive"
    return
  fi
  case $url in
    *.tar.gz | *.tgz) printf 'tar.gz' ;;
    *.zip) printf 'zip' ;;
    *) printf 'raw' ;;
  esac
}

validate_files_item() {
  local item=$1
  if [[ -z $item ]]; then
    printf 'installr: FILES has an empty item\n' >&2
    exit 1
  fi
  if [[ $item == /* ]]; then
    printf 'installr: FILES must be a relative path\n' >&2
    exit 1
  fi
  if [[ $item == *..* ]]; then
    printf 'installr: FILES must not contain ..\n' >&2
    exit 1
  fi
}

validate_files() {
  local files=${CONF[FILES]:-} item
  files=${files#"${files%%[![:space:]]*}"}
  files=${files%"${files##*[![:space:]]}"}
  [[ -z $files ]] && return 0
  if [[ $files == '*' ]]; then
    if [[ ${CONF[SOURCE]} == github_release ]]; then
      case $(files_archive_kind) in
        tar.gz | zip) ;;
        *)
          printf 'installr: FILES=* needs a tree\n' >&2
          exit 1
          ;;
      esac
    fi
    return 0
  fi
  local IFS=','
  local -a items
  read -ra items <<< "$files"
  for item in "${items[@]}"; do
    item=${item#"${item%%[![:space:]]*}"}
    item=${item%"${item##*[![:space:]]}"}
    item=${item%/}
    if [[ $item == '*' ]]; then
      printf 'installr: FILES=* must be the only item\n' >&2
      exit 1
    fi
    validate_files_item "$item"
  done
}
