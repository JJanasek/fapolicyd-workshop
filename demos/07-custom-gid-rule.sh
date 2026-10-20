#!/usr/bin/env bash
# Demo 7: Custom first-match rule — gid-gated access to a trusted binary.
# Creates a drop-in, regenerates rules, demonstrates allow vs deny by group.
set -euo pipefail

RULE=/etc/fapolicyd/rules.d/55-workshop-ping.rules
GROUP=fapo_workshop

echo "=== create group ${GROUP} (idempotent) ==="
getent group "${GROUP}" >/dev/null || groupadd "${GROUP}"

# Place BEFORE the catch-all deny-execute unit (90-*).
# Ping is RPM-trusted; we still deny execute for non-members.
cat >"${RULE}" <<EOF
# workshop: only ${GROUP} may execute ping
allow perm=any gid=${GROUP} : trust=1 path=/usr/bin/ping
deny_audit perm=execute all : trust=1 path=/usr/bin/ping
EOF

echo "=== regenerate & reload ==="
fagenrules
systemctl reload fapolicyd || systemctl restart fapolicyd
sleep 1

echo
echo "=== as current user (likely deny unless already in group) ==="
set +e
/usr/bin/ping -c1 127.0.0.1
echo "rc=$?"
set -e

echo
echo "Add yourself: usermod -aG ${GROUP} \$USER  (re-login), then retry."
echo "Cleanup: rm -f ${RULE} && fagenrules && systemctl reload fapolicyd"
echo "Optional: groupdel ${GROUP}"
