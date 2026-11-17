# Shared helpers for workshop demos/showcases.
# Source:  . "$(dirname "$0")/lib.sh"           # from demos/
#          . "$(dirname "$0")/../lib.sh"        # from demos/showcases/

WORKSHOP_USER="${WORKSHOP_USER:-fapo}"
# Key created by 00-lab-prep.sh so root can log in as the workshop user.
WORKSHOP_KEY="${WORKSHOP_KEY:-/root/.ssh/fapo_workshop_ed25519}"

# Dual-stack AVC needs staff_t, and only a real login gets there:
#   - su / runuser skip pam_selinux      -> stay unconfined_t
#   - runcon from unconfined_t           -> transition to staff_t is denied
#   - ssh (sshd + pam_selinux + mapping) -> staff_u:staff_r:staff_t
workshop_ssh() {
  ssh -q -i "${WORKSHOP_KEY}" -o IdentitiesOnly=yes \
      -o StrictHostKeyChecking=accept-new "$@"
}

# Run a command as the workshop user in staff_t.
# Root + trusted shell matches: allow perm=any uid=0 trust=1 : all
# -- so deny tests must not be uid 0.
as_user() {
  if [[ ${EUID} -ne 0 ]]; then
    case "$(id -Z 2>/dev/null || true)" in
      *staff_t*|"") ;;
      *) echo "WARN: not in staff_t ($(id -Z)) -- no AVC expected; log in with: ssh ${WORKSHOP_USER}@localhost" >&2 ;;
    esac
    "$@"
    return
  fi
  if ! id "${WORKSHOP_USER}" &>/dev/null || [[ ! -r "${WORKSHOP_KEY}" ]]; then
    echo "WARN: user ${WORKSHOP_USER} or ${WORKSHOP_KEY} missing (run demos/00-lab-prep.sh)." >&2
    echo "WARN: executing as root -- untrusted binaries may be ALLOWED." >&2
    "$@"
    return
  fi
  local cmd
  printf -v cmd '%q ' "$@"
  workshop_ssh -o BatchMode=yes "${WORKSHOP_USER}@localhost" -- "${cmd}"
}
