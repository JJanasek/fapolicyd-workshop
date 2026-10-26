# Shared helpers for workshop demos/showcases.
# Source:  . "$(dirname "$0")/lib.sh"           # from demos/
#          . "$(dirname "$0")/../lib.sh"        # from demos/showcases/

WORKSHOP_USER="${WORKSHOP_USER:-fapo}"

# Run a command as the workshop user. Root + trusted shell often matches
# shipped: allow perm=any uid=0 trust=1 : all — so deny tests must not be uid 0.
as_user() {
  if [[ ${EUID} -ne 0 ]]; then
    "$@"
    return
  fi
  if ! id "${WORKSHOP_USER}" &>/dev/null; then
    echo "WARN: user ${WORKSHOP_USER} missing (run demos/00-lab-prep.sh)." >&2
    echo "WARN: executing as root — untrusted binaries may be ALLOWED." >&2
    "$@"
    return
  fi
  runuser -u "${WORKSHOP_USER}" -- "$@"
}
