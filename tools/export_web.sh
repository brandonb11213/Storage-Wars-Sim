#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
mkdir -p build/web test-results
touch build/.gdignore test-results/.gdignore
godot --headless --path . --export-release Web build/web/index.html 2>&1 | tee test-results/export.log
if rg -n 'SCRIPT ERROR:|ERROR:' test-results/export.log; then
  exit 1
fi
test -s build/web/index.html
test -s build/web/index.wasm
test -s build/web/index.pck
printf 'Static web build: build/web (serve the entire directory).\n'
