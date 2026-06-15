# Sources

Every skill in this repo comes from an **external upstream**. None of it is
original to this repo — so there's no "ours vs theirs". Sources differ only by
**edit policy**, which is what decides where they live and how they're updated.

| Source | Edit policy | Lives in | Update | Lock |
|---|---|---|---|---|
| [`mattpocock/skills`](https://github.com/mattpocock/skills) | **forked & diverged** — we adapt these for OCaml/FP | `skills/` | `git merge upstream/main` then resolve | [`mattpocock-skills.lock`](./mattpocock-skills.lock) |
| [`avsm/ocaml-claude-marketplace`](https://github.com/avsm/ocaml-claude-marketplace) | **vendored verbatim** — never hand-edited | `vendor/ocaml-claude-marketplace/` | `make vendor-update` | [`ocaml-claude-marketplace.lock`](./ocaml-claude-marketplace.lock) |

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
  by convention).

## Updating

```sh
make fork-status     # how far skills/ is behind mattpocock/skills upstream
make vendor-status   # the pinned avsm commit
make vendor-diff     # what avsm changed since our pin
make vendor-update   # re-sync avsm to latest upstream main
```

To pull upstream Pocock changes into the fork: `git fetch upstream && git merge
upstream/main`, resolve conflicts (our OCaml edits vs their changes), then update
`mattpocock-skills.lock` to the new merge-base.
