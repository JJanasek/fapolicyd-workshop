#!/usr/bin/env bash
# SHOWCASE: mutate trusted file under integrity=size → deny, then heal.
# Temporarily edits fapolicyd.conf; restores on exit.
# Exec checks run as fapo — root bypasses via uid=0 trust=1 subject rule.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

CONF=/etc/fapolicyd/fapolicyd.conf
BACKUP=$(mktemp)
WORK=/opt/fapo-workshop
BIN="${WORK}/integrity-demo"

cleanup() {
  cp -a "${BACKUP}" "${CONF}" 2>/dev/null || true
  systemctl restart fapolicyd 2>/dev/null || true
}
trap cleanup EXIT
cp -a "${CONF}" "${BACKUP}"

mkdir -p "${WORK}"
cp -a /usr/bin/true "${BIN}"
chmod 755 "${BIN}"
fapolicyd-cli --file add "${BIN}" --trust-file workshop
fapolicyd-cli --update

if grep -q '^integrity' "${CONF}"; then
  sed -i 's/^integrity.*/integrity = size/' "${CONF}"
else
  echo 'integrity = size' >>"${CONF}"
fi
systemctl restart fapolicyd
sleep 1

echo "=== run as ${WORKSHOP_USER} (trusted, size ok) ==="
as_user "${BIN}"; echo "ok rc=$?"

echo
echo "=== mutate (grow file, keep path) ==="
{ cat /usr/bin/true; dd if=/dev/zero bs=1 count=32 2>/dev/null; } >"${BIN}.new"
mv "${BIN}.new" "${BIN}"
chmod 755 "${BIN}"

echo "=== run after mutation (expect DENY) ==="
set +e
as_user "${BIN}"; echo "exit=$?"
set -e

echo
echo "=== heal trust hashes ==="
fapolicyd-cli --file update "${BIN}"
fapolicyd-cli --update
as_user "${BIN}"; echo "healed rc=$?"

echo
echo "Trust is path+size(+hash). Mutation without --file update = deny."
