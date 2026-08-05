---
name: fork-package
description: "Importing a third-party OCaml package into the monorepo as a fork: nox- naming on a name clash, preserved upstream license and per-file copyright, provenance in sources.toml, the house fork warning, and a seeded UPSTREAM.md. Use when vendoring or forking an external library. For a greenfield package, use init-ocaml instead."
---

# Forking a Package Into the Monorepo

Importing an existing package is `init-ocaml` plus the fork obligations: keep
the upstream's license and credit, mark the package as an experimental fork, and
wire the queue that sends improvements back.

**You are a guest in someone else's copyright.** Preserve their license and
attribution verbatim, add ours only to what we author, never relicense their
code. A fork that hides its origin or drops the upstream credit is not
acceptable here.

## 1. Name: `nox-` only on a clash

The opam package takes the `nox-` prefix **when it would collide with the
upstream's published opam name**, which is the normal case for a fork of a
published library: `nox-x509` (from `mirleft/ocaml-x509`, opam `x509`),
`nox-git` (from `mirage/ocaml-git`, opam `git`), `nox-pkcs11` (the `pkcs11` name
is taken by Cryptosense). If the upstream name is genuinely free, no prefix:
the bar is the clash, not the fork.

The **library module keeps the plain name** (`X509`, `Git`, `Pkcs11`); only the
opam package is prefixed. So `dune-project` gets `(name nox-<name>)`, generating
`nox-<name>.opam`, and `lib/dune` gets `(public_name nox-<name>)` with
`(name <name>)`.

## 2. Preserve the license

- **Keep the upstream `LICENSE.md` verbatim**, including its copyright holders.
  You may not change someone else's license.
- `dune-project` `(license <upstream SPDX>)` matches the upstream, not the
  monorepo default. `nox-x509` is `BSD-2-Clause` because ocaml-x509 is; it is
  not silently changed to ISC.
- `(maintainers ...)` and `(authors ...)` keep the **upstream's**. Add ours only
  if we take on real maintenance.
- **Per-file headers:** a file imported verbatim keeps its original copyright
  line and SPDX identifier.

  ```ocaml
  (*---------------------------------------------------------------------------
    Copyright (c) 2014 David Kaloper and Hannes Mehnert. All rights reserved.
    SPDX-License-Identifier: BSD-3-Clause
    ---------------------------------------------------------------------------*)
  ```

  A file we write from scratch inside the fork gets our own header (ISC plus our
  copyright). Never stamp our copyright over theirs on a file we merely edited.

## 3. Provenance: register the upstream in `sources.toml`

The link back to the upstream lives in the monorepo's root `sources.toml`, not
in the package's `dune-project`. The package's own `(source ...)` is just its
tangled repo, as `init-ocaml` sets it.

Add one line, keyed by the **directory name** (`ocaml-x509`, `ocaml-git`): the
name the fork's own repo carries, not `nox-<name>`:

```toml
<dir-name>={source="git+https://tangled.org/gazagnaire.org/<dir-name>",upstream="git+https://github.com/<owner>/<repo>",reason="<why forked>"}
```

`upstream` is the original's git URL, and may be a list when the fork merges
more than one (`ocaml-tcp` merges utcp and mirage-tcpip). `reason` is short and
honest: `"Maintenance fork"`, `"Fork"`, or a sentence when the divergence needs
one.

**`upstream` is optional, and dropping it is a normal outcome.** Record it while
you still track the original: pulling its changes, mirroring its fixes. Many
nox-* packages have diverged enough to be their own canonical source and simply
have no `upstream` (a `source` and a `reason`, no more). That is fine, not an
edge case: once the fork is what people depend on and the original is no longer
a live mirror, an `upstream` line is a stale promise. Judge by whether you still
meaningfully pull from the original.

`monopam` reads `sources.toml` to know each package's canonical source and,
where `upstream` is set, to pull its changes in.

## 4. The house fork warning

This text is load-bearing: readers must be pointed at the upstream, not at the
fork. Copy it verbatim, substituting the upstream name and URL.

**README**, as a blockquote directly under the title:

```markdown
# <name>

> **Warning.** This is a work-in-progress experimental fork of
> [<upstream-name>](<upstream-url>). Do not use it in production; use
> [<upstream-name>](<upstream-url>) instead.
```

**`dune-project` `(description ...)`**, prefixed with the WARNING sentence (the
`.opam` description regenerates from it):

```
(description "WARNING: This is an experimental fork of <upstream-name>. Do not use in production. Use <upstream-name> instead: <upstream-url>. <the real one-paragraph description of what the package does>")
```

Give the README body an attribution paragraph and a License section naming the
upstream's license:

```markdown
`nox-<name>` is a fork of [<owner>/<upstream>](<upstream-url>), whose design
is ...

## License

<upstream SPDX>. See [LICENSE.md](LICENSE.md).
```

## 5. Seed `UPSTREAM.md`, and never commit it

Create the package's `UPSTREAM.md` with a one-line note recording the fork
point: the upstream repo, the commit or version imported from, and the date.
From then on the doctrine rule "Changed A Fork? Record It For Upstream" keeps it
filled, so every non-fork-specific change flows back. Wiring it at import time
is what gives that reflex somewhere to write.

**`UPSTREAM.md` is a private local file: gitignored, never committed, never
`git add -f`'d**, exactly like `TODO.md`. This is not just hygiene: its entries
are a raw queue, and some describe changes (a half-formed security note, a bug
whose framing still needs work) that must be cleaned up and reviewed before
being exposed to the world as a public issue or PR. Committing the file would
publish that unreviewed queue. Entries leave it only through a deliberate,
reviewed patch to the host: see the `upstream` skill.

## 6. The rest is `init-ocaml`

`.ocamlformat`, `.gitignore`, the `dune-project` skeleton, `tags (org:blacksun
...)`, tests, fuzz, README structure, opam metadata: all standard. Follow
`init-ocaml` and `ocaml-project-setup`; this skill only adds the fork
obligations on top.

## Done when

- The opam name is `nox-<name>` (on a clash) and the module keeps the plain name.
- `LICENSE.md`, `(license ...)`, `(maintainers/authors ...)` and per-file headers
  all preserve the upstream's terms and credit; only files we authored carry our
  copyright.
- `sources.toml` has an entry keyed by the directory name with a `reason`, and an
  `upstream` URL if you still track the original; the package's own `(source
  ...)` is its tangled repo.
- The README blockquote and the description WARNING both point readers upstream.
- `UPSTREAM.md` exists with the fork-point entry, and is gitignored.
- The package builds and its tests pass.
