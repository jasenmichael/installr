command -v git >/dev/null 2>&1 || {
  printf 'install.sh: missing dep: git\n' >&2
  exit 1
}

STAGE=$(mktemp -d)
git clone --depth 1 --branch __Q_REPO_REF__ __Q_REPO_URL__ "$STAGE"

BIN_PATTERN=__Q_BIN__
BIN_OVERRIDE=
case "${OS}_${ARCH}" in
  linux_amd64) BIN_OVERRIDE=__Q_BIN_linux_amd64__ ;;
  linux_arm64) BIN_OVERRIDE=__Q_BIN_linux_arm64__ ;;
  darwin_amd64) BIN_OVERRIDE=__Q_BIN_darwin_amd64__ ;;
  darwin_arm64) BIN_OVERRIDE=__Q_BIN_darwin_arm64__ ;;
  *)
    printf 'install.sh: no binary for %s-%s\n' "$OS" "$ARCH" >&2
    exit 1
    ;;
esac

if [[ -n $BIN_OVERRIDE ]]; then
  BIN_REL=$BIN_OVERRIDE
elif [[ -n $BIN_PATTERN ]]; then
  BIN_REL=$BIN_PATTERN
  BIN_REL=${BIN_REL//\{\{name\}\}/$APP_NAME}
  BIN_REL=${BIN_REL//\{\{os\}\}/$OS}
  BIN_REL=${BIN_REL//\{\{arch\}\}/$ARCH}
else
  printf 'install.sh: no binary path for %s-%s\n' "$OS" "$ARCH" >&2
  exit 1
fi

FETCHED_BIN=$STAGE/$BIN_REL
