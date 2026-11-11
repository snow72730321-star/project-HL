#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$repo_dir/.local/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$repo_dir/.local/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$repo_dir/.local/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
exec godot --path "$repo_dir/godot" "$@"
