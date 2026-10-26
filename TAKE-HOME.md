# fapolicyd — configure it yourself + cool showcases

Self-paced pack after the live **why / what / how** session.
Goal: you can install, configure, debug, and demo fapolicyd without hand-holding.

**Learning order:** `00-lab-prep` → **[`EXERCISES.md`](EXERCISES.md)** (type by hand) → showcases last.  
`demos/*.sh` are spoilers if you get stuck. This file is the **config reference**.

Use a **disposable VM**. Prefer SELinux **enforcing**.
**Never** `strace` / `gdb` / `ptrace` the daemon.

---

## 1. Bootstrap

```bash
sudo ./demos/00-lab-prep.sh
# creates workshop user "fapo" — then:
su - fapo

# or manually:
sudo dnf install -y fapolicyd fapolicyd-selinux rpm-plugin-fapolicyd
sudo auditctl -w /etc/shadow -p w          # so deny_audit actually logs
sudo systemctl enable --now fapolicyd
fapolicyd-cli --check-status
fapolicyd-cli --list | head
```

**Non-root for deny demos:** shipped `allow perm=any uid=0 trust=1 : all`
lets root+trusted shell run untrusted binaries. Use `fapo` to execute;
`sudo` for `fapolicyd-cli` / trust / ausearch.

Soak tip: run permissive first if this is a real machine:

```bash
# in /etc/fapolicyd/fapolicyd.conf
permissive = 1
sudo systemctl restart fapolicyd
# watch denials for a day/week, then flip to 0
```

---

## 2. Config cookbook (do these once)

### A. Trust an unpackaged `/opt` app (most common task)

```bash
sudo mkdir -p /opt/myapp/bin
sudo cp /usr/bin/id /opt/myapp/bin/mytool
sudo chmod 755 /opt/myapp/bin/mytool

/opt/myapp/bin/mytool                      # expect DENY

sudo fapolicyd-cli --file add /opt/myapp --trust-file myapp
sudo fapolicyd-cli --update
/opt/myapp/bin/mytool                      # ALLOW

# inspect
fapolicyd-cli --dump-db | grep myapp
ls /etc/fapolicyd/trust.d/
```

**Rule of thumb:** trust trees > sprinkle allow rules.

### B. Add a custom rule drop-in

```bash
# Place BEFORE catch-all deny (90-*). Example: only fapo_workshop may run ping
sudo groupadd -f fapo_workshop
sudo tee /etc/fapolicyd/rules.d/55-workshop-ping.rules <<'EOF'
allow perm=any gid=fapo_workshop : trust=1 path=/usr/bin/ping
deny_audit perm=execute all : trust=1 path=/usr/bin/ping
EOF

sudo fagenrules
sudo fapolicyd-cli --check-rules --lint
sudo systemctl reload fapolicyd   # or restart
fapolicyd-cli --list | grep -n ping
```

Reload is transactional: a bad candidate keeps the old ruleset.

### C. Dial logging for debugging

In `/etc/fapolicyd/fapolicyd.conf`, append `trust` to `syslog_format` so denials
show whether the object was trusted. Optionally change a deny rule from
`deny_audit` → `deny_syslog` while debugging, then revert.

### D. Integrity (optional, deliberate)

```bash
# /etc/fapolicyd/fapolicyd.conf
integrity = size          # pragmatic; sha256 is heavier
sudo systemctl restart fapolicyd
# then run demos/06-integrity.sh
```

### E. Health checks you should know by heart

```bash
fapolicyd-cli --check-status
fapolicyd-cli --check-metrics
fapolicyd-cli --check-trustdb
fapolicyd-cli --check-path
fapolicyd-cli --check-rules --lint
fapolicyd-cli --check-ignore_mounts --verbose   # before enabling ignore_mounts
```

### F. Safe debug X-ray

