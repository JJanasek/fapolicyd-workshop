# fapolicyd Power Users Workshop

Live Beamer deck teaches you to **configure and debug** fapolicyd;
**EXERCISES.md** drills it; showcases are for presenting later.

## How to go through this (important)

```
1) sudo ./demos/00-lab-prep.sh   ← once as root (creates user "fapo")
2) su - fapo                     ← deny demos need a non-root user
3) presentation.pdf
   + PRESENTATION-NOTES.txt      ← READ BOTH (notes explain every slide)
4) EXERCISES.md                  ← practice (type, predict, answer)
5) demos/*.sh                    ← only if stuck (spoilers)
6) demos/showcases/              ← LAST (presenting)
```

Root + trusted bash is often allowed to run untrusted binaries (shipped
`uid=0 trust=1` rule). Use **`fapo`** for Exercise 2 / deny checks; `sudo` for CLI.

Do **not** start with showcases. They run themselves; you learn less.

| Path | Role |
|------|------|
| `presentation.pdf` | Short slides |
| **`PRESENTATION-NOTES.txt`** | **Full explanation per slide (start here if new)** |
| **`EXERCISES.md`** | Practice |
| `TAKE-HOME.md` | Config cookbook reference |
| `demos/` | Spoiler scripts + showcases |

## Live session (~60–75 min)

Open `presentation.pdf`, follow along setup + one small demo.

## At home

1. `sudo ./demos/00-lab-prep.sh`
2. Work through **[EXERCISES.md](EXERCISES.md)** (predict → do → check → notes)
3. Later: pick 3 scripts from `demos/showcases/` and present them

## Rebuild slides

```bash
make
```

**Never** `strace` / `gdb` / `ptrace` the fapolicyd daemon.
