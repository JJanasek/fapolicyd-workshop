#!/usr/bin/env bash
# Spoiler for EXERCISES.md #2 — prefer typing that yourself.
# Setup as root OK; exec via as_user (fapo).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

ask() {
  local prompt=$1 ans
  read -r -p "$prompt " ans
  echo "  (you said: ${ans})"
}

WORK=/opt/fapo-workshop
BIN="${WORK}/my-ls"

mkdir -p "${WORK}"
cp -a /usr/bin/ls "${BIN}"
chmod 755 "${BIN}"

echo "Created ${BIN}. Exec checks run as uid of ${WORKSHOP_USER}."
cmp -s /usr/bin/ls "${BIN}" && echo "Bytes identical to /usr/bin/ls."
echo
ask "PREDICT: will it run under enforcing fapolicyd as ${WORKSHOP_USER}? (y/n)"

echo
echo "=== run as ${WORKSHOP_USER} ==="
set +e
as_user "${BIN}"
rc=$?
set -e
echo "exit=${rc}"

echo
ask "Match your prediction? fanotify or avc in ausearch?"

echo
ausearch --start recent -m fanotify -f "${BIN}" 2>/dev/null | tail -15 || true

echo
ask "NEXT: which two fapolicyd-cli commands heal this? (do them in another shell, Enter here)"

echo
echo "=== verify ==="
if ! as_user "${BIN}" 2>/dev/null; then
  echo "(still denied — applying trust)"
  fapolicyd-cli --file add "${BIN}" --trust-file workshop
  fapolicyd-cli --update
  sleep 1
  as_user "${BIN}"
fi
echo "ok when trusted"

echo
echo "Cleanup: fapolicyd-cli --file delete ${BIN} --trust-file workshop && fapolicyd-cli --update && rm -f ${BIN}"
