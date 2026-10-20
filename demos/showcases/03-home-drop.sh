#!/usr/bin/env bash
# SHOWCASE: "malware" dropped in $HOME (simulated download) cannot run.
# Run as a normal user for realism; sudo only if ausearch needs it.
set -euo pipefail

DROP="${HOME}/.cache/totally-legit-update"
mkdir -p "$(dirname "${DROP}")"

echo "=== simulate a dropped ELF (copy of id) ==="
cp -a /usr/bin/id "${DROP}"
chmod 755 "${DROP}"

echo "=== try to run it (expect DENY) ==="
set +e
"${DROP}"
echo "exit=$?"
set -e

echo
echo "=== optional: python drop ==="
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
echo "Punchline: pip/curl/wget into \$HOME is exactly this class of failure."
echo "Remediation: don't; or package it; or trust a deliberate /opt tree."
echo "Audit: sudo ausearch --start recent -m fanotify -f ${DROP}"
