#!/usr/bin/env bash
# SHOWCASE: real unpackaged app (trs-viewer) — trust the whole tree.
# Prep: build https://github.com/JJanasek/trs-viewer once, then:
#   export TRS_VIEWER_SRC=/path/to/trs-viewer/build   # or path to the binary
#   sudo ./demos/showcases/08-trs-viewer-app.sh
# See 08-trs-viewer-app.md for the live GUI step.
set -euo pipefail

APP_ROOT=/opt/trs-viewer
BIN="${APP_ROOT}/bin/trs-viewer"
HELPER="${APP_ROOT}/bin/trs-helper"
SAMPLE=/var/tmp/trs-viewer-sample.npy
TRUST_NAME=trs-viewer

resolve_binary() {
  local cand="${TRS_VIEWER_SRC:-}"
  if [[ -z ${cand} ]]; then
    echo "Set TRS_VIEWER_SRC to the built trs-viewer binary or its build directory."
    echo "Example: export TRS_VIEWER_SRC=\$HOME/src/trs-viewer/build"
    exit 1
  fi
  if [[ -d ${cand} ]]; then
    if [[ -x ${cand}/trs-viewer ]]; then
      cand="${cand}/trs-viewer"
    elif [[ -x ${cand}/bin/trs-viewer ]]; then
      cand="${cand}/bin/trs-viewer"
    else
      echo "No trs-viewer binary under ${TRS_VIEWER_SRC}"
      exit 1
    fi
  fi
  [[ -x ${cand} ]] || { echo "Not executable: ${cand}"; exit 1; }
  printf '%s\n' "${cand}"
}

SRC_BIN=$(resolve_binary)

echo "=== 0) deploy unpackaged app tree to ${APP_ROOT} ==="
rm -rf "${APP_ROOT}"
mkdir -p "${APP_ROOT}/bin" "${APP_ROOT}/lib"
cp -a "${SRC_BIN}" "${BIN}"
chmod 755 "${BIN}"
# Second ELF in the same tree — models plugins/helpers real apps ship.
cp -a /usr/bin/true "${HELPER}"
chmod 755 "${HELPER}"
# Optional: ship any build-tree .so next to the binary (RPATH / plugins).
SRC_DIR=$(dirname "${SRC_BIN}")
shopt -s nullglob
for so in "${SRC_DIR}"/*.so "${SRC_DIR}"/*.so.*; do
  cp -a "${so}" "${APP_ROOT}/lib/"
done
shopt -u nullglob

# Drop any prior trust for a clean deny.
fapolicyd-cli --file delete "${APP_ROOT}" --trust-file "${TRUST_NAME}" 2>/dev/null || true
fapolicyd-cli --file delete "${BIN}" --trust-file "${TRUST_NAME}" 2>/dev/null || true
fapolicyd-cli --update 2>/dev/null || true
sleep 1

echo
echo "=== 1) run without trust (expect DENY) ==="
set +e
"${BIN}"
echo "trs-viewer exit=$?"
"${HELPER}"
echo "trs-helper exit=$?"
set -e
echo "--- recent FANOTIFY ---"
ausearch --start recent -m fanotify -f "${BIN}" 2>/dev/null | tail -20 || \
  ausearch --start recent -m fanotify 2>/dev/null | tail -20 || true

echo
echo "=== 2) trust ONLY the main binary (helper still untrusted) ==="
fapolicyd-cli --file add "${BIN}" --trust-file "${TRUST_NAME}"
fapolicyd-cli --update
sleep 1
set +e
"${BIN}"
echo "trs-viewer exit=$?"
"${HELPER}"
echo "trs-helper exit=$?  (expect DENY — still trust=0)"
set -e

echo
echo "=== 3) trust the whole ${APP_ROOT} tree ==="
fapolicyd-cli --file delete "${BIN}" --trust-file "${TRUST_NAME}" 2>/dev/null || true
fapolicyd-cli --file add "${APP_ROOT}" --trust-file "${TRUST_NAME}"
fapolicyd-cli --update
sleep 1
set +e
"${HELPER}"
echo "trs-helper exit=$?  (expect ALLOW)"
# GUI may fail on headless VM; FANOTIFY must not deny the exec itself.
timeout 2 "${BIN}" >/dev/null 2>&1
echo "trs-viewer short-run exit=$?  (124=timeout OK; FANOTIFY deny usually 126/1)"
set -e
fapolicyd-cli --dump-db 2>/dev/null | grep -F "${APP_ROOT}" | head -10 || true

echo
echo "=== 4) untrusted dataset open (code trusted, data not in trust DB) ==="
python3 - <<'PY'
import pathlib
# Minimal NPY: magic + ver + header len + tiny header + 4 float32 zeros
import struct
path = pathlib.Path("/var/tmp/trs-viewer-sample.npy")
header = b"{'descr': '<f4', 'fortran_order': False, 'shape': (1, 1), }"
header = header + b" " * ((16 - (10 + len(header) + 1) % 16) % 16) + b"\n"
path.write_bytes(b"\x93NUMPY\x01\x00" + struct.pack("<H", len(header)) + header + struct.pack("<f", 0.0))
print(f"wrote {path} ({path.stat().st_size} bytes)")
PY
# Trusted interpreter reading untrusted bytes — default rules allow open of data.
python3 -c "p=open('${SAMPLE}','rb'); print('open ok, magic=', p.read(6)); p.close()"
echo "(GUI: ${BIN} ${SAMPLE} — datasets need not be whitelisted)"

echo
echo "Punchline: trust the /opt app *tree* (binary + helpers/.so). Data stays untrusted."
echo "Cleanup:"
echo "  fapolicyd-cli --file delete ${APP_ROOT} --trust-file ${TRUST_NAME}"
echo "  fapolicyd-cli --update && rm -rf ${APP_ROOT} ${SAMPLE}"
