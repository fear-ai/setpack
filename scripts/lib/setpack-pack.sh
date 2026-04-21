. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/setpack-common.sh"

if [ -n "${SETPACK_PACK_SH_LOADED:-}" ]; then
  return 0
fi
SETPACK_PACK_SH_LOADED=1

setpack_pack_resolve_root() {
  if [ -f "./pack.toml" ]; then
    pwd -P
    return 0
  fi
  if [ -n "${SETPACK_PACK_ROOT:-}" ] && [ -f "${SETPACK_PACK_ROOT}/pack.toml" ]; then
    (CDPATH= cd -- "$SETPACK_PACK_ROOT" && pwd -P)
    return 0
  fi
  return 1
}

setpack_pack_load_context() {
  local pack_root_default
  pack_root_default="$(setpack_pack_resolve_root || true)"
  [ -n "$pack_root_default" ] || setpack_die "could not resolve pack root; run from a pack root or set SETPACK_PACK_ROOT"

  PACK_ROOT="$(CDPATH= cd -- "$pack_root_default" && pwd -P)"
  SETPACK_ROOT_DEFAULT="$(CDPATH= cd -- "$PACK_ROOT/../.." && pwd)"
  SETPACK_ROOT="${SETPACK_ROOT:-$SETPACK_ROOT_DEFAULT}"
  SET_NAME="$(basename "$(dirname "$PACK_ROOT")")"
  PACK_NAME="$(basename "$PACK_ROOT")"
  PACK_BIN_DIR="$PACK_ROOT/bin"
  STATUS_FILE="$PACK_ROOT/status.toml"
  PACK_ENV_FILE="$PACK_ROOT/.setpack.pack.sh"

  export PACK_ROOT SETPACK_ROOT SET_NAME PACK_NAME PACK_BIN_DIR STATUS_FILE PACK_ENV_FILE
}

setpack_pack_bootstrap_status_file() {
  mkdir -p "$(dirname "$STATUS_FILE")"
  [ -f "$STATUS_FILE" ] || : > "$STATUS_FILE"
}

setpack_pack_status_set() {
  local key="$1"
  local value="$2"
  local tmp
  setpack_pack_bootstrap_status_file
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { done = 0 }
    $0 ~ "^" key " = " {
      print key " = \"" value "\""
      done = 1
      next
    }
    { print }
    END {
      if (!done) {
        print key " = \"" value "\""
      }
    }
  ' "$STATUS_FILE" > "$tmp"
  mv "$tmp" "$STATUS_FILE"
}

setpack_pack_status_value() {
  local key="$1"
  [ -f "$STATUS_FILE" ] || return 0
  sed -n "s/^$key = \"\\(.*\\)\"/\\1/p" "$STATUS_FILE" | head -n 1
}

setpack_pack_status_mark() {
  local base="$1"
  local state="$2"
  setpack_pack_status_set "$base.status" "$state"
  case "$state" in
    planned)
      setpack_pack_status_set "$base.attempted" "no"
      setpack_pack_status_set "$base.completed" "no"
      setpack_pack_status_set "$base.validated" "no"
      ;;
    validated)
      setpack_pack_status_set "$base.attempted" "yes"
      setpack_pack_status_set "$base.completed" "yes"
      setpack_pack_status_set "$base.validated" "yes"
      ;;
    completed|configured|initialized|imported|available)
      setpack_pack_status_set "$base.attempted" "yes"
      setpack_pack_status_set "$base.completed" "yes"
      setpack_pack_status_set "$base.validated" "no"
      ;;
    in_progress|attempted|hybrid_manual)
      setpack_pack_status_set "$base.attempted" "yes"
      setpack_pack_status_set "$base.completed" "no"
      setpack_pack_status_set "$base.validated" "no"
      ;;
    *)
      ;;
  esac
  setpack_pack_status_set "$base.last_updated" "$(setpack_ts)"
}

setpack_pack_ensure_substrate() {
  setpack_log "ensure pack substrate"
  mkdir -p "$PACK_BIN_DIR"
  setpack_pack_bootstrap_status_file
  setpack_pack_status_mark "subsystem.pack.layout" "completed"
}

setpack_pack_role_status_key() {
  local role="$1"
  case "$role" in
    conf) printf 'config\n' ;;
    cred) printf 'cred\n' ;;
    state) printf 'state\n' ;;
    workspace) printf 'workspace\n' ;;
    *) return 1 ;;
  esac
}

setpack_pack_clear_dir() {
  local dir="$1"
  mkdir -p "$dir"
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

setpack_pack_dir_has_contents() {
  local dir="$1"
  [ -d "$dir" ] || return 1
  find "$dir" -mindepth 1 -maxdepth 1 -print -quit | grep -q .
}

setpack_pack_copy_dir_contents() {
  local src="$1"
  local dst="$2"
  local force="${3:-no}"

  [ -d "$src" ] || setpack_die "missing source dir: $src"
  if setpack_pack_dir_has_contents "$dst"; then
    [ "$force" = "yes" ] || setpack_die "destination is not empty: $dst (rerun import with -f to replace)"
  fi
  mkdir -p "$dst"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --checksum --delete --exclude='.git' "$src"/ "$dst"/
    return 0
  fi

  setpack_pack_clear_dir "$dst"
  cp -R "$src"/. "$dst"/
  rm -rf "$dst/.git"
}

setpack_pack_write_env() {
  setpack_log "write pack env"
  cat > "$PACK_ENV_FILE" <<EOF
export SETPACK_ROOT="\${SETPACK_ROOT:-$SETPACK_ROOT}"
export SETPACK_SET="\${SETPACK_SET:-$SET_NAME}"
export SETPACK_PACK="\${SETPACK_PACK:-$PACK_NAME}"
export SETPACK_PACK_ROOT="\${SETPACK_PACK_ROOT:-$PACK_ROOT}"
export SETPACK_PACK_BIN="\${SETPACK_PACK_BIN:-$PACK_BIN_DIR}"
export SETPACK_STATUS_FILE="\${SETPACK_STATUS_FILE:-$STATUS_FILE}"
EOF
  setpack_pack_status_mark "subsystem.pack.env" "completed"
}

setpack_pack_import_component_role() {
  local role="$1"
  local component="$2"
  local src_set="$3"
  local src_pack="$4"
  local force="${5:-no}"
  local src_root src_path dst_path status_key

  src_root="$SETPACK_ROOT/$src_set/$src_pack"
  [ -d "$src_root" ] || setpack_die "missing source pack: $src_root"
  status_key="$(setpack_pack_role_status_key "$role")" || setpack_die "unknown role: $role"

  case "$role" in
    conf)
      src_path="$src_root/$component/config"
      dst_path="$PACK_ROOT/$component/config"
      ;;
    cred)
      src_path="$src_root/$component/cred"
      dst_path="$PACK_ROOT/$component/cred"
      ;;
    state)
      src_path="$src_root/$component/state"
      dst_path="$PACK_ROOT/$component/state"
      ;;
    workspace)
      src_path="$src_root/$component/workspace"
      dst_path="$PACK_ROOT/$component/workspace"
      ;;
    *)
      setpack_die "unknown role: $role"
      ;;
  esac

  setpack_log "import $role for $component from $src_set/$src_pack"
  setpack_pack_copy_dir_contents "$src_path" "$dst_path" "$force"
  setpack_pack_status_mark "subsystem.$component.$status_key" "imported"
  setpack_pack_status_set "subsystem.$component.$status_key.source_pack" "$src_set/$src_pack"
}

setpack_pack_show_status() {
  if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE"
  fi
}
