#!/usr/bin/env bash
# Demo 6: integrity=size — mutate trusted file, observe deny, heal.
# Restores fapolicyd.conf on exit. Exec as fapo.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

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

echo "=== current integrity ==="
grep -E '^integrity' "${CONF}" || echo "(default / unset)"

echo
echo "=== set integrity = size, restart ==="
if grep -q '^integrity' "${CONF}"; then
  sed -i 's/^integrity.*/integrity = size/' "${CONF}"
else
  echo 'integrity = size' >>"${CONF}"
fi
systemctl restart fapolicyd
sleep 1

echo "=== run as ${WORKSHOP_USER} before mutation ==="
as_user "${BIN}"; echo "rc=$?"

echo
echo "=== mutate (grow file) ==="
{ cat /usr/bin/true; dd if=/dev/zero bs=1 count=64 2>/dev/null; } >"${BIN}.new"
mv "${BIN}.new" "${BIN}"
chmod 755 "${BIN}"

echo "=== run after mutation (expect deny) ==="
set +e
as_user "${BIN}"
echo "rc=$?"
set -e

echo
echo "=== heal trust hashes ==="
fapolicyd-cli --file update "${BIN}"
fapolicyd-cli --update
as_user "${BIN}"; echo "healed rc=$?"
