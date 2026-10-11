#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.runtime/cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/.runtime/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.runtime/config}"
mkdir -p "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" test-results
touch test-results/.gdignore
godot --headless --editor --path . --import > test-results/import.log 2>&1
if rg -n 'SCRIPT ERROR:|Parse Error:|ERROR:' test-results/import.log; then
  exit 1
fi
godot --headless --path . --script tests/run_tests.gd 2>&1 | tee test-results/headless.log
if rg -n 'SCRIPT ERROR:|ERROR:' test-results/headless.log; then
  exit 1
fi

godot --headless --path . --script tests/economy_simulation.gd 2>&1 | tee test-results/economy.log
if rg -n 'SCRIPT ERROR:|ERROR:' test-results/economy.log; then
  exit 1
fi
