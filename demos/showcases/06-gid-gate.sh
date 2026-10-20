#!/usr/bin/env bash
# SHOWCASE: RPM-trusted ping, still denied unless you're in the group.
set -euo pipefail
RULE=/etc/fapolicyd/rules.d/55-showcase-ping.rules
GROUP=fapo_showcase

getent group "${GROUP}" >/dev/null || groupadd "${GROUP}"

cat >"${RULE}" <<EOF
# showcase: only ${GROUP} may execute ping (even though RPM-trusted)
allow perm=any gid=${GROUP} : trust=1 path=/usr/bin/ping
deny_audit perm=execute all : trust=1 path=/usr/bin/ping
EOF

fagenrules
systemctl reload fapolicyd || systemctl restart fapolicyd
sleep 1

echo "=== ping as current user (likely DENY) ==="
set +e
/usr/bin/ping -c1 127.0.0.1
echo "exit=$?"
set -e

echo
echo "Add yourself: sudo usermod -aG ${GROUP} \$USER  && re-login, then retry."
echo "Punchline: trust answers 'known?'; rules answer 'who/how?'."
echo "Cleanup: rm -f ${RULE} && fagenrules && systemctl reload fapolicyd"
