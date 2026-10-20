#!/usr/bin/env bash
# SHOWCASE: one binary, two denials — AVC and FANOTIFY.
set -euo pipefail
WORK=/var/tmp/fapo-workshop
mkdir -p "${WORK}"
BIN="${WORK}/dual"
cp -a /usr/bin/id "${BIN}"
chmod 755 "${BIN}"
# Wrong type for many policies (tmp/user_tmp) + untrusted path
chcon -t user_tmp_t "${BIN}" 2>/dev/null || chcon -t tmp_t "${BIN}" 2>/dev/null || true

echo "=== context ==="
ls -lZ "${BIN}" 2>/dev/null || ls -l "${BIN}"
id -Z 2>/dev/null || true

echo
echo "=== exec (expect failure) ==="
set +e
"${BIN}"; echo "exit=$?"
set -e

echo
echo "=== SELinux AVCs ==="
ausearch --start recent -m avc 2>/dev/null | tail -25 || echo "(no AVC / ausearch empty)"

echo
echo "=== fapolicyd FANOTIFY ==="
ausearch --start recent -m fanotify -f "${BIN}" 2>/dev/null | tail -25 || echo "(no FANOTIFY)"

echo
echo "Punchline: fix ONLY restorecon → still FANOTIFY. Trust ONLY → still AVC."
echo "Teach customers both reflexes."
