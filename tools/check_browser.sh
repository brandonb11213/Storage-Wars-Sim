#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
mkdir -p test-results
touch test-results/.gdignore
python3 -u tests/browser_smoke.py "$@" 2>&1 | tee test-results/browser-run.log
