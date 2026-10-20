# Demo 5 — Safe interactive debug (instructor-led)

**Do not** `strace` / `gdb` / `ptrace` the daemon.

## Terminal A (root)

```bash
systemctl stop fapolicyd
fapolicyd --permissive --debug-deny
```

Optional: isolate to one mount while teaching:

```bash
mount -t tmpfs tmpfs /mnt/fapo-lab
grep fapo-lab /proc/mounts > /tmp/fapo-mounts
# in another shell, recreate files under /mnt/fapo-lab
fapolicyd --permissive --debug-deny --mounts=/tmp/fapo-mounts
```

## Terminal B (user)

```bash
cp /usr/bin/ls /tmp/my-ls && chmod +x /tmp/my-ls
/tmp/my-ls
/usr/lib64/ld-linux-x86-64.so.2 /tmp/my-ls   # adjust loader path
python3 ~/fapo-workshop-hello.py             # from demo 04
```

## Read the line

```
rule:N dec=deny_audit perm=execute ... exe=/usr/bin/bash : file=/tmp/my-ls ftype=...
```

Map `N`:

```bash
fapolicyd-cli --list | nl -ba | sed -n '1,80p'
```

## Finish

Ctrl-C in Terminal A, then:

```bash
systemctl start fapolicyd
```

Only remove `--permissive` once the deny set is understood and intended.
