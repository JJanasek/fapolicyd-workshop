#!/usr/bin/env bash
# SHOWCASE: dropped ELF/script under $HOME cannot run.
# Prefer: su - fapo && ./demos/showcases/03-home-drop.sh
# If run as root, re-exec under fapo (HOME must be that user's).
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

if [[ ${EUID} -eq 0 ]]; then
  if id "${WORKSHOP_USER}" &>/dev/null; then
    echo "Re-running as ${WORKSHOP_USER} (root would skip deny)..."
    exec runuser -u "${WORKSHOP_USER}" -- "$0" "$@"
  fi
  echo "WARN: no ${WORKSHOP_USER}; root often ALLOW untrusted home drops." >&2
fi

DROP="${HOME}/.cache/totally-legit-update"
mkdir -p "$(dirname "${DROP}")"

echo "=== dropped ELF (copy of id) ==="
cp -a /usr/bin/id "${DROP}"
chmod 755 "${DROP}"

echo "=== run (expect DENY) ==="
set +e
"${DROP}"
echo "exit=$?"
set -e

echo
echo "=== python drop ==="
PY="${HOME}/.cache/legit-helper.py"
cat >"${PY}" <<'PY'
#!/usr/bin/env python3
print("pwned")
PY
chmod 755 "${PY}"
set +e
python3 "${PY}"
echo "python exit=$?"
set -e

echo
echo "pip/curl into \$HOME hits the same class of deny."
echo "ausearch: sudo ausearch --start recent -m fanotify -f ${DROP}"
