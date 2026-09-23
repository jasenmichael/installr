print_help() {
  cat <<'EOF'
installr — turn installr.conf into an install.sh for your CLI app.

Usage: installr [options]

Options:
  -h, --help           Show this help and exit (no config required).
  -v, --version        Print installr's version and exit (no config required).
  --config PATH        Config file (default: ./installr.conf).
  --output PATH        Path to write install.sh.
  --check              Validate config only; write nothing.

Environment:
  INSTALLR_CONFIG      Default config path (overridden by --config).
  INSTALLR_OUTPUT      Default output path (overridden by --output).

Exit codes:
  0  Success (help, version, --check, or install.sh written).
  1  Invalid config (stderr names the field).
  2  Usage error (unknown flag or missing flag argument).

Config keys (installr.conf; KEY=value; not sourced):

  App
    APP_NAME           required — installed command and app dir name.
    SOURCE             required — repo | github_release.

  Output
    INSTALL_SCRIPT     optional, default install.sh — path installr writes.

  Scope lock
    SCOPE              optional, omit = user chooses (default local) —
                       author lock: local rejects --global; global rejects --local.

  Prefixes
    LOCAL_PREFIX       optional, default $HOME/.local — local root;
                       app $LOCAL_PREFIX/share/$APP_NAME, bin $LOCAL_PREFIX/bin.
    GLOBAL_PREFIX      optional, default /usr/local — global root;
                       app $GLOBAL_PREFIX/$APP_NAME, bin $GLOBAL_PREFIX/bin.

  App config
    CONFIG_EXT         optional, default toml — used when CONFIG_PATH empty.
    CONFIG_PATH        optional, default $HOME/.config/$APP_NAME.$CONFIG_EXT —
                       destination for default config.
    DEFAULT_CONFIG     optional, empty — omit writes no settings file.
                       Path inside the fetched tree, or a command:
                       DEFAULT_CONFIG=!cat path/to/app.toml
                       ! runs via bash -lc at generate time; trim stdout;
                       non-zero or empty → exit 1. No ! means a path, never run.
                       Same replace prompt and --yes rules either way.

  App dir payload
    FILES              optional, empty — omit = binary only (files: binary).
                       FILES=* puts the fetched tree in the app dir
                       (git clone includes .git; archive unpacks; raw asset errors).
                       Or a comma-separated list copied beside the binary.
                       Quote the whole value: FILES="lib/, data/*".
                       Globs expand at install time and keep repo paths.
                       * mixed with other items, absolute paths, and .. fail.

  Deps
    DEPS               optional, empty — space-separated PATH commands to require.

  Repo source (SOURCE=repo)
    REPO_URL           required for repo — git remote or local path.
    REPO_REF           optional, default main — branch or tag.
    BUILD              optional, empty — shell command in clone after fetch.
    BIN                required for repo unless BIN_* set — binary path pattern.
    BIN_linux_amd64, BIN_linux_arm64, BIN_darwin_amd64, BIN_darwin_arm64
                       optional — per-platform override; wins over BIN.

  GitHub release (SOURCE=github_release)
    GH_ASSET_URL       required for release — download URL pattern.
    GH_REPO            optional, empty — substituted as {{repo}}.
    GH_VERSION         optional, default latest — substituted as {{version}}
                       when VERSION is unset.
    GH_EXT             optional, empty — substituted as {{ext}}.
    GH_ARCHIVE         optional, from URL — raw | tar.gz | zip.
    GH_BIN_PATH        optional, default {{name}} — path inside archive.
    GH_BIN_PATH_linux_amd64, GH_BIN_PATH_linux_arm64,
    GH_BIN_PATH_darwin_amd64, GH_BIN_PATH_darwin_arm64
                       optional — per-platform archive path override.

  Version
    VERSION            optional — app version baked into install.sh.
                       Literal: VERSION=1.4.2 (no leading !).
                       Command: VERSION=!cat VERSION — run via bash -lc at
                       generate time; trim stdout; non-zero or empty → exit 1.
                       When set, resolved value overrides GH_VERSION for
                       {{version}}. install.sh -v prints APP_NAME <resolved>
                       (or APP_NAME unknown if VERSION omitted).

Placeholders (BIN, GH_ASSET_URL, GH_BIN_PATH, GH_BIN_PATH_*):
  {{name}} {{os}} {{arch}} {{version}} {{ext}} {{repo}}

Docs: README.md · https://github.com/jasenmichael/installr#readme
EOF
}

print_version() {
  local ver=${INSTALLR_VERSION:-}
  if [[ -z $ver && -n ${INSTALLR_ROOT:-} && -f $INSTALLR_ROOT/VERSION ]]; then
    ver=$(< "$INSTALLR_ROOT/VERSION")
    ver=${ver#"${ver%%[![:space:]]*}"}
    ver=${ver%"${ver##*[![:space:]]}"}
  fi
  printf 'installr %s\n' "${ver:-unknown}"
}

main() {
  local config=${INSTALLR_CONFIG:-./installr.conf}
  local output=${INSTALLR_OUTPUT:-}
  local check=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help)
        print_help
        exit 0
        ;;
      -v | --version)
        print_version
        exit 0
        ;;
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
  resolve_version
  resolve_default_config
  if [[ $check == 1 ]]; then
    exit 0
  fi
  if [[ -z $output ]]; then
    output=${CONF[INSTALL_SCRIPT]:-install.sh}
  fi
  emit_install_sh "$output"
}
