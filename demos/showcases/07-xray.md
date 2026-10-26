# SHOWCASE: Live X-ray — map denials to rule numbers

Two terminals. Do **not** strace the daemon.

## Terminal A (root)

```bash
systemctl stop fapolicyd
fapolicyd --permissive --debug-deny
```

## Terminal B

```bash
cp /usr/bin/ls /tmp/xray-ls && chmod +x /tmp/xray-ls
/tmp/xray-ls
# optional:
# python3 ~/…  or  ld-linux … /tmp/xray-ls
```

## Read the line in A

```
rule:N dec=deny_audit perm=execute ... exe=/usr/bin/bash : file=/tmp/xray-ls ...
```

Map it:

```bash
fapolicyd-cli --list | nl -ba | sed -n '1,100p'
```

## Finish

Ctrl-C in A, then `systemctl start fapolicyd`.

Every deny has a rule number — read the decision, not only “Permission denied”.
