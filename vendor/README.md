# Vendored skills (verbatim)

This directory holds skills **vendored verbatim** from an external upstream:
checked in (not submodules) so the repo is self-contained, pinned to a commit,
and **never hand-edited** — change them upstream and re-sync.

> The rest of the repo (`skills/`) is a *diverged fork* of `mattpocock/skills`,
> which we **do** edit. Both are external; they differ only by edit policy. See
> [`sources/README.md`](../sources/README.md) for the full provenance model.

## ocaml-claude-marketplace / ocaml-dev

Anil Madhavapeddy's OCaml development plugin — the OCaml *domain* skills (eio,
effects, result, cmdliner, jsont, fuzz, memtrace, testing, code-style,
project-setup, oxcaml, ...). These complement our engineering *workflow* skills:
ours cover discipline (tdd, diagnose, triage, architecture); these cover OCaml
expertise.

- **Upstream**: https://github.com/avsm/ocaml-claude-marketplace (`plugins/ocaml-dev`)
- **License**: ISC (see upstream `LICENSE`)
- **Pinned commit**: recorded in [`sources/ocaml-claude-marketplace.lock`](../sources/ocaml-claude-marketplace.lock)

## Updating

From the repo root (omit `SOURCE` to act on every vendored source):

```sh
make vendor-status SOURCE=<name>   # show the pinned commit
make vendor-diff   SOURCE=<name>   # show what upstream main changed vs our copy
make vendor-update SOURCE=<name>   # sync to latest upstream main and rewrite the lock
```

To pin a specific commit instead of latest main:

```sh
make vendor-update SOURCE=<name> REF=<sha>
```

**Do not hand-edit files under `vendor/`** — they'll be overwritten on the next
`make vendor-update`. If something needs changing, send it upstream.
