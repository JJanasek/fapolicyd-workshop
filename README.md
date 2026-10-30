# fapolicyd Power Users Workshop

For SELinux / policy people: **configure and triage** fapolicyd (trust, `rules.d`, FANOTIFY vs AVC).

## Path

```
1) sudo ./demos/00-lab-prep.sh   ← root once (creates confined user fapo)
2) presentation.pdf
   + PRESENTATION-NOTES.txt
3) EXERCISES.md                  ← type, predict, answer
4) demos/showcases/              ← present later (3 scripts)
5) sudo ./demos/99-cleanup.sh    ← reset lab artifacts
```

`TAKE-HOME.md` = config cookbook.

Root + trusted bash often skips untrusted-exec deny (`uid=0 trust=1`). Use **`fapo`** for deny checks; `sudo` for CLI.

| Path | Role |
|------|------|
| `presentation.pdf` | Short slides |
| `PRESENTATION-NOTES.txt` | Per-slide notes |
| `EXERCISES.md` | Hands-on |
| `TAKE-HOME.md` | Reference |
| `demos/` | Prep, cleanup, showcases |

```bash
make          # rebuild slides
```

**Never** `strace` / `gdb` / `ptrace` the fapolicyd daemon.
