# Sources

Every skill in this repo comes from an **external upstream**. None of it is
original to this repo — so there's no "ours vs theirs". Sources differ only by
**edit policy**, which is what decides where they live and how they're updated.

| Source | Edit policy | Lives in | Update | Lock |
|---|---|---|---|---|
| [`mattpocock/skills`](https://github.com/mattpocock/skills) | **forked & diverged** — we adapt these for OCaml/FP | `skills/` | `git merge upstream/main` then resolve | [`mattpocock-skills.lock`](./mattpocock-skills.lock) |
| [`avsm/ocaml-claude-marketplace`](https://github.com/avsm/ocaml-claude-marketplace) | **vendored verbatim** — never hand-edited | `vendor/ocaml-claude-marketplace/` | `make vendor-update SOURCE=ocaml-claude-marketplace` | [`ocaml-claude-marketplace.lock`](./ocaml-claude-marketplace.lock) |

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
make vendor-list     # the vendored sources
make vendor-status   # the pinned commits
make vendor-diff     # what upstream changed since our pins
make vendor-update   # re-sync every vendored source to latest upstream main
```

Every vendor target takes `SOURCE=<name>` to act on one source only, and
`vendor-update` takes `REF=<sha>` (with `SOURCE`) to pin a specific commit.

## Adding a vendored source

A vendored source is any `sources/<name>.lock` with a `subdir:` field; the lock
is both its config and its pin (`scripts/vendor.sh` reads it). Write the config
fields, then let `make vendor-update` fetch, mirror and pin:

```sh
cat > sources/<name>.lock <<'LOCK'
upstream: https://github.com/<owner>/<repo>.git
subdir:   .                       # path inside upstream to mirror
location: vendor/<name>           # where it lands in this repo
include:  <glob> LICENSE          # optional: top-level entries to copy
exclude:  <glob>                  # optional: top-level entries to skip
LOCK
make vendor-update SOURCE=<name>
```

Then add a row to the table above and a section to
[`vendor/README.md`](../vendor/README.md).

To pull upstream Pocock changes into the fork: `git fetch upstream && git merge
upstream/main`, resolve conflicts (our OCaml edits vs their changes), then update
`mattpocock-skills.lock` to the new merge-base.
