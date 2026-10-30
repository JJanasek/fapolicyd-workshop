#!/usr/bin/env bash
# Remove workshop artifacts (trust entries, binaries, drop-in rules).
# Does NOT remove user fapo, packages, or fapolicyd itself.
# Run as root on the disposable VM.
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root" >&2
  exit 1
fi

echo "==> Removing lab binaries / dirs"
rm -rf /opt/fapo-workshop /opt/myapp /var/tmp/fapo-workshop
rm -f /tmp/xray-ls /tmp/my-ls
if getent passwd fapo >/dev/null; then
  rm -f /home/fapo/.cache/totally-legit-update 2>/dev/null || true
fi

echo "==> Removing trust.d workshop files"
find /etc/fapolicyd/trust.d -maxdepth 1 -type f \
  \( -name '*workshop*' -o -name '*myapp*' -o -name '*showcase*' \) \
  -delete 2>/dev/null || true

echo "==> Removing rules.d workshop drop-ins"
rm -f /etc/fapolicyd/rules.d/55-workshop-ping.rules \
      /etc/fapolicyd/rules.d/55-showcase-ping.rules

if command -v fagenrules >/dev/null; then
  fagenrules || true
fi

if systemctl is-active --quiet fapolicyd; then
  fapolicyd-cli --update 2>/dev/null || true
  systemctl reload fapolicyd 2>/dev/null || systemctl restart fapolicyd || true
fi

echo "Cleanup done. (groups fapo_workshop / fapo_showcase left in place)"
