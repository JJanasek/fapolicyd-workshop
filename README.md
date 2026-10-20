# fapolicyd Power Users Workshop

Workshop materials for the SELinux development team: live Beamer deck,
self-serve config cookbook, and cool showcases.

## Live session (~60–75 min)

Open `presentation.pdf` — why / what / how + setup + one small demo.

## At home (configure it yourself)

1. Read **[TAKE-HOME.md](TAKE-HOME.md)** (cookbook + showcase gallery).
2. On a disposable VM:

```bash
sudo ./demos/00-lab-prep.sh
sudo ./demos/showcases/01-clone-attack.sh
sudo ./demos/showcases/05-dual-stack.sh
```

3. Pick three showcases and present them back to the team.

## Contents

| Path | Purpose |
|------|---------|
| `presentation.pdf` / `.tex` | Live deck |
| `TAKE-HOME.md` | Config cookbook + showcases |
| `demos/00`–`09` | Structured drills |
| `demos/showcases/` | ~2-minute flashy demos |
| `Makefile` | `make` → rebuild PDF |

## Rebuild slides

Needs TeX Live with Beamer (or a local TinyTeX):

```bash
make
```

**Never** `strace` / `gdb` / `ptrace` the fapolicyd daemon.
