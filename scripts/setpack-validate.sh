#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/setpack-common.sh
. "$script_dir/lib/setpack-common.sh"

usage() {
  echo "usage: $(basename "$0") <set> <pack>" >&2
  exit 2
}

set_name="${1:-}"
pack_name="${2:-}"
[ -n "$set_name" ] || usage
[ -n "$pack_name" ] || usage

setpack_require_pack "$set_name" "$pack_name"
pack_dir="$(setpack_pack_dir "$set_name" "$pack_name")"

[ -d "$pack_dir/bin" ] || setpack_die "missing pack bin dir: $pack_dir/bin"
[ -f "$pack_dir/pack.toml" ] || setpack_die "missing pack.toml"

setpack_component_dirs "$set_name" "$pack_name" | while IFS= read -r component_dir; do
  component_name="$(setpack_component_name "$component_dir")"
  wrapper="$(setpack_component_bin "$pack_dir" "$component_name")"
  manifest="$(setpack_component_manifest "$component_dir")"

  [ -f "$manifest" ] || setpack_die "missing package manifest: $manifest"
  [ -x "$wrapper" ] || setpack_die "missing wrapper: $wrapper"

  setpack_log "validate component=$component_name"
  "$script_dir/adapters/install-package.sh" \
    --validate \
    "$set_name" \
    "$pack_name" \
    "$component_name" \
    "$manifest"
done

setpack_log "validate complete"
