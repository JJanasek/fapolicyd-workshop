#!/usr/bin/env bash
# SHOWCASE: Clone attack — bit-identical copy of ls is still untrusted.
set -euo pipefail
WORK=/opt/fapo-workshop
BIN="${WORK}/evil-ls"
mkdir -p "${WORK}"

echo "=== 1) Clone /usr/bin/ls to ${BIN} ==="
cp -a /usr/bin/ls "${BIN}"
chmod 755 "${BIN}"
cmp -s /usr/bin/ls "${BIN}" && echo "bytes identical to /usr/bin/ls"

echo
echo "=== 2) Execute clone (expect DENY under enforcing) ==="
set +e
"${BIN}"
echo "exit=$?"
set -e

echo
echo "=== 3) Trust it, update, retry ==="
fapolicyd-cli --file add "${BIN}" --trust-file workshop
fapolicyd-cli --update
sleep 1
"${BIN}"
echo "trusted clone runs"

echo
echo "Punchline: same bytes, wrong provenance → deny until trust DB says so."
echo "Cleanup: fapolicyd-cli --file delete ${BIN} && fapolicyd-cli --update && rm -f ${BIN}"
