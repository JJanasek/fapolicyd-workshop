#!/usr/bin/env bash
# SHOWCASE: one binary, wrong for both layers — AVC first, then FANOTIFY.
# SELinux is asked before fapolicyd, so each attempt logs the first denier.
# FANOTIFY needs non-root. as_user logs in over ssh → staff_t for AVC.
# Plain su/runuser stay unconfined_t (FANOTIFY only); runcon is denied.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

WORK=/var/tmp/fapo-workshop
mkdir -p "${WORK}"
chmod 1777 "${WORK}" 2>/dev/null || true
BIN="${WORK}/dual"
cp -a /usr/bin/id "${BIN}"
chmod 755 "${BIN}"
# user_tmp_t is executable by staff_t while staff_exec_content is on.
# tmp_t is not — that is the AVC. cp -a would otherwise keep bin_t.
chcon -t tmp_t "${BIN}"

echo "=== context ==="
ls -lZ "${BIN}" 2>/dev/null || ls -l "${BIN}"
echo "runner will be: ${WORKSHOP_USER} (or current non-root)"
as_user id -Z 2>/dev/null || id -Z 2>/dev/null || true

echo
START=$(date +%T)
echo "=== exec as ${WORKSHOP_USER} ==="
set +e
as_user "${BIN}"; echo "exit=$?"
set -e

echo
echo "=== SELinux AVCs (may be empty if runner is unconfined_t) ==="
ausearch --start "${START}" -m AVC 2>/dev/null | tail -25 || echo "(no AVC)"

echo
echo "=== fapolicyd FANOTIFY (no -f: compact events often lack path) ==="
ausearch --start "${START}" -m FANOTIFY -i 2>/dev/null | tail -25 || echo "(no FANOTIFY)"

echo
echo "Permission denied = SELinux/DAC (EACCES); Operation not permitted = fapolicyd (EPERM)."
echo "chcon -t bin_t → AVC gone, now FANOTIFY denies (still untrusted)."
echo "trust alone → AVC remains while type is tmp_t."
echo "restorecon on /var/tmp often changes nothing (file_contexts <<none>>)."
