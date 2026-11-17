# fapolicyd Power Users Workshop

For SELinux / policy people: **configure and triage** fapolicyd (trust, `rules.d`, FANOTIFY vs AVC).

## Path

```
1) sudo ./demos/00-lab-prep.sh   ← root once (fapo in staff_t via ssh login)
2) presentation.pdf
   + PRESENTATION-NOTES.txt
3) EXERCISES.md                  ← type, predict, answer (ANSWERS.md when stuck)
4) demos/showcases/              ← present later (3 scripts)
5) sudo ./demos/99-cleanup.sh    ← reset lab artifacts
```

`TAKE-HOME.md` = config cookbook.

Root + trusted bash often skips untrusted-exec deny (`uid=0 trust=1`). Use **`fapo`** for deny checks; `sudo` for CLI.

| Path | Role |
|------|------|
| `presentation.pdf` | Slides (50 min talk + live demo) |
| `PRESENTATION-NOTES.txt` | Per-slide notes |
| `EXERCISES.md` | Hands-on (60–75 min) |
| `ANSWERS.md` | Expected results per exercise |
| `TAKE-HOME.md` | Reference |
| `demos/` | Prep, cleanup, showcases |

```bash
make          # rebuild slides (pdflatex, TinyTeX or tectonic)
```

**Never** `strace` / `gdb` / `ptrace` the fapolicyd daemon.
