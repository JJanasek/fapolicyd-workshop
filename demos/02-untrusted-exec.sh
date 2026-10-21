#!/usr/bin/env bash
# SPOILER for Exercise 2 — prefer typing commands from EXERCISES.md yourself.
# This script pauses so you still have to think.
set -euo pipefail

ask() {
  local prompt=$1
  local ans
  read -r -p "$prompt " ans
  echo "  (you said: ${ans})"
}

WORK=/opt/fapo-workshop
BIN="${WORK}/my-ls"

mkdir -p "${WORK}"
cp -a /usr/bin/ls "${BIN}"
chmod 755 "${BIN}"

echo "Created ${BIN} (copy of /usr/bin/ls)."
cmp -s /usr/bin/ls "${BIN}" && echo "Bytes are identical to /usr/bin/ls."
echo
ask "PREDICT: will ${BIN} run under enforcing fapolicyd? (y/n + why in your notes)"

echo
echo "=== running it now ==="
set +e
"${BIN}"
rc=$?
set -e
echo "exit=${rc}"

echo
ask "Was that what you predicted? What audit type will ausearch show? (fanotify/avc)"

echo
echo "=== ausearch fanotify ==="
ausearch --start recent -m fanotify -f "${BIN}" 2>/dev/null | tail -15 || true

echo
ask "NEXT: what two fapolicyd-cli commands heal this? (type them yourself in another shell, then press Enter here)"

echo
echo "=== verifying trust (script will also trust if still denied) ==="
if ! "${BIN}" 2>/dev/null; then
  echo "(still denied — applying spoiler trust)"
  fapolicyd-cli --file add "${BIN}" --trust-file workshop
  fapolicyd-cli --update
  sleep 1
  "${BIN}"
fi
echo "ok — runs when trusted"

echo
echo "Write in notes: why identical bytes were denied; commands you used to trust."
echo "Cleanup: fapolicyd-cli --file delete ${BIN} && fapolicyd-cli --update && rm -f ${BIN}"
