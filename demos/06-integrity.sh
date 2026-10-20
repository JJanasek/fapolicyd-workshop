#!/usr/bin/env bash
# Demo 6: Integrity modes — mutate a trusted file and observe.
# WARNING: temporarily changes fapolicyd.conf; restores on exit if possible.
set -euo pipefail

CONF=/etc/fapolicyd/fapolicyd.conf
BACKUP=$(mktemp)
WORK=/opt/fapo-workshop
BIN="${WORK}/integrity-victim"

cleanup() {
  if [[ -f ${BACKUP} ]]; then
    cp -a "${BACKUP}" "${CONF}"
    systemctl restart fapolicyd || true
  fi
}
trap cleanup EXIT

cp -a "${CONF}" "${BACKUP}"
mkdir -p "${WORK}"
cp -a /usr/bin/true "${BIN}"
chmod 755 "${BIN}"

fapolicyd-cli --file add "${BIN}" --trust-file workshop
fapolicyd-cli --update

echo "=== current integrity setting ==="
grep -E '^integrity' "${CONF}" || echo "(default / unset)"

echo
echo "=== set integrity = size and restart ==="
if grep -q '^integrity' "${CONF}"; then
  sed -i 's/^integrity.*/integrity = size/' "${CONF}"
else
  echo 'integrity = size' >>"${CONF}"
fi
systemctl restart fapolicyd
sleep 1

echo "=== run before mutation ==="
"${BIN}"; echo "rc=$?"

echo
echo "=== mutate file (overwrite with larger payload, keep path) ==="
# Keep executable; change size so size-integrity fails
{
  cat /usr/bin/true
  dd if=/dev/zero bs=1 count=64 2>/dev/null
} >"${BIN}.new"
mv "${BIN}.new" "${BIN}"
chmod 755 "${BIN}"

echo "=== run after mutation (expect deny with integrity=size) ==="
set +e
"${BIN}"
echo "rc=$?"
set -e

echo
echo "=== refresh trust hashes to heal ==="
fapolicyd-cli --file update "${BIN}"
fapolicyd-cli --update
"${BIN}"; echo "healed rc=$?"

echo
echo "Discuss: size vs ima vs sha256 tradeoffs; deadlock risk of sha256 under load."
