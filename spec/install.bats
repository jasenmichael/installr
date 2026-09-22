#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  INSTALLR="$REPO_ROOT/src/installr.sh"
  WORK=$(mktemp -d)
  cd "$WORK"
}

teardown() {
  rm -rf "$WORK" "${DUMMY_REPO:-}"
}

make_dummy_repo() {
  DUMMY_REPO=$(mktemp -d)
  cp "$REPO_ROOT/fixtures/dummy/dummy" "$DUMMY_REPO/dummy"
  cp "$REPO_ROOT/fixtures/dummy/dummy.toml" "$DUMMY_REPO/dummy.toml"
  chmod +x "$DUMMY_REPO/dummy"
  git -C "$DUMMY_REPO" init -b main
  git -C "$DUMMY_REPO" config user.email t@example.com
  git -C "$DUMMY_REPO" config user.name test
  git -C "$DUMMY_REPO" add .
  git -C "$DUMMY_REPO" commit -m init
}

prompt_install() {
  local answer=$1
  PROMPT_ANSWER=$answer HOME="$WORK/home" python3 - "$WORK/install.sh" <<'PY'
import os, pty, select, sys

cmd = [sys.argv[1]]
answer = os.environ["PROMPT_ANSWER"].encode()
pid, fd = pty.fork()
if pid == 0:
    os.execvp(cmd[0], cmd)
out = b""
sent = False
while True:
    ready, _, _ = select.select([fd], [], [], 10)
    if not ready:
        break
    try:
        chunk = os.read(fd, 4096)
    except OSError:
        break
    if not chunk:
        break
    out += chunk
    if not sent and b"Replace" in out:
        os.write(fd, answer)
        sent = True
_, status = os.waitpid(pid, 0)
sys.stdout.buffer.write(out)
if not sent:
    sys.stderr.write("prompt never appeared\n")
    raise SystemExit(2)
if os.WIFEXITED(status):
    raise SystemExit(os.WEXITSTATUS(status))
raise SystemExit(1)
PY
}

write_repo_config() {
  cat > installr.conf <<EOF
APP_NAME=dummy
SOURCE=repo
REPO_URL=$DUMMY_REPO
BIN=dummy
EOF
}

@test "installed dummy symlink prints dummy ok" {
  make_dummy_repo
  write_repo_config
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"wrote install.sh"* ]]
  mkdir -p "$WORK/home"
  run --separate-stderr env HOME="$WORK/home" "$WORK/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$WORK/home/.local/share/dummy"* ]]
  [[ "$output" == *"$WORK/home/.local/bin/dummy"* ]]
  [[ "$output" == *"config: skipped"* ]]
  [[ "$output" == *"scope: local"* ]]
  run --separate-stderr "$WORK/home/.local/bin/dummy"
  [ "$status" -eq 0 ]
  [ "$output" = "dummy ok" ]
}

