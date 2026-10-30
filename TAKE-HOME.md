# fapolicyd — config cookbook

After the live session: **[EXERCISES.md](EXERCISES.md)** for muscle memory; this file for copy-paste reference.

Order: `00-lab-prep` → exercises → showcases. Disposable VM. SELinux enforcing.  
**Never** `strace` / `gdb` / `ptrace` the daemon.

---

## Bootstrap

```bash
sudo ./demos/00-lab-prep.sh    # fapo + staff_u + audit watch + sudo
# lands as fapo; or: su - fapo

sudo fapolicyd-cli --check-status
sudo fapolicyd-cli --list | head
```

Non-root for deny demos (`uid=0 trust=1` bypass). `sudo` for CLI / trust / rules.

Soak on a real host: `permissive = 1` in `fapolicyd.conf` → watch → then `0`.

Reset lab junk: `sudo ./demos/99-cleanup.sh`

---

## Cookbook

### Trust an `/opt` tree

```bash
sudo mkdir -p /opt/myapp/bin
sudo cp /usr/bin/id /opt/myapp/bin/mytool && sudo chmod 755 /opt/myapp/bin/mytool
/opt/myapp/bin/mytool                      # DENY as fapo

sudo fapolicyd-cli --file add /opt/myapp --trust-file myapp
sudo fapolicyd-cli --update
/opt/myapp/bin/mytool                      # ALLOW

sudo fapolicyd-cli --dump-db | grep myapp
ls /etc/fapolicyd/trust.d/
```

Prefer trust trees over allow-rule sprawl.

### `rules.d` drop-in

```bash
sudo groupadd -f fapo_workshop
sudo tee /etc/fapolicyd/rules.d/55-workshop-ping.rules <<'EOF'
allow perm=any gid=fapo_workshop : trust=1 path=/usr/bin/ping
deny_audit perm=execute all : trust=1 path=/usr/bin/ping
EOF

sudo fagenrules
sudo fapolicyd-cli --check-rules --lint
sudo systemctl reload fapolicyd
sudo fapolicyd-cli --list | grep -n ping
```

Number above catch-all deny. Bad reload keeps previous ruleset.

### Conf knobs

- `permissive = 1|0`
- `integrity = none|size|sha256` — try `size` before `sha256`
- Optional: append `trust` to `syslog_format` while debugging

### Health

```bash
sudo fapolicyd-cli --check-status
sudo fapolicyd-cli --check-metrics
sudo fapolicyd-cli --check-trustdb
sudo fapolicyd-cli --check-path
sudo fapolicyd-cli --check-rules --lint
sudo fapolicyd-cli --check-ignore_mounts --verbose
```

### Debug X-ray

```bash
sudo systemctl stop fapolicyd
sudo fapolicyd --permissive --debug-deny
# other terminal: reproduce → rule:N … file=…
sudo fapolicyd-cli --list | nl -ba | sed -n '1,80p'
# Ctrl-C → sudo systemctl start fapolicyd
```

---

## Showcases (after exercises)

| Demo | Script |
|------|--------|
| Home drop | `demos/showcases/01-home-drop.sh` |
| Dual stack | `demos/showcases/02-dual-stack.sh` |
| GID gate | `demos/showcases/03-gid-gate.sh` |

---

## Cheat sheet

```bash
systemctl stop|start|reload fapolicyd
sudo fapolicyd --permissive --debug-deny
sudo fapolicyd-cli --list | --dump-db | --update
sudo fapolicyd-cli --file add PATH --trust-file NAME
sudo fapolicyd-cli --check-status|--check-metrics|--check-trustdb|--check-rules|--check-path
sudo ausearch -m FANOTIFY -i --start recent
sudo ausearch -m AVC --start recent
journalctl -b -u fapolicyd.service
```

```
Denied?
  ├─ ausearch -m AVC      → SELinux (label/policy)
  ├─ ausearch -m FANOTIFY → trust / rule order
  │     (compact events often lack path → --debug-deny)
  │     ├─ known software? → trust DB + --update
  │     └─ who/how?        → rules.d drop-in
  └─ neither → dontaudit? / debug-deny
```

## Instincts

1. Trust DB before allow-rule sprawl.  
2. FANOTIFY ≠ AVC — check both.  
3. First-match: order is policy.  
4. Root can disable this (by design).  
5. Never hand-edit `compiled.rules`.  
