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
# Re-run safe: drop trust left over from a previous run (round 3).
if fapolicyd-cli --file delete "${BIN}" >/dev/null 2>&1; then
  fapolicyd-cli --update; sleep 1
fi

if [[ ${EUID} -ne 0 ]]; then
  echo "Run with sudo (needs chcon and ausearch)" >&2
  exit 1
fi

pause() {   # let the presenter talk between rounds
  [[ -t 0 ]] && read -r -p "--- Enter for: $1 ---" _ || true
}

attempt() {
  local start
  start=$(date +%T)
  ls -Z "${BIN}"
  set +e
  as_user "${BIN}"; echo "exit=$?"
  set -e
  echo "--- AVC ---"
  ausearch -ts "${start}" -m AVC 2>/dev/null | grep -F 'dual' || echo "(no AVC)"
  echo "--- FANOTIFY ---"
  ausearch -ts "${start}" -m FANOTIFY -i 2>/dev/null | tail -4 || true
  ausearch -ts "${start}" -m FANOTIFY >/dev/null 2>&1 || echo "(no FANOTIFY)"
}

echo "=== runner ==="
as_user id -Z

echo
echo "=== Round 1: wrong label (tmp_t) AND untrusted ==="
attempt
echo "→ Permission denied (EACCES): SELinux answered. fapolicyd was never asked."

pause "fix the label only (chcon -t bin_t)"
echo
echo "=== Round 2: label fixed (bin_t), still untrusted ==="
chcon -t bin_t "${BIN}"
attempt
echo "→ Operation not permitted (EPERM): now fapolicyd answers."

pause "trust the file"
echo
echo "=== Round 3: label fixed AND trusted ==="
fapolicyd-cli --file add "${BIN}" --trust-file showcase >/dev/null
fapolicyd-cli --update
sleep 1
attempt
echo "→ runs. Two layers, two fixes."

echo
echo "Clean up: sudo ./demos/99-cleanup.sh"
