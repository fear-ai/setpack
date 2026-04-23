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
  OPENCLAW_CLAUDE_WRAPPER="$PACK_BIN_DIR/claude"
  OPENCLAW_GATEWAY_SERVICE_HELPER="$PACK_BIN_DIR/openclaw-gateway-service"
  OPENCLAW_HOME_DIR="$OPENCLAW_DIR/home"
  OPENCLAW_CLAUDE_HOME_DIR="$OPENCLAW_HOME_DIR/.claude"
  OPENCLAW_CODEX_HOME_DIR="$OPENCLAW_HOME_DIR/.codex"
  OPENCLAW_CRED_ENV_FILE="$OPENCLAW_DIR/cred/openclaw.env"
  OPENCLAW_CRED_SECRETS_FILE="$OPENCLAW_DIR/cred/openclaw.secrets.json"
  OPENCLAW_CLAUDE_CRED_DIR="$OPENCLAW_DIR/cred/claude-cli"
  OPENCLAW_CLAUDE_CRED_FILE="$OPENCLAW_CLAUDE_CRED_DIR/credentials.json"
  OPENCLAW_CLAUDE_NATIVE_CRED_LINK="$OPENCLAW_CLAUDE_HOME_DIR/.credentials.json"
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
    OPENCLAW_CLAUDE_WRAPPER \
    OPENCLAW_GATEWAY_SERVICE_HELPER \
    OPENCLAW_HOME_DIR \
    OPENCLAW_CLAUDE_HOME_DIR \
    OPENCLAW_CODEX_HOME_DIR \
    OPENCLAW_CRED_ENV_FILE \
    OPENCLAW_CRED_SECRETS_FILE \
    OPENCLAW_CLAUDE_CRED_DIR \
    OPENCLAW_CLAUDE_CRED_FILE \
    OPENCLAW_CLAUDE_NATIVE_CRED_LINK \
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
    "$OPENCLAW_CLAUDE_HOME_DIR" \
    "$OPENCLAW_CODEX_HOME_DIR" \
    "$OPENCLAW_DIR"/bin \
    "$OPENCLAW_DIR"/exports \
    "$OPENCLAW_DIR"/reports \
    "$OPENCLAW_CLAUDE_CRED_DIR"
  chmod 700 \
    "$OPENCLAW_DIR"/config \
    "$OPENCLAW_DIR"/cred \
    "$OPENCLAW_DIR"/state \
    "$OPENCLAW_DIR"/runtime \
    "$OPENCLAW_DIR"/home \
    "$OPENCLAW_CLAUDE_HOME_DIR" \
    "$OPENCLAW_CODEX_HOME_DIR" \
    "$OPENCLAW_CLAUDE_CRED_DIR"
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
  setpack_openclaw_patch_bundle_model_defaults
  setpack_pack_status_set "subsystem.openclaw.bundle.completed_at" "$(setpack_ts)"
  setpack_pack_status_mark "subsystem.openclaw.bundle" "completed"
}

