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
pack_file="$(setpack_pack_file "$set_name" "$pack_name")"
lock_file="$(setpack_lock_file "$set_name" "$pack_name")"

printf 'set=%s\n' "$set_name"
printf 'pack=%s\n' "$pack_name"
printf 'pack_dir=%s\n' "$pack_dir"
printf 'pack_file=%s\n' "$pack_file"
printf 'lock_file=%s\n' "$lock_file"

setpack_log "components"
setpack_component_dirs "$set_name" "$pack_name" | while IFS= read -r component_dir; do
  component_name="$(setpack_component_name "$component_dir")"
  manifest="$(setpack_component_manifest "$component_dir")"
  adapter="$(setpack_component_adapter "$manifest")"
  kind="$(setpack_component_kind "$manifest")"
  printf 'component=%s kind=%s adapter=%s dir=%s\n' \
    "$component_name" "${kind:-unknown}" "${adapter:-unknown}" "$component_dir"
done
