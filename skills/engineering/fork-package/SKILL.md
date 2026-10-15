---
name: fork-package
description: Forking a third-party OCaml package in an unpac workspace — vendor it with unpac, patch it in edit sessions, and carry the fork obligations when it graduates to a published library, including fsx- naming on an opam name clash, preserved upstream license and per-file copyright, and the house fork warning. Use when vendoring or forking an external library, or when publishing a diverged fork under your own name. For a greenfield package, use unpac opam init instead.
---
<!-- override: adapted from gazagnaire/ocaml-claude-skills plugins/monopam/skills/fork-package (ISC, Copyright (c) 2026 Thomas Gazagnaire), base dd1c75e, ported from monopam to unpac. Static: not in sources/overrides/overrides.lock, so upstream changes are not merged automatically.
Local changes: unpac instead of monopam (provenance is the vendored branch, the upstream queue is the patches branch, no sources.toml or UPSTREAM.md); fsx- instead of nox- naming; "you" instead of upstream's house "we".
-->

# Forking a Package in an unpac Workspace

Forking starts as plain vendoring — `unpac opam add <pkg>` (or `unpac git add
<url>`) creates the three-tier branches and records provenance in `unpac.toml`
automatically — and your changes live as commits on `opam/patches/<pkg>` made
through edit sessions (see the `unpac` skill). Most "forks" end there: a
vendored package with local patches, merged into your projects, never
published. The obligations below turn on when the fork **graduates**: exported
and pushed as a package of its own.

**You are a guest in someone else's copyright.** Preserve their license and
attribution verbatim, add yours only to what you author, never relicense their
code. A fork that hides its origin or drops the upstream credit is not
acceptable.

## 1. Name: `fsx-` only on a clash

While the fork only lives as a vendored package merged into your own projects,
keep the upstream's name — nothing else sees it. The naming question arises at
publish time: the opam package takes the `fsx-` prefix **when it would collide
with the upstream's published opam name**, which is the normal case for a fork
of a published library. If the upstream name is genuinely free, no prefix: the
bar is the clash, not the fork.

The **library module keeps the plain name**; only the opam package is
prefixed. So `dune-project` gets `(name fsx-<name>)`, generating
`fsx-<name>.opam`, and `lib/dune` gets `(public_name fsx-<name>)` with
`(name <name>)`.

Graduation paths:

```bash
# a project maturing into a library
unpac opam promote myproject --as fsx-<name>

# a heavily-patched vendored package, published standalone
unpac export <pkg> --backend opam --from-patches
unpac export-set-remote <pkg> git@tangled.org:frej.soya.network/ocaml-<name>
unpac export-push <pkg> --backend opam
```

## 2. Preserve the license

- **Keep the upstream `LICENSE.md` verbatim**, including its copyright
  holders. You may not change someone else's license.
- `dune-project` `(license <upstream SPDX>)` matches the upstream — never
  silently switched to your default.
- `(maintainers ...)` and `(authors ...)` keep the **upstream's**. Add yours
  only if you take on real maintenance.
- **Per-file headers:** a file imported verbatim keeps its original copyright
  line and SPDX identifier.

  ```ocaml
  (*---------------------------------------------------------------------------
    Copyright (c) 2014 David Kaloper and Hannes Mehnert. All rights reserved.
    SPDX-License-Identifier: BSD-3-Clause
    ---------------------------------------------------------------------------*)
  ```

  A file you write from scratch inside the fork gets your own header (ISC plus
  your copyright). Never stamp your copyright over theirs on a file you merely
  edited.

## 3. Provenance: unpac already has it

The upstream URL and pinned version live in `unpac.toml` (written by `unpac
opam add`; `unpac opam info <pkg>` shows them), and the fork point is the
`opam/upstream/<pkg>` branch itself — there is no separate provenance file to
maintain. The *why* of the fork goes where readers look: the fork warning and
attribution paragraph below.

While you still meaningfully track the original, keep pulling with `unpac opam
update <pkg>`. Once the fork has diverged into its own canonical source, simply
stop updating — the `unpac.toml` entry remains as honest history, not a
promise. For a promoted local package that later grows an upstream of its own,
wire it with `unpac opam set-upstream`.

## 4. The house fork warning

This text is load-bearing: readers must be pointed at the upstream, not at the
fork. Copy it verbatim into the published fork, substituting the upstream name
and URL.

**README**, as a blockquote directly under the title:

```markdown
# <name>

> **Warning.** This is a work-in-progress experimental fork of
> [<upstream-name>](<upstream-url>). Do not use it in production; use
> [<upstream-name>](<upstream-url>) instead.
```

**`dune-project` `(description ...)`**, prefixed with the WARNING sentence
(the `.opam` description regenerates from it):

```text
(description "WARNING: This is an experimental fork of <upstream-name>. Do not use in production. Use <upstream-name> instead: <upstream-url>. <the real one-paragraph description of what the package does>")
```

Give the README body an attribution paragraph and a License section naming the
upstream's license:

```markdown
`fsx-<name>` is a fork of [<owner>/<upstream>](<upstream-url>), whose design
is ...

## License

<upstream SPDX>. See [LICENSE.md](LICENSE.md).
```

## 5. The upstream queue is the patches branch

There is no `UPSTREAM.md` to maintain: what you have changed against upstream
*is* `unpac opam diff <pkg>`, commit by commit. Keep patches-branch commits
clean and self-contained — fork-specific ones (build tweaks, integration glue)
clearly separated from upstreamable fixes — because they are the raw material
for both future `unpac opam update` merges and any patch you send back.
Sending work upstream is a deliberate, reviewed export
(`unpac export --from-patches`), never a dump of the branch.

Half-formed notes (a security suspicion, a bug whose framing needs work) don't
belong in patches-branch commits — `unpac push` publishes those branches. Keep
them in the private, gitignored `TODO.md` until they're ready to become a
commit or an upstream issue.

## Done when

- The published opam name is `fsx-<name>` (on a clash) and the module keeps
  the plain name; a merely-vendored fork keeps the upstream name.
- `LICENSE.md`, `(license ...)`, `(maintainers/authors ...)` and per-file
  headers all preserve the upstream's terms and credit; only files you
  authored carry your copyright.
- `unpac opam info <pkg>` shows the upstream URL and pin; updates still merge
  if you claim to track the original.
- The README blockquote and the description WARNING both point readers
  upstream, and the export's remote is
  `git@tangled.org:frej.soya.network/ocaml-<name>`.
- The exported package builds and its tests pass.
