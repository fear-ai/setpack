. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/setpack-pack.sh"

if [ -n "${SETPACK_GOG_SH_LOADED:-}" ]; then
  return 0
fi
SETPACK_GOG_SH_LOADED=1

setpack_gog_load_context() {
  GOG_DIR="$PACK_ROOT/gog"
  GOG_MANIFEST="$GOG_DIR/comp.toml"
  GOG_WRAPPER="$PACK_BIN_DIR/gog"
  GOG_BUNDLE_BIN="$GOG_DIR/bundle/bin/gog"
  export GOG_DIR GOG_MANIFEST GOG_WRAPPER GOG_BUNDLE_BIN
}

setpack_gog_ensure_layout() {
  setpack_log "ensure gog layout"
  mkdir -p \
    "$GOG_DIR"/bundle \
    "$GOG_DIR"/config \
    "$GOG_DIR"/cred \
    "$GOG_DIR"/state \
    "$GOG_DIR"/runtime \
    "$GOG_DIR"/home
  mkdir -p \
    "$GOG_DIR"/config/gogcli \
    "$GOG_DIR"/cred/gogcli \
    "$GOG_DIR"/cred/gogcli/tokens \
    "$GOG_DIR"/cred/gogcli/keyring \
    "$GOG_DIR"/state/gogcli \
    "$GOG_DIR"/runtime/gogcli
  setpack_pack_status_mark "subsystem.gog.layout" "completed"
}

setpack_gog_system_bin() {
  [ -f "$GOG_MANIFEST" ] || setpack_die "missing gog manifest: $GOG_MANIFEST"
  setpack_read_toml_string "$GOG_MANIFEST" "system_bin"
}

setpack_gog_install_bundle() {
  local bin real_bin
  bin="$(setpack_gog_system_bin)"
  [ -n "$bin" ] || setpack_die "cannot read gog system_bin from $GOG_MANIFEST"
  [ -x "$bin" ] || setpack_die "missing gog system binary: $bin"
  setpack_require_command realpath
  real_bin="$(realpath "$bin")"

  setpack_log "duplicate gog binary into local bundle from: $real_bin"
  mkdir -p "$GOG_DIR/bundle/bin"
  cp -f "$real_bin" "$GOG_BUNDLE_BIN"
  chmod +x "$GOG_BUNDLE_BIN"
  cat > "$GOG_DIR/bundle/SOURCE.toml" <<EOF
source_kind = "bundle-copy"
install_adapter = "system-existing"
binary = "$bin"
resolved_binary = "$real_bin"
recorded_at = "$(setpack_ts)"
bundle_binary = "$GOG_BUNDLE_BIN"
EOF
  setpack_pack_status_set "subsystem.gog.bundle.recorded_binary" "$real_bin"
  setpack_pack_status_set "subsystem.gog.bundle.local_binary" "$GOG_BUNDLE_BIN"
  setpack_pack_status_mark "subsystem.gog.bundle" "completed"
}

