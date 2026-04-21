. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/setpack-pack.sh"

if [ -n "${SETPACK_GWS_SH_LOADED:-}" ]; then
  return 0
fi
SETPACK_GWS_SH_LOADED=1

setpack_gws_load_context() {
  GWS_DIR="$PACK_ROOT/gws"
  GWS_MANIFEST="$GWS_DIR/comp.toml"
  GWS_WRAPPER="$PACK_BIN_DIR/gws"
  GWS_BUNDLE_BIN="$GWS_DIR/bundle/bin/gws"
  GWS_SYSTEM_CONFIG_DIR="${HOME}/.config/gws"
  export GWS_DIR GWS_MANIFEST GWS_WRAPPER GWS_BUNDLE_BIN
}

setpack_gws_ensure_layout() {
  setpack_log "ensure gws layout"
  mkdir -p \
    "$GWS_DIR"/bundle/bin \
    "$GWS_DIR"/config \
    "$GWS_DIR"/cred \
    "$GWS_DIR"/state/cache \
    "$GWS_DIR"/runtime \
    "$GWS_DIR"/home
  setpack_pack_status_mark "subsystem.gws.layout" "completed"
}

setpack_gws_dir_has_contents() {
  local dir="$1"
  [ -d "$dir" ] || return 1
  find "$dir" -mindepth 1 -maxdepth 1 -print -quit | grep -q .
}

