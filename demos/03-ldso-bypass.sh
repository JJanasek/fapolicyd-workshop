#!/usr/bin/env bash
# Demo 3: ld.so bypass — pattern=ld_so must deny.
# Spoiler for EXERCISES.md #3. Exec as fapo.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

WORK=/opt/fapo-workshop
BIN="${WORK}/my-ls-ldso"
mkdir -p "${WORK}"
cp -a /usr/bin/ls "${BIN}"
chmod 755 "${BIN}"

fapolicyd-cli --file delete "${BIN}" --trust-file workshop 2>/dev/null || true
fapolicyd-cli --update 2>/dev/null || true

LDSO=$(find /usr/lib64 /lib64 -name 'ld-linux-*.so.*' 2>/dev/null | head -1)
if [[ -z ${LDSO} ]]; then
  echo "Could not locate ld-linux" >&2
  exit 1
fi

echo "Using loader: ${LDSO}"
echo "=== direct exec as ${WORKSHOP_USER} (expect deny) ==="
set +e
as_user "${BIN}"
echo "direct rc=$?"

echo
echo "=== via ld.so (expect deny) ==="
as_user "${LDSO}" "${BIN}"
echo "ldso rc=$?"
set -e

echo
fapolicyd-cli --list | grep -n ld_so || true
