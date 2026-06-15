# Vendored third-party skills

This directory holds **vendored copies** of external OCaml agent skills. They are
checked in (not submodules) so the repo is self-contained, but they are *not* ours
to edit — change them upstream and re-sync.

## ocaml-claude-marketplace / ocaml-dev

Anil Madhavapeddy's OCaml development plugin — the OCaml *domain* skills (eio,
effects, result, cmdliner, jsont, fuzz, memtrace, testing, code-style,
project-setup, oxcaml, ...). These complement our engineering *workflow* skills:
ours cover discipline (tdd, diagnose, triage, architecture); these cover OCaml
expertise.

- **Upstream**: https://github.com/avsm/ocaml-claude-marketplace (`plugins/ocaml-dev`)
- **License**: ISC (see upstream `LICENSE`)
- **Pinned commit**: recorded in [`ocaml-claude-marketplace.lock`](./ocaml-claude-marketplace.lock)

### Updating

From the repo root:

```sh
make vendor-status   # show the pinned commit
make vendor-diff     # show what upstream main changed vs our copy
make vendor-update   # sync to latest upstream main and rewrite the lock
```

To pin a specific commit instead of latest main:

```sh
make vendor-update REF=<sha>
```

**Do not hand-edit files under `vendor/`** — they'll be overwritten on the next
`make vendor-update`. If something needs changing, send it upstream.
