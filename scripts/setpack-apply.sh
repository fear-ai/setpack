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

setpack_log "apply set=$set_name pack=$pack_name"
setpack_log "pack dir: $pack_dir"

setpack_component_dirs "$set_name" "$pack_name" | while IFS= read -r component_dir; do
  component_name="$(setpack_component_name "$component_dir")"
  manifest="$(setpack_component_manifest "$component_dir")"
  adapter="$(setpack_component_adapter "$manifest")"
  kind="$(setpack_component_kind "$manifest")"

  setpack_log "component=$component_name kind=${kind:-unknown} adapter=${adapter:-unknown}"

  "$script_dir/adapters/install-package.sh" \
    "$set_name" \
    "$pack_name" \
    "$component_name" \
    "$manifest"
done

setpack_log "apply complete"
