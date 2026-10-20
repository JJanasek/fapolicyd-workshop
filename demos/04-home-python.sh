#!/usr/bin/env bash
# Demo 4: Untrusted interpreted content under $HOME.
# Run as a normal user for realism; sudo only for ausearch if needed.
set -euo pipefail

SCRIPT="${HOME}/fapo-workshop-hello.py"
cat >"${SCRIPT}" <<'PY'
#!/usr/bin/env python3
print("hello from home")
PY
chmod 755 "${SCRIPT}"

echo "=== run home python script (expect deny under known-libs) ==="
set +e
python3 "${SCRIPT}"
echo "rc=$?"
set -e

echo
echo "=== open of script by trusted interpreter is the interesting event ==="
echo "Watch with: sudo fapolicyd --permissive --debug-deny"
echo "Or: sudo ausearch --start recent -m fanotify -f ${SCRIPT}"

echo
echo "Remediation options to discuss:"
echo "  1) move to packaged/RPM path"
echo "  2) fapolicyd-cli --file add ${SCRIPT} --trust-file workshop && --update"
echo "  3) gid-scoped allow rule for trusted_user + %languages under /home"
