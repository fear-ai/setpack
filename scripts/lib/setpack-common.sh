#!/usr/bin/env bash
set -euo pipefail

setpack_log() {
  printf '[setpack] %s\n' "$*" >&2
}

setpack_die() {
  printf '[setpack] error: %s\n' "$*" >&2
  exit 1
}

setpack_root() {
  local script_dir
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  cd -- "$script_dir/../.." && pwd
}

setpack_pack_dir() {
  local set_name="$1"
  local pack_name="$2"
  printf '%s/%s/%s\n' "${SETPACK_PACKS_ROOT:-$HOME/Work/Claw/Setpacks}" "$set_name" "$pack_name"
}

setpack_pack_file() {
  local set_name="$1"
  local pack_name="$2"
  printf '%s/pack.toml\n' "$(setpack_pack_dir "$set_name" "$pack_name")"
}

setpack_lock_file() {
  local set_name="$1"
  local pack_name="$2"
  printf '%s/lock.toml\n' "$(setpack_pack_dir "$set_name" "$pack_name")"
}

setpack_require_pack() {
  local set_name="$1"
  local pack_name="$2"
  local pack_dir
  pack_dir="$(setpack_pack_dir "$set_name" "$pack_name")"
  [ -d "$pack_dir" ] || setpack_die "missing pack directory: $pack_dir"
  [ -f "$pack_dir/pack.toml" ] || setpack_die "missing pack file: $pack_dir/pack.toml"
}

setpack_component_names() {
  local pack_file="$1"
  awk '
    /^\[components\]$/ { in_comp = 1; next }
    /^\[/ && $0 != "[components]" { in_comp = 0 }
    in_comp && $0 ~ /^[a-z]+=(true|false)$/ {
      split($0, parts, "=")
      if (parts[2] == "true") print parts[1]
    }
  ' "$pack_file"
}

setpack_component_dirs() {
  local set_name="$1"
  local pack_name="$2"
  local pack_dir pack_file component_name component_dir
  pack_dir="$(setpack_pack_dir "$set_name" "$pack_name")"
  pack_file="$(setpack_pack_file "$set_name" "$pack_name")"

  if setpack_component_names "$pack_file" | grep -q .; then
    while IFS= read -r component_name; do
      component_dir="$pack_dir/$component_name"
      [ -d "$component_dir" ] || setpack_die "declared component dir missing: $component_dir"
      [ -f "$component_dir/comp.toml" ] || setpack_die "declared component manifest missing: $component_dir/comp.toml"
      printf '%s\n' "$component_dir"
    done < <(setpack_component_names "$pack_file")
    return 0
  fi

  find "$pack_dir" -mindepth 1 -maxdepth 1 -type d ! -name bin ! -name .git \
    | while IFS= read -r component_dir; do
        [ -f "$component_dir/comp.toml" ] || continue
        printf '%s\n' "$component_dir"
      done
}

setpack_component_name() {
  basename "$1"
}

setpack_component_manifest() {
  printf '%s/comp.toml\n' "$1"
}

setpack_component_adapter() {
  local manifest="$1"
  sed -n 's/^install_adapter = "\(.*\)"/\1/p' "$manifest" | head -n 1
}

setpack_component_kind() {
  local manifest="$1"
  sed -n 's/^name = "\(.*\)"/\1/p' "$manifest" | head -n 1
}

setpack_component_bin() {
  local pack_dir="$1"
  local component_name="$2"
  printf '%s/bin/%s\n' "$pack_dir" "$component_name"
}