setpack_gog_write_wrapper() {
  setpack_log "write gog wrapper"
  cat > "$GOG_WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)"
PACK_ROOT="\$(CDPATH= cd -- "\$SCRIPT_DIR/.." && pwd)"
ROOT="\$PACK_ROOT/gog"
BIN="\$ROOT/bundle/bin/gog"
CONFIG_ROOT="\$ROOT/config/gogcli"
CRED_ROOT="\$ROOT/cred/gogcli"
STATE_ROOT="\$ROOT/state/gogcli"
XDG_ROOT="\$ROOT/runtime"
APP_ROOT="\$XDG_ROOT/gogcli"
TOKENS_ROOT="\$CRED_ROOT/tokens"
KEYRING_ROOT="\$CRED_ROOT/keyring"
DEFAULT_ACCOUNT_FILE="\$CRED_ROOT/default-account"
KEYRING_PASSWORD_FILE="\$CRED_ROOT/keyring-password"
LEGACY_KEYRING_PASSWORD_FILE="\$STATE_ROOT/keyring-password"
TOKEN_STAMPS_ROOT="\$STATE_ROOT/imported-token-stamps"

[ -x "\$BIN" ] || {
  echo "missing gog bundle binary: \$BIN" >&2
  exit 1
}

mkdir -p "\$ROOT/home" "\$ROOT/config" "\$ROOT/cred" "\$ROOT/state" "\$ROOT/runtime"
mkdir -p "\$CONFIG_ROOT" "\$CRED_ROOT" "\$STATE_ROOT" "\$APP_ROOT" "\$TOKEN_STAMPS_ROOT"
export HOME="\$ROOT/home"
export XDG_CONFIG_HOME="\$XDG_ROOT"

: "\${GOG_KEYRING_BACKEND:=file}"
export GOG_KEYRING_BACKEND

if [ -z "\${GOG_KEYRING_PASSWORD:-}" ]; then
  if [ ! -f "\$KEYRING_PASSWORD_FILE" ]; then
    umask 077
    openssl rand -hex 32 >"\$KEYRING_PASSWORD_FILE"
  fi
  GOG_KEYRING_PASSWORD="\$(tr -d '\r\n' < "\$KEYRING_PASSWORD_FILE")"
  export GOG_KEYRING_PASSWORD
fi

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

dir_has_contents() {
  local dir="\$1"
  [ -d "\$dir" ] || return 1
  find "\$dir" -mindepth 1 -maxdepth 1 -print -quit | grep -q .
}

migrate_runtime_dir_to_cred() {
  local runtime_dir="\$1"
  local cred_dir="\$2"

  if [ ! -d "\$runtime_dir" ] || [ -L "\$runtime_dir" ]; then
    return 0
  fi

  mkdir -p "\$cred_dir"
  if dir_has_contents "\$runtime_dir" && ! dir_has_contents "\$cred_dir"; then
    cp -R "\$runtime_dir"/. "\$cred_dir"/
  fi
  rm -rf "\$runtime_dir"
}

mkdir -p "\$KEYRING_ROOT" "\$STATE_ROOT/state" "\$STATE_ROOT/drive-downloads" "\$STATE_ROOT/gmail-attachments"
if [ ! -f "\$KEYRING_PASSWORD_FILE" ] && [ -f "\$LEGACY_KEYRING_PASSWORD_FILE" ]; then
  mkdir -p "\$(dirname "\$KEYRING_PASSWORD_FILE")"
  cp "\$LEGACY_KEYRING_PASSWORD_FILE" "\$KEYRING_PASSWORD_FILE"
  chmod 600 "\$KEYRING_PASSWORD_FILE" 2>/dev/null || true
fi
migrate_runtime_dir_to_cred "\$APP_ROOT/keyring" "\$KEYRING_ROOT"
ensure_link "\$CONFIG_ROOT/config.json" "\$APP_ROOT/config.json"
ensure_link "\$CRED_ROOT/credentials.json" "\$APP_ROOT/credentials.json"
ensure_link "\$KEYRING_ROOT" "\$APP_ROOT/keyring"
ensure_link "\$STATE_ROOT/state" "\$APP_ROOT/state"
ensure_link "\$STATE_ROOT/drive-downloads" "\$APP_ROOT/drive-downloads"
ensure_link "\$STATE_ROOT/gmail-attachments" "\$APP_ROOT/gmail-attachments"

for pattern in "credentials-"*.json "sa-"*.json "keep-sa-"*.json; do
  for source in "\$CRED_ROOT"/\$pattern; do
    [ -e "\$source" ] || continue
    ensure_link "\$source" "\$APP_ROOT/\$(basename "\$source")"
  done
done

if [ -z "\${GOG_ACCOUNT:-}" ] && [ -f "\$DEFAULT_ACCOUNT_FILE" ]; then
  GOG_ACCOUNT="\$(tr -d '\r\n' < "\$DEFAULT_ACCOUNT_FILE")"
  export GOG_ACCOUNT
fi

if [ -d "\$TOKENS_ROOT" ]; then
  for token_file in "\$TOKENS_ROOT"/*.json; do
    [ -e "\$token_file" ] || continue
    token_name="\$(basename "\$token_file")"
    stamp_file="\$TOKEN_STAMPS_ROOT/\$token_name.sha256"
    token_hash="\$(shasum -a 256 "\$token_file" | awk '{print \$1}')"
    current_hash=""
    if [ -f "\$stamp_file" ]; then
      current_hash="\$(tr -d '\r\n' < "\$stamp_file")"
    fi
    if [ "\$token_hash" != "\$current_hash" ]; then
      "\$BIN" --no-input auth tokens import "\$token_file" >/dev/null
      printf '%s\n' "\$token_hash" >"\$stamp_file"
    fi
  done
fi

exec "\$BIN" "\$@"
EOF
  chmod +x "$GOG_WRAPPER"
  setpack_pack_status_mark "subsystem.gog.wrapper" "completed"
}

setpack_gog_validate() {
  setpack_log "validate gog"
  [ -x "$GOG_WRAPPER" ] || setpack_die "missing gog wrapper: $GOG_WRAPPER"
  "$GOG_WRAPPER" --version >/dev/null
  setpack_pack_status_mark "subsystem.gog.wrapper" "validated"
  setpack_pack_status_set "subsystem.gog.bundle.validated_at" "$(setpack_ts)"
  setpack_pack_status_mark "subsystem.gog.bundle" "validated"
}