```bash
sudo systemctl stop fapolicyd
sudo fapolicyd --permissive --debug-deny
# other terminal: reproduce the deny
# read: rule:N dec=deny ...
fapolicyd-cli --list | nl -ba | sed -n '1,80p'
# Ctrl-C, then:
sudo systemctl start fapolicyd
```

---

## 3. Cool showcases (run & present these)

Scripted under `demos/showcases/`. Each is meant to be **demo-able in ~2 minutes**.

| Showcase | Script | Punchline |
|----------|--------|-----------|
| Clone attack | `showcases/01-clone-attack.sh` | Bit-identical copy of `ls` still denied until trusted |
| ld.so smuggle | `showcases/02-ldso-smuggle.sh` | Trusted loader cannot run untrusted ELF |
| Home malware drop | `showcases/03-home-drop.sh` | “Downloaded” payload in `$HOME` cannot exec |
| Integrity bite | `showcases/04-integrity-bite.sh` | Trusted path, mutated bytes → deny |
| Dual stack | `showcases/05-dual-stack.sh` | Same binary: AVC **and** FANOTIFY |
| GID gate | `showcases/06-gid-gate.sh` | RPM-trusted `ping`, still denied by group rule |
| Live X-ray | `showcases/07-xray.md` | Map `rule:N` live with `--debug-deny` |
| Real app (trs-viewer) | `showcases/08-trs-viewer-app.sh` (+ `.md`) | Trust the `/opt` **tree**; datasets need not be whitelisted |

Also keep the structured drills `demos/01`–`09` if you want a slower curriculum.

### Suggested “present back to the team” set

Pick **three**: clone attack, dual stack, and either ld.so or integrity.
Narrate: what failed, which audit class, how you fixed it (trust vs rule).

---

## 4. Structured drills (optional full path)

| # | Script | Focus |
|---|--------|-------|
| 1 | `demos/01-baseline.sh` | inventory |
| 2 | `demos/02-untrusted-exec.sh` | deny → trust |
| 3 | `demos/03-ldso-bypass.sh` | loader |
| 4 | `demos/04-home-python.sh` | interpreters |
| 5 | `demos/05-debug-permissive.md` | debug loop |
| 6 | `demos/06-integrity.sh` | integrity=size |
| 7 | `demos/07-custom-gid-rule.sh` | custom rules |
| 8 | `demos/08-selinux-duo.sh` | AVC vs FANOTIFY |
| 9 | `demos/09-ops-metrics.sh` | metrics / ignore_mounts |

---

## 5. Cheat sheet

```bash
systemctl stop|start|reload fapolicyd
fapolicyd --permissive --debug-deny
fapolicyd-cli --list | --dump-db | --update
fapolicyd-cli --file add PATH --trust-file NAME
fapolicyd-cli --check-status|--check-metrics|--check-trustdb|--check-rules|--check-path
fapolicyd-cli --compact-trustdb | --delete-db
ausearch -m fanotify --start recent
ausearch -m avc --start recent
journalctl -b -u fapolicyd.service
```

### Decision tree

```
Denied?
  ├─ ausearch -m avc      → fix SELinux (label/policy)
  ├─ ausearch -m fanotify → untrusted or rule order
  │     ├─ should be known software? → trust DB (+ --update)
  │     └─ who/how exception?       → rules.d drop-in
  └─ neither, still EACCES → dontaudit? permissive debug-deny
```

---

## 6. Power-user instincts

1. Prefer **trust DB** over allow-rule sprawl.
2. FANOTIFY ≠ AVC — check both.
3. First-match: **order is policy**.
4. Root can disable this (by design).
5. `ignore_mounts` / `integrity=sha256` are tradeoffs, not free upgrades.
6. Ship numbered `rules.d` snippets from automation; never hand-edit `compiled.rules`.

---

## 7. Stretch

- Permissive soak → enforce on a real workload.
- Wire `--check-status` / `--check-metrics` into monitoring.
- Skim [fapolicyd-tests](https://github.com/linux-application-whitelisting/fapolicyd-tests) `Sanity/`.
- Build a 5-minute internal demo from three showcases.
