# Exercises — work through these (don’t just run scripts)

**Order for you:**

1. `sudo ./demos/00-lab-prep.sh` — once (as **root**)  
2. **`su - fapo`** — switch to the workshop user (created by prep)  
3. **This file** — exercises 1 → 6 (type commands yourself)  
4. Optional: `demos/*.sh` only if stuck (spoilers)  
5. **Last:** `demos/showcases/` — short demos to show others  

Showcases are for *presenting*. Exercises are for *learning*.

Use a disposable VM. Prefer SELinux enforcing.  
**Never** `strace` / `gdb` / `ptrace` fapolicyd.

### Root vs workshop user (read this)

Default shipped rules include something like:

```text
allow perm=any uid=0 trust=1 : all
```

Meaning: **root + trusted shell (bash from RPM) may do anything**, including
running untrusted copies under `/opt`. So as root, Exercise 2 will **not** deny.

| Who | Use for |
|-----|---------|
| `fapo` (or other normal user) | Run binaries, feel deny/allow |
| `root` / `sudo` | `fapolicyd-cli`, `systemctl`, `ausearch`, trust updates |

After prep:

```bash
su - fapo
# now do exercises that execute my-ls / scripts
# when you need sudo: sudo fapolicyd-cli ...
```

For each exercise: **Predict → Do → Check → Answer** (write answers in a notes file).

---

## Exercise 1 — Can you read the system?

**Goal:** Know what “healthy fapolicyd” looks like.

**Predict:** Roughly how many trust DB entries do you expect on a minimal Fedora install? (order of magnitude)

**Do:**

```bash
systemctl is-active fapolicyd
fapolicyd-cli --check-status
fapolicyd-cli --list | head -30
fapolicyd-cli --dump-db | head -5
fapolicyd-cli --check-path
```

**Check / answer in your notes:**

1. Is `Permissive` true or false? What does that mean for denials?
2. What is `Integrity` set to?
3. How many `Trust database entries`?
4. Find the rule that looks like a catch-all execute deny. What is its number in `--list`?

**Done when:** you can explain status + point at the deny-execute rule without reading docs.

---

## Exercise 2 — Clone of `ls` (core loop)

**Goal:** Feel deny → trust → allow.

**Who:** run the binary as **`fapo` (non-root)**. Prep/`cp` may use sudo.

**Predict:** You copy `/usr/bin/ls` to `/opt/fapo-workshop/my-ls` (same bytes).
As a normal user, will it run? Why? (What if you were root instead?)

**Do (type it — don’t paste the whole showcase):**

```bash
# still fine as fapo with sudo, or do the copy once as root then su - fapo
sudo mkdir -p /opt/fapo-workshop
sudo cp -a /usr/bin/ls /opt/fapo-workshop/my-ls
sudo chmod 755 /opt/fapo-workshop/my-ls
cmp -s /usr/bin/ls /opt/fapo-workshop/my-ls && echo identical-bytes

# IMPORTANT: not root here
id -u    # must NOT be 0
/opt/fapo-workshop/my-ls          # expect DENY
echo $?

sudo ausearch --start recent -m fanotify -f /opt/fapo-workshop/my-ls
```

If it **runs** and you are uid 0, switch user and retry — do not “fix” trust yet.

**Then heal it yourself** (look up the CLI if needed):

- add the file to the file trust DB under trust-file name `workshop` (`sudo`)
- tell the daemon to reload trust (`sudo`)
- run `my-ls` again **as fapo**

**Check / answer:**

1. Why was identical-to-RPM still denied (as non-root)?
2. Why does the same binary often succeed as root without trust?
3. Which audit message type did you see (`avc` vs `fanotify`)?
4. Exact commands you used to trust + update?

**Done when:** you saw deny as `fapo`, then allow after trust — without looking at a script first.

---

## Exercise 3 — ld.so smuggle

**Goal:** See that a trusted loader does not bless untrusted ELF.

**Who:** as **`fapo`** (non-root), same reason as Exercise 2.

