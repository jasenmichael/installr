# STACK

installr is bash. It has no runtime dependency beyond a POSIX-ish environment with `bash`, and the tools an install script needs (`curl` or `git`, and `sudo` for global installs).

## Tests

Tests use [bats-core](https://github.com/bats-core/bats-core) 1.5 or newer.

```bash
bats spec
```

If `bats` is not on `PATH`, use a local clone:

```bash
/tmp/bats-core/bin/bats spec
```

The config-prompt tests need a pseudo-terminal. They skip when `pty.openpty()` fails. Run the suite outside a sandbox that blocks ptys when you need those cases.

## Build

Edit `src/installr.sh`, `lib/`, and `share/fragments/`. Bundle into one file:

```bash
script/bundle.sh
```

That writes executable `bin/installr` (libs and fragments inlined; no `source` of `lib/` or `share/`). Publish `bin/installr`. The curl URL is that file:

```bash
curl -fsSL https://github.com/jasenmichael/installr/raw/main/bin/installr | bash -s --
```

`./src/installr.sh` is checkout-only: it sources `lib/` via `BASH_SOURCE`. Do not point curl at it. See [README.md](README.md).
