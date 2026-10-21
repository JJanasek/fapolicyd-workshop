# fapolicyd Power Users Workshop

Live Beamer deck teaches you to **configure and debug** fapolicyd;
**EXERCISES.md** drills it; showcases are for presenting later.

## How to go through this (important)

```
1) demos/00-lab-prep.sh          ← once
2) EXERCISES.md                  ← MAIN PATH (you type, predict, answer)
3) demos/*.sh                    ← only if stuck (spoilers)
4) demos/showcases/              ← LAST (flashy demos for presenting)
```

Do **not** start with showcases. They run themselves; you learn less.

| Path | Role |
|------|------|
| `presentation.pdf` | Live talk (why / what / how) |
| **`EXERCISES.md`** | **Practice — required work** |
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
