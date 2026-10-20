#!/usr/bin/env bash
# Demo 1: Baseline inventory — what a power user looks at first.
set -euo pipefail

echo "=== service ==="
systemctl is-active fapolicyd || true
systemctl status fapolicyd --no-pager -l | head -20

echo
echo "=== assembled policy (first 40 lines) ==="
fapolicyd-cli --list | head -40

echo
echo "=== trust DB sample ==="
fapolicyd-cli --dump-db 2>/dev/null | head -15 || fapolicyd-cli -D | head -15

echo
echo "=== health ==="
fapolicyd-cli --check-status || true

echo
echo "=== PATH coverage ==="
fapolicyd-cli --check-path || true

echo
echo "=== config sanity ==="
fapolicyd-cli --check-config || true
fapolicyd-cli --check-rules --lint || true
