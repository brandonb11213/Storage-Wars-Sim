#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source tools/env.sh
port="${STORAGE_WARS_PORT:-8060}"
mkdir -p "$STORAGE_WARS_RUNTIME"
test -s build/web/index.html
page="$STORAGE_WARS_RUNTIME/web-readiness.html"
ready() {
  curl -fsS --max-time 2 "http://127.0.0.1:$port/index.html" -o "$page" 2>/dev/null && rg -q 'Storage Wars Sim' "$page"
}
if ready; then
  printf 'Storage Wars web server is already responding on port %s.\n' "$port"
  exit 0
fi
nohup python3 -m http.server "$port" --bind 0.0.0.0 --directory build/web > "$STORAGE_WARS_RUNTIME/web-$port.log" 2>&1 < /dev/null &
server_pid=$!
printf '%s\n' "$server_pid" > "$STORAGE_WARS_RUNTIME/web-$port.pid"
for attempt in {1..30}; do
  if ready; then
    printf 'Storage Wars web server is responding on port %s (PID %s).\n' "$port" "$server_pid"
    exit 0
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    cat "$STORAGE_WARS_RUNTIME/web-$port.log"
    exit 1
  fi
  sleep 0.2
done
printf 'Server did not become ready; inspect %s.\n' "$STORAGE_WARS_RUNTIME/web-$port.log" >&2
exit 1
