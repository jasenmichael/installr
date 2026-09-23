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
| `{{version}}` | Resolved `VERSION` when set; else `GH_VERSION` (default `latest`; release only) |
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

## VERSION

`VERSION` is optional. installr resolves it at generate time and bakes the result into `install.sh`.

- Literal: `VERSION=1.4.2` (no leading `!`). Baked as that string.
- Command: `VERSION=!cat VERSION` or `VERSION=!cat path/to/VERSION`. The `!` prefix means run the rest via `bash -lc` in the cwd. installr trims whitespace from stdout. Non-zero exit or empty stdout → exit 1 and stderr names `VERSION`. Unprefixed values are never `eval`'d. The config is never sourced.

When `VERSION` is set, the resolved value overrides `GH_VERSION` for the `{{version}}` placeholder in `GH_ASSET_URL` and `GH_BIN_PATH`. When only `GH_VERSION` is set, that value is used (default `latest` when neither is set).

Generated `install.sh` accepts `-v` / `--version` and prints `<APP_NAME> <resolved>` (or `<APP_NAME> unknown` when `VERSION` was omitted), then exits 0 before fetch. `-h` / `--help` prints short usage (including `--local`, `--global`, `--yes`, and scope lock behavior) and exits 0 before fetch.

When one platform’s archive layout differs, set that platform only:

```
GH_BIN_PATH={{name}}
GH_BIN_PATH_darwin_arm64=bin/myapp-apple
```

Supported override keys: `GH_BIN_PATH_linux_amd64`, `GH_BIN_PATH_linux_arm64`, `GH_BIN_PATH_darwin_amd64`, `GH_BIN_PATH_darwin_arm64`. A specific key wins over `GH_BIN_PATH` for that OS and arch.

The generated `install.sh` starts with `#!/usr/bin/env bash`, then comment lines naming installr (and the app when known) plus `https://github.com/jasenmichael/installr`, sets `set -euo pipefail`, detects OS and arch, contains the asset URL pattern, and downloads with `curl` or `wget` (curl preferred when both exist; missing both is an error). A release `install.sh` does not contain `git clone`. A successful generate prints `wrote <path>` on stdout.

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

At install time, if the detected platform has no override and `BIN` is empty, `install.sh` exits non-zero. A repo `install.sh` contains `git clone` and the `REPO_URL`. It does not contain the release asset download (`curl -fsSL` / `wget -q -O`).

Worked config with build:

```
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BUILD=make build-dummy
BIN=dist/{{name}}
```

## Dependencies

`DEPS` is a space-separated list of commands that must be on `PATH`. When it is empty or omitted, `install.sh` has no `for dep in` loop. When it is set, the loop lists those commands, for example `for dep in make jq; do`. A GitHub release fetch still requires `curl` or `wget` (curl preferred; neither is an error). `git` is still required inside a repo fetch. Those checks are not the `DEPS` loop.

## Install layout

`SCOPE` is an optional author lock: `local` or `global`. Invalid values make installr exit 1 and name `SCOPE` on stderr. When omitted, `install.sh` defaults to local and the user may pass `--local` or `--global`. When `SCOPE=local`, `--global` exits non-zero and installs nothing. When `SCOPE=global`, a run with no flag installs global, and `--local` exits non-zero and installs nothing. Local prefix defaults to `$HOME/.local`. Global prefix defaults to `/usr/local`. A global install uses `sudo` when the user is not root, and the log records `SUDO=yes`. `uninstall.sh` uses `sudo` for removes when `SUDO=yes`. A local install copies the binary to `$LOCAL_PREFIX/share/<APP_NAME>/<APP_NAME>` (default `$HOME/.local/share/<APP_NAME>/<APP_NAME>`) and creates a symlink at `$LOCAL_PREFIX/bin/<APP_NAME>` (default `$HOME/.local/bin/<APP_NAME>`). A global install copies to `$GLOBAL_PREFIX/<APP_NAME>/<APP_NAME>` and symlinks `$GLOBAL_PREFIX/bin/<APP_NAME>` with no `share/` segment. On success, `install.sh` prints a short stdout summary (version when `VERSION` was set, app dir, symlink, `files:` line, config action, scope; `(sudo)` when sudo was used). Help and version exit before the summary. If that `bin` directory is not on `PATH`, `install.sh` also prints `export PATH="<bin-dir>:$PATH"` and still exits 0.

