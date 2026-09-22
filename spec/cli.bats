#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  INSTALLR="$REPO_ROOT/src/installr.sh"
  WORK=$(mktemp -d)
  cd "$WORK"
}

teardown() {
  rm -rf "$WORK"
}

@test "missing APP_NAME exits 1 and names the field" {
  printf 'SOURCE=github_release\n' > installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"APP_NAME"* ]]
}

@test "release config emits header, os and arch detection, and the asset URL" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  [ -f install.sh ]
  [ "$(head -n 1 install.sh)" = '#!/usr/bin/env bash' ]
  grep -q 'set -euo pipefail' install.sh
  grep -q 'uname -s' install.sh
  grep -q 'Darwin' install.sh
  grep -q 'linux' install.sh
  grep -q 'uname -m' install.sh
  grep -q 'amd64' install.sh
  grep -q 'arm64' install.sh
  grep -F -q 'https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}' install.sh
  grep -q 'curl' install.sh
}

@test "INSTALL_SCRIPT selects the output path" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}
INSTALL_SCRIPT=custom.sh
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  [ -f custom.sh ]
  [ ! -e install.sh ]
}

@test "INSTALLR_OUTPUT overrides INSTALL_SCRIPT" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}
INSTALL_SCRIPT=from-file.sh
EOF
  run --separate-stderr env INSTALLR_OUTPUT=from-env.sh "$INSTALLR"
  [ "$status" -eq 0 ]
  [ -f from-env.sh ]
  [ ! -e from-file.sh ]
}

@test "--output overrides INSTALLR_OUTPUT" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}
INSTALL_SCRIPT=from-file.sh
EOF
  run --separate-stderr env INSTALLR_OUTPUT=from-env.sh "$INSTALLR" --output from-flag.sh
  [ "$status" -eq 0 ]
  [ -f from-flag.sh ]
  [ ! -e from-env.sh ]
  [ ! -e from-file.sh ]
}

@test "--config overrides INSTALLR_CONFIG" {
  cat > from-env.conf <<'EOF'
APP_NAME=from-env
SOURCE=github_release
GH_ASSET_URL=https://example.com/env
EOF
  cat > from-flag.conf <<'EOF'
APP_NAME=from-flag
SOURCE=github_release
GH_ASSET_URL=https://example.com/flag-asset
EOF
  run --separate-stderr env INSTALLR_CONFIG=from-env.conf "$INSTALLR" --config from-flag.conf
  [ "$status" -eq 0 ]
  grep -q 'from-flag' install.sh
  grep -F -q 'https://example.com/flag-asset' install.sh
  ! grep -q 'from-env' install.sh
}

@test "--check exits 0 and writes nothing" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}
EOF
  run --separate-stderr "$INSTALLR" --check
  [ "$status" -eq 0 ]
  [ ! -e install.sh ]
}

@test "repo config emits git clone and omits the release download" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BIN=dist/{{name}}
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  grep -q 'git clone' install.sh
  grep -F -q 'https://github.com/acme/myapp.git' install.sh
  ! grep -q 'curl -fsSL' install.sh
}

@test "BIN pattern with placeholders is baked into install.sh" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BIN=dist/{{name}}-{{os}}-{{arch}}
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  grep -F -q 'dist/{{name}}-{{os}}-{{arch}}' install.sh
  ! grep -q 'BIN_linux_amd64' install.sh
}

@test "BIN_* override wins over BIN for that platform" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BIN=dist/{{name}}-{{os}}-{{arch}}
BIN_darwin_arm64=out/apple-silicon
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  grep -F -q 'dist/{{name}}-{{os}}-{{arch}}' install.sh
  grep -F -q 'out/apple-silicon' install.sh
}

@test "repo with neither BIN nor BIN_* fails and names BIN" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"BIN"* ]]
}

@test "BIN_* alone without BIN is valid" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BIN_linux_amd64=dist/linux-only
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  grep -F -q 'dist/linux-only' install.sh
}

@test "BUILD is baked into the repo install.sh" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BUILD=make build-dummy
BIN=dist/{{name}}
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  grep -F -q 'make build-dummy' install.sh
}

@test "empty BUILD omits the build command" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BIN=dist/{{name}}
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  ! grep -q 'build-dummy' install.sh
  ! grep -q 'bash -lc' install.sh
}

@test "release install.sh does not clone" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  ! grep -q 'git clone' install.sh
}

@test "empty DEPS omits the dep loop" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  ! grep -q 'for dep in' install.sh
}

@test "DEPS are checked in install.sh" {
  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}
DEPS=make jq
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  grep -F -q 'for dep in make jq; do' install.sh
}

@test "bad SOURCE exits 1 and names the field" {
  printf 'APP_NAME=dummy\nSOURCE=nope\n' > installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"SOURCE"* ]]
}

@test "bad SCOPE exits 1 and names the field" {
  cat > installr.conf <<'EOF'
APP_NAME=dummy
SOURCE=github_release
GH_ASSET_URL=https://example.com/x
SCOPE=both
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"SCOPE"* ]]
}

@test "example config passes --check" {
  run --separate-stderr "$INSTALLR" --check --config "$REPO_ROOT/installr.conf.example"
  [ "$status" -eq 0 ]
}
