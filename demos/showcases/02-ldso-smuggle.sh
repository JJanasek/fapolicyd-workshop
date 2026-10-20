#!/usr/bin/env bash
# SHOWCASE: ld.so cannot smuggle an untrusted ELF.
set -euo pipefail
WORK=/opt/fapo-workshop
BIN="${WORK}/smuggle-ls"
cp -a /usr/bin/ls "${BIN}"
chmod 755 "${BIN}"
fapolicyd-cli --file delete "${BIN}" 2>/dev/null || true
fapolicyd-cli --update 2>/dev/null || true

LDSO=$(find /usr/lib64 /lib64 -name 'ld-linux-*.so.*' 2>/dev/null | head -1)
[[ -n ${LDSO} ]] || { echo "ld-linux not found"; exit 1; }

echo "Loader: ${LDSO}"
echo "=== direct exec (expect DENY) ==="
set +e
"${BIN}"; echo "direct rc=$?"
echo
echo "=== via ld.so (expect DENY — pattern=ld_so) ==="
"${LDSO}" "${BIN}"; echo "ldso rc=$?"
set -e

echo
echo "Punchline: trusted interpreter/loader ≠ permission to run untrusted code."
fapolicyd-cli --list | grep -n ld_so || true
