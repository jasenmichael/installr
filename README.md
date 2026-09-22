# installr

installr turns a small config file into an `install.sh` for your CLI app. You run installr once (or in CI). End users run the generated script: `./install.sh` or `curl …/install.sh | bash`.

Behavior that must stay stable across ports lives in [SPEC.md](SPEC.md). Flags, env vars, and exit codes live in [CLI.md](CLI.md). Tools and the one-file release build live in [STACK.md](STACK.md).

## What installr is

Two programs:

1. **installr** — the generator. Reads `installr.conf`, validates it, writes `install.sh`.
2. **install.sh** — the installer. Detects OS and arch, checks deps, fetches a GitHub release or clones a repo (optional build), installs the binary, optionally copies a default config, then writes `install.log` and `uninstall.sh` into the app directory.

```
author ──► installr + installr.conf ──► install.sh
user   ──► install.sh ──► ~/.local/<app>/  +  ~/.local/bin/<app>
                                      └── install.log
                                      └── uninstall.sh
```

## Build

Edit `src/installr.sh`, `lib/`, and `share/fragments/`. Then:

```bash
script/bundle.sh
```

Result: executable `bin/installr` (libs and fragments pasted in; no `source` of `lib/` or `share/`). That file is the curl target and what dogfood installs via `BIN=bin/installr`.

## Checkout vs curl one-file build

### From a git checkout

```bash
./src/installr.sh
./src/installr.sh --check
./src/installr.sh --config path/to/installr.conf --output /tmp/install.sh
```

`./src/installr.sh` resolves `lib/` from the repo root via `BASH_SOURCE`. That only works when the script is a real file on disk. Do not point curl at it.

### Curl the one-file build

`curl … | bash` has no script path and no `lib/` beside it. Use the bundled binary:

```bash
script/bundle.sh          # writes bin/installr
curl -fsSL https://github.com/jasenmichael/installr/raw/main/bin/installr | bash -s -- --config ./installr.conf
curl -fsSL https://github.com/jasenmichael/installr/raw/main/bin/installr | bash -s -- --check --config ./installr.conf
```

See [STACK.md](STACK.md) and [CLI.md](CLI.md).

## Config file format

Default path: `./installr.conf` in the current directory.

Rules:

- One `KEY=value` per line.
- Blank lines and `#` comments are ignored.
- The file is **not** sourced. Quoting is optional for simple values.
- Unknown keys fail validation.
- Values are escaped when baked into `install.sh`.

Copy [installr.conf.example](installr.conf.example) (annotated catalog of every accepted key) and edit it, or use the short dogfood [installr.conf](installr.conf) in this repo.

### Every key

| Key | Required | Default | Meaning |
| --- | --- | --- | --- |
| `APP_NAME` | yes | — | Installed command name and app directory name. |
| `SOURCE` | yes | — | `repo` or `github_release`. |
| `INSTALL_SCRIPT` | no | `install.sh` | Path installr writes. |
| `SCOPE` | no | (omit: user chooses; default local) | Optional lock: `local` or `global`. Omit so `--local` / `--global` choose. |
| `LOCAL_PREFIX` | no | `$HOME/.local` | Local install root. |
| `GLOBAL_PREFIX` | no | `/usr/local` | Global install root. |
| `CONFIG_EXT` | no | `toml` | Used when `CONFIG_PATH` is empty. |
| `CONFIG_PATH` | no | `$HOME/.config/$APP_NAME.$CONFIG_EXT` | Destination for the default config. |
| `DEFAULT_CONFIG` | no | empty | Path inside the fetched tree. Empty skips config install. |
| `DEPS` | no | empty | Space-separated commands that must be on `PATH`. |
| `REPO_URL` | if `SOURCE=repo` | — | Git remote (or a local path for tests). |
| `REPO_REF` | no | `main` | Branch or tag to clone. |
| `BUILD` | no | empty | Shell command run in the clone after fetch. Empty skips build. |
| `BIN` | if repo and no `BIN_*` | — | Path pattern to the binary inside the clone. |
| `BIN_linux_amd64` etc. | optional | — | Per-platform override. Wins over `BIN` for that OS/arch. |
| `GH_ASSET_URL` | if `SOURCE=github_release` | — | Download URL pattern. |
| `GH_REPO` | no | empty | Substituted as `{{repo}}`. |
| `GH_VERSION` | no | `latest` | Substituted as `{{version}}`. |
| `GH_EXT` | no | empty | Substituted as `{{ext}}`. |
| `GH_ARCHIVE` | no | from URL suffix | `raw`, `tar.gz`, or `zip`. |
| `GH_BIN_PATH` | no | `{{name}}` | Path inside a tar/zip archive. |
| `GH_BIN_PATH_linux_amd64` etc. | optional | — | Per-platform override inside the archive. |

Supported platform suffixes: `linux_amd64`, `linux_arm64`, `darwin_amd64`, `darwin_arm64`.

### Placeholders