`INSTALL_SCRIPT` defaults to `install.sh`. `CONFIG_EXT` defaults to `toml`. `CONFIG_PATH` defaults to `$HOME/.config/$APP_NAME.$CONFIG_EXT`.

`FILES` is optional. Omitted or empty stays binary-only and the success line is `files: binary`. `FILES=*` (the whole value, not a glob) puts the fetched tree in the app dir. A git source clones there, including `.git`, and the symlink points at the binary inside the tree (`BIN` or `BIN_<os>_<arch>`). `install.log` `BIN` is that path. `install.log` and `uninstall.sh` are written after the clone. Reinstall into an existing git checkout fetches and checks out `REPO_REF`. If that directory exists and is not a git repo, `install.sh` exits 1 and names `APP_DIR`. A release archive unpacks into the app dir and does not leave the archive file. A second release install into an existing app dir exits 1 and names `APP_DIR`. A raw single-file asset with `FILES=*` makes installr exit 1 and name `FILES`.

A `FILES` list is comma-separated paths relative to the fetched tree, copied in addition to the binary install. Spaces around commas are trimmed. One pair of quotes may wrap the whole value (`FILES="bin/app, public/, data/*"`). Quotes around each item are not parsed. A path cannot contain a comma. `public/` and `public` are the same directory. Globs expand when `install.sh` runs. A glob does not match dotfiles unless the pattern starts with a dot. Each match keeps its repo path (`data/foo` lands at `<app-dir>/data/foo`). Absolute paths, any item containing `..`, an empty item, and `*` mixed with other items make installr exit 1 and name `FILES`. A missing path or a glob that matches nothing makes `install.sh` exit 1 and name that item, before the success summary. Success line: `files: *` or `files: <copied paths>`.

`DEFAULT_CONFIG` empty or omitted: `install.sh` creates no settings file and prints `config: skipped (no DEFAULT_CONFIG)`. A path is copied from the fetched tree. A command (`DEFAULT_CONFIG=!cat path/to/app.toml`) runs via `bash -lc` when installr generates the script, same rules as `VERSION`. Trimmed stdout is the file body baked into `install.sh`. Non-zero exit or empty stdout: installr exits 1 and names `DEFAULT_CONFIG`. A value without `!` is never executed. `install.sh` writes that body to `CONFIG_PATH` (or the default destination) with the same replace prompt and `--yes` rules. `CONFIG_INSTALLED=yes` only when this run wrote the file.

## Install log and uninstall

After a successful install the app dir contains `install.log` and `uninstall.sh`. The log is `KEY=value` and is not sourced. It records `APP_NAME`, `APP_DIR`, `BIN`, `SYMLINK`, `CONFIG`, `CONFIG_INSTALLED` (`yes` or `no`), and `SUDO` (`yes` or `no`).

`CONFIG_INSTALLED` is `yes` only when this run wrote the config file. A missing destination is created and copied. When the destination exists and `--yes` is passed, the file is replaced and `CONFIG_INSTALLED` is `yes`. When the destination exists and `--yes` was not passed, `install.sh` always prompts `Replace <path>? [y/N]` (even when stdin is not a terminal). An answer of `y`, `Y`, or `yes` replaces the file. Any other answer, including empty and EOF (`read` failure), leaves the file and `CONFIG_INSTALLED` is `no`.

`uninstall.sh` reads the log into memory first. If `APP_DIR` is not the directory that contains `uninstall.sh`, it exits 1 and deletes nothing. Otherwise it removes the symlink, removes `CONFIG` only when `CONFIG_INSTALLED=yes`, and removes `APP_DIR` last. When `SUDO=yes`, those removes go through `sudo`. Running `uninstall.sh` is the confirmation. There is no second prompt.

## Out of scope

Windows, checksums, apt/brew package managers, and editing shell rc files.
