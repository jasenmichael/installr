for dep in __DEPS__; do
  command -v "$dep" >/dev/null 2>&1 || {
    printf 'install.sh: missing dep: %s\n' "$dep" >&2
    exit 1
  }
done
