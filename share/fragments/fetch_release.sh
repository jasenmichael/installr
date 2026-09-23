if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  printf 'install.sh: need curl or wget\n' >&2
  exit 1
fi

GH_VERSION=__Q_GH_VERSION__
GH_EXT=__Q_GH_EXT__
GH_REPO=__Q_GH_REPO__
GH_ARCHIVE=__Q_GH_ARCHIVE__
BIN_INSIDE=__Q_GH_BIN_PATH__
BIN_INSIDE_OVERRIDE=
case "${OS}_${ARCH}" in
  linux_amd64) BIN_INSIDE_OVERRIDE=__Q_GH_BIN_PATH_linux_amd64__ ;;
  linux_arm64) BIN_INSIDE_OVERRIDE=__Q_GH_BIN_PATH_linux_arm64__ ;;
  darwin_amd64) BIN_INSIDE_OVERRIDE=__Q_GH_BIN_PATH_darwin_amd64__ ;;
  darwin_arm64) BIN_INSIDE_OVERRIDE=__Q_GH_BIN_PATH_darwin_arm64__ ;;
esac
if [[ -n $BIN_INSIDE_OVERRIDE ]]; then
  BIN_INSIDE=$BIN_INSIDE_OVERRIDE
fi

ASSET_URL=__Q_GH_ASSET_URL__
ASSET_URL=${ASSET_URL//\{\{name\}\}/$APP_NAME}
ASSET_URL=${ASSET_URL//\{\{os\}\}/$OS}
ASSET_URL=${ASSET_URL//\{\{arch\}\}/$ARCH}
ASSET_URL=${ASSET_URL//\{\{version\}\}/$GH_VERSION}
ASSET_URL=${ASSET_URL//\{\{ext\}\}/$GH_EXT}
ASSET_URL=${ASSET_URL//\{\{repo\}\}/$GH_REPO}
BIN_INSIDE=${BIN_INSIDE//\{\{name\}\}/$APP_NAME}
BIN_INSIDE=${BIN_INSIDE//\{\{os\}\}/$OS}
BIN_INSIDE=${BIN_INSIDE//\{\{arch\}\}/$ARCH}
BIN_INSIDE=${BIN_INSIDE//\{\{version\}\}/$GH_VERSION}
BIN_INSIDE=${BIN_INSIDE//\{\{ext\}\}/$GH_EXT}
BIN_INSIDE=${BIN_INSIDE//\{\{repo\}\}/$GH_REPO}

if [[ -z $GH_ARCHIVE ]]; then
  case $ASSET_URL in
    *.tar.gz | *.tgz) GH_ARCHIVE=tar.gz ;;
    *.zip) GH_ARCHIVE=zip ;;
    *) GH_ARCHIVE=raw ;;
  esac
fi

fetch_asset() {
  local dest=$1
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$ASSET_URL" -o "$dest"
  else
    wget -q -O "$dest" "$ASSET_URL"
  fi
}

FILES_MODE=__FILES_MODE__
if [[ $FILES_MODE == star ]]; then
  if [[ -e $APP_DIR ]]; then
    printf 'install.sh: APP_DIR exists and is not a git repo: %s\n' "$APP_DIR" >&2
    exit 1
  fi
  as_root mkdir -p -- "$APP_DIR"
  archive_tmp=$(mktemp)
  fetch_asset "$archive_tmp"
  case $GH_ARCHIVE in
    tar.gz)
      as_root tar -xzf "$archive_tmp" -C "$APP_DIR"
      ;;
    zip)
      as_root unzip -q "$archive_tmp" -d "$APP_DIR"
      ;;
    *)
      printf 'install.sh: FILES=* needs a tree\n' >&2
      exit 1
      ;;
  esac
  rm -f -- "$archive_tmp"
  STAGE=$APP_DIR
  FETCHED_BIN=$STAGE/$BIN_INSIDE
else
STAGE=$(mktemp -d)
case $GH_ARCHIVE in
  raw)
    fetch_asset "$STAGE/$APP_NAME"
    FETCHED_BIN=$STAGE/$APP_NAME
    ;;
  tar.gz)
    fetch_asset "$STAGE/asset.tar.gz"
    tar -xzf "$STAGE/asset.tar.gz" -C "$STAGE"
    FETCHED_BIN=$STAGE/$BIN_INSIDE
    ;;
  zip)
    fetch_asset "$STAGE/asset.zip"
    unzip -q "$STAGE/asset.zip" -d "$STAGE"
    FETCHED_BIN=$STAGE/$BIN_INSIDE
    ;;
  *)
    printf 'install.sh: unknown archive: %s\n' "$GH_ARCHIVE" >&2
    exit 1
    ;;
esac
chmod +x "$FETCHED_BIN"
fi
