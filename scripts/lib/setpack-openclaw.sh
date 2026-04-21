. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/setpack-pack.sh"

if [ -n "${SETPACK_OPENCLAW_SH_LOADED:-}" ]; then
  return 0
fi
SETPACK_OPENCLAW_SH_LOADED=1

setpack_openclaw_load_context() {
  OPENCLAW_DIR="$PACK_ROOT/openclaw"
  OPENCLAW_MANIFEST="$OPENCLAW_DIR/comp.toml"
  OPENCLAW_CONFIG_FILE="$OPENCLAW_DIR/config/openclaw.json"
  OPENCLAW_WRAPPER="$PACK_BIN_DIR/openclaw"
  export OPENCLAW_DIR OPENCLAW_MANIFEST OPENCLAW_CONFIG_FILE OPENCLAW_WRAPPER
}

setpack_openclaw_ensure_layout() {
  setpack_log "ensure openclaw layout"
  mkdir -p \
    "$OPENCLAW_DIR"/bundle \
    "$OPENCLAW_DIR"/config \
    "$OPENCLAW_DIR"/cred \
    "$OPENCLAW_DIR"/state \
    "$OPENCLAW_DIR"/runtime \
    "$OPENCLAW_DIR"/workspace \
    "$OPENCLAW_DIR"/home \
    "$OPENCLAW_DIR"/bin \
    "$OPENCLAW_DIR"/exports \
    "$OPENCLAW_DIR"/reports
  setpack_pack_status_mark "subsystem.openclaw.layout" "completed"
}

setpack_openclaw_version() {
  [ -f "$OPENCLAW_MANIFEST" ] || setpack_die "missing openclaw manifest: $OPENCLAW_MANIFEST"
  setpack_read_toml_string "$OPENCLAW_MANIFEST" "package_version"
}

setpack_openclaw_install_bundle() {
  local version
  version="$(setpack_openclaw_version)"
  [ -n "$version" ] || setpack_die "cannot read openclaw version from $OPENCLAW_MANIFEST"

  setpack_require_command npm
  setpack_pack_status_set "subsystem.openclaw.bundle.attempted_at" "$(setpack_ts)"
  setpack_log "install openclaw@$version into bundle"
  npm --loglevel=error install --no-audit --no-fund --prefix "$OPENCLAW_DIR/bundle" "openclaw@$version"
  setpack_pack_status_set "subsystem.openclaw.bundle.completed_at" "$(setpack_ts)"
  setpack_pack_status_mark "subsystem.openclaw.bundle" "completed"
}

setpack_openclaw_write_wrapper() {
  setpack_log "write openclaw wrapper"
  cat > "$OPENCLAW_WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)"
PACK_ROOT="\$(CDPATH= cd -- "\$SCRIPT_DIR/.." && pwd)"
ROOT="\$PACK_ROOT/openclaw"
BIN="\$ROOT/bundle/node_modules/.bin/openclaw"
PACK_WORKSPACE="\$ROOT/workspace"
PACK_BIN="\$PACK_ROOT/bin"
SETPACK_ROOT_DEFAULT="\$(CDPATH= cd -- "\$PACK_ROOT/../.." && pwd)"
SETPACK_SET_DEFAULT="\$(basename "\$(dirname "\$PACK_ROOT")")"
SETPACK_PACK_DEFAULT="\$(basename "\$PACK_ROOT")"

[ -x "\$BIN" ] || {
  echo "missing openclaw bundle binary: \$BIN" >&2
  exit 1
}

export OPENCLAW_STATE_DIR="\$ROOT/state"
export OPENCLAW_CONFIG_PATH="\$ROOT/config/openclaw.json"
export SETPACK_ROOT="\${SETPACK_ROOT:-\$SETPACK_ROOT_DEFAULT}"
export SETPACK_SET="\${SETPACK_SET:-\$SETPACK_SET_DEFAULT}"
export SETPACK_PACK="\${SETPACK_PACK:-\$SETPACK_PACK_DEFAULT}"
export SETPACK_PACK_ROOT="\${SETPACK_PACK_ROOT:-\$PACK_ROOT}"
export SETPACK_PACK_BIN="\${SETPACK_PACK_BIN:-\$PACK_BIN}"
export SETPACK_STATUS_FILE="\${SETPACK_STATUS_FILE:-\$PACK_ROOT/status.toml}"

case ":\$PATH:" in
  *":\$PACK_BIN:"*) ;;
  *) export PATH="\$PACK_BIN:\$PATH" ;;
esac

args=("\$@")

if [ "\${1:-}" = "onboard" ]; then
  has_workspace_flag=0
  for arg in "\${args[@]}"; do
    case "\$arg" in
      --workspace|--workspace=*)
        has_workspace_flag=1
        break
        ;;
    esac
  done
  if [ "\$has_workspace_flag" -eq 0 ]; then
    args+=("--workspace" "\$PACK_WORKSPACE")
  fi
fi

exec "\$BIN" "\${args[@]}"
EOF
  chmod +x "$OPENCLAW_WRAPPER"
  setpack_pack_status_mark "subsystem.openclaw.wrapper" "completed"
}

setpack_openclaw_validate() {
  setpack_log "validate openclaw"
  [ -x "$OPENCLAW_WRAPPER" ] || setpack_die "missing openclaw wrapper: $OPENCLAW_WRAPPER"
  "$OPENCLAW_WRAPPER" --version >/dev/null
  setpack_pack_status_mark "subsystem.openclaw.wrapper" "validated"
  setpack_pack_status_set "subsystem.openclaw.bundle.validated_at" "$(setpack_ts)"
  setpack_pack_status_mark "subsystem.openclaw.bundle" "validated"

  if [ -f "$OPENCLAW_CONFIG_FILE" ]; then
    if ! "$OPENCLAW_WRAPPER" config file >/dev/null; then
      setpack_pack_status_set "subsystem.openclaw.config.status" "invalid"
      setpack_pack_status_set "subsystem.openclaw.config.attempted" "yes"
      setpack_pack_status_set "subsystem.openclaw.config.completed" "no"
      setpack_pack_status_set "subsystem.openclaw.config.validated" "no"
      setpack_pack_status_set "subsystem.openclaw.config.last_updated" "$(setpack_ts)"
      return 1
    fi
    if ! "$OPENCLAW_WRAPPER" config validate >/dev/null; then
      setpack_pack_status_set "subsystem.openclaw.config.status" "invalid"
      setpack_pack_status_set "subsystem.openclaw.config.attempted" "yes"
      setpack_pack_status_set "subsystem.openclaw.config.completed" "no"
      setpack_pack_status_set "subsystem.openclaw.config.validated" "no"
      setpack_pack_status_set "subsystem.openclaw.config.last_updated" "$(setpack_ts)"
      return 1
    fi
    setpack_pack_status_mark "subsystem.openclaw.config" "validated"
    return 0
  fi

  setpack_pack_status_set "subsystem.openclaw.config.status" "missing"
  setpack_pack_status_set "subsystem.openclaw.config.attempted" "yes"
  setpack_pack_status_set "subsystem.openclaw.config.completed" "no"
  setpack_pack_status_set "subsystem.openclaw.config.validated" "no"
  setpack_pack_status_set "subsystem.openclaw.config.last_updated" "$(setpack_ts)"
  return 1
}
