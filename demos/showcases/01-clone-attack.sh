#!/usr/bin/env bash
# SHOWCASE: clone of ls is untrusted until added to trust DB.
# Run as root for setup/trust; binary under as_user (fapo) — root would be allowed.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

WORK=/opt/fapo-workshop
BIN="${WORK}/evil-ls"
mkdir -p "${WORK}"

echo "=== 1) Clone /usr/bin/ls → ${BIN} ==="
cp -a /usr/bin/ls "${BIN}"
chmod 755 "${BIN}"
cmp -s /usr/bin/ls "${BIN}" && echo "bytes identical to /usr/bin/ls"

echo
echo "=== 2) Exec as ${WORKSHOP_USER} (expect DENY) ==="
set +e
as_user "${BIN}"
echo "exit=$?"
set -e

echo
echo "=== 3) Trust + update, retry ==="
fapolicyd-cli --file add "${BIN}" --trust-file workshop
fapolicyd-cli --update
sleep 1
as_user "${BIN}"
echo "trusted clone runs"

echo
echo "Same bytes, wrong provenance → deny until trust DB says so."
echo "Cleanup: fapolicyd-cli --file delete ${BIN} && fapolicyd-cli --update && rm -f ${BIN}"