setpack_openclaw_patch_bundle_model_defaults() {
  local defaults_js

  defaults_js="$(printf '%s\n' "$OPENCLAW_DIR"/bundle/node_modules/openclaw/dist/config-defaults-*.js | head -n 1)"
  [ -n "$defaults_js" ] || setpack_die "missing openclaw config-defaults bundle file"
  [ -f "$defaults_js" ] || setpack_die "missing openclaw config-defaults bundle file: $defaults_js"

  python3 - <<'PY' "$defaults_js"
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()

old = """\tif (authMode === \"oauth\" && usesClaudeCliModelSelection(params.config)) {\n\t\tconst nextModels = defaults.models ? { ...defaults.models } : {};\n\t\tlet modelsMutated = false;\n\t\tfor (const ref of CLAUDE_CLI_DEFAULT_ALLOWLIST_REFS) {\n\t\t\tif (ref in nextModels) continue;\n\t\t\tnextModels[ref] = {};\n\t\t\tmodelsMutated = true;\n\t\t}\n\t\tif (modelsMutated) {\n\t\t\tnextDefaults.models = nextModels;\n\t\t\tmutated = true;\n\t\t}\n\t}"""
new = """\tif (authMode === \"oauth\" && usesClaudeCliModelSelection(params.config)) {\n\t\t// Setpack: keep the Claude CLI allowlist explicit in openclaw.json.\n\t}"""

if new in text:
    raise SystemExit(0)
if old not in text:
    raise SystemExit(f\"openclaw bundle patch target not found: {path}\")

path.write_text(text.replace(old, new))
PY
}

setpack_openclaw_write_gateway_service_helper() {
  local version
  version="$(setpack_openclaw_version)"
  [ -n "$version" ] || setpack_die "cannot read openclaw version from $OPENCLAW_MANIFEST"

  setpack_log "write openclaw gateway service helper"
  cat > "$OPENCLAW_GATEWAY_SERVICE_HELPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)"
PACK_ROOT="\$(CDPATH= cd -- "\$SCRIPT_DIR/.." && pwd)"
ROOT="\$PACK_ROOT/openclaw"
DIST="\$ROOT/bundle/node_modules/openclaw/dist/index.js"
CONFIG="\$ROOT/config/openclaw.json"
STATE="\$ROOT/state"
PACK_HOME="\$ROOT/home"
CLAUDE_HOME="\$PACK_HOME/.claude"
CODEX_HOME="\$PACK_HOME/.codex"
LOG_DIR="\$STATE/logs"
LABEL="ai.openclaw.gateway"
PORT="18789"
VERSION="$version"

resolve_node() {
  if [ -x /opt/homebrew/opt/node/bin/node ]; then
    printf '/opt/homebrew/opt/node/bin/node\\n'
    return 0
  fi
  if [ -x /usr/local/bin/node ]; then
    printf '/usr/local/bin/node\\n'
    return 0
  fi
  command -v node
}

resolve_user_home() {
  python3 - <<'PY'
import os, pwd
print(pwd.getpwuid(os.getuid()).pw_dir)
PY
}

NODE="\$(resolve_node)"
USER_HOME="\$(resolve_user_home)"
PLIST="\$USER_HOME/Library/LaunchAgents/\$LABEL.plist"
[ -x "\$NODE" ] || {
  echo "missing stable node binary for gateway service" >&2
  exit 1
}
[ -f "\$DIST" ] || {
  echo "missing openclaw gateway entrypoint: \$DIST" >&2
  exit 1
}

MIN_PATH="\$(dirname "\$NODE"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

write_plist() {
  mkdir -p "\$(dirname "\$PLIST")" "\$LOG_DIR"
  python3 - <<'PY' "\$PLIST" "\$NODE" "\$DIST" "\$CONFIG" "\$STATE" "\$PORT" "\$LABEL" "\$VERSION" "\$MIN_PATH" "\$PACK_HOME" "\$CLAUDE_HOME" "\$CODEX_HOME" "\${TMPDIR:-/tmp}" "\$LOG_DIR/gateway.log" "\$LOG_DIR/gateway.err.log"
import plistlib, sys
from pathlib import Path

plist_path = Path(sys.argv[1])
node = sys.argv[2]
dist = sys.argv[3]
config = sys.argv[4]
state = sys.argv[5]
port = sys.argv[6]
label = sys.argv[7]
version = sys.argv[8]
path_value = sys.argv[9]
home = sys.argv[10]
claude_home = sys.argv[11]
codex_home = sys.argv[12]
tmpdir = sys.argv[13]
stdout_path = sys.argv[14]
stderr_path = sys.argv[15]

payload = {
    "Label": label,
    "ProgramArguments": [node, dist, "gateway", "--port", port],
    "RunAtLoad": True,
    "KeepAlive": True,
    "ThrottleInterval": 1,
    "Umask": 0o77,
    "StandardOutPath": stdout_path,
    "StandardErrorPath": stderr_path,
    "EnvironmentVariables": {
        "HOME": home,
        "TMPDIR": tmpdir,
        "NODE_EXTRA_CA_CERTS": "/etc/ssl/cert.pem",
        "NODE_USE_SYSTEM_CA": "1",
        "CLAUDE_CONFIG_DIR": claude_home,
        "CODEX_HOME": codex_home,
        "OPENCLAW_CONFIG_PATH": config,
        "OPENCLAW_STATE_DIR": state,
        "OPENCLAW_GATEWAY_PORT": port,
        "OPENCLAW_LAUNCHD_LABEL": label,
        "OPENCLAW_SYSTEMD_UNIT": "openclaw-gateway.service",
        "OPENCLAW_WINDOWS_TASK_NAME": "OpenClaw Gateway",
        "OPENCLAW_SERVICE_MARKER": "openclaw",
        "OPENCLAW_SERVICE_KIND": "gateway",
        "OPENCLAW_SERVICE_VERSION": version,
        "PATH": path_value,
    },
}

with plist_path.open("wb") as fh:
    plistlib.dump(payload, fh, sort_keys=False)
PY
}

gui_target() {
  printf 'gui/%s' "\$(id -u)"
}

service_target() {
  printf '%s/%s' "\$(gui_target)" "\$LABEL"
}

bootout_existing() {
  launchctl bootout "\$(gui_target)" "\$PLIST" >/dev/null 2>&1 || true
  launchctl bootout "\$(service_target)" >/dev/null 2>&1 || true
  launchctl unload "\$PLIST" >/dev/null 2>&1 || true
}

enable_service() {
  launchctl enable "\$(service_target)" >/dev/null 2>&1 || true
}

bootstrap_agent() {
  launchctl bootstrap "\$(gui_target)" "\$PLIST"
}

kickstart_agent() {
  launchctl kickstart -k "\$(gui_target)/\$LABEL"
}

is_loaded() {
  launchctl print "\$(gui_target)/\$LABEL" >/dev/null 2>&1
}

command_name="\${2:-}"
case "\${1:-}" in
  gateway) ;;
  *)
    echo "usage: openclaw gateway <install|start|stop|restart|uninstall>" >&2
    exit 2
    ;;
