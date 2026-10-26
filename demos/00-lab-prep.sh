#!/usr/bin/env bash
# Lab prep for fapolicyd power-user workshop.
# Run as root on a disposable VM (Fedora/RHEL/CentOS Stream).
#
# After this script: switch to the workshop user for deny demos.
# Shipped rule "allow perm=any uid=0 trust=1 : all" lets root+trusted
# shell run untrusted binaries — so Exercise 2 as root will NOT deny.
set -euo pipefail

WORKSHOP_USER="${WORKSHOP_USER:-fapo}"
WORKSHOP_HOME="/home/${WORKSHOP_USER}"

need_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "Run as root" >&2
    exit 1
  fi
}

need_root

echo "==> Installing packages"
# rpm-plugin-fapolicyd name varies slightly by distro/version
dnf -y install fapolicyd fapolicyd-selinux rpm-plugin-fapolicyd \
  || dnf -y install fapolicyd fapolicyd-selinux

# Ensure at least one audit rule so deny_audit emits fanotify events
if ! auditctl -l 2>/dev/null | grep -q .; then
  echo "==> Adding minimal audit watch (shadow writes)"
  auditctl -w /etc/shadow -p w
fi

mkdir -p /opt/fapo-workshop /var/tmp/fapo-workshop
chmod 755 /opt/fapo-workshop /var/tmp/fapo-workshop

echo "==> Workshop user: ${WORKSHOP_USER} (use this for deny/allow exercises)"
if ! id "${WORKSHOP_USER}" &>/dev/null; then
  useradd -m -s /bin/bash "${WORKSHOP_USER}"
  echo "==> Created ${WORKSHOP_USER} (no password set — use: su - ${WORKSHOP_USER})"
else
  echo "==> User ${WORKSHOP_USER} already exists"
fi
# Lab dirs must be executable/readable by that user
chmod 755 /opt/fapo-workshop
chown root:root /opt/fapo-workshop
# Optional shared scratch the user can write
mkdir -p /var/tmp/fapo-workshop
chmod 1777 /var/tmp/fapo-workshop

cat >/etc/audit/rules.d/99-fapo-workshop.rules <<'EOF'
-w /etc/shadow -p w
EOF
augenrules --load 2>/dev/null || true

systemctl enable --now fapolicyd
sleep 1
fapolicyd-cli --check-status || true

echo
echo "================================================================"
echo "Prep done."
echo
echo "IMPORTANT — switch off root for most exercises:"
echo "  su - ${WORKSHOP_USER}"
echo
echo "Why: default policy has roughly:"
echo "  allow perm=any uid=0 trust=1 : all"
echo "Root running a trusted shell (bash) can execute untrusted"
echo "binaries — you will NOT see the deny in Exercise 2 as root."
echo
echo "Use root/sudo only for: fapolicyd-cli, systemctl, ausearch, trust."
echo "Debug foreground still as root:"
echo "  systemctl stop fapolicyd && fapolicyd --permissive --debug-deny"
echo "================================================================"
