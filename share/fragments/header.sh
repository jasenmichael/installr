#!/usr/bin/env bash
set -euo pipefail

APP_NAME=__Q_APP_NAME__
APP_VERSION=__Q_APP_VERSION__
SCOPE_LOCK=__Q_SCOPE_LOCK__
if [[ -n $SCOPE_LOCK ]]; then
  SCOPE=$SCOPE_LOCK
else
  SCOPE=local
fi
ASSUME_YES=no
while [[ $# -gt 0 ]]; do
  case $1 in
    -h | --help)
      cat <<EOF
$APP_NAME installer.

Usage: install.sh [options]

Options:
  -h, --help     Show this help and exit (before fetch).
  -v, --version  Print "$APP_NAME <version>" and exit (before fetch).
  --local        Install under the local prefix.
  --global       Install under the global prefix (sudo if not root).
  --yes          Replace an existing app config without prompting.

Scope lock: when the author set SCOPE=local, --global fails.
When SCOPE=global, --local fails. When SCOPE is omitted, default is local
and both --local and --global are allowed.
EOF
      exit 0
      ;;
    -v | --version)
      printf '%s %s\n' "$APP_NAME" "$APP_VERSION"
      exit 0
      ;;
    --local)
      if [[ $SCOPE_LOCK == global ]]; then
        printf 'install.sh: SCOPE is global; --local is not allowed\n' >&2
        exit 1
      fi
      SCOPE=local
      shift
      ;;
    --global)
      if [[ $SCOPE_LOCK == local ]]; then
        printf 'install.sh: SCOPE is local; --global is not allowed\n' >&2
        exit 1
      fi
      SCOPE=global
      shift
      ;;
    --yes) ASSUME_YES=yes; shift ;;
    *)
      printf 'install.sh: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done
