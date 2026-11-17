#!/usr/bin/env bash
# Lab prep for fapolicyd power-user workshop.
# Run as root on a disposable VM (Fedora/RHEL/CentOS Stream).
#
# Ends in a staff_t shell as workshop user, via ssh to localhost.
# (su/runuser stay unconfined; runcon unconfined_t -> staff_t is denied.)
# Shipped rule "allow perm=any uid=0 trust=1 : all" lets root+trusted
# shell run untrusted binaries — so Exercise 2 as root will NOT deny.
# SKIP_USER_SWITCH=1  — stay root (CI / automation)
set -euo pipefail

WORKSHOP_USER="${WORKSHOP_USER:-fapo}"
WORKSHOP_HOME="/home/${WORKSHOP_USER}"
WORKSHOP_KEY="${WORKSHOP_KEY:-/root/.ssh/fapo_workshop_ed25519}"
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
dnf -y install fapolicyd policycoreutils-python-utils openssh-server openssh-clients

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

# Login mapping, applied by pam_selinux on a real login (ssh/console).
# su/runuser do NOT apply it, so the shell below is an ssh login.
if command -v semanage >/dev/null && [[ -d /etc/selinux ]]; then
  echo "==> Mapping ${WORKSHOP_USER} → staff_u"
  if ! semanage login -l 2>/dev/null | awk '{print $1}' | grep -qx "${WORKSHOP_USER}"; then
    semanage login -a -s staff_u "${WORKSHOP_USER}" || true
  else
    semanage login -m -s staff_u "${WORKSHOP_USER}" || true
  fi
fi

# Dedicated key so root (and the showcases) can log in as the workshop user
echo "==> ssh key for root -> ${WORKSHOP_USER}@localhost"
mkdir -p /root/.ssh && chmod 700 /root/.ssh
[[ -f "${WORKSHOP_KEY}" ]] || ssh-keygen -q -t ed25519 -N '' -C fapo-workshop -f "${WORKSHOP_KEY}"
install -d -m 700 -o "${WORKSHOP_USER}" -g "${WORKSHOP_USER}" "${WORKSHOP_HOME}/.ssh"
AUTH="${WORKSHOP_HOME}/.ssh/authorized_keys"
touch "${AUTH}"
grep -qxF "$(cat "${WORKSHOP_KEY}.pub")" "${AUTH}" || cat "${WORKSHOP_KEY}.pub" >>"${AUTH}"
chown "${WORKSHOP_USER}:${WORKSHOP_USER}" "${AUTH}" && chmod 600 "${AUTH}"
restorecon -RF "${WORKSHOP_HOME}/.ssh" 2>/dev/null || true
systemctl enable --now sshd

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

SSH_CMD="ssh -i ${WORKSHOP_KEY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new ${WORKSHOP_USER}@localhost"

echo
echo "================================================================"
echo "Prep done. Logging in as ${WORKSHOP_USER} over ssh (real login -> staff_t)."
echo "su / runuser / runcon do not get you into staff_t."
echo "Check: id -Z  → should contain staff_t"
echo "sudo → unconfined_t (for fapolicyd-cli / systemctl / ausearch)."
echo "Reset artifacts later: sudo ./demos/99-cleanup.sh"
echo "================================================================"

if [[ "${SKIP_USER_SWITCH}" == "1" ]]; then
  echo "(SKIP_USER_SWITCH=1 — staying root)"
  exit 0
fi

if [[ ! -t 0 || ! -t 1 ]]; then
  echo "Not a tty — run as root:"
  echo "  ${SSH_CMD}"
  exit 0
fi

CTX="$(${SSH_CMD} -o BatchMode=yes id -Z 2>/dev/null || true)"
case "${CTX}" in
  *staff_t*) ;;
  *) echo "WARNING: ssh login gave context '${CTX:-<login failed>}', expected staff_t." >&2
     echo "         Exercise 5 (dual stack) will not produce an AVC." >&2 ;;
esac
exec ${SSH_CMD}
