#!/usr/bin/env bash
# Lab prep for fapolicyd power-user workshop.
# Run as root on a disposable VM (Fedora/RHEL/CentOS Stream).
#
# Ends by switching to the workshop user (interactive tty).
# Shipped rule "allow perm=any uid=0 trust=1 : all" lets root+trusted
# shell run untrusted binaries — so Exercise 2 as root will NOT deny.
# SKIP_USER_SWITCH=1  — stay root (CI / automation)
set -euo pipefail

WORKSHOP_USER="${WORKSHOP_USER:-fapo}"
WORKSHOP_HOME="/home/${WORKSHOP_USER}"
SKIP_USER_SWITCH="${SKIP_USER_SWITCH:-0}"

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

echo "==> Workshop user: ${WORKSHOP_USER}"
if ! id "${WORKSHOP_USER}" &>/dev/null; then
  useradd -m -s /bin/bash "${WORKSHOP_USER}"
  echo "==> Created user ${WORKSHOP_USER}"
else
  echo "==> User ${WORKSHOP_USER} already exists"
fi
# From root: su - fapo works with no password. Give fapo sudo for CLI/trust.
passwd -d "${WORKSHOP_USER}" 2>/dev/null || true
if getent group wheel >/dev/null; then
  usermod -aG wheel "${WORKSHOP_USER}" || true
fi
# passwordless sudo for lab convenience (disposable VM)
mkdir -p /etc/sudoers.d
cat >"/etc/sudoers.d/99-${WORKSHOP_USER}-workshop" <<EOF
${WORKSHOP_USER} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 "/etc/sudoers.d/99-${WORKSHOP_USER}-workshop"
id "${WORKSHOP_USER}"

chmod 755 /opt/fapo-workshop
chown root:root /opt/fapo-workshop
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
echo "Prep done. Switching to ${WORKSHOP_USER} for deny labs."
echo "Use sudo for fapolicyd-cli / systemctl. exit → back to root."
echo "================================================================"

if [[ "${SKIP_USER_SWITCH}" == "1" ]]; then
  echo "(SKIP_USER_SWITCH=1 — staying root)"
  exit 0
fi

if [[ ! -t 0 || ! -t 1 ]]; then
  echo "Not a tty — run: su - ${WORKSHOP_USER}"
  exit 0
fi

# Replace this process with a login shell as workshop user.
exec su - "${WORKSHOP_USER}"
