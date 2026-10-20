#!/usr/bin/env bash
# Demo 3: ld.so bypass attempt — pattern=ld_so must deny.
set -euo pipefail

WORK=/opt/fapo-workshop
BIN="${WORK}/my-ls-ldso"
cp -a /usr/bin/ls "${BIN}"
chmod 755 "${BIN}"

# Do NOT trust this binary for this demo
fapolicyd-cli --file delete "${BIN}" 2>/dev/null || true
fapolicyd-cli --update 2>/dev/null || true

LDSO=$(find /usr/lib64 /lib64 -name 'ld-linux-*.so.*' 2>/dev/null | head -1)
if [[ -z ${LDSO} ]]; then
  echo "Could not locate ld-linux" >&2
  exit 1
fi

echo "Using loader: ${LDSO}"
echo "=== direct exec (expect deny) ==="
set +e
"${BIN}"
echo "direct rc=$?"

echo
echo "=== via ld.so (expect deny — even if loader is trusted) ==="
"${LDSO}" "${BIN}"
echo "ldso rc=$?"
set -e

echo
echo "Teaching point: shipped rules deny pattern=ld_so to close this class of bypass."
fapolicyd-cli --list | grep -n ld_so || true
