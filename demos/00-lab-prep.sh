#!/usr/bin/env bash
# Lab prep for fapolicyd power-user workshop.
# Run as root on a disposable VM (Fedora/RHEL/CentOS Stream).
set -euo pipefail

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
chmod 755 /opt/fapo-workshop

cat >/etc/audit/rules.d/99-fapo-workshop.rules <<'EOF'
-w /etc/shadow -p w
EOF
augenrules --load 2>/dev/null || true

systemctl enable --now fapolicyd
sleep 1
fapolicyd-cli --check-status || true

echo
echo "Prep done. Prefer: systemctl stop fapolicyd && fapolicyd --permissive --debug-deny"
echo "for interactive demos, then systemctl start fapolicyd when finished."