**Predict:** `/usr/lib64/ld-linux-*.so.* /opt/fapo-workshop/my-ls` — allow or deny?

**Do:**

```bash
id -u    # must NOT be 0
# ensure my-ls is NOT trusted for this exercise
sudo fapolicyd-cli --file delete /opt/fapo-workshop/my-ls 2>/dev/null
sudo fapolicyd-cli --update

LDSO=$(find /usr/lib64 /lib64 -name 'ld-linux-*.so.*' | head -1)
echo "loader=$LDSO"
"$LDSO" /opt/fapo-workshop/my-ls
echo $?

fapolicyd-cli --list | grep -n ld_so
```

**Check / answer:**

1. Did ld.so help? Why / why not?
2. Which rule pattern is responsible?

---

## Exercise 4 — Debug X-ray (forced understanding)

**Goal:** Map `rule:N` to a real rule line.

**Predict:** Which rule number will deny `/tmp/xray-ls`? (guess from `--list` first)

**Do:**

```bash
# Terminal A
sudo systemctl stop fapolicyd
sudo fapolicyd --permissive --debug-deny
```

```bash
# Terminal B
cp /usr/bin/ls /tmp/xray-ls && chmod +x /tmp/xray-ls
/tmp/xray-ls
```

In A, find `rule:N`. Then:

```bash
fapolicyd-cli --list | nl -ba | sed -n '1,100p'
```

Ctrl-C in A, `sudo systemctl start fapolicyd`.

**Check / answer:**

1. What was `N`?
2. Paste the matching rule line into your notes.
3. Why is `--permissive` safer while learning?

---

## Exercise 5 — Dual stack (SELinux × fapolicyd)

**Goal:** One binary, two denial classes.

**Predict:** Untrusted ELF under `/var/tmp` with a wrong SELinux type — will you see AVC, FANOTIFY, both, or neither?

**Do:**

```bash
sudo mkdir -p /var/tmp/fapo-workshop
sudo cp -a /usr/bin/id /var/tmp/fapo-workshop/dual
sudo chmod 755 /var/tmp/fapo-workshop/dual
sudo chcon -t user_tmp_t /var/tmp/fapo-workshop/dual 2>/dev/null \
  || sudo chcon -t tmp_t /var/tmp/fapo-workshop/dual

ls -lZ /var/tmp/fapo-workshop/dual
/var/tmp/fapo-workshop/dual; echo exit=$?

sudo ausearch --start recent -m avc | tail -20
sudo ausearch --start recent -m fanotify -f /var/tmp/fapo-workshop/dual | tail -20
```

**Check / answer:**

1. Which messages appeared?
2. If you only `restorecon`, what still fails?
3. If you only trust the file, what still fails?

---

## Exercise 6 — Your own `/opt` app (config yourself)

**Goal:** Trust a tree without a workshop script.

**Task:** Create `/opt/myapp/bin/hello` (shell or copied binary). Make it fail, then make it work using **only** the trust DB (no custom allow rule).

**Deliverable in notes:**

```
commands used:
...
proof it was untrusted then trusted:
  dump-db line:
  before exit code / after exit code:
```

**Stretch:** Write a `rules.d/55-…` rule that allows `ping` only for a group you create. Reload safely. Prove deny then allow after `usermod -aG` + re-login.

---

## After exercises — showcases

Only now run flashy scripts (they auto-drive; use them to *demo*, not to learn):

```bash
sudo ./demos/showcases/01-clone-attack.sh
sudo ./demos/showcases/05-dual-stack.sh
# … pick a third
```

Prepare a 5-minute talk: what failed, which audit class, how you fixed it.

---

## Self-check (ready without hand-holding?)

- [ ] Explain trust vs SELinux behavior in two sentences  
- [ ] Trust an `/opt` tree and reload  
- [ ] Find which rule denied an event  
- [ ] Triage AVC vs FANOTIFY  
- [ ] Know why not to strace the daemon  