@test "BIN pattern with os and arch installs the matching file" {
  DUMMY_REPO=$(mktemp -d)
  mkdir -p "$DUMMY_REPO/dist"
  cp "$REPO_ROOT/fixtures/dummy/dummy" "$DUMMY_REPO/dist/dummy-linux-amd64"
  cp "$REPO_ROOT/fixtures/dummy/dummy" "$DUMMY_REPO/dist/dummy-linux-arm64"
  cp "$REPO_ROOT/fixtures/dummy/dummy" "$DUMMY_REPO/dist/dummy-darwin-amd64"
  cp "$REPO_ROOT/fixtures/dummy/dummy" "$DUMMY_REPO/dist/dummy-darwin-arm64"
  chmod +x "$DUMMY_REPO"/dist/*
  git -C "$DUMMY_REPO" init -b main
  git -C "$DUMMY_REPO" config user.email t@example.com
  git -C "$DUMMY_REPO" config user.name test
  git -C "$DUMMY_REPO" add .
  git -C "$DUMMY_REPO" commit -m init
  cat > installr.conf <<EOF
APP_NAME=dummy
SOURCE=repo
REPO_URL=$DUMMY_REPO
BIN=dist/{{name}}-{{os}}-{{arch}}
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home"
  run --separate-stderr env HOME="$WORK/home" "$WORK/install.sh"
  [ "$status" -eq 0 ]
  run --separate-stderr "$WORK/home/.local/bin/dummy"
  [ "$status" -eq 0 ]
  [ "$output" = "dummy ok" ]
}

@test "install writes install.log and uninstall.sh with the real paths" {
  make_dummy_repo
  write_repo_config
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home"
  run --separate-stderr env HOME="$WORK/home" "$WORK/install.sh"
  [ "$status" -eq 0 ]
  local app="$WORK/home/.local/share/dummy"
  [ -f "$app/install.log" ]
  [ -x "$app/uninstall.sh" ]
  grep -F -q "APP_DIR=$app" "$app/install.log"
  grep -F -q "BIN=$app/dummy" "$app/install.log"
  grep -F -q "SYMLINK=$WORK/home/.local/bin/dummy" "$app/install.log"
}

@test "uninstall removes the app dir, symlink, and config it wrote" {
  make_dummy_repo
  write_repo_config
  printf 'DEFAULT_CONFIG=dummy.toml\nCONFIG_EXT=toml\n' >> installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home"
  run --separate-stderr env HOME="$WORK/home" "$WORK/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$WORK/home/.config/dummy.toml"* ]]
  [[ "$output" == *"config: copied"* ]]
  [ -f "$WORK/home/.config/dummy.toml" ]
  grep -F -q 'name = "dummy"' "$WORK/home/.config/dummy.toml"
  grep -F -q 'CONFIG_INSTALLED=yes' "$WORK/home/.local/share/dummy/install.log"
  run --separate-stderr "$WORK/home/.local/share/dummy/uninstall.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$WORK/home/.local/share/dummy" ]
  [ ! -e "$WORK/home/.local/bin/dummy" ]
  [ ! -e "$WORK/home/.config/dummy.toml" ]
}

@test "uninstall leaves a config it did not write" {
  make_dummy_repo
  write_repo_config
  printf 'DEFAULT_CONFIG=dummy.toml\n' >> installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home/.config"
  printf 'name = "keep"\n' > "$WORK/home/.config/dummy.toml"
  run --separate-stderr env HOME="$WORK/home" "$WORK/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: left in place $WORK/home/.config/dummy.toml"* ]]
  grep -F -q 'CONFIG_INSTALLED=no' "$WORK/home/.local/share/dummy/install.log"
  grep -F -q 'name = "keep"' "$WORK/home/.config/dummy.toml"
  run --separate-stderr "$WORK/home/.local/share/dummy/uninstall.sh"
  [ "$status" -eq 0 ]
  [ ! -e "$WORK/home/.local/share/dummy" ]
  [ ! -e "$WORK/home/.local/bin/dummy" ]
  grep -F -q 'name = "keep"' "$WORK/home/.config/dummy.toml"
}

@test "--yes replaces an existing config" {
  make_dummy_repo
  write_repo_config
  printf 'DEFAULT_CONFIG=dummy.toml\n' >> installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home/.config"
  printf 'name = "keep"\n' > "$WORK/home/.config/dummy.toml"
  run --separate-stderr env HOME="$WORK/home" "$WORK/install.sh" --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: replaced $WORK/home/.config/dummy.toml"* ]]
  grep -F -q 'name = "dummy"' "$WORK/home/.config/dummy.toml"
  grep -F -q 'CONFIG_INSTALLED=yes' "$WORK/home/.local/share/dummy/install.log"
}

@test "prompt answer n keeps an existing config" {
  python3 -c 'import pty; pty.openpty()' 2>/dev/null || skip "no pty"
  make_dummy_repo
  write_repo_config
  printf 'DEFAULT_CONFIG=dummy.toml\n' >> installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home/.config"
  printf 'name = "keep"\n' > "$WORK/home/.config/dummy.toml"
  run --separate-stderr prompt_install $'n\n'
  [ "$status" -eq 0 ]
  grep -F -q 'name = "keep"' "$WORK/home/.config/dummy.toml"
  grep -F -q 'CONFIG_INSTALLED=no' "$WORK/home/.local/share/dummy/install.log"
}

@test "prompt answer y replaces an existing config" {
  python3 -c 'import pty; pty.openpty()' 2>/dev/null || skip "no pty"
  make_dummy_repo
  write_repo_config
  printf 'DEFAULT_CONFIG=dummy.toml\n' >> installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home/.config"
  printf 'name = "keep"\n' > "$WORK/home/.config/dummy.toml"
  run --separate-stderr prompt_install $'y\n'
  [ "$status" -eq 0 ]
  grep -F -q 'name = "dummy"' "$WORK/home/.config/dummy.toml"
  grep -F -q 'CONFIG_INSTALLED=yes' "$WORK/home/.local/share/dummy/install.log"
}

@test "no SCOPE defaults to local without sudo" {
  make_dummy_repo
  write_repo_config
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home" "$WORK/bin"
  cat > "$WORK/bin/sudo" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$SUDO_LOG"
"$@"
EOF
  chmod +x "$WORK/bin/sudo"
  : > "$WORK/sudo.log"
  run --separate-stderr env HOME="$WORK/home" PATH="$WORK/bin:$PATH" SUDO_LOG="$WORK/sudo.log" "$WORK/install.sh"
  [ "$status" -eq 0 ]
  [ ! -s "$WORK/sudo.log" ]
  grep -F -q 'SUDO=no' "$WORK/home/.local/share/dummy/install.log"
  [ -x "$WORK/home/.local/bin/dummy" ]
}

@test "--global installs global and records SUDO=yes" {
  make_dummy_repo
  write_repo_config
  printf 'GLOBAL_PREFIX=%s\n' "$WORK/opt" >> installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home" "$WORK/bin"
  cat > "$WORK/bin/sudo" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$SUDO_LOG"
"$@"
EOF
  chmod +x "$WORK/bin/sudo"
  : > "$WORK/sudo.log"
  run --separate-stderr env HOME="$WORK/home" PATH="$WORK/bin:$PATH" SUDO_LOG="$WORK/sudo.log" "$WORK/install.sh" --global
  [ "$status" -eq 0 ]
  [[ "$output" == *"scope: global (sudo)"* ]]
  [ -s "$WORK/sudo.log" ]
  grep -F -q 'SUDO=yes' "$WORK/opt/dummy/install.log"
  : > "$WORK/sudo.log"
  run --separate-stderr env HOME="$WORK/home" PATH="$WORK/bin:$PATH" SUDO_LOG="$WORK/sudo.log" "$WORK/opt/dummy/uninstall.sh"
  [ "$status" -eq 0 ]
  grep -q 'rm' "$WORK/sudo.log"
  [ ! -e "$WORK/opt/dummy" ]
}

@test "SCOPE=global installs global without a flag" {
  make_dummy_repo
  write_repo_config
  printf 'SCOPE=global\nGLOBAL_PREFIX=%s\n' "$WORK/opt" >> installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home" "$WORK/bin"
  cat > "$WORK/bin/sudo" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$SUDO_LOG"
"$@"
EOF
  chmod +x "$WORK/bin/sudo"
  : > "$WORK/sudo.log"
  run --separate-stderr env HOME="$WORK/home" PATH="$WORK/bin:$PATH" SUDO_LOG="$WORK/sudo.log" "$WORK/install.sh"
  [ "$status" -eq 0 ]
  [ -s "$WORK/sudo.log" ]
  grep -F -q 'SUDO=yes' "$WORK/opt/dummy/install.log"
  [ -x "$WORK/opt/bin/dummy" ]
}

@test "SCOPE=local rejects --global and installs nothing" {
  make_dummy_repo
  write_repo_config
  printf 'SCOPE=local\n' >> installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home"
  run --separate-stderr env HOME="$WORK/home" "$WORK/install.sh" --global
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"SCOPE"* || "$stderr" == *"global"* ]]
  [ ! -e "$WORK/home/.local/share/dummy" ]
  [ ! -e "$WORK/opt/dummy" ]
}

@test "SCOPE=global rejects --local and installs nothing" {
  make_dummy_repo
  write_repo_config
  printf 'SCOPE=global\nGLOBAL_PREFIX=%s\n' "$WORK/opt" >> installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home"
  run --separate-stderr env HOME="$WORK/home" "$WORK/install.sh" --local
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"SCOPE"* || "$stderr" == *"local"* ]]
  [ ! -e "$WORK/home/.local/share/dummy" ]
  [ ! -e "$WORK/opt/dummy" ]
}

@test "missing dep fails before fetch" {
  make_dummy_repo
  write_repo_config
  printf 'DEPS=missing-cmd-xyz\n' >> installr.conf
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home" "$WORK/bin"
  cat > "$WORK/bin/git" <<'EOF'
#!/bin/bash
printf 'called\n' >> "$GIT_LOG"
exec /usr/bin/git "$@"
EOF
  chmod +x "$WORK/bin/git"
  : > "$WORK/git.log"
  run --separate-stderr env HOME="$WORK/home" PATH="$WORK/bin:$PATH" GIT_LOG="$WORK/git.log" "$WORK/install.sh"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"missing-cmd-xyz"* ]]
  [ ! -s "$WORK/git.log" ]
}

@test "github release tar.gz installs the binary from the archive" {
  mkdir -p "$WORK/home" "$WORK/bin" "$WORK/payload/pkg"
  cp "$REPO_ROOT/fixtures/dummy/dummy" "$WORK/payload/pkg/dummy"
  chmod +x "$WORK/payload/pkg/dummy"
  cat > "$WORK/bin/curl" <<EOF
#!/bin/bash
out=""
while [[ \$# -gt 0 ]]; do
  if [[ \$1 == -o ]]; then
    out=\$2
    shift 2
  else
    shift
  fi
done
tar -C "$WORK/payload" -czf "\$out" pkg
EOF
  chmod +x "$WORK/bin/curl"
  cat > installr.conf <<'EOF'
APP_NAME=dummy
SOURCE=github_release
GH_ASSET_URL=https://example.com/dummy-{{os}}-{{arch}}.tar.gz
GH_BIN_PATH=pkg/dummy
EOF
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  run --separate-stderr env HOME="$WORK/home" PATH="$WORK/bin:$PATH" "$WORK/install.sh"
  [ "$status" -eq 0 ]
  run --separate-stderr "$WORK/home/.local/bin/dummy"
  [ "$status" -eq 0 ]
  [ "$output" = "dummy ok" ]
}

@test "unknown arch exits non-zero" {
  make_dummy_repo
  write_repo_config
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home" "$WORK/bin"
  cat > "$WORK/bin/uname" <<'EOF'
#!/bin/bash
case ${1:-} in
  -s) printf 'Linux\n' ;;
  -m) printf 'mips\n' ;;
  *) /usr/bin/uname "$@" ;;
esac
EOF
  chmod +x "$WORK/bin/uname"
  run --separate-stderr env HOME="$WORK/home" PATH="$WORK/bin:$PATH" "$WORK/install.sh"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"unknown arch"* ]]
  [ ! -e "$WORK/home/.local/share/dummy" ]
}

@test "uninstall refuses when APP_DIR does not match" {
  make_dummy_repo
  write_repo_config
  run --separate-stderr "$INSTALLR"
  [ "$status" -eq 0 ]
  mkdir -p "$WORK/home"
  run --separate-stderr env HOME="$WORK/home" "$WORK/install.sh"
  [ "$status" -eq 0 ]
  printf 'APP_DIR=/tmp/not-the-app\nAPP_NAME=dummy\nBIN=/tmp/not-the-app/dummy\nSYMLINK=/tmp/bin/dummy\nCONFIG=\nCONFIG_INSTALLED=no\nSUDO=no\n' > "$WORK/home/.local/share/dummy/install.log"
  run --separate-stderr "$WORK/home/.local/share/dummy/uninstall.sh"
  [ "$status" -eq 1 ]
  [ -d "$WORK/home/.local/share/dummy" ]
  [ -L "$WORK/home/.local/bin/dummy" ]
}
