# Sources

Every skill set this repo composes comes from an **external upstream**, vendored
verbatim and pinned. What is ours lives in `skills/`: skills written here, and
**overrides** — local adaptations of an upstream skill that keep tracking it.

| Source | Lives in | Update | Lock |
|---|---|---|---|
| [`mattpocock/skills`](https://github.com/mattpocock/skills) | `vendor/mattpocock-skills/` | `make vendor-update-mattpocock-skills` | [`mattpocock-skills.lock`](./mattpocock-skills.lock) |
| [`avsm/ocaml-claude-marketplace`](https://github.com/avsm/ocaml-claude-marketplace) | `vendor/ocaml-claude-marketplace/` | `make vendor-update-ocaml-claude-marketplace` | [`ocaml-claude-marketplace.lock`](./ocaml-claude-marketplace.lock) |
| [`gazagnaire.org/ocaml-claude-skills`](https://tangled.org/gazagnaire.org/ocaml-claude-skills) | `vendor/ocaml-claude-skills/` | `make vendor-update-ocaml-claude-skills` | [`ocaml-claude-skills.lock`](./ocaml-claude-skills.lock) |
| [`DreambigOu/ELI5`](https://github.com/DreambigOu/ELI5) | `vendor/eli5/` | `make vendor-update-eli5` | [`eli5.lock`](./eli5.lock) |

All four are **vendored verbatim** — never hand-edited.

## Two locations, one rule

- **`vendor/` is verbatim.** We pull these in unchanged and pin a commit. Never
  hand-edit them — changes go upstream, then `make vendor-update` re-syncs.
  `git` won't warn you if you edit them; `make vendor-check` will (drift
  against the pinned commit). Each vendored set lives at
  `vendor/<name>/<subdir basename>/`, with the upstream license beside it
  (`VENDOR_LICENSE_<name>` in the Makefile, recorded as `license:` in the lock)
  when the license sits outside the vendored subdir:
  - `mattpocock-skills/skills/` — Matt Pocock's engineering and productivity
    workflow skills (grilling, domain-modeling, pr, research, retro, wizard,
    handoff, teach, …). This repo began as a fork of that repo; the git
    history keeps that, the layout no longer does.
  - `ocaml-claude-marketplace/ocaml-dev/` — Anil Madhavapeddy's OCaml domain
    skills (eio, effects, result, cmdliner, jsont, …).
  - `ocaml-claude-skills/monopam/` — Thomas Gazagnaire's monopam monorepo
    skills (cram, mdx, git-commit, git-rewrite, ocaml-functors,
    interop-testing, perf, console, …).
  - `eli5/eli5/` — DreambigOu's ELI5: one skill that explains a topic, a
    piece of code, or an error to a named audience (age, grade, job role,
    family member), calibrating vocabulary, analogy, and length to it.

    Vendored **whole** (`UPSTREAM_SUB := .`, `UPSTREAM_DIR := eli5`) because
    the repo has no plugin directory — its skill sits at `skills/eli5/` — so
    no subdir holds both the skill and the MIT `LICENSE` that must travel
    with it. `eli5-workspace/` is dropped via `VENDOR_EXCLUDE_eli5`: it is
    upstream's own eval harness, and this repo already has `evals/`.

- **`skills/` is ours.** Local skills (`unpac`, `fork-package`, `merlint`,
  `review-diff`) and overrides. We edit these freely; `make check` lints them.

## Overrides

An override is a copy of an upstream skill directory with local edits that
still wants upstream's improvements. It lives in `skills/`, its upstream copy
is dropped from the vendored tree (`VENDOR_EXCLUDE_<vendor>`), and it is
registered in [`overrides/overrides.lock`](./overrides/overrides.lock):

```
# override                          vendor              upstream dir (in subdir)     base
skills/engineering/tdd              mattpocock-skills   engineering/tdd              49dd158…
skills/engineering/ocaml-protocols  ocaml-claude-skills skills/ocaml-protocols       c3c436b…
```

On `make vendor-update-<vendor>`, `scripts/merge-overrides.sh` three-way merges
every file upstream changed since `base` into the override (`git merge-file`),
copies in files upstream added, drops files upstream removed when the local copy
is untouched, then advances `base`. The base itself is kept as a snapshot of the
upstream directory under `overrides/<skill>/`, so a rewritten upstream history
cannot break the merge. Conflicts are left as `<<<<<<<` markers with
instructions; `make integrity` fails until they are gone.

Each override's `SKILL.md` opens with an `<!-- override: ... -->` comment naming
the upstream, its license, and the **local changes to keep** — that list is what
a merge must preserve, and what to prune when upstream catches up.

Current overrides:

- From `mattpocock/skills`, adapted to OCaml + dune: `codebase-design`,
  `diagnosing-bugs`, `implement`, `implement-spec`, `prototype`, `tdd`,
  `to-spec`, `to-tickets`, `triage`, `wayfinder`.
- From `ocaml-claude-skills`, adapted to the unpac workflow: `ocaml-protocols`,
  `init-ocaml`.

## Declared excludes

`VENDOR_EXCLUDE_<name>` drops paths at vendor time; each is recorded in the
lock's `exclude:` lines and honoured by the drift check. Excludes are
**path-anchored** (rsync `/`-prefixed), so `skills/foo` drops only that
directory, not every `foo` in the tree.

`mattpocock-skills` drops `misc`, `deprecated` and the unfinished
`in-progress` skills (not promoted upstream; `chief-of-staff` and
`claude-handoff` are kept from `in-progress`), `ask-matt` and
`setup-matt-pocock-skills` (they route to and configure upstream's own set; the
tracker and label context lives in `AGENTS.md` here), `code-review`
(`review-diff` owns review here), and the ten skills that are overrides.

`ocaml-claude-marketplace` drops `fuzz` (the house fuzz library is alcobar,
whose skill comes from `ocaml-claude-skills`), `project-setup` (`init-ocaml`
owns new-package setup), `progress`, `logs`, `memtrace` and `tutorials` (tool
conflicts with console, ocaml-observe, perf and mdx/readme).

`ocaml-claude-skills` drops `monopam`, `concurrent-claude` and `fork-package`
(they document the monopam subtree workflow; this workspace vendors with unpac,
whose counterparts are `skills/engineering/unpac` and
`skills/engineering/fork-package`), `ocaml-protocols` and `init-ocaml` (local
overrides), and `requests` (cohttp-eio owns HTTP).

## Name collisions across sources

The install surface is flat (one symlink per skill name), so overlapping
upstreams collide — e.g. both OCaml sets ship a `fuzz` skill. `make install`
keeps the **first in discover order** (local skills, then vendors sorted by
name) and prints what it skipped; `make integrity` warns about every
cross-source duplicate and names the winner.

## Updating

```sh
make vendor-status   # the pinned commit of each vendored set
make vendor-diff     # what each upstream changed since our pin
make vendor-update   # re-sync ALL vendored sets to latest upstream main and
                     # merge upstream changes into the overrides
                     # (per-vendor: make vendor-update-<name>, etc.)
make vendor-update-<name> REF=<sha>   # pin a specific commit instead
```
