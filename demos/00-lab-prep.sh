#!/usr/bin/env bash
# Lab prep for fapolicyd power-user workshop.
# Run as root on a disposable VM (Fedora/RHEL/CentOS Stream).
#
# Ends in a staff_t shell as workshop user (runcon — su alone stays unconfined).
# Shipped rule "allow perm=any uid=0 trust=1 : all" lets root+trusted
# shell run untrusted binaries — so Exercise 2 as root will NOT deny.
# SKIP_USER_SWITCH=1  — stay root (CI / automation)
set -euo pipefail

WORKSHOP_USER="${WORKSHOP_USER:-fapo}"
WORKSHOP_HOME="/home/${WORKSHOP_USER}"
WORKSHOP_CONTEXT="${WORKSHOP_CONTEXT:-staff_u:staff_r:staff_t:s0}"
SKIP_USER_SWITCH="${SKIP_USER_SWITCH:-0}"

need_root() {
  if [[ ${EUID} -ne 0 ]]; then
    echo "Run as root" >&2
    exit 1
  fi
}

need_root

echo "==> Installing packages"
# fapolicyd alone is enough (rawhide: rpm-plugin-fapolicyd obsolete)
dnf -y install fapolicyd policycoreutils-python-utils

# ≥1 audit rule so deny_audit emits FANOTIFY events
if ! auditctl -l 2>/dev/null | grep -q .; then
  echo "==> Adding minimal audit watch (shadow writes)"
  auditctl -a always,exit -F path=/etc/shadow -F perm=wa
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
passwd -d "${WORKSHOP_USER}" 2>/dev/null || true
if getent group wheel >/dev/null; then
  usermod -aG wheel "${WORKSHOP_USER}" || true
fi
if getent group fapolicyd >/dev/null; then
  usermod -aG fapolicyd "${WORKSHOP_USER}" || true
fi

# Login mapping (ssh/console). su/runuser do NOT apply pam_selinux —
# interactive shell below uses runcon for staff_t.
if command -v semanage >/dev/null && [[ -d /etc/selinux ]]; then
  echo "==> Mapping ${WORKSHOP_USER} → staff_u (login + runcon target)"
  if ! semanage login -l 2>/dev/null | awk '{print $1}' | grep -qx "${WORKSHOP_USER}"; then
    semanage login -a -s staff_u "${WORKSHOP_USER}" || true
  else
    semanage login -m -s staff_u "${WORKSHOP_USER}" || true
  fi
fi

# staff_t cannot admin; sudo must land in unconfined for CLI/trust/ausearch
mkdir -p /etc/sudoers.d
cat >"/etc/sudoers.d/99-${WORKSHOP_USER}-workshop" <<EOF
${WORKSHOP_USER} ALL=(ALL) ROLE=unconfined_r TYPE=unconfined_t NOPASSWD: ALL
EOF
chmod 440 "/etc/sudoers.d/99-${WORKSHOP_USER}-workshop"
id "${WORKSHOP_USER}"
id -Z "${WORKSHOP_USER}" 2>/dev/null || true

chmod 755 /opt/fapo-workshop
chown root:root /opt/fapo-workshop
mkdir -p /var/tmp/fapo-workshop
chmod 1777 /var/tmp/fapo-workshop

cat >/etc/audit/rules.d/99-fapo-workshop.rules <<'EOF'
-a always,exit -F path=/etc/shadow -F perm=wa
EOF
augenrules --load 2>/dev/null || true

systemctl enable --now fapolicyd
sleep 1
fapolicyd-cli --check-status || true

echo
echo "================================================================"
echo "Prep done. Entering ${WORKSHOP_USER} in ${WORKSHOP_CONTEXT}."
echo "Plain 'su - ${WORKSHOP_USER}' stays unconfined — use runcon (below)."
echo "Check: id -Z  → should contain staff_t"
echo "sudo → unconfined_t (for fapolicyd-cli / systemctl / ausearch)."
echo "Reset artifacts later: sudo ./demos/99-cleanup.sh"
echo "================================================================"

if [[ "${SKIP_USER_SWITCH}" == "1" ]]; then
  echo "(SKIP_USER_SWITCH=1 — staying root)"
  exit 0
fi

if [[ ! -t 0 || ! -t 1 ]]; then
  echo "Not a tty — run:"
  echo "  runuser -u ${WORKSHOP_USER} -- runcon ${WORKSHOP_CONTEXT} bash -l"
  exit 0
fi

cd "${WORKSHOP_HOME}" || cd /
if command -v runcon >/dev/null && command -v selinuxenabled >/dev/null && selinuxenabled; then
  exec runuser -u "${WORKSHOP_USER}" -- runcon "${WORKSHOP_CONTEXT}" bash -l
fi
exec su - "${WORKSHOP_USER}"
