#!/usr/bin/env bash
# SHOWCASE: one binary — try for AVC and FANOTIFY.
# FANOTIFY needs non-root. Prep maps fapo → staff_u so AVC can fire;
# if id -Z is still unconfined_t, you may see FANOTIFY only.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

WORK=/var/tmp/fapo-workshop
mkdir -p "${WORK}"
chmod 1777 "${WORK}" 2>/dev/null || true
BIN="${WORK}/dual"
cp -a /usr/bin/id "${BIN}"
chmod 755 "${BIN}"
chcon -t user_tmp_t "${BIN}" 2>/dev/null || chcon -t tmp_t "${BIN}" 2>/dev/null || true

echo "=== context ==="
ls -lZ "${BIN}" 2>/dev/null || ls -l "${BIN}"
echo "runner will be: ${WORKSHOP_USER} (or current non-root)"
as_user id -Z 2>/dev/null || id -Z 2>/dev/null || true

echo
echo "=== exec as ${WORKSHOP_USER} ==="
set +e
as_user "${BIN}"; echo "exit=$?"
set -e

echo
echo "=== SELinux AVCs (may be empty if runner is unconfined_t) ==="
ausearch --start recent -m AVC 2>/dev/null | tail -25 || echo "(no AVC)"

echo
echo "=== fapolicyd FANOTIFY (no -f: compact events often lack path) ==="
ausearch --start recent -m FANOTIFY -i 2>/dev/null | tail -25 || echo "(no FANOTIFY)"

echo
echo "restorecon alone → still FANOTIFY. trust alone → maybe still AVC (if confined)."
