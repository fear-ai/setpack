. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/setpack-openclaw.sh"
. "$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/setpack-gog.sh"

if [ -n "${SETPACK_OPENCLAW_GOG_SH_LOADED:-}" ]; then
  return 0
fi
SETPACK_OPENCLAW_GOG_SH_LOADED=1

setpack_openclaw_gog_refresh_integration_status() {
  local config_file openclaw_gog_state
  config_file="$OPENCLAW_CONFIG_FILE"
  openclaw_gog_state="$(setpack_pack_status_value 'integration\.openclaw\.gog\.status')"

  if [ -x "$OPENCLAW_WRAPPER" ] && [ -x "$GOG_WRAPPER" ]; then
    if [ "$openclaw_gog_state" != "validated" ]; then
      setpack_pack_status_mark "integration.openclaw.gog" "configured"
    fi
  fi

  [ -f "$config_file" ] || return 0

  if grep -q '"provider": "brave"' "$config_file"; then
    setpack_pack_status_mark "integration.openclaw.brave" "configured"
  fi
  if grep -q 'ollama/' "$config_file"; then
    setpack_pack_status_mark "integration.openclaw.ollama" "configured"
  fi
  if grep -q 'openai/gpt-5.4' "$config_file"; then
    setpack_pack_status_mark "integration.openclaw.openai" "configured"
  fi
  if grep -q 'openai-codex/gpt-5.4' "$config_file"; then
    setpack_pack_status_mark "integration.openclaw.openai_codex" "configured"
  fi
  if grep -q 'anthropic/claude-opus-4-6' "$config_file"; then
    setpack_pack_status_mark "integration.openclaw.anthropic" "configured"
  fi
  if grep -q 'claude-cli/claude-opus-4-6' "$config_file"; then
    setpack_pack_status_mark "integration.openclaw.claude_cli" "configured"
  fi
}

setpack_openclaw_gog_refresh_overall() {
  local openclaw_bundle_state openclaw_wrapper_state openclaw_config_state
  local gog_bundle_state gog_wrapper_state openclaw_gog_state

  openclaw_bundle_state="$(setpack_pack_status_value 'subsystem\.openclaw\.bundle\.status')"
  openclaw_wrapper_state="$(setpack_pack_status_value 'subsystem\.openclaw\.wrapper\.status')"
  openclaw_config_state="$(setpack_pack_status_value 'subsystem\.openclaw\.config\.status')"
  gog_bundle_state="$(setpack_pack_status_value 'subsystem\.gog\.bundle\.status')"
  gog_wrapper_state="$(setpack_pack_status_value 'subsystem\.gog\.wrapper\.status')"
  openclaw_gog_state="$(setpack_pack_status_value 'integration\.openclaw\.gog\.status')"

  if [ "$openclaw_bundle_state" = "validated" ] && [ "$openclaw_wrapper_state" = "validated" ] && [ "$openclaw_config_state" = "validated" ] && [ "$gog_bundle_state" = "validated" ] && [ "$gog_wrapper_state" = "validated" ] && { [ "$openclaw_gog_state" = "configured" ] || [ "$openclaw_gog_state" = "validated" ]; }; then
    setpack_pack_status_set "overall.status" "openclaw_and_gog_ready"
    setpack_pack_status_set "overall.ready_to_run" "openclaw_and_gog"
  elif [ "$openclaw_bundle_state" = "validated" ] && [ "$openclaw_wrapper_state" = "validated" ] && [ "$openclaw_config_state" = "validated" ]; then
    setpack_pack_status_set "overall.status" "openclaw_ready"
    setpack_pack_status_set "overall.ready_to_run" "openclaw_only"
  elif [ "$openclaw_bundle_state" = "validated" ] || [ "$gog_bundle_state" = "validated" ]; then
    setpack_pack_status_set "overall.status" "partially_validated"
    setpack_pack_status_set "overall.ready_to_run" "partial"
  else
    setpack_pack_status_set "overall.status" "bootstrap"
    setpack_pack_status_set "overall.ready_to_run" "no"
  fi

  setpack_pack_status_set "pack.updated_at" "$(setpack_ts)"
}

setpack_openclaw_gog_validate_combination() {
  local openclaw_config_state

  setpack_log "validate openclaw-gog combination"
  [ -x "$OPENCLAW_WRAPPER" ] || setpack_die "missing openclaw wrapper: $OPENCLAW_WRAPPER"
  [ -x "$GOG_WRAPPER" ] || setpack_die "missing gog wrapper: $GOG_WRAPPER"
  openclaw_config_state="$(setpack_pack_status_value 'subsystem\.openclaw\.config\.status')"
  if [ "$openclaw_config_state" = "validated" ]; then
    setpack_pack_status_mark "integration.openclaw.gog" "validated"
  else
    setpack_pack_status_mark "integration.openclaw.gog" "configured"
  fi
  setpack_openclaw_gog_refresh_integration_status
  setpack_openclaw_gog_refresh_overall
}
