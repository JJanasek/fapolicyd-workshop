# Answers — check yourself after each exercise

Expected results for [EXERCISES.md](EXERCISES.md), derived from the rules
shipped with fapolicyd 2.0.1 (`known-libs` set). Rule numbers differ between
builds, so answers name the rule file, not the number. Find the number with
`sudo fapolicyd-cli --list`.

Exercises 3 and 5 were confirmed on a Fedora 44 lab VM; the rest is derived
from the shipped rules.

Rough time: Ex1 5 min · Ex2 10 · Ex3 5 · Ex4 10 (optional) · Ex5 15 · Ex6 20.

---

## Exercise 1 — Read the system

- **Permissive:** `false`. **Integrity:** `none` (the default).
- **Trust entries:** tens of thousands on a normal install, nearly all `rpmdb`.
  A count of 0 means the RPM backend did not load — stop and fix that first.
- **Catch-all execute deny:** `deny_audit perm=execute all : all`, from
  `90-deny-execute.rules`. It is the second-to-last rule; the last is
  `allow perm=open all : all`.
- `--check-path` lists anything on `$PATH` that is not trusted. A clean system
  prints nothing worrying.

## Exercise 2 — Clone of `ls`

- **Why is a byte-identical copy denied?** Trust is recorded per *path*
  (plus size and hash). `/opt/fapo-workshop/my-ls` is in neither the RPM
  database nor a trust file, so it is `trust=0`. No earlier rule allows it and
  `90-deny-execute` denies it.
- **Error text:** `Operation not permitted` (EPERM). `Permission denied`
  would point at SELinux or file modes instead.
- **Why does root often skip the deny?** `20-dracut.rules` contains
  `allow perm=any uid=0 trust=1 : all`. The *subject* is root running a
  trusted program (bash), so any object is allowed before the deny is reached.
- **Heal:**

  ```bash
  sudo fapolicyd-cli --file add /opt/fapo-workshop/my-ls --trust-file workshop
  sudo fapolicyd-cli --update
  /opt/fapo-workshop/my-ls          # runs now
  ```

  The entry lands in `/etc/fapolicyd/trust.d/workshop` and shows as `filedb`
  in `--dump-db`.

## Exercise 3 — ld.so smuggle

- Both commands are denied with `Operation not permitted`, including the
  trusted `/usr/bin/ls`.
- **Decided by:** `deny_audit perm=any pattern=ld_so : all` from
  `30-patterns.rules`. It matches on how the *subject* started, and the object
  is `all`, so trust does not matter.
- **Why the rule is needed:** the loader only *opens* the program. Without the
  pattern rule that open would fall through to `allow perm=open all : all`.

## Exercise 4 — Debug X-ray

- The line looks like:

  ```
  rule=N dec=deny_audit perm=execute auid=… pid=… exe=/usr/bin/bash : path=/tmp/xray-ls ftype=application/x-executable trust=0
  ```

- `N` maps to `deny_audit perm=execute all : all` (`90-deny-execute`).
- Because of `--permissive` the binary still runs: `dec=deny_audit` is what
  *would* happen. That is the point of soaking in permissive mode.
- If the daemon refuses to start with a pid-file error, `/run/fapolicyd` is
  missing — that is what the `mkdir -p` step is for.

## Exercise 5 — Dual stack

- **First attempt** (`tmp_t`, untrusted): `Permission denied`, one AVC
  (`staff_t` → `tmp_t`, `execute`), and **no** FANOTIFY record for this
  attempt. SELinux is asked first, so fapolicyd never sees the exec.
- **After `chcon -t bin_t`:** `Operation not permitted`, no AVC, one FANOTIFY
  record. The file is still untrusted (`90-deny-execute`).
- **Trust the file but leave `tmp_t`:** still `Permission denied` with an AVC.
  Trust does nothing about the label.
- **Lesson:** fix the layer that answered, then test again. Two problems means
  two rounds.

If you see both records for one attempt, check whether the FANOTIFY one is
older than your `$T` timestamp.

## Exercise 6a — Trust an `/opt` tree

```bash
sudo mkdir -p /opt/myapp/bin
sudo cp /usr/bin/id /opt/myapp/bin/hello
/opt/myapp/bin/hello; echo $?            # Operation not permitted, 126
sudo fapolicyd-cli --file add /opt/myapp --trust-file myapp
sudo fapolicyd-cli --update
/opt/myapp/bin/hello; echo $?            # runs, 0
sudo fapolicyd-cli --dump-db | grep myapp
# filedb /opt/myapp/bin/hello SIZE HASH
```

No rule was added: `42-trusted-elf` (`allow perm=execute all : trust=1`)
already covers every trusted file. A shell script would have run even before
trusting it, because of `72-shell.rules`.

## Exercise 6b — `rules.d` drop-in

```bash
sudo groupadd -f fapo_workshop
sudo tee /etc/fapolicyd/rules.d/39-ping.rules <<'EOF'
allow perm=any gid=fapo_workshop : trust=1 path=/usr/bin/ping
deny_audit perm=execute all : trust=1 path=/usr/bin/ping
EOF
sudo fagenrules --load
sudo fapolicyd-cli --check-rules --lint
sudo fapolicyd-cli --list | nl -ba | grep -n -E 'ping|trust=1$'
```

- **Before joining the group:** `ping -c1 127.0.0.1` → `Operation not permitted`.
- **After** `sudo usermod -aG fapo_workshop fapo` and a fresh login shell: works.
- **Why `39-`:** the two ping lines must appear above
  `allow perm=execute all : trust=1`. With `55-` that allow matches first and
  the deny is never reached.
- **Why the group needs a new shell:** group membership is read when the
  process starts; the running shell keeps its old groups.
- **As root it always works:** `uid=0 trust=1` in `20-dracut` matches first.