setpack_gws_clear_dir() {
  local dir="$1"
  mkdir -p "$dir"
  find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

setpack_gws_copy_file_if_present() {
  local src="$1"
  local dst="$2"
  [ -f "$src" ] || return 0
  mkdir -p "$(dirname "$dst")"
  cp -p "$src" "$dst"
}

setpack_gws_copy_cache_if_present() {
  local src="$1"
  local dst="$2"

  [ -d "$src" ] || return 0
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --checksum --delete "$src"/ "$dst"/
    return 0
  fi

  setpack_gws_clear_dir "$dst"
  cp -R "$src"/. "$dst"/
}

setpack_gws_system_bin() {
  [ -f "$GWS_MANIFEST" ] || setpack_die "missing gws manifest: $GWS_MANIFEST"
  setpack_read_toml_string "$GWS_MANIFEST" "system_bin"
}

setpack_gws_keyring_backend() {
  local backend
  [ -f "$GWS_MANIFEST" ] || setpack_die "missing gws manifest: $GWS_MANIFEST"
  backend="$(setpack_read_toml_string "$GWS_MANIFEST" "keyring_backend")"
  if [ -n "$backend" ]; then
    printf '%s\n' "$backend"
  else
    printf 'file\n'
  fi
}

setpack_gws_install_bundle() {
  local bin real_bin
  bin="$(setpack_gws_system_bin)"
  [ -n "$bin" ] || setpack_die "cannot read gws system_bin from $GWS_MANIFEST"
  [ -x "$bin" ] || setpack_die "missing gws system binary: $bin"
  setpack_require_command realpath
  real_bin="$(realpath "$bin")"

  setpack_log "record gws system entrypoint from: $real_bin"
  mkdir -p "$GWS_DIR/bundle/bin"
  cat > "$GWS_BUNDLE_BIN" <<EOF
#!/usr/bin/env bash
exec "$real_bin" "\$@"
EOF
  chmod +x "$GWS_BUNDLE_BIN"
  cat > "$GWS_DIR/bundle/SOURCE.toml" <<EOF
source_kind = "bundle-shim"
install_adapter = "system-existing"
binary = "$bin"
resolved_binary = "$real_bin"
recorded_at = "$(setpack_ts)"
bundle_binary = "$GWS_BUNDLE_BIN"
EOF
  setpack_pack_status_set "subsystem.gws.bundle.recorded_binary" "$real_bin"
  setpack_pack_status_set "subsystem.gws.bundle.local_binary" "$GWS_BUNDLE_BIN"
  setpack_pack_status_mark "subsystem.gws.bundle" "completed"
}

setpack_gws_import_system() {
  local force="no"
  local src_dir="$GWS_SYSTEM_CONFIG_DIR"

  while [ $# -gt 0 ]; do
    case "$1" in
      -f|--force)
        force="yes"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        setpack_die "usage: scripts/setpack-gws import-system [-f] [source-config-dir]"
        ;;
      *)
        src_dir="$1"
        shift
        ;;
    esac
  done

  [ $# -eq 0 ] || setpack_die "usage: scripts/setpack-gws import-system [-f] [source-config-dir]"
  [ -d "$src_dir" ] || setpack_die "missing gws source config dir: $src_dir"

  setpack_gws_ensure_layout
  if [ "$force" != "yes" ]; then
    if setpack_gws_dir_has_contents "$GWS_DIR/cred" || setpack_gws_dir_has_contents "$GWS_DIR/state/cache"; then
      setpack_die "gws cred/state already has content; rerun with -f to replace"
    fi
  fi

  setpack_log "import gws system config from: $src_dir"
  setpack_gws_clear_dir "$GWS_DIR/cred"
  setpack_gws_clear_dir "$GWS_DIR/state/cache"

  setpack_gws_copy_file_if_present "$src_dir/client_secret.json" "$GWS_DIR/cred/client_secret.json"
  setpack_gws_copy_file_if_present "$src_dir/credentials.enc" "$GWS_DIR/cred/credentials.enc"
  setpack_gws_copy_file_if_present "$src_dir/credentials.json" "$GWS_DIR/cred/credentials.json"
  setpack_gws_copy_file_if_present "$src_dir/token_cache.json" "$GWS_DIR/cred/token_cache.json"
  setpack_gws_copy_file_if_present "$src_dir/.encryption_key" "$GWS_DIR/cred/.encryption_key"
  setpack_gws_copy_cache_if_present "$src_dir/cache" "$GWS_DIR/state/cache"

  setpack_pack_status_mark "subsystem.gws.cred" "imported"
  setpack_pack_status_set "subsystem.gws.cred.source" "$src_dir"
  setpack_pack_status_mark "subsystem.gws.state" "imported"
  setpack_pack_status_set "subsystem.gws.state.source" "$src_dir/cache"
}

setpack_gws_write_wrapper() {
  local keyring_backend
  keyring_backend="$(setpack_gws_keyring_backend)"
  setpack_log "write gws wrapper"
  cat > "$GWS_WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)"
PACK_ROOT="\$(CDPATH= cd -- "\$SCRIPT_DIR/.." && pwd)"
ROOT="\$PACK_ROOT/gws"
BIN="\$ROOT/bundle/bin/gws"
CRED_ROOT="\$ROOT/cred"
STATE_ROOT="\$ROOT/state"
APP_ROOT="\$ROOT/runtime"
CACHE_ROOT="\$STATE_ROOT/cache"
CLIENT_SECRET_FILE="\$CRED_ROOT/client_secret.json"
ENCRYPTED_CREDENTIALS_FILE="\$CRED_ROOT/credentials.enc"
PLAIN_CREDENTIALS_FILE="\$CRED_ROOT/credentials.json"
TOKEN_CACHE_FILE="\$CRED_ROOT/token_cache.json"
ENCRYPTION_KEY_FILE="\$CRED_ROOT/.encryption_key"

[ -x "\$BIN" ] || {
  echo "missing gws bundle binary: \$BIN" >&2
  exit 1
}

mkdir -p "\$ROOT/home" "\$CRED_ROOT" "\$STATE_ROOT" "\$CACHE_ROOT" "\$APP_ROOT"
export HOME="\$ROOT/home"
export GOOGLE_WORKSPACE_CLI_CONFIG_DIR="\$APP_ROOT"
export GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND="\${GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND:-$keyring_backend}"

ensure_link() {
  local source="\$1"
  local dest="\$2"
  local current=""

  if [ -L "\$dest" ]; then
    current="\$(readlink "\$dest" || true)"
    if [ "\$current" = "\$source" ]; then
      return 0
    fi
  fi

  rm -rf "\$dest"
  ln -s "\$source" "\$dest" 2>/dev/null || {
    if [ -L "\$dest" ]; then
      current="\$(readlink "\$dest" || true)"
      [ "\$current" = "\$source" ] && return 0
    fi
    echo "failed to link \$dest -> \$source" >&2
    return 1
  }
}

copy_if_present() {
  local source="\$1"
  local dest="\$2"
  if [ -f "\$source" ]; then
    mkdir -p "\$(dirname "\$dest")"
    rm -rf "\$dest"
    cp -p "\$source" "\$dest"
  else
    rm -rf "\$dest"
  fi
}

sync_back_if_present() {
  local source="\$1"
  local dest="\$2"
  if [ -f "\$source" ]; then
    mkdir -p "\$(dirname "\$dest")"
    rm -rf "\$dest"
    cp -p "\$source" "\$dest"
  else
    rm -rf "\$dest"
  fi
}

copy_if_present "\$CLIENT_SECRET_FILE" "\$APP_ROOT/client_secret.json"
if [ -s "\$PLAIN_CREDENTIALS_FILE" ]; then
  copy_if_present "\$PLAIN_CREDENTIALS_FILE" "\$APP_ROOT/credentials.json"
  rm -rf "\$APP_ROOT/credentials.enc" "\$APP_ROOT/.encryption_key"
else
  rm -rf "\$APP_ROOT/credentials.json"
  copy_if_present "\$ENCRYPTED_CREDENTIALS_FILE" "\$APP_ROOT/credentials.enc"
  copy_if_present "\$ENCRYPTION_KEY_FILE" "\$APP_ROOT/.encryption_key"
fi
copy_if_present "\$TOKEN_CACHE_FILE" "\$APP_ROOT/token_cache.json"
ensure_link "\$CACHE_ROOT" "\$APP_ROOT/cache"

"\$BIN" "\$@"
rc=\$?

if [ -f "\$APP_ROOT/credentials.json" ]; then
  sync_back_if_present "\$APP_ROOT/credentials.json" "\$PLAIN_CREDENTIALS_FILE"
  rm -rf "\$CRED_ROOT/credentials.enc" "\$CRED_ROOT/.encryption_key"
else
  sync_back_if_present "\$APP_ROOT/credentials.enc" "\$ENCRYPTED_CREDENTIALS_FILE"
  sync_back_if_present "\$APP_ROOT/.encryption_key" "\$ENCRYPTION_KEY_FILE"
  rm -rf "\$CRED_ROOT/credentials.json"
fi
sync_back_if_present "\$APP_ROOT/token_cache.json" "\$TOKEN_CACHE_FILE"
sync_back_if_present "\$APP_ROOT/client_secret.json" "\$CLIENT_SECRET_FILE"

exit \$rc
EOF
  chmod +x "$GWS_WRAPPER"
  setpack_pack_status_mark "subsystem.gws.wrapper" "completed"
}

setpack_gws_validate() {
  setpack_log "validate gws"
  [ -x "$GWS_WRAPPER" ] || setpack_die "missing gws wrapper: $GWS_WRAPPER"
  "$GWS_WRAPPER" --version >/dev/null
  "$GWS_WRAPPER" auth --help >/dev/null
  "$GWS_WRAPPER" auth status >/dev/null
  setpack_pack_status_mark "subsystem.gws.wrapper" "validated"
  setpack_pack_status_set "subsystem.gws.bundle.validated_at" "$(setpack_ts)"
  setpack_pack_status_mark "subsystem.gws.bundle" "validated"
}
