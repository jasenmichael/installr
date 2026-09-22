main() {
  local config=${INSTALLR_CONFIG:-./installr.conf}
  local output=${INSTALLR_OUTPUT:-}
  local check=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --check)
        check=1
        shift
        ;;
      --config)
        [[ $# -ge 2 ]] || {
          printf 'installr: --config needs a path\n' >&2
          exit 2
        }
        config=$2
        shift 2
        ;;
      --output)
        [[ $# -ge 2 ]] || {
          printf 'installr: --output needs a path\n' >&2
          exit 2
        }
        output=$2
        shift 2
        ;;
      *)
        printf 'installr: unknown argument: %s\n' "$1" >&2
        exit 2
        ;;
    esac
  done
  load_config "$config"
  validate_config
  if [[ $check == 1 ]]; then
    exit 0
  fi
  if [[ -z $output ]]; then
    output=${CONF[INSTALL_SCRIPT]:-install.sh}
  fi
  emit_install_sh "$output"
}
