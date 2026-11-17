# fapolicyd — config cookbook

After the live session: **[EXERCISES.md](EXERCISES.md)** for muscle memory; this file for copy-paste reference.

Order: `00-lab-prep` → exercises → showcases. Disposable VM. SELinux enforcing.  
**Never** `strace` / `gdb` / `ptrace` the daemon.

---

## Bootstrap

```bash
sudo ./demos/00-lab-prep.sh    # fapo in staff_t (runcon) + audit + sudo→unconfined
# plain "su - fapo" stays unconfined — no AVC; use prep or:
#   runuser -u fapo -- runcon staff_u:staff_r:staff_t:s0 bash -l

# or: sudo dnf install fapolicyd
# audit (else deny_audit is quiet):
#   sudo auditctl -a always,exit -F path=/etc/shadow -F perm=wa
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
sudo tee /etc/fapolicyd/rules.d/39-workshop-ping.rules <<'EOF'
allow perm=any gid=fapo_workshop : trust=1 path=/usr/bin/ping
deny_audit perm=execute all : trust=1 path=/usr/bin/ping
EOF

sudo fagenrules --load
# or: sudo fagenrules && sudo fapolicyd-cli --reload-rules
sudo fapolicyd-cli --check-rules --lint
sudo fapolicyd-cli --list | nl -ba | grep -n ping
```

`systemctl reload fapolicyd` does **not** load rules (no ExecReload).
Number **before** `allow perm=execute all : trust=1` (`42-trusted-elf`).
`55-` is after that allow, so it never matches. Prove the ping lines sit above it.
Test as `fapo`, not root (`uid=0 trust=1`). Failed in-daemon reload keeps the previous ruleset.

### Conf knobs

- `permissive = 1|0`
- `integrity = none | size | ima | sha256` — try `size` before `sha256`
- `fapolicyd-filter.conf`: `+` include / `-` exclude; `fapolicyd-cli --test-filter PATH` (import-time, not per access)

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
systemctl stop|start fapolicyd
fagenrules --load          # compile + signal daemon (not systemctl reload)
sudo fapolicyd --permissive --debug-deny
sudo fapolicyd-cli --list | --dump-db | --update | --reload-rules
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
6. RPM trust scope: `fapolicyd-filter.conf` (man 5).  

## Extras

Unsupported helpers / fanotify notes:
https://github.com/linux-application-whitelisting/fapolicyd-extras 
