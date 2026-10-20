#!/usr/bin/env bash
# Demo 8: SELinux vs fapolicyd — same action, different denial classes.
# Best on enforcing SELinux + enforcing fapolicyd.
set -euo pipefail

WORK=/var/tmp/fapo-workshop
mkdir -p "${WORK}"
BIN="${WORK}/dual-deny"
cp -a /usr/bin/id "${BIN}"
chmod 755 "${BIN}"
# Intentionally wrong label for many policies (var_tmp_t executable)
chcon -t user_tmp_t "${BIN}" 2>/dev/null || chcon -t tmp_t "${BIN}" 2>/dev/null || true

echo "=== contexts ==="
ls -lZ "${BIN}" || ls -l "${BIN}"
id -Z || true

echo
echo "=== attempt exec ==="
set +e
"${BIN}"
echo "rc=$?"
set -e

echo
echo "=== SELinux AVCs (recent) ==="
ausearch --start recent -m avc -c id 2>/dev/null | tail -30 || \
  ausearch --start recent -m avc 2>/dev/null | tail -30 || true

echo
echo "=== fapolicyd FANOTIFY (recent) ==="
ausearch --start recent -m fanotify -f "${BIN}" 2>/dev/null | tail -30 || true

echo
echo "Teaching points:"
echo "  * Fixing only restorecon may still leave FANOTIFY deny (untrusted)."
echo "  * Trusting the file may still leave AVC (wrong type / no exec perm)."
echo "  * Triage: ausearch -m avc vs -m fanotify — teach both reflexes."
