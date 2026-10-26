# SHOWCASE: trs-viewer — real unpackaged app under fapolicyd

Live companion to `08-trs-viewer-app.sh`. Script covers deny → single-file trust →
tree trust → untrusted dataset open. Use this file for **prep** and the optional
**GUI** beat.

App: [JJanasek/trs-viewer](https://github.com/JJanasek/trs-viewer)

## Prep (once, before the talk)

```bash
git clone https://github.com/JJanasek/trs-viewer
cd trs-viewer
./scripts/install-deps.sh          # or --print first
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"

export TRS_VIEWER_SRC="$PWD/build"   # directory or path to the binary
```

fapolicyd must be **enforcing** (same lab as other showcases).

## Scripted half (~2 min)

```bash
sudo -E ./demos/showcases/08-trs-viewer-app.sh
```

Narrate:

1. Unpackaged tree under `/opt/trs-viewer` → FANOTIFY deny on exec.
2. Trust **only** `bin/trs-viewer` → helper ELF in the same tree still denied.
3. `fapolicyd-cli --file add /opt/trs-viewer` → whole suite runs.
4. Sample `.npy` in `/var/tmp` is **not** in the trust DB; open still works —
   whitelist **code**, not every dataset.

## Live GUI (optional, ~1 min)

On a machine with a display:

```bash
/opt/trs-viewer/bin/trs-viewer /var/tmp/trs-viewer-sample.npy
# or pick a real .trs / .npy / .npz from a capture folder
```

Show that analysis/export still works after tree trust. No need to
`fapolicyd-cli --file add` on the traces themselves.

## Cleanup

```bash
sudo fapolicyd-cli --file delete /opt/trs-viewer --trust-file trs-viewer
sudo fapolicyd-cli --update
sudo rm -rf /opt/trs-viewer /var/tmp/trs-viewer-sample.npy
```

**Punchline:** real apps are trees (binary + helpers/libs). Trust `/opt/...`, not
one path. fapolicyd gates code provenance; your data files stay ordinary files.
