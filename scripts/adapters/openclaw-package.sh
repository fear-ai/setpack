#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/setpack-common.sh
. "$script_dir/../lib/setpack-common.sh"

validate_mode=0
if [ "${1:-}" = "--validate" ]; then
  validate_mode=1
  shift
fi

set_name="${1:-}"
pack_name="${2:-}"
component_name="${3:-}"
manifest="${4:-}"

[ -n "$set_name" ] || setpack_die "missing set"
[ -n "$pack_name" ] || setpack_die "missing pack"
[ -n "$component_name" ] || setpack_die "missing component"
[ -n "$manifest" ] || setpack_die "missing manifest"

pack_dir="$(setpack_pack_dir "$set_name" "$pack_name")"
component_dir="$pack_dir/$component_name"

if [ "$validate_mode" -eq 1 ]; then
  [ -d "$component_dir/config" ] || setpack_die "missing openclaw config dir"
  [ -d "$component_dir/state" ] || setpack_die "missing openclaw state dir"
  [ -d "$component_dir/workspace" ] || setpack_die "missing openclaw workspace dir"
  [ -x "$pack_dir/bin/openclaw" ] || setpack_die "missing openclaw wrapper"
  setpack_log "openclaw validate: wrapper, config/state/workspace present"
  setpack_log "openclaw validate: add smoke checks for version, config file, models status"
  exit 0
fi

setpack_log "openclaw apply: ensure standard dirs exist"
mkdir -p \
  "$component_dir/bundle" \
  "$component_dir/config" \
  "$component_dir/cred" \
  "$component_dir/state" \
  "$component_dir/runtime" \
  "$component_dir/workspace"

setpack_log "openclaw apply: choose one install strategy"
setpack_log "  - system-existing: record existing npm/brew binary and wrap it"
setpack_log "  - npm-dist: npm install --prefix <bundle> openclaw@<version>"
setpack_log "  - git-build: clone repo, pin node/pnpm, build dist into <bundle>"

setpack_log "openclaw apply: render openclaw.json into $component_dir/config"
setpack_log "openclaw apply: materialize provider creds and channel creds"
setpack_log "openclaw apply: restore state snapshot only when explicitly requested"
setpack_log "openclaw apply: refresh wrapper at $pack_dir/bin/openclaw"
setpack_log "openclaw apply: optional sandbox layer can wrap native OpenClaw --profile or dedicated state roots"
setpack_log "openclaw apply: NemoClaw technique can be applied as workspace import/export, not as bundle install"