esac

case "\$command_name" in
  install)
    write_plist
    bootout_existing
    enable_service
    bootstrap_agent
    ;;
  start)
    write_plist
    bootout_existing
    enable_service
    bootstrap_agent
    ;;
  restart)
    write_plist
    bootout_existing
    enable_service
    bootstrap_agent
    ;;
  stop)
    bootout_existing
    ;;
  uninstall)
    bootout_existing
    rm -f "\$PLIST"
    ;;
  *)
    echo "usage: openclaw gateway <install|start|stop|restart|uninstall>" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "$OPENCLAW_GATEWAY_SERVICE_HELPER"
}

setpack_openclaw_write_claude_wrapper() {
  setpack_log "write claude wrapper"
  cat > "$OPENCLAW_CLAUDE_WRAPPER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PACK_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
ROOT="$PACK_ROOT/openclaw"

resolve_claude() {
  local entry real_entry
  IFS=':' read -r -a entries <<< "${PATH:-}"
  for entry in "${entries[@]}"; do
    [ -n "$entry" ] || continue
    real_entry="$(CDPATH= cd -- "$entry" 2>/dev/null && pwd)" || continue
    [ "$real_entry" = "$SCRIPT_DIR" ] && continue
    if [ -x "$real_entry/claude" ]; then
      printf '%s\n' "$real_entry/claude"
      return 0
    fi
  done
  return 1
}

BIN="$(resolve_claude)"
[ -n "$BIN" ] || {
  echo "missing system claude binary outside pack PATH" >&2
  exit 1
}

export HOME="$ROOT/home"
export CLAUDE_CONFIG_DIR="$ROOT/home/.claude"
export CODEX_HOME="$ROOT/home/.codex"

exec "$BIN" "$@"
EOF
  chmod +x "$OPENCLAW_CLAUDE_WRAPPER"
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
SERVICE_HELPER="\$PACK_BIN/openclaw-gateway-service"
SETPACK_ROOT_DEFAULT="\$(CDPATH= cd -- "\$PACK_ROOT/../.." && pwd)"
SETPACK_SET_DEFAULT="\$(basename "\$(dirname "\$PACK_ROOT")")"
SETPACK_PACK_DEFAULT="\$(basename "\$PACK_ROOT")"

resolve_user_home() {
  python3 - <<'PY'
import os, pwd
print(pwd.getpwuid(os.getuid()).pw_dir)
PY
}

[ -x "\$BIN" ] || {
  echo "missing openclaw bundle binary: \$BIN" >&2
  exit 1
}

USER_HOME="\$(resolve_user_home)"
export OPENCLAW_STATE_DIR="\$ROOT/state"
export OPENCLAW_CONFIG_PATH="\$ROOT/config/openclaw.json"
export HOME="\$ROOT/home"
export OPENCLAW_HOME="\$ROOT/home"
export CLAUDE_CONFIG_DIR="\$ROOT/home/.claude"
export CODEX_HOME="\$ROOT/home/.codex"
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

if [ "\${1:-}" = "gateway" ] && [ -x "\$SERVICE_HELPER" ]; then
  case "\${2:-}" in
    install|start|stop|restart|uninstall)
      exec "\$SERVICE_HELPER" "\${args[@]}"
      ;;
    status)
      export HOME="\$USER_HOME"
      ;;
  esac
