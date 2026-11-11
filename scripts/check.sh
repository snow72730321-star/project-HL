#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
check_log="$(mktemp)"
trap 'rm -f "$check_log"' EXIT
run_check() {
  local expected="$1"
  shift
  local command_status=0
  timeout 45s "$repo_dir/scripts/godot.sh" "$@" >"$check_log" 2>&1 || command_status=$?
  cat "$check_log"
  if [[ "$command_status" -ne 0 ]] || rg -q 'SCRIPT ERROR:|^ERROR:|Parse Error:' "$check_log"; then
    return 1
  fi
  if [[ -n "$expected" ]]; then
    rg -qF "$expected" "$check_log"
  fi
}
run_check '' --headless --editor --import --quit
run_check 'COMBAT TEST PASS: 128' --headless --script res://tests/combat_test.gd
run_check 'GAME SMOKE PASS:' --headless -- --game-smoke
run_check 'SMOKE PASS:' --headless res://main.tscn -- --smoke
