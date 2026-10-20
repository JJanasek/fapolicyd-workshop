#!/usr/bin/env bash
# Demo 2: Untrusted executable — deny, trust, re-test.
# Expect fapolicyd enforcing. Safe paths under /opt and /var/tmp.
set -euo pipefail

WORK=/opt/fapo-workshop
BIN="${WORK}/my-ls"

mkdir -p "${WORK}"
cp -a /usr/bin/ls "${BIN}"
chmod 755 "${BIN}"

echo "=== attempt untrusted copy of ls ==="
set +e
"${BIN}"
rc=$?
set -e
echo "exit=${rc} (expect non-zero under enforcing known-libs)"

echo
echo "=== recent fanotify denials (if any) ==="
ausearch --start recent -m fanotify -f "${BIN}" --raw 2>/dev/null | tail -20 || true

echo
echo "=== add to file trust DB ==="
fapolicyd-cli --file add "${BIN}" --trust-file workshop
fapolicyd-cli --update
sleep 1

echo
echo "=== retry after trust ==="
"${BIN}"
echo "ok — trusted copy runs"

echo
echo "=== cleanup hint ==="
echo "fapolicyd-cli --file delete ${BIN} && fapolicyd-cli --update && rm -f ${BIN}"
