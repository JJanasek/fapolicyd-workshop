#!/usr/bin/env bash
# SHOWCASE: ld.so cannot smuggle an untrusted ELF.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

WORK=/opt/fapo-workshop
BIN="${WORK}/smuggle-ls"
cp -a /usr/bin/ls "${BIN}"
chmod 755 "${BIN}"
fapolicyd-cli --file delete "${BIN}" 2>/dev/null || true
fapolicyd-cli --update 2>/dev/null || true

LDSO=$(find /usr/lib64 /lib64 -name 'ld-linux-*.so.*' 2>/dev/null | head -1)
[[ -n ${LDSO} ]] || { echo "ld-linux not found" >&2; exit 1; }

echo "Loader: ${LDSO}"
echo "=== direct exec as ${WORKSHOP_USER} (expect DENY) ==="
set +e
as_user "${BIN}"
echo "direct rc=$?"

echo
echo "=== via ld.so (expect DENY) ==="
as_user "${LDSO}" "${BIN}"
echo "ldso rc=$?"
set -e

echo
fapolicyd-cli --list | grep -n ld_so || true
