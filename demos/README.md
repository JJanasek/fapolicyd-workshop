# demos/

Prefer **[EXERCISES.md](../EXERCISES.md)** by hand. Scripts here are spoilers / automation.

Deny/allow checks run as user **`fapo`** (`lib.sh` → `as_user`). Root + trusted
shell matches shipped `allow perm=any uid=0 trust=1 : all` and skips the deny.

| Path | Role |
|------|------|
| `00-lab-prep.sh` | Install, audit watch, create `fapo`, start service |
| `lib.sh` | `as_user` helper |
| `01`–`09` | Spoilers for exercises |
| `showcases/` | Short demos after exercises |
