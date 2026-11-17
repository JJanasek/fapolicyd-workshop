# Exercises — configure fapolicyd (type commands yourself)

**Audience:** SELinux / policy people. Goal = trust, rules.d, triage FANOTIFY vs AVC.

**Order:**

1. `sudo ./demos/00-lab-prep.sh` — once as root (creates confined `fapo`)  
2. You should land as **`fapo` in `staff_t`** (prep logs in over `ssh`; plain `su -` stays unconfined)  
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

Always **`sudo fapolicyd-cli`** here (sudoers → `unconfined_t` for admin).
Prep enters `staff_t` via an `ssh` login so dual-stack can emit AVC.

For each exercise: **Predict → Do → Check** (notes file).
Expected results: **[ANSWERS.md](ANSWERS.md)** — look only after you tried.

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
/opt/fapo-workshop/my-ls          # expect DENY: "Operation not permitted" (EPERM)
echo $?                           # SELinux/DAC would say "Permission denied" (EACCES)

# Compact FANOTIFY often has no path — prefer:
sudo ausearch --start recent -m FANOTIFY -i
```

If empty: `sudo auditctl -l` (need ≥1 rule), re-deny, search again.  
Kernel ≥ 6.3: the record carries `fan_info` (rule number as in
`fapolicyd-cli --list`, but **hex** in the raw record: `fan_info=B` = rule 11),
`subj_trust`, `obj_trust`.  
**Full line (`rule=N … path=…`)** → Exercise 4 (`--debug-deny`).

**Heal:** `--file add … --trust-file workshop` + `--update`; run again as `fapo`.

**Answer:** Why identical-to-RPM denied? Why root often skips deny? Commands used?

---

## Exercise 3 — ld.so smuggle

**Goal:** Starting a program through the loader is denied — even a trusted one. As **`fapo`**.

```bash
id -u
LDSO=$(find /usr/lib64 /lib64 -name 'ld-linux-*.so.*' | head -1)
echo "loader=$LDSO"

"$LDSO" /usr/bin/ls                  # trusted RPM binary — still DENY
echo $?
"$LDSO" /opt/fapo-workshop/my-ls     # trusted or not — DENY
echo $?

sudo fapolicyd-cli --list | grep -n ld_so
```

Read: `deny_audit perm=any pattern=ld_so : all`  
= subject looks like linker smuggle → deny any object + audit.  
Without it the loader only *opens* the ELF, and `95-allow-open` would allow that.

Then remove the trust again (later exercises expect `my-ls` untrusted):

```bash
sudo fapolicyd-cli --file delete /opt/fapo-workshop/my-ls --trust-file workshop
sudo fapolicyd-cli --update
```

---

## Exercise 4 — Debug X-ray *(optional)*

Same deny as Ex2, deeper: `--debug-deny` prints the full decision line:
`rule=N dec=deny_audit perm=execute auid=… pid=… exe=… : path=… ftype=… trust=0`

```bash
# Terminal A
sudo systemctl stop fapolicyd
sudo mkdir -p /run/fapolicyd     # 2.0.1: systemd removes it on stop; daemon needs it for its pid file
sudo fapolicyd --permissive --debug-deny

# Terminal B as fapo
cp /usr/bin/ls /tmp/xray-ls && chmod +x /tmp/xray-ls
/tmp/xray-ls
```

Map `N`: `sudo fapolicyd-cli --list | nl -ba | sed -n '1,100p'`  
Ctrl-C → `sudo systemctl start fapolicyd` → `rm -f /tmp/xray-ls`.

**Without stopping the daemon:** change the matching rule from `deny_audit` to
`deny_log`, `sudo fagenrules --load`, reproduce, then
`journalctl -b -u fapolicyd` shows the same line. Per-rule hit counts:
`sudo fapolicyd-cli --check-metrics`.

---

## Exercise 5 — Dual stack (SELinux × fapolicyd)

**Goal:** One binary, wrong for both layers — meet them one at a time.

SELinux is asked before fapolicyd gets the fanotify event, so one attempt
normally logs only the first denier. Use a fresh timestamp for each attempt
(`--start recent` also shows FANOTIFY from earlier exercises).

Check `id -Z` contains **`staff_t`** (not `unconfined_t`).
If you used plain `su -`, re-enter:
`sudo ssh -i /root/.ssh/fapo_workshop_ed25519 fapo@localhost`

Use **`tmp_t`**. `user_tmp_t` is executable by `staff_t` while
`staff_exec_content` is on (default), so you only see FANOTIFY.
`cp -a` also keeps `bin_t`, which `staff_t` may execute.

```bash
id -u; id -Z
sudo mkdir -p /var/tmp/fapo-workshop
sudo cp -a /usr/bin/id /var/tmp/fapo-workshop/dual
sudo chmod 755 /var/tmp/fapo-workshop/dual
sudo chcon -t tmp_t /var/tmp/fapo-workshop/dual

ls -lZ /var/tmp/fapo-workshop/dual
T=$(date +%T)
/var/tmp/fapo-workshop/dual; echo exit=$?     # note the error text

sudo ausearch --start $T -m AVC | tail -20
sudo ausearch --start $T -m FANOTIFY -i | tail -20
```

**Answer:** Which record(s) for this one attempt, and which error text
(*Permission denied* vs *Operation not permitted*)?
`chcon -t bin_t` (drop AVC only) → what fails now, with which error?
Trust the file only → what still fails on `tmp_t`?
(`restorecon` on `/var/tmp` often changes nothing — `file_contexts` is `<<none>>`.)

---

## Exercise 6 — Configure yourself (trust + rules.d)

### 6a — Trust an `/opt` tree

Copy an **ELF** to `/opt/myapp/bin/hello` (e.g. `/usr/bin/id`). A shell script
often already runs (`allow … ftype=text/x-shellscript`). Fail as `fapo`, then
allow using **only** the trust DB (no custom allow).

Notes deliverable: commands, dump-db line, before/after exit codes.

### 6b — `rules.d` drop-in *(required)*

Allow `ping` only for a group you create (not `wheel` — prep puts `fapo` in `wheel`).
Prove deny as `fapo`, then allow after `usermod -aG` + re-login.

File must sort **before** `42-trusted-elf` (`allow perm=execute all : trust=1`).
`55-` is too late — first match already allowed trusted ping.

```text
# /etc/fapolicyd/rules.d/39-ping.rules
allow perm=any gid=YOURGROUP : trust=1 path=/usr/bin/ping
deny_audit perm=execute all : trust=1 path=/usr/bin/ping
```

`fagenrules --load` (not `systemctl reload` — that does not load rules).  
Then `--check-rules --lint`. Confirm ping lines sit above the trusted-ELF allow:

```bash
sudo fapolicyd-cli --list | nl -ba | grep -n -E 'ping|trust=1$'
```

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
