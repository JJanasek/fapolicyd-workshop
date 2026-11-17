# Shared helpers for workshop demos/showcases.
# Source:  . "$(dirname "$0")/lib.sh"           # from demos/
#          . "$(dirname "$0")/../lib.sh"        # from demos/showcases/

WORKSHOP_USER="${WORKSHOP_USER:-fapo}"
# Dual-stack AVC needs staff_t. Plain su/runuser skip pam_selinux → unconfined_t.
WORKSHOP_CONTEXT="${WORKSHOP_CONTEXT:-staff_u:staff_r:staff_t:s0}"

# Run a command as the workshop user in staff_t when SELinux is on.
# Root + trusted shell often matches: allow perm=any uid=0 trust=1 : all
# — so deny tests must not be uid 0.
as_user() {
  if [[ ${EUID} -ne 0 ]]; then
    if command -v runcon >/dev/null \
       && command -v selinuxenabled >/dev/null \
       && selinuxenabled 2>/dev/null; then
      # Already non-root: ensure staff_t if caller is still unconfined
      case "$(id -Z 2>/dev/null || true)" in
        *staff_t*) "$@" ;;
        *) runcon "${WORKSHOP_CONTEXT}" "$@" ;;
      esac
    else
      "$@"
    fi
    return
  fi
  if ! id "${WORKSHOP_USER}" &>/dev/null; then
    echo "WARN: user ${WORKSHOP_USER} missing (run demos/00-lab-prep.sh)." >&2
    echo "WARN: executing as root — untrusted binaries may be ALLOWED." >&2
    "$@"
    return
  fi
  if command -v runcon >/dev/null \
     && command -v selinuxenabled >/dev/null \
     && selinuxenabled 2>/dev/null; then
    runuser -u "${WORKSHOP_USER}" -- runcon "${WORKSHOP_CONTEXT}" "$@"
  else
    runuser -u "${WORKSHOP_USER}" -- "$@"
  fi
}
