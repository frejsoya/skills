# Vendored skills (verbatim)

This directory holds skill sets **vendored verbatim** from an external upstream:
checked in (not submodules) so the repo is self-contained, pinned to a commit,
and **never hand-edited** — change them upstream and re-sync.

> The rest of the repo (`skills/`) is ours: local skills, and *overrides* of
> upstream skills that keep tracking their upstream through
> `sources/overrides/overrides.lock`. See
> [`sources/README.md`](../sources/README.md) for the full provenance model.

Each set lands at `vendor/<name>/<subdir basename>/`, with a copy of the
upstream license next to it when the license sits outside the vendored subdir.

## mattpocock-skills / skills

Matt Pocock's engineering and productivity workflow skills — grilling,
domain-modeling, grill-with-docs, improve-codebase-architecture, pr, research,
retro, wizard, handoff, teach, wait-what, writing-for-agents, and the
in-progress chief-of-staff and claude-handoff. The OCaml-adapted ones (tdd,
prototype, codebase-design, diagnosing-bugs, triage, …) are *not* here: they
are overrides in `skills/engineering/`.

This repo began as a fork of `mattpocock/skills`. The git history keeps that;
the layout no longer does — it is vendored like every other set.

- **Upstream**: https://github.com/mattpocock/skills (`skills/`)
- **License**: MIT ([`LICENSE`](./mattpocock-skills/LICENSE))
- **Pinned commit**: recorded in [`sources/mattpocock-skills.lock`](../sources/mattpocock-skills.lock)

## ocaml-claude-marketplace / ocaml-dev

Anil Madhavapeddy's OCaml development plugin — the OCaml *domain* skills (eio,
effects, result, cmdliner, jsont, testing, code-style, oxcaml, ...). These
complement the workflow skills: those cover discipline (tdd, diagnose, triage,
architecture); these cover OCaml expertise.

- **Upstream**: https://github.com/avsm/ocaml-claude-marketplace (`plugins/ocaml-dev`)
- **License**: ISC ([`LICENSE`](./ocaml-claude-marketplace/LICENSE))
- **Pinned commit**: recorded in [`sources/ocaml-claude-marketplace.lock`](../sources/ocaml-claude-marketplace.lock)

## ocaml-claude-skills / monopam

Thomas Gazagnaire's monopam monorepo plugin — cram, mdx, git-commit,
git-rewrite, ocaml-functors, interop-testing, perf, todo, fuzz, readme, and the
console and ocaml-observe library skills.

- **Upstream**: https://tangled.org/gazagnaire.org/ocaml-claude-skills (`plugins/monopam`)
- **License**: ISC ([`LICENSE.md`](./ocaml-claude-skills/LICENSE.md))
- **Pinned commit**: recorded in [`sources/ocaml-claude-skills.lock`](../sources/ocaml-claude-skills.lock)

## eli5

DreambigOu's ELI5 — a single skill that explains a topic, a piece of code, or an
error to a *named audience*: an age, a grade level, a job role (manager,
designer, director), or a family member. It picks the vocabulary, the analogy
domain, and the length to match, and refuses to talk down. Neither OCaml nor
workflow: the one skill here aimed at the reader of an explanation rather than
at the work.

Vendored whole (the repo root), because its `LICENSE` and its `skills/eli5/`
have no common subdir. Upstream's `eli5-workspace/` eval harness is excluded —
see [`sources/README.md`](../sources/README.md).

- **Upstream**: https://github.com/DreambigOu/ELI5 (repo root)
- **License**: MIT ([`LICENSE`](./eli5/eli5/LICENSE))
- **Pinned commit**: recorded in [`sources/eli5.lock`](../sources/eli5.lock)

## Updating

From the repo root:

```sh
make vendor-status   # show the pinned commits
make vendor-diff     # show what upstream main changed vs our copies
make vendor-update   # sync to latest upstream main, rewrite the locks,
                     # merge upstream changes into the skills/ overrides
```

To pin a specific commit instead of latest main:

```sh
make vendor-update-<name> REF=<sha>
```

**Do not hand-edit files under `vendor/`** — they'll be overwritten on the next
`make vendor-update`, and `make vendor-check` reports the drift. If something
needs changing, send it upstream; if it needs changing *here*, make it an
override (see `sources/README.md`).