Use these in `BIN`, `GH_ASSET_URL`, and `GH_BIN_PATH` (and in the per-platform `GH_BIN_PATH_*` overrides) so you do not list every OS and arch:

| Token | Becomes |
| --- | --- |
| `{{name}}` | `APP_NAME` |
| `{{os}}` | `linux` or `darwin` |
| `{{arch}}` | `amd64` or `arm64` |
| `{{version}}` | `GH_VERSION` |
| `{{ext}}` | `GH_EXT` |
| `{{repo}}` | `GH_REPO` |

## Repo source

Clone a repository, optionally build, then copy the binary for the current OS and arch.

**Same relative path on every platform** (no os/arch in the filename):

```
APP_NAME=installr
SOURCE=repo
REPO_URL=https://github.com/example/installr.git
BIN=bin/installr
```

**One pattern with os and arch in the path:**

```
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BIN=dist/{{name}}-{{os}}-{{arch}}
```

**Pattern plus one override** when darwin arm64 is different:

```
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BIN=dist/{{name}}-{{os}}-{{arch}}
BIN_darwin_arm64=out/apple-silicon
```

**Only specific keys** (no `BIN`) is also valid when platforms do not share a pattern:

```
BIN_linux_amd64=dist/linux-x64/myapp
BIN_darwin_arm64=dist/macos/myapp
```

You do **not** need all four `BIN_*` keys. A platform with neither `BIN` nor a matching `BIN_*` fails at install time.

With an optional build:

```
APP_NAME=myapp
SOURCE=repo
REPO_URL=https://github.com/acme/myapp.git
BUILD=make release
BIN=dist/{{name}}
DEPS=make
```

Generate and install locally:

```bash
./src/installr.sh
./install.sh
~/.local/bin/myapp
```

## GitHub release source

Download a release asset. Prefer one URL with placeholders.

```
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/download/{{version}}/{{name}}-{{os}}-{{arch}}.tar.gz
GH_VERSION=v1.2.3
GH_BIN_PATH={{name}}
```

`GH_ARCHIVE` defaults from the URL: `.tar.gz` / `.tgz` → `tar.gz`, `.zip` → `zip`, otherwise `raw` (the downloaded file *is* the binary).

When the path inside one platform’s archive differs:

```
GH_BIN_PATH={{name}}
GH_BIN_PATH_darwin_arm64=bin/myapp-apple
```

Example release config without an archive (raw binary URL):

```
APP_NAME=myapp
SOURCE=github_release
GH_ASSET_URL=https://github.com/acme/myapp/releases/latest/download/{{name}}-{{os}}-{{arch}}
```

## What install.sh does

In order:

1. Parse `--local`, `--global`, `--yes`. Enforce author `SCOPE` lock if set (forbidden flag → exit before fetch).
2. Detect OS (`linux` / `darwin`) and arch (`amd64` / `arm64`). Unknown → exit non-zero.
3. If `DEPS` is set, require each command on `PATH`.
4. Fetch:
   - **repo:** require `git`, clone `REPO_URL` at `REPO_REF`, run `BUILD` if set, resolve `BIN` / `BIN_*` for this platform.
   - **github_release:** require `curl`, expand `GH_ASSET_URL`, download, unpack if needed, resolve `GH_BIN_PATH` / `GH_BIN_PATH_*`.
5. Choose prefix from the resolved scope (`--local` / `--global`, else lock, else local). Global and not root → use `sudo`, set `SUDO=yes` in the log.
6. Copy the binary to `<prefix>/<APP_NAME>/<APP_NAME>`, symlink `<prefix>/bin/<APP_NAME>`.
7. If `DEFAULT_CONFIG` is set, copy it to `CONFIG_PATH` (prompt / `--yes` / no-TTY rules below).
8. Write `install.log` and `uninstall.sh` into the app dir.
9. If `<prefix>/bin` is not on `PATH`, print `export PATH="<prefix>/bin:$PATH"` and exit 0.

## Install layout

Local (default):

```
$HOME/.local/<APP_NAME>/<APP_NAME>     # binary
$HOME/.local/<APP_NAME>/install.log
$HOME/.local/<APP_NAME>/uninstall.sh
$HOME/.local/bin/<APP_NAME>            # symlink
$HOME/.config/<APP_NAME>.<ext>         # optional config
```

Global:

```
/usr/local/<APP_NAME>/...
/usr/local/bin/<APP_NAME>
```

Override with `LOCAL_PREFIX`, `GLOBAL_PREFIX`, or `CONFIG_PATH`.

## install.log

Written after a successful install. `KEY=value`, not sourced.

| Field | Meaning |
| --- | --- |
| `APP_NAME` | Command name. |
| `APP_DIR` | Directory that holds the binary, this log, and `uninstall.sh`. |
| `BIN` | Installed binary path inside `APP_DIR`. |
| `SYMLINK` | Path of the symlink under `<prefix>/bin`. |
| `CONFIG` | Config destination, or empty if none was configured. |
| `CONFIG_INSTALLED` | `yes` only if this run wrote the config file. |
| `SUDO` | `yes` if install used sudo. |

