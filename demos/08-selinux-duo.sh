#!/usr/bin/env bash
# Demo 8: SELinux vs fapolicyd. Spoiler for EXERCISES.md #5.
# FANOTIFY: needs non-root. AVC: only if the runner is confined (not unconfined_t).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

WORK=/var/tmp/fapo-workshop
mkdir -p "${WORK}"
chmod 1777 "${WORK}" 2>/dev/null || true
BIN="${WORK}/dual-deny"
cp -a /usr/bin/id "${BIN}"
chmod 755 "${BIN}"
chcon -t user_tmp_t "${BIN}" 2>/dev/null || chcon -t tmp_t "${BIN}" 2>/dev/null || true

echo "=== contexts ==="
ls -lZ "${BIN}" || ls -l "${BIN}"
as_user id -Z 2>/dev/null || id -Z || true

echo
echo "=== exec as ${WORKSHOP_USER} ==="
set +e
as_user "${BIN}"
echo "rc=$?"
set -e

echo
echo "=== SELinux AVCs (empty if unconfined_t) ==="
ausearch --start recent -m avc 2>/dev/null | tail -30 || true

echo
echo "=== fapolicyd FANOTIFY ==="
ausearch --start recent -m fanotify -f "${BIN}" 2>/dev/null | tail -30 || true