fi

exec "\$BIN" "\${args[@]}"
EOF
  chmod +x "$OPENCLAW_WRAPPER"
  setpack_openclaw_write_claude_wrapper
  setpack_openclaw_write_gateway_service_helper
  setpack_pack_status_mark "subsystem.openclaw.wrapper" "completed"
}

setpack_openclaw_ensure_link() {
  local link_path="$1"
  local target_path="$2"
  local target_dir

  if [ "${target_path#/}" != "$target_path" ]; then
    target_dir="$(dirname "$target_path")"
  else
    target_dir="$(dirname "$link_path")/$(dirname "$target_path")"
  fi
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
# OpenClaw pack-local secret template for the apr20 pack.
# Runtime reads cred/openclaw.secrets.json via file SecretRefs; this file is not auto-loaded.
OPENCLAW_GATEWAY_TOKEN=
DISCORD_BOT_TOKEN=
TELEGRAM_BOT_TOKEN=
SLACK_BOT_TOKEN=
SLACK_APP_TOKEN=
SLACK_SIGNING_SECRET=
EOF
  chmod 600 "$OPENCLAW_CRED_ENV_FILE"
}

setpack_openclaw_write_secret_store() {
  if [ -e "$OPENCLAW_CRED_SECRETS_FILE" ]; then
    return 0
  fi

  setpack_log "write openclaw file-backed secret store"
  python3 - <<'PY' "$OPENCLAW_CRED_ENV_FILE" "$OPENCLAW_CRED_SECRETS_FILE"
import json, os, sys
from pathlib import Path

env_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
values = {}
if env_path.exists():
    for raw_line in env_path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()

payload = {
    "gateway": {
        "token": values.get("OPENCLAW_GATEWAY_TOKEN", "")
    },
    "channels": {
        "discord": {
            "botToken": values.get("DISCORD_BOT_TOKEN", "")
        },
        "telegram": {
            "botToken": values.get("TELEGRAM_BOT_TOKEN", "")
        },
        "slack": {
            "botToken": values.get("SLACK_BOT_TOKEN", ""),
            "appToken": values.get("SLACK_APP_TOKEN", ""),
            "signingSecret": values.get("SLACK_SIGNING_SECRET", "")
        }
    }
}

out_path.write_text(json.dumps(payload, indent=2) + "\\n")
os.chmod(out_path, 0o600)
PY
}

setpack_openclaw_write_state_env_stub() {
  if [ -L "$OPENCLAW_STATE_ENV_LINK" ]; then
    rm -f "$OPENCLAW_STATE_ENV_LINK"
  fi
  if [ -e "$OPENCLAW_STATE_ENV_LINK" ]; then
    return 0
  fi

  setpack_log "write openclaw state .env stub"
  cat > "$OPENCLAW_STATE_ENV_LINK" <<'EOF'
# Setpack-managed state dotenv intentionally left blank.
# Secrets are resolved from cred/openclaw.secrets.json via file SecretRefs.
EOF
  chmod 600 "$OPENCLAW_STATE_ENV_LINK"
}

setpack_openclaw_write_auth_profiles_template() {
  local auth_profiles_file="$OPENCLAW_AGENT_CRED_DIR/auth-profiles.json"
  if [ -e "$auth_profiles_file" ]; then
    return 0
  fi

  setpack_log "write openclaw auth profiles template"
  mkdir -p "$(dirname "$auth_profiles_file")"
  cat > "$auth_profiles_file" <<'EOF'
{"version":1,"profiles":{}}
EOF
  chmod 600 "$auth_profiles_file"
}

setpack_openclaw_write_auth_state_template() {
  local auth_state_file="$OPENCLAW_AGENT_CRED_DIR/auth-state.json"
  if [ -e "$auth_state_file" ]; then
    return 0
  fi

  setpack_log "write openclaw auth state template"
  mkdir -p "$(dirname "$auth_state_file")"
  cat > "$auth_state_file" <<'EOF'
{"version":1,"lastGood":{},"usageStats":{}}
EOF
  chmod 600 "$auth_state_file"
}

