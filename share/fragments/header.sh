#!/usr/bin/env bash
set -euo pipefail

APP_NAME=__Q_APP_NAME__
SCOPE_LOCK=__Q_SCOPE_LOCK__
if [[ -n $SCOPE_LOCK ]]; then
  SCOPE=$SCOPE_LOCK
else
  SCOPE=local
fi
ASSUME_YES=no
while [[ $# -gt 0 ]]; do
  case $1 in
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
