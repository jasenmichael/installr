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
}