setpack_openclaw_sync_config_defaults() {
  if [ ! -e "$OPENCLAW_CONFIG_FILE" ]; then
    setpack_openclaw_write_config
    return 0
  fi

  setpack_log "sync openclaw config with setpack-local paths"
  python3 - <<'PY' \
    "$OPENCLAW_CONFIG_FILE" \
    "$OPENCLAW_DIR/workspace" \
    "$OPENCLAW_CRED_SECRETS_FILE" \
    "$OPENCLAW_CLAUDE_WRAPPER" \
    "$OPENCLAW_HOME_DIR" \
    "$OPENCLAW_CLAUDE_HOME_DIR" \
    "$OPENCLAW_CODEX_HOME_DIR"
import json, pathlib, sys

config_path = pathlib.Path(sys.argv[1])
workspace_path = sys.argv[2]
secret_store_path = sys.argv[3]
claude_wrapper = sys.argv[4]
pack_home = sys.argv[5]
claude_home = sys.argv[6]
codex_home = sys.argv[7]

data = json.loads(config_path.read_text())

agents = data.setdefault("agents", {}).setdefault("defaults", {})
agents["workspace"] = workspace_path
claude_backend = agents.setdefault("cliBackends", {}).setdefault("claude-cli", {})
claude_backend["command"] = claude_wrapper
env = claude_backend.setdefault("env", {})
env["HOME"] = pack_home
env["CLAUDE_CONFIG_DIR"] = claude_home
env["CODEX_HOME"] = codex_home

models = agents.get("models")
if isinstance(models, dict):
    for entry in models.values():
        if isinstance(entry, dict) and entry.get("alias") == "":
            entry.pop("alias", None)

secrets = data.setdefault("secrets", {})
providers = secrets.setdefault("providers", {})
default_provider = providers.setdefault("default", {})
default_provider["source"] = "file"
default_provider["path"] = secret_store_path
default_provider["mode"] = "json"
secrets.setdefault("defaults", {})["file"] = "default"

config_path.write_text(json.dumps(data, indent=2) + "\n")
PY
  chmod 600 "$OPENCLAW_CONFIG_FILE"
}

setpack_openclaw_sync_channel_activation() {
  [ -f "$OPENCLAW_CONFIG_FILE" ] || return 0
  [ -f "$OPENCLAW_CRED_SECRETS_FILE" ] || return 0

  setpack_log "disable channels with blank pack-local secrets"
  python3 - <<'PY' \
    "$OPENCLAW_CONFIG_FILE" \
    "$OPENCLAW_CRED_SECRETS_FILE"
import json, pathlib, sys

config_path = pathlib.Path(sys.argv[1])
secrets_path = pathlib.Path(sys.argv[2])

config = json.loads(config_path.read_text())
secrets = json.loads(secrets_path.read_text())

channels = config.setdefault("channels", {})
secret_channels = secrets.get("channels", {}) if isinstance(secrets.get("channels"), dict) else {}

def non_empty(value):
    return isinstance(value, str) and value.strip() != ""

discord = channels.get("discord")
discord_secrets = secret_channels.get("discord", {}) if isinstance(secret_channels.get("discord"), dict) else {}
if isinstance(discord, dict) and not non_empty(discord_secrets.get("botToken")):
    discord["enabled"] = False

telegram = channels.get("telegram")
telegram_secrets = secret_channels.get("telegram", {}) if isinstance(secret_channels.get("telegram"), dict) else {}
if isinstance(telegram, dict) and not non_empty(telegram_secrets.get("botToken")):
    telegram["enabled"] = False

slack = channels.get("slack")
slack_secrets = secret_channels.get("slack", {}) if isinstance(secret_channels.get("slack"), dict) else {}
if isinstance(slack, dict):
    mode = slack.get("mode")
    if not isinstance(mode, str) or not mode.strip():
        mode = "socket"
    required = [non_empty(slack_secrets.get("botToken"))]
    if mode == "socket":
        required.append(non_empty(slack_secrets.get("appToken")))
    else:
        required.append(non_empty(slack_secrets.get("signingSecret")))
    if not all(required):
        slack["enabled"] = False

config_path.write_text(json.dumps(config, indent=2) + "\n")
PY
  chmod 600 "$OPENCLAW_CONFIG_FILE"
}

