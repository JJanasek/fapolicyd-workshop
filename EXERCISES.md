# Exercises — configure fapolicyd (type commands yourself)

**Audience:** SELinux / policy people. Goal = trust, rules.d, triage FANOTIFY vs AVC.

**Order:**

1. `sudo ./demos/00-lab-prep.sh` — once as root (creates confined `fapo`)  
2. You should land as **`fapo`** (prep does `su -`)  
3. Core path **1 → 2 → 3 → 5 → 6**  
4. Exercise 4 — optional (`--debug-deny` / `rule:N`)  
5. `demos/showcases/` — present later (3 scripts)  
6. Reset: `sudo ./demos/99-cleanup.sh`

Disposable VM. SELinux enforcing. **Never** `strace` / `gdb` / `ptrace` fapolicyd.

### Root vs `fapo`

Shipped roughly: `allow perm=any uid=0 trust=1 : all`  
→ root + trusted bash often **allows** untrusted `/opt` copies. Deny labs need **`fapo`**.

| Who | Use for |
|-----|---------|
| `fapo` | Run binaries, feel deny/allow |
| `sudo` | `fapolicyd-cli`, `systemctl`, `ausearch`, trust / rules |

Always **`sudo fapolicyd-cli`** here. Prep maps `fapo` → `staff_u` so dual-stack can emit AVC.

For each exercise: **Predict → Do → Check** (notes file).

---

## Exercise 1 — Read the system

**Goal:** Healthy fapolicyd looks like…

```bash
systemctl is-active fapolicyd
sudo fapolicyd-cli --check-status
sudo fapolicyd-cli --list | head -30
sudo fapolicyd-cli --dump-db | head -5
sudo fapolicyd-cli --check-path
```

**Answer:** Permissive? Integrity? Trust entry count? Catch-all execute deny line #?

---

## Exercise 2 — Clone of `ls` (core loop)

**Goal:** deny → trust → allow. Run as **`fapo`**.

```bash
sudo mkdir -p /opt/fapo-workshop
sudo cp -a /usr/bin/ls /opt/fapo-workshop/my-ls
sudo chmod 755 /opt/fapo-workshop/my-ls
cmp -s /usr/bin/ls /opt/fapo-workshop/my-ls && echo identical-bytes

id -u    # must NOT be 0
/opt/fapo-workshop/my-ls          # expect DENY
echo $?

# Compact FANOTIFY often has no path — prefer:
sudo ausearch --start recent -m FANOTIFY -i
```

If empty: `sudo auditctl -l` (need ≥1 rule), re-deny, search again.  
**Path / `rule:N`** → Exercise 4 (`--debug-deny`).

**Heal:** `--file add … --trust-file workshop` + `--update`; run again as `fapo`.

**Answer:** Why identical-to-RPM denied? Why root often skips deny? Commands used?

---

## Exercise 3 — ld.so smuggle

**Goal:** Trusted loader does not bless untrusted ELF. As **`fapo`**.

```bash
id -u
sudo fapolicyd-cli --file delete /opt/fapo-workshop/my-ls --trust-file workshop 2>/dev/null
sudo fapolicyd-cli --update

LDSO=$(find /usr/lib64 /lib64 -name 'ld-linux-*.so.*' | head -1)
echo "loader=$LDSO"
"$LDSO" /opt/fapo-workshop/my-ls
echo $?

sudo fapolicyd-cli --list | grep -n ld_so
```

Read: `deny_audit perm=any pattern=ld_so : all`  
= subject looks like linker smuggle → deny any object + audit.

---

## Exercise 4 — Debug X-ray *(optional)*

Same deny as Ex2, deeper: `--debug-deny` for `file=` / `rule:N` (ausearch often omits both).

```bash
# Terminal A
sudo systemctl stop fapolicyd
sudo fapolicyd --permissive --debug-deny

# Terminal B as fapo
cp /usr/bin/ls /tmp/xray-ls && chmod +x /tmp/xray-ls
/tmp/xray-ls
```

Map `N`: `sudo fapolicyd-cli --list | nl -ba | sed -n '1,100p'`  
Ctrl-C → `sudo systemctl start fapolicyd` → `rm -f /tmp/xray-ls`.

---

## Exercise 5 — Dual stack (SELinux × fapolicyd)

**Goal:** One binary, two denial classes when confined.

Prep should give `staff_u` — check `id -Z` (not `unconfined_t`).

```bash
id -u; id -Z
sudo mkdir -p /var/tmp/fapo-workshop
sudo cp -a /usr/bin/id /var/tmp/fapo-workshop/dual
sudo chmod 755 /var/tmp/fapo-workshop/dual
sudo chcon -t user_tmp_t /var/tmp/fapo-workshop/dual 2>/dev/null \
  || sudo chcon -t tmp_t /var/tmp/fapo-workshop/dual

ls -lZ /var/tmp/fapo-workshop/dual
/var/tmp/fapo-workshop/dual; echo exit=$?

sudo ausearch --start recent -m AVC | tail -20
sudo ausearch --start recent -m FANOTIFY -i | tail -20
```

**Answer:** Which messages? Only `restorecon` → what still fails? Only trust → what still fails?

---

## Exercise 6 — Configure yourself (trust + rules.d)

### 6a — Trust an `/opt` tree

Create `/opt/myapp/bin/hello` (script or copied binary). Fail as `fapo`, then allow using **only** the trust DB (no custom allow).

Notes deliverable: commands, dump-db line, before/after exit codes.

### 6b — `rules.d` drop-in *(required)*

Allow `ping` only for a group you create. Reload safely. Prove deny, then allow after `usermod -aG` + re-login.

Hint shape (place **above** catch-all deny):

```text
allow perm=any gid=YOURGROUP : trust=1 path=/usr/bin/ping
deny_audit perm=execute all : trust=1 path=/usr/bin/ping
```

`fagenrules` → `--check-rules --lint` → `systemctl reload fapolicyd`.

---

## After exercises — showcases

Present only (auto-drive):

```bash
./demos/showcases/01-home-drop.sh
sudo ./demos/showcases/02-dual-stack.sh
sudo ./demos/showcases/03-gid-gate.sh
```

5-minute talk: what failed, which audit class, how you fixed it.

---

## Self-check

- [ ] Trust vs SELinux in two sentences  
- [ ] Trust an `/opt` tree + `--update`  
- [ ] Ship a numbered `rules.d` drop-in + reload  
- [ ] Triage AVC vs FANOTIFY  
- [ ] Know why not to strace the daemon  
