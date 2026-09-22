# Read installr.conf. Assignments only. The file is not sourced.

declare -gA CONF=()

config_key_known() {
  case "$1" in
    APP_NAME | SOURCE | GH_ASSET_URL | INSTALL_SCRIPT | REPO_URL | REPO_REF | BUILD | DEPS | BIN | \
      SCOPE | LOCAL_PREFIX | GLOBAL_PREFIX | DEFAULT_CONFIG | CONFIG_EXT | CONFIG_PATH | \
      VERSION | GH_VERSION | GH_EXT | GH_REPO | GH_ARCHIVE | GH_BIN_PATH | \
      GH_BIN_PATH_linux_amd64 | GH_BIN_PATH_linux_arm64 | GH_BIN_PATH_darwin_amd64 | GH_BIN_PATH_darwin_arm64 | \
      BIN_linux_amd64 | BIN_linux_arm64 | BIN_darwin_amd64 | BIN_darwin_arm64) return 0 ;;
    *) return 1 ;;
  esac
}

# Resolve CONF[VERSION] into APP_VERSION_RESOLVED (literal or !command).
# Empty VERSION leaves APP_VERSION_RESOLVED empty (install.sh --version → unknown).
declare -g APP_VERSION_RESOLVED=""

resolve_version() {
  local raw=${CONF[VERSION]:-} out
  APP_VERSION_RESOLVED=""
  [[ -z $raw ]] && return 0
  if [[ $raw == !* ]]; then
    if ! out=$(bash -lc "${raw#!}"); then
      printf 'installr: VERSION command failed\n' >&2
      exit 1
    fi
  else
    out=$raw
  fi
  out=${out#"${out%%[![:space:]]*}"}
  out=${out%"${out##*[![:space:]]}"}
  if [[ -z $out ]]; then
    printf 'installr: VERSION produced empty output\n' >&2
    exit 1
  fi
  APP_VERSION_RESOLVED=$out
}

load_config() {
  local file=$1 line key val
  if [[ ! -f $file ]]; then
    printf 'installr: config not found: %s\n' "$file" >&2
    exit 1
  fi
  CONF=()
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    [[ -z $line || $line == \#* ]] && continue
    if [[ $line != *=* ]]; then
      printf 'installr: invalid config line: %s\n' "$line" >&2
      exit 1
    fi
    key=${line%%=*}
    key=${key%"${key##*[![:space:]]}"}
    val=${line#*=}
    if [[ $val == \"*\" && $val == *\" ]]; then
      val=${val#\"}
      val=${val%\"}
    elif [[ $val == \'*\' && $val == *\' ]]; then
      val=${val#\'}
      val=${val%\'}
    fi
    if ! config_key_known "$key"; then
      printf 'installr: unknown key: %s\n' "$key" >&2
      exit 1
    fi
    CONF[$key]=$val
  done < "$file"
}