setpack_openclaw_wire_native_credential_links() {
  setpack_openclaw_ensure_link "$OPENCLAW_CLAUDE_NATIVE_CRED_LINK" "../../cred/claude-cli/credentials.json"
}

setpack_openclaw_import_claude_auth() {
  local force="${1:-0}"
  local user_home source_desc temp_file

  user_home="$(python3 - <<'PY'
import os, pwd
print(pwd.getpwuid(os.getuid()).pw_dir)
PY
)"

  if [ -e "$OPENCLAW_CLAUDE_CRED_FILE" ] && [ "$force" -ne 1 ]; then
    setpack_die "refusing to overwrite existing claude credentials: $OPENCLAW_CLAUDE_CRED_FILE (use -f)"
  fi

  mkdir -p "$OPENCLAW_CLAUDE_CRED_DIR" "$OPENCLAW_CLAUDE_HOME_DIR"
  temp_file="$(mktemp "${TMPDIR:-/tmp}/setpack-claude-auth.XXXXXX")"

  if [ -f "$user_home/.claude/.credentials.json" ]; then
    cp "$user_home/.claude/.credentials.json" "$temp_file"
    source_desc="$user_home/.claude/.credentials.json"
  elif command -v security >/dev/null 2>&1; then
    if ! security find-generic-password -s "Claude Code-credentials" -w > "$temp_file" 2>/dev/null; then
      rm -f "$temp_file"
      setpack_die "missing Claude credentials in $user_home/.claude/.credentials.json and macOS keychain"
    fi
    source_desc="macOS keychain item Claude Code-credentials"
  else
    rm -f "$temp_file"
    setpack_die "missing Claude credentials in $user_home/.claude/.credentials.json"
  fi

  python3 - <<'PY' "$temp_file"
import json, pathlib, sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
oauth = data.get("claudeAiOauth")
if not isinstance(oauth, dict):
    raise SystemExit("Claude credential import failed: missing claudeAiOauth object")
if not isinstance(oauth.get("accessToken"), str) or not oauth.get("accessToken"):
    raise SystemExit("Claude credential import failed: missing accessToken")
expires_at = oauth.get("expiresAt")
if not isinstance(expires_at, (int, float)) or expires_at <= 0:
    raise SystemExit("Claude credential import failed: missing expiresAt")
refresh = oauth.get("refreshToken")
if refresh is not None and not isinstance(refresh, str):
    raise SystemExit("Claude credential import failed: invalid refreshToken")
path.write_text(json.dumps(data, indent=2) + "\n")
PY

  cp "$temp_file" "$OPENCLAW_CLAUDE_CRED_FILE"
  chmod 600 "$OPENCLAW_CLAUDE_CRED_FILE"
  rm -f "$temp_file"
  setpack_openclaw_wire_native_credential_links
  setpack_log "imported claude credentials into $OPENCLAW_CLAUDE_CRED_FILE from $source_desc"
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
  "secrets": {
    "providers": {
      "default": {
        "source": "file",
        "path": "__PACK_SECRET_STORE__",
        "mode": "json"
      }
    },
    "defaults": {
      "file": "default"
    }
  },
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": {
        "source": "file",
        "provider": "default",
        "id": "/gateway/token"
      }
    },
    "controlUi": {
      "enabled": true
    }
  },
  "auth": {
    "profiles": {
      "anthropic:claude-cli": {
        "provider": "claude-cli",
        "mode": "oauth"
      },
      "anthropic:anthropic": {
        "provider": "anthropic",
        "mode": "token"
      },
      "openai-codex:default": {
        "provider": "openai-codex",
        "mode": "oauth"
      },
      "openai:default": {
        "provider": "openai",
        "mode": "api_key"
      }
    },
    "order": {
      "claude-cli": ["anthropic:claude-cli"],
      "anthropic": ["anthropic:anthropic"],
      "openai-codex": ["openai-codex:default"],
      "openai": ["openai:default"]
    }
  },
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://127.0.0.1:11434",
        "apiKey": "ollama-local",
        "models": [
          {
            "id": "qwen3.5:latest",
            "name": "qwen3.5:latest",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 262144,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "__PACK_WORKSPACE__",
      "model": {
        "primary": "claude-cli/claude-opus-4-6",
        "fallbacks": [
          "anthropic/claude-opus-4-6",
          "openai-codex/gpt-5.4",
          "openai/gpt-5.4",
          "ollama/qwen3.5:latest"
        ]
      },
      "models": {
        "claude-cli/claude-opus-4-6": {},
        "anthropic/claude-opus-4-6": {},
        "openai-codex/gpt-5.4": {},
        "openai/gpt-5.4": {},
        "ollama/qwen3.5:latest": {}
      },
      "cliBackends": {
        "claude-cli": {
          "command": "__PACK_CLAUDE_WRAPPER__",
          "env": {
            "HOME": "__PACK_HOME__",
            "CLAUDE_CONFIG_DIR": "__PACK_CLAUDE_HOME__",
            "CODEX_HOME": "__PACK_CODEX_HOME__"
          }
        }
      },
      "heartbeat": {
        "every": "12h"
      }
    }
  },
  "channels": {
    "discord": {
      "enabled": true,
      "token": {
        "source": "file",
        "provider": "default",
        "id": "/channels/discord/botToken"
      },
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist"
    },
    "telegram": {
      "enabled": false,
      "botToken": {
        "source": "file",
        "provider": "default",
        "id": "/channels/telegram/botToken"
      },
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist"
    },
    "slack": {
      "enabled": false,
      "mode": "socket",
      "botToken": {
        "source": "file",
        "provider": "default",
        "id": "/channels/slack/botToken"
      },
      "appToken": {
        "source": "file",
        "provider": "default",
        "id": "/channels/slack/appToken"
      },
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist"
    }
  }
}
EOF
  python3 - <<'PY' "$OPENCLAW_CONFIG_FILE" "$OPENCLAW_DIR/workspace" "$OPENCLAW_CRED_SECRETS_FILE" "$OPENCLAW_CLAUDE_WRAPPER" "$OPENCLAW_HOME_DIR" "$OPENCLAW_CLAUDE_HOME_DIR" "$OPENCLAW_CODEX_HOME_DIR"
