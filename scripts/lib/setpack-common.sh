if [ -n "${SETPACK_COMMON_SH_LOADED:-}" ]; then
  return 0
fi
SETPACK_COMMON_SH_LOADED=1

SETPACK_LIB_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SETPACK_SCRIPTS_DIR="$(CDPATH= cd -- "$SETPACK_LIB_DIR/.." && pwd)"
SETPACK_REPO_ROOT="$(CDPATH= cd -- "$SETPACK_SCRIPTS_DIR/.." && pwd)"

setpack_log() {
  local tag="${SETPACK_TAG:-setpack}"
  printf '[%s] %s\n' "$tag" "$*" >&2
}

setpack_die() {
  local tag="${SETPACK_TAG:-setpack}"
  printf '[%s] error: %s\n' "$tag" "$*" >&2
  exit 1
}

setpack_ts() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

setpack_read_toml_string() {
  local file="$1"
  local key="$2"
  sed -n "s/^$key = \"\\(.*\\)\"/\\1/p" "$file" | head -n 1
}

setpack_require_command() {
  command -v "$1" >/dev/null 2>&1 || setpack_die "missing required command: $1"
}
