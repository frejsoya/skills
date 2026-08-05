# Sources

Every skill in this repo comes from an **external upstream**. None of it is
original to this repo — so there's no "ours vs theirs". Sources differ only by
**edit policy**, which is what decides where they live and how they're updated.

| Source | Edit policy | Lives in | Update | Lock |
|---|---|---|---|---|
| [`mattpocock/skills`](https://github.com/mattpocock/skills) | **forked & diverged** — we adapt these for OCaml/FP | `skills/` | `git merge upstream/main` then resolve | [`mattpocock-skills.lock`](./mattpocock-skills.lock) |
| [`avsm/ocaml-claude-marketplace`](https://github.com/avsm/ocaml-claude-marketplace) | **vendored verbatim** — never hand-edited | `vendor/ocaml-claude-marketplace/` | `make vendor-update-ocaml-claude-marketplace` | [`ocaml-claude-marketplace.lock`](./ocaml-claude-marketplace.lock) |
| [`gazagnaire.org/ocaml-claude-skills`](https://tangled.org/gazagnaire.org/ocaml-claude-skills) | **vendored verbatim** — never hand-edited | `vendor/ocaml-claude-skills/` | `make vendor-update-ocaml-claude-skills` | [`ocaml-claude-skills.lock`](./ocaml-claude-skills.lock) |

## Why two locations

The split is by edit policy, not authorship:

- **`skills/` is a diverged fork.** This whole repo *is* the `mattpocock/skills`
  fork (tracked by the `upstream` git remote). We edit these freely — the OCaml
  adaptation lives here. Pulling upstream improvements is a **merge**, not a
  re-sync, because our copy has diverged. `mattpocock-skills.lock` records the
  fork point so `make fork-status` can show how far behind we are.

- **`vendor/` is verbatim.** We pull these in unchanged and pin a commit. Never
  hand-edit them — changes go upstream, then `make vendor-update` re-syncs.
  `git` won't warn you if you edit them; the lint will (`vendor/` is read-only
  by convention). Each vendored set lives at `vendor/<name>/<plugin>/`:
  - `ocaml-claude-marketplace/ocaml-dev/` — Anil Madhavapeddy's OCaml domain
    skills (eio, effects, result, cmdliner, fuzz, memtrace, …).
  - `ocaml-claude-skills/monopam/` — Thomas Gazagnaire's monopam monorepo
    skills (cram, mdx, git-commit, git-rewrite, ocaml-functors,
    interop-testing, perf, console, requests, …).

## Name collisions across sources

The install surface is flat (one symlink per skill name), so overlapping
upstreams collide — e.g. both vendored sets ship a `fuzz` skill. `make install`
keeps the **first in discover order** (fork skills, then vendors sorted by
name) and prints what it skipped; `make integrity` warns about every
cross-source duplicate and names the winner.

## Updating

```sh
make fork-status     # how far skills/ is behind mattpocock/skills upstream
make vendor-status   # the pinned commit of each vendored set
make vendor-diff     # what each upstream changed since our pin
make vendor-update   # re-sync ALL vendored sets to latest upstream main
                     # (per-vendor: make vendor-update-<name>, etc.)
```

To pull upstream Pocock changes into the fork: `git fetch upstream && git merge
upstream/main`, resolve conflicts (our OCaml edits vs their changes), then update
`mattpocock-skills.lock` to the new merge-base.
