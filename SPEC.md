# SPEC

installr reads `installr.conf`, validates it, and writes `install.sh`. This file is the behavior contract. A later language port keeps these rules.

## Config file

`installr.conf` is `KEY=value` lines. Blank lines and lines whose first non-space character is `#` are ignored. installr does not source the file. Unknown keys fail. A line without `=` fails. Values are shell-escaped when baked into `install.sh`.

## Required fields

- `APP_NAME` is required. When it is missing or empty, installr exits 1 and the stderr text includes `APP_NAME`.
- `SOURCE` is required. The value is `repo` or `github_release`. Any other value exits 1 and the stderr text includes `SOURCE`.

## Placeholders

These tokens may appear in `BIN`, `GH_ASSET_URL`, and `GH_BIN_PATH` (and in `GH_BIN_PATH_*` overrides). install.sh substitutes them at install time from the detected OS and arch, the app name, and the baked release fields:

| Token | Meaning |
| --- | --- |
| `{{name}}` | `APP_NAME` |
| `{{os}}` | `linux` or `darwin` |
| `{{arch}}` | `amd64` or `arm64` |
| `{{version}}` | `GH_VERSION` (release only) |
| `{{ext}}` | `GH_EXT` (release only) |
| `{{repo}}` | `GH_REPO` (release only) |

OS mapping: `Linux` → `linux`, `Darwin` → `darwin`. Arch mapping: `x86_64` and `amd64` → `amd64`, `aarch64` and `arm64` → `arm64`. An unknown OS or arch exits non-zero before fetch.

## GitHub release

`SOURCE=github_release` requires `GH_ASSET_URL`. Prefer one URL pattern with placeholders instead of listing every platform.

```
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}.tar.gz
GH_BIN_PATH={{name}}
```

`GH_VERSION` defaults to `latest`. `GH_EXT` and `GH_REPO` default to empty. `GH_BIN_PATH` is the path inside an archive and defaults to `{{name}}`. It accepts the same placeholders. `GH_ARCHIVE` is `raw`, `tar.gz`, or `zip`. When empty, a URL ending in `.tar.gz` or `.tgz` is `tar.gz`, a URL ending in `.zip` is `zip`, and anything else is `raw`.

When one platform’s archive layout differs, set that platform only:

```
GH_BIN_PATH={{name}}
GH_BIN_PATH_darwin_arm64=bin/myapp-apple
```

Supported override keys: `GH_BIN_PATH_linux_amd64`, `GH_BIN_PATH_linux_arm64`, `GH_BIN_PATH_darwin_amd64`, `GH_BIN_PATH_darwin_arm64`. A specific key wins over `GH_BIN_PATH` for that OS and arch.

The generated `install.sh` starts with `#!/usr/bin/env bash`, sets `set -euo pipefail`, detects OS and arch, contains the asset URL pattern, and downloads with `curl`. A release `install.sh` does not contain `git clone`.

## Repo

`SOURCE=repo` requires `REPO_URL` and a binary path: `BIN`, or at least one `BIN_<os>_<arch>`, or both. `REPO_REF` defaults to `main`. `BUILD` is optional. When `BUILD` is empty, `install.sh` does not run a build. When `BUILD` is set, `install.sh` runs that command in the clone before it picks the binary.

Prefer one path pattern:

```
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BIN=dist/{{name}}-{{os}}-{{arch}}
```

When every platform shares the same relative path (no OS or arch in the name):

```
BIN=bin/installr
```

When one platform differs, override that platform only. The specific key wins over `BIN`:

```
BIN=dist/{{name}}-{{os}}-{{arch}}
BIN_darwin_arm64=out/apple-silicon
```

Supported override keys: `BIN_linux_amd64`, `BIN_linux_arm64`, `BIN_darwin_amd64`, `BIN_darwin_arm64`. You do not need all four. A config with only `BIN_*` and no `BIN` is valid. A config with neither `BIN` nor any `BIN_*` fails and stderr includes `BIN`.

At install time, if the detected platform has no override and `BIN` is empty, `install.sh` exits non-zero. A repo `install.sh` contains `git clone` and the `REPO_URL`. It does not contain the release `curl -fsSL` download.

Worked config with build:

```
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BUILD=make build-dummy
BIN=dist/{{name}}
```

## Dependencies

`DEPS` is a space-separated list of commands that must be on `PATH`. When it is empty or omitted, `install.sh` has no `for dep in` loop. When it is set, the loop lists those commands, for example `for dep in make jq; do`. `curl` is still required inside a GitHub release fetch. `git` is still required inside a repo fetch. Those checks are not the `DEPS` loop.

## Install layout

`SCOPE` is an optional author lock: `local` or `global`. Invalid values make installr exit 1 and name `SCOPE` on stderr. When omitted, `install.sh` defaults to local and the user may pass `--local` or `--global`. When `SCOPE=local`, `--global` exits non-zero and installs nothing. When `SCOPE=global`, a run with no flag installs global, and `--local` exits non-zero and installs nothing. Local prefix defaults to `$HOME/.local`. Global prefix defaults to `/usr/local`. A global install uses `sudo` when the user is not root, and the log records `SUDO=yes`. `uninstall.sh` uses `sudo` for removes when `SUDO=yes`. The binary is copied to `<prefix>/<APP_NAME>/<APP_NAME>`. A symlink is created at `<prefix>/bin/<APP_NAME>`. If that `bin` directory is not on `PATH`, `install.sh` prints `export PATH="<bin-dir>:$PATH"` and still exits 0.

`INSTALL_SCRIPT` defaults to `install.sh`. `CONFIG_EXT` defaults to `toml`. `CONFIG_PATH` defaults to `$HOME/.config/$APP_NAME.$CONFIG_EXT`. `DEFAULT_CONFIG` is a path inside the fetched tree; empty skips config install.

## Install log and uninstall

After a successful install the app dir contains `install.log` and `uninstall.sh`. The log is `KEY=value` and is not sourced. It records `APP_NAME`, `APP_DIR`, `BIN`, `SYMLINK`, `CONFIG`, `CONFIG_INSTALLED` (`yes` or `no`), and `SUDO` (`yes` or `no`).

`CONFIG_INSTALLED` is `yes` only when this run wrote the config file. A missing destination is created and copied. When the destination exists and `--yes` is passed, the file is replaced and `CONFIG_INSTALLED` is `yes`. When the destination exists, stdin is not a terminal, and `--yes` was not passed, the file stays and `CONFIG_INSTALLED` is `no`. When stdin is a terminal, `install.sh` prompts `Replace <path>? [y/N]`. An answer of `y`, `Y`, or `yes` replaces the file.

`uninstall.sh` reads the log into memory first. If `APP_DIR` is not the directory that contains `uninstall.sh`, it exits 1 and deletes nothing. Otherwise it removes the symlink, removes `CONFIG` only when `CONFIG_INSTALLED=yes`, and removes `APP_DIR` last. When `SUDO=yes`, those removes go through `sudo`. Running `uninstall.sh` is the confirmation. There is no second prompt.

## Out of scope

Windows, checksums, apt/brew package managers, and editing shell rc files.
