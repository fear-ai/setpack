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

adapter="$(setpack_component_adapter "$manifest")"
[ -n "$adapter" ] || setpack_die "missing install_adapter in $manifest"

pack_dir="$(setpack_pack_dir "$set_name" "$pack_name")"
component_dir="$pack_dir/$component_name"

case "$adapter" in
  system-existing)
    if [ "$validate_mode" -eq 1 ]; then
      setpack_log "validate adapter=system-existing component=$component_name"
    else
      setpack_log "apply adapter=system-existing component=$component_name"
      setpack_log "record binary path/version, do not reinstall"
    fi
    ;;
  brew|npm-dist|npm-source-build|curl-tarball|git-build|cargo-build|manual)
    if [ "$validate_mode" -eq 1 ]; then
      setpack_log "validate adapter=$adapter component=$component_name"
    else
      setpack_log "apply adapter=$adapter component=$component_name"
      setpack_log "install bundle into $component_dir/bundle"
    fi
    ;;
  *)
    setpack_die "unknown install adapter: $adapter"
    ;;
esac

case "$component_name" in
  openclaw)
    "$script_dir/openclaw-package.sh" \
      ${validate_mode:+--validate} \
      "$set_name" "$pack_name" "$component_name" "$manifest"
    ;;
  *)
    if [ "$validate_mode" -eq 1 ]; then
      setpack_log "generic validate component=$component_name"
    else
      setpack_log "generic apply component=$component_name"
      setpack_log "render config, materialize cred, restore state, refresh wrapper"
    fi
    ;;
esac