## uninstall.sh

Lives in the app dir. Paths come from `install.log`, not from `installr.conf`.

```bash
~/.local/myapp/uninstall.sh
```

Behavior:

1. Read the log into memory.
2. If the log is missing or `APP_DIR` is not this script’s directory → exit 1, delete nothing.
3. Remove `SYMLINK` if set.
4. Remove `CONFIG` only when `CONFIG_INSTALLED=yes`.
5. Remove `APP_DIR` last (binary, log, and `uninstall.sh` go with it).
6. Use `sudo` when `SUDO=yes`.

Running the script is the confirmation. No second prompt. A reinstall overwrites the log and `uninstall.sh`.

## Flags, env, exit codes

### installr

| Flag / env | Role |
| --- | --- |
| `--config PATH` / `INSTALLR_CONFIG` | Config path (default `./installr.conf`). |
| `--output PATH` / `INSTALLR_OUTPUT` | Output path (overrides `INSTALL_SCRIPT`). |
| `--check` | Validate only; write nothing. |

Precedence: flags > env > config file > defaults.

| Exit | Meaning |
| --- | --- |
| 0 | Valid (and written, unless `--check`). |
| 1 | Invalid config; stderr names the field. |
| 2 | Usage error. |

### install.sh

| Flag | Role |
| --- | --- |
| `--local` | Force local prefix. |
| `--global` | Force global prefix (sudo if not root). |
| `--yes` | Replace existing config without prompting. |

Exit non-zero on unknown OS/arch, missing dep, missing binary for this platform, or fetch/install failure.

Full detail: [CLI.md](CLI.md).

## Dependencies

- `DEPS` in the config: optional list checked with a `for dep in …` loop.
- Implied: `curl` for GitHub releases, `git` for repo clones (checked inside the fetch fragment, not via the `DEPS` loop).
- `sudo` for global installs when not root.

## Local vs global and sudo

The person who runs `install.sh` chooses with `--local` or `--global`, unless the app author sets `SCOPE` as a lock.

- No `SCOPE` in config: default is local (`LOCAL_PREFIX`, no sudo, log `SUDO=no`). `--global` installs under `GLOBAL_PREFIX` (sudo when not root, log `SUDO=yes`). `--local` is explicit local.
- `SCOPE=local`: only local allowed. `--global` exits non-zero and installs nothing.
- `SCOPE=global`: only global allowed. No flag installs global. `--local` exits non-zero and installs nothing.
- `LOCAL_PREFIX` / `GLOBAL_PREFIX` are directory settings, not the user's scope choice.

## Config copy, prompt, --yes, no TTY

When `DEFAULT_CONFIG` is set:

| Situation | Result | `CONFIG_INSTALLED` |
| --- | --- | --- |
| Destination missing | Copy | `yes` |
| Exists + `--yes` | Replace | `yes` |
| Exists + TTY | Prompt `Replace <path>? [y/N]` | `yes` only on `y` / `Y` / `yes` |
| Exists + no TTY + no `--yes` | Keep existing | `no` |

Uninstall only deletes the config when `CONFIG_INSTALLED=yes`.

## How to run tests

Install [bats-core](https://github.com/bats-core/bats-core) 1.5+, then:

```bash
bats spec
```

Or with a local bats clone:

```bash
/tmp/bats-core/bin/bats spec
```

Tests cover:

- CLI validation and emit (including `BIN` patterns and `BIN_*` overrides).
- Dummy script app install, log, uninstall, config prompt/`--yes`, global sudo, missing deps, release tar.gz, unknown arch.
- `script/bundle.sh` → `bin/installr` as a file and via stdin.

Prompt tests need a pty; they skip if `pty.openpty()` fails. See [STACK.md](STACK.md).

## Dogfood: install installr with installr

[installr.conf](installr.conf) is a repo-source config for this project:

```
APP_NAME=installr
SOURCE=repo
REPO_URL=https://github.com/example/installr.git
BIN=bin/installr
```

1. Set `REPO_URL` to the real remote (or a local clone path).
2. `script/bundle.sh` so `bin/installr` exists, then `./src/installr.sh` (or `./bin/installr`).
3. `./install.sh` — installs under `~/.local/installr` and symlinks `~/.local/bin/installr`.
4. `~/.local/installr/uninstall.sh` removes that install.

Because `BIN=bin/installr` is the same relative path on every platform, one line replaces four `BIN_*` keys.

## Quick start

```bash
# 1. Write a config
cp installr.conf.example installr.conf
# installr.conf.example is the annotated catalog; edit the copy for your app

# 2. Generate install.sh (checkout)
./src/installr.sh

# 3. Install (end-user step)
./install.sh

# 4. Run and uninstall
~/.local/bin/<APP_NAME>
~/.local/<APP_NAME>/uninstall.sh
```
