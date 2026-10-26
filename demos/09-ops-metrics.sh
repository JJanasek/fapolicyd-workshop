#!/usr/bin/env bash
# Demo 9: Ops toolkit — status, metrics, timing, ignore_mounts preflight.
set -euo pipefail

echo "=== status (health + DB generations / sizing) ==="
fapolicyd-cli --check-status || true

echo
echo "=== metrics (rule hits, caches) ==="
fapolicyd-cli --check-metrics || true

echo
echo "=== optional timing window (~5s of load) ==="
if fapolicyd-cli --timing-start 2>/dev/null; then
  # light churn
  for i in $(seq 1 200); do ls /usr/bin >/dev/null; done
  fapolicyd-cli --timing-stop || true
else
  echo "(timing API not available on this build — skip)"
fi

echo
echo "=== ignore_mounts preflight (advisory) ==="
fapolicyd-cli --check-ignore_mounts --verbose 2>/dev/null | head -60 || \
  echo "(no ignore_mounts configured or option missing)"

echo
echo "=== watch_fs vs mounts ==="
fapolicyd-cli --check-watch_fs || true

echo
echo "Tune q_size/caches from metrics; ignore_mounts only for noexec data mounts."