import json, pathlib, sys
config_path = pathlib.Path(sys.argv[1])
workspace_path = sys.argv[2]
secret_store_path = sys.argv[3]
claude_wrapper = sys.argv[4]
pack_home = sys.argv[5]
claude_home = sys.argv[6]
codex_home = sys.argv[7]
data = json.loads(config_path.read_text())
data["agents"]["defaults"]["workspace"] = workspace_path
data["agents"]["defaults"]["cliBackends"]["claude-cli"]["command"] = claude_wrapper
data["agents"]["defaults"]["cliBackends"]["claude-cli"]["env"]["HOME"] = pack_home
data["agents"]["defaults"]["cliBackends"]["claude-cli"]["env"]["CLAUDE_CONFIG_DIR"] = claude_home
data["agents"]["defaults"]["cliBackends"]["claude-cli"]["env"]["CODEX_HOME"] = codex_home
data["secrets"]["providers"]["default"]["path"] = secret_store_path
config_path.write_text(json.dumps(data, indent=2) + "\n")
PY
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
  setpack_openclaw_write_secret_store
  setpack_openclaw_write_auth_profiles_template
  setpack_openclaw_write_auth_state_template
  setpack_openclaw_write_state_env_stub
  setpack_openclaw_wire_native_credential_links
  setpack_openclaw_ensure_link "$OPENCLAW_AUTH_PROFILES_LINK" "../../../../cred/agents/main/agent/auth-profiles.json"
  setpack_openclaw_ensure_link "$OPENCLAW_AUTH_STATE_LINK" "../../../../cred/agents/main/agent/auth-state.json"
  setpack_openclaw_sync_config_defaults
  setpack_openclaw_sync_channel_activation
  setpack_openclaw_seed_workspace_docs

  setpack_pack_status_mark "subsystem.openclaw.config" "completed"
  setpack_pack_status_mark "subsystem.openclaw.cred" "configured"
  setpack_pack_status_mark "subsystem.openclaw.state" "configured"
}

setpack_openclaw_validate() {
  setpack_log "validate openclaw"
  [ -x "$OPENCLAW_WRAPPER" ] || setpack_die "missing openclaw wrapper: $OPENCLAW_WRAPPER"
  [ -x "$OPENCLAW_CLAUDE_WRAPPER" ] || setpack_die "missing claude wrapper: $OPENCLAW_CLAUDE_WRAPPER"
  "$OPENCLAW_CLAUDE_WRAPPER" --version >/dev/null
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
