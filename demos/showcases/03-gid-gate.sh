#!/usr/bin/env bash
# SHOWCASE: RPM-trusted ping, denied unless you're in the group.
# Run as root. The ping itself runs as fapo — root hits
# allow perm=any uid=0 trust=1 : all before any later ping rule.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  echo "Ping is executed as ${WORKSHOP_USER}." >&2
  exit 1
fi

RULE=/etc/fapolicyd/rules.d/39-showcase-ping.rules
GROUP=fapo_showcase

getent group "${GROUP}" >/dev/null || groupadd "${GROUP}"

cat >"${RULE}" <<EOF
# BEFORE 42-trusted-elf — else trusted ping is already allowed
allow perm=any gid=${GROUP} : trust=1 path=/usr/bin/ping
deny_audit perm=execute all : trust=1 path=/usr/bin/ping
EOF

fagenrules --load || { fagenrules; fapolicyd-cli --reload-rules; } \
  || systemctl restart fapolicyd
sleep 1

echo "=== assembled (ping lines must sit above trusted-ELF allow) ==="
fapolicyd-cli --list | nl -ba | grep -n -E 'ping|42-trusted|trust=1' | head -20 || true

echo
echo "=== ping as ${WORKSHOP_USER} (expect DENY if not in ${GROUP}) ==="
set +e
as_user /usr/bin/ping -c1 127.0.0.1
echo "exit=$?"
set -e

echo
echo "Then: usermod -aG ${GROUP} ${WORKSHOP_USER}"
echo "      sudo ssh -i /root/.ssh/fapo_workshop_ed25519 ${WORKSHOP_USER}@localhost"
echo "      /usr/bin/ping -c1 127.0.0.1"
echo "Trust = known?; rules = who/how. Do not test this as root."
echo "Cleanup: rm -f ${RULE} && fagenrules --load"
