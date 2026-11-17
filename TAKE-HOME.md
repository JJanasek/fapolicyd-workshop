# fapolicyd — config cookbook

After the live session: **[EXERCISES.md](EXERCISES.md)** for muscle memory; this file for copy-paste reference.

Order: `00-lab-prep` → exercises → showcases. Disposable VM. SELinux enforcing.  
**Never** `strace` / `gdb` / `ptrace` the daemon.

---

## Bootstrap

```bash
sudo ./demos/00-lab-prep.sh    # fapo in staff_t (ssh login) + audit + sudo→unconfined
# plain "su - fapo" stays unconfined — no AVC; use prep or:
#   sudo ssh -i /root/.ssh/fapo_workshop_ed25519 fapo@localhost

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
- `decision_threads` (2.0), `ignore_mounts`, `db_max_size = auto` (default), `rpm_sha256_only`, `reset_strategy`, `timing_collection` — man 5 fapolicyd.conf
- `fapolicyd-filter.conf`: `+` include / `-` exclude; `fapolicyd-cli --test-filter PATH` (import-time, not per access); also `--file add PATH --filter`

### Rule syntax new in 2.0

```text
allow perm=execute all : path=glob:/opt/vendor/*/bin/tool trust=1   # exe= / path= only; * does not cross /
allow perm=execute all : dir="/tmp/first last/"                    # double quotes for spaces
%languages+=application/x-vendor-script                            # package fragment after 10-languages
```

`dir=untrusted` is deprecated (use object `trust=`). `FILE_HASH` replaces `SHA256HASH`.
`fapolicyd-cli --ftype FILE` shows the MIME type rules will see.

### Health

```bash
sudo fapolicyd-cli --check-status
sudo fapolicyd-cli --check-metrics
sudo fapolicyd-cli --check-trustdb
sudo fapolicyd-cli --check-path
sudo fapolicyd-cli --check-rules --lint
sudo fapolicyd-cli --check-ignore_mounts --verbose
sudo fapolicyd-cli --compact-trustdb      # only when --check-status recommends it
```

Reports: man 5 `fapolicyd.state`, `fapolicyd.metrics` (per-rule hit counts), `fapolicyd.timing`.

### Debug X-ray

```bash
sudo systemctl stop fapolicyd
sudo mkdir -p /run/fapolicyd      # 2.0.1: removed on stop, needed for the pid file
sudo fapolicyd --permissive --debug-deny
# other terminal: reproduce → rule=N dec=… : path=… ftype=… trust=…
sudo fapolicyd-cli --list | nl -ba | sed -n '1,80p'
# Ctrl-C → sudo systemctl start fapolicyd
```

Without stopping the daemon: switch the rule to `deny_log`, `fagenrules --load`,
reproduce, read `journalctl -b -u fapolicyd`.

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
  ├─ "Permission denied" (EACCES)       → SELinux / DAC first
  ├─ "Operation not permitted" (EPERM)  → fapolicyd first
  ├─ ausearch -m AVC      → SELinux (label/policy)
  ├─ ausearch -m FANOTIFY → trust / rule order
  │     (kernel ≥ 6.3: fan_info = rule number (hex), subj_trust, obj_trust;
  │      full line → deny_log or --debug-deny)
  │     ├─ known software? → trust DB + --update
  │     └─ who/how?        → rules.d drop-in
  └─ neither → dontaudit? / debug-deny
```

## Instincts

1. Trust DB before allow-rule sprawl.  
2. FANOTIFY ≠ AVC — check both; SELinux answers first, so fix one and re-test.  
3. First-match: order is policy.  
4. Root can disable this (by design).  
5. Never hand-edit `compiled.rules`.  
6. Trust import scope: `fapolicyd-filter.conf` (man 5).  
7. The daemon's own SELinux module is the `fapolicyd-selinux` subpackage.  

## Extras

Unsupported helpers / fanotify notes:
https://github.com/linux-application-whitelisting/fapolicyd-extras 
