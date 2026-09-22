#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  WORK=$(mktemp -d)
  cd "$WORK"
}

teardown() {
  rm -rf "$WORK"
}

@test "bin/installr is one file and works from disk and from stdin" {
  run --separate-stderr "$REPO_ROOT/script/bundle.sh"
  [ "$status" -eq 0 ]
  [ -x "$REPO_ROOT/bin/installr" ]
  ! grep -E 'source .*(lib/|share/)' "$REPO_ROOT/bin/installr"

  cat > installr.conf <<'EOF'
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}
EOF

  run --separate-stderr "$REPO_ROOT/bin/installr" --check --config "$WORK/installr.conf"
  [ "$status" -eq 0 ]
  [ ! -e install.sh ]

  run --separate-stderr bash -c 'cat "$1" | bash -s -- --check --config "$2"' bash "$REPO_ROOT/bin/installr" "$WORK/installr.conf"
  [ "$status" -eq 0 ]
  [ ! -e install.sh ]
}

@test "example and dogfood configs pass --check" {
  run --separate-stderr "$REPO_ROOT/src/installr.sh" --check --config "$REPO_ROOT/installr.conf.example"
  [ "$status" -eq 0 ]
  run --separate-stderr "$REPO_ROOT/src/installr.sh" --check --config "$REPO_ROOT/installr.conf"
  [ "$status" -eq 0 ]
}

@test "bundled bin/installr --version prints baked 0.1.0" {
  run --separate-stderr "$REPO_ROOT/script/bundle.sh"
  [ "$status" -eq 0 ]
  run --separate-stderr bash -c 'cat "$1" | bash -s -- --version' bash "$REPO_ROOT/bin/installr"
  [ "$status" -eq 0 ]
  [ "$output" = "installr 0.1.0" ]
}
