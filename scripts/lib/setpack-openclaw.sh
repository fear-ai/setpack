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
  OPENCLAW_CRED_ENV_FILE="$OPENCLAW_DIR/cred/openclaw.env"
  OPENCLAW_STATE_ENV_LINK="$OPENCLAW_DIR/state/.env"
  OPENCLAW_AGENT_STATE_DIR="$OPENCLAW_DIR/state/agents/main/agent"
  OPENCLAW_AGENT_CRED_DIR="$OPENCLAW_DIR/cred/agents/main/agent"
  OPENCLAW_AUTH_PROFILES_LINK="$OPENCLAW_AGENT_STATE_DIR/auth-profiles.json"
  OPENCLAW_AUTH_STATE_LINK="$OPENCLAW_AGENT_STATE_DIR/auth-state.json"
  OPENCLAW_WORKSPACE_TEMPLATE_DIR="${HOME}/.openclaw/workspace"
  OPENCLAW_SOUL_FILE="$OPENCLAW_DIR/workspace/SOUL.md"
  export \
    OPENCLAW_DIR \
    OPENCLAW_MANIFEST \
    OPENCLAW_CONFIG_FILE \
    OPENCLAW_WRAPPER \
    OPENCLAW_CRED_ENV_FILE \
    OPENCLAW_STATE_ENV_LINK \
    OPENCLAW_AGENT_STATE_DIR \
    OPENCLAW_AGENT_CRED_DIR \
    OPENCLAW_AUTH_PROFILES_LINK \
    OPENCLAW_AUTH_STATE_LINK \
    OPENCLAW_WORKSPACE_TEMPLATE_DIR \
    OPENCLAW_SOUL_FILE
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
  chmod 700 \
    "$OPENCLAW_DIR"/config \
    "$OPENCLAW_DIR"/cred \
    "$OPENCLAW_DIR"/state \
    "$OPENCLAW_DIR"/runtime \
    "$OPENCLAW_DIR"/home
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
export OPENCLAW_HOME="\${OPENCLAW_HOME:-\$ROOT/home}"
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

setpack_openclaw_ensure_link() {
  local link_path="$1"
  local target_path="$2"
  local target_dir

  target_dir="$(dirname "$target_path")"
  mkdir -p "$target_dir"
  mkdir -p "$(dirname "$link_path")"

  if [ -L "$link_path" ]; then
    if [ "$(readlink "$link_path")" = "$target_path" ]; then
      return 0
    fi
    setpack_die "refusing to replace mismatched symlink: $link_path"
  fi

  if [ -e "$link_path" ]; then
    setpack_die "refusing to replace existing path: $link_path"
  fi

  ln -s "$target_path" "$link_path"
}

setpack_openclaw_write_cred_env_template() {
  if [ -e "$OPENCLAW_CRED_ENV_FILE" ]; then
    return 0
  fi

  setpack_log "write openclaw cred env template"
  mkdir -p "$(dirname "$OPENCLAW_CRED_ENV_FILE")"
  cat > "$OPENCLAW_CRED_ENV_FILE" <<'EOF'
# OpenClaw pack-local secrets for the apr20 pack.
# Populate values here; OpenClaw auto-loads this file through state/.env.
OPENCLAW_GATEWAY_TOKEN=
DISCORD_BOT_TOKEN=
TELEGRAM_BOT_TOKEN=
SLACK_BOT_TOKEN=
SLACK_APP_TOKEN=
SLACK_SIGNING_SECRET=
EOF
  chmod 600 "$OPENCLAW_CRED_ENV_FILE"
}

setpack_openclaw_write_config() {
  [ ! -e "$OPENCLAW_CONFIG_FILE" ] || setpack_die "refusing to overwrite existing config: $OPENCLAW_CONFIG_FILE"

  setpack_log "write openclaw config"
  mkdir -p "$(dirname "$OPENCLAW_CONFIG_FILE")"
  cat > "$OPENCLAW_CONFIG_FILE" <<'EOF'
{
  "env": {
    "shellEnv": {
      "enabled": true,
      "timeoutMs": 15000
    }
  },
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": {
        "source": "env",
        "provider": "default",
        "id": "OPENCLAW_GATEWAY_TOKEN"
      }
    },
    "controlUi": {
      "enabled": true
    }
  },
  "channels": {
    "discord": {
      "enabled": true,
      "token": {
        "source": "env",
        "provider": "default",
        "id": "DISCORD_BOT_TOKEN"
      },
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist"
    },
    "telegram": {
      "enabled": false,
      "botToken": {
        "source": "env",
        "provider": "default",
        "id": "TELEGRAM_BOT_TOKEN"
      },
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist"
    },
    "slack": {
      "enabled": false,
      "mode": "socket",
      "botToken": {
        "source": "env",
        "provider": "default",
        "id": "SLACK_BOT_TOKEN"
      },
      "appToken": {
        "source": "env",
        "provider": "default",
        "id": "SLACK_APP_TOKEN"
      },
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist"
    }
  }
}
EOF
  chmod 600 "$OPENCLAW_CONFIG_FILE"
}

setpack_openclaw_seed_workspace_docs() {
  local src_dir="$OPENCLAW_WORKSPACE_TEMPLATE_DIR"
  local dest_dir="$OPENCLAW_DIR/workspace"
  local copied=0
  local src_file
  local dest_file

  mkdir -p "$dest_dir"

  [ -d "$src_dir" ] || setpack_die "missing openclaw workspace template dir: $src_dir"

  for src_file in "$src_dir"/*.md; do
    [ -e "$src_file" ] || continue
    dest_file="$dest_dir/$(basename "$src_file")"
    if [ -e "$dest_file" ]; then
      continue
    fi
    cp "$src_file" "$dest_file"
    chmod 600 "$dest_file"
    copied=1
  done

  if [ "$copied" -eq 1 ]; then
    setpack_log "seed openclaw workspace docs from $src_dir"
  fi
}

setpack_openclaw_configure() {
  setpack_log "configure openclaw pack-local config and credential wiring"
  mkdir -p "$OPENCLAW_AGENT_CRED_DIR"
  chmod 700 \
    "$OPENCLAW_DIR/cred" \
    "$OPENCLAW_DIR/state" \
    "$OPENCLAW_DIR/cred/agents" \
    "$OPENCLAW_DIR/cred/agents/main" \
    "$OPENCLAW_AGENT_CRED_DIR"

  setpack_openclaw_write_cred_env_template
  setpack_openclaw_ensure_link "$OPENCLAW_STATE_ENV_LINK" "../cred/openclaw.env"
  setpack_openclaw_ensure_link "$OPENCLAW_AUTH_PROFILES_LINK" "../../../../cred/agents/main/agent/auth-profiles.json"
  setpack_openclaw_ensure_link "$OPENCLAW_AUTH_STATE_LINK" "../../../../cred/agents/main/agent/auth-state.json"
  setpack_openclaw_write_config
  setpack_openclaw_seed_workspace_docs

  setpack_pack_status_mark "subsystem.openclaw.config" "completed"
  setpack_pack_status_mark "subsystem.openclaw.cred" "configured"
  setpack_pack_status_mark "subsystem.openclaw.state" "configured"
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
