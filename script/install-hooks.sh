#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$root/.git/hooks"
chmod +x "$root/script/hooks/pre-commit" "$root/script/hooks/post-commit"
ln -sfn ../../script/hooks/pre-commit "$root/.git/hooks/pre-commit"
ln -sfn ../../script/hooks/post-commit "$root/.git/hooks/post-commit"
printf 'installed %s\n' "$root/.git/hooks/pre-commit" "$root/.git/hooks/post-commit"
