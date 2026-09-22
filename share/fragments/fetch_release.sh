command -v curl >/dev/null 2>&1 || {
  printf 'install.sh: missing dep: curl\n' >&2
  exit 1
}

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

STAGE=$(mktemp -d)
case $GH_ARCHIVE in
  raw)
    curl -fsSL "$ASSET_URL" -o "$STAGE/$APP_NAME"
    FETCHED_BIN=$STAGE/$APP_NAME
    ;;
  tar.gz)
    curl -fsSL "$ASSET_URL" -o "$STAGE/asset.tar.gz"
    tar -xzf "$STAGE/asset.tar.gz" -C "$STAGE"
    FETCHED_BIN=$STAGE/$BIN_INSIDE
    ;;
  zip)
    curl -fsSL "$ASSET_URL" -o "$STAGE/asset.zip"
    unzip -q "$STAGE/asset.zip" -d "$STAGE"
    FETCHED_BIN=$STAGE/$BIN_INSIDE
    ;;
  *)
    printf 'install.sh: unknown archive: %s\n' "$GH_ARCHIVE" >&2
    exit 1
    ;;
esac
chmod +x "$FETCHED_BIN"
