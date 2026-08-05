---
name: init-ocaml
description: "Create a new OCaml package with the house layout: dune-project metadata, lib/test/fuzz structure, standard dotfiles, and pre-commit hooks. Use when starting a library from scratch or extracting code into a standalone package. For importing an existing third-party library, use fork-package instead."
---

# Initialising an OCaml Package

## Before you start: search first

The monorepo has 150+ packages, and authors pick idiosyncratic names (`jsonwt`
for JWT, `requests` for an HTTP client). A new package costs a remote repo, CI,
release plumbing, and an opam namespace, so confirm nothing fits before adding
one:

1. Grep `llms.txt` for the concept name and its synonyms and abbreviations, then
   `ls` the top-level directories, then grep module and type names across
   `**/*.mli`. Grep RFC numbers where applicable.
2. Search [opam](https://opam.ocaml.org/packages/) and GitHub for existing OCaml
   implementations, and other ecosystems (Go, Rust, Python) for reference
   implementations worth citing.
3. Prefer extending a nearby package. A shared RFC or spec needed by two or more
   packages is good justification for a new one; a single consumer is not.
4. Record what you found in the README's "Related Work" section and say how this
   differs. If you did create a new package, say in the commit message what you
   looked at and why none fit.

## Layout

```
ocaml-<name>/
  .gitignore
  .ocamlformat
  LICENSE.md
  README.md
  dune-project
  <name>.opam          # generated, committed
  lib/
    dune
    <name>.ml
    <name>.mli
  test/
    dune
    test.ml            # runner
    test_<name>.ml(i)
  fuzz/
    dune
    fuzz.ml            # runner
    fuzz_<name>.ml(i)
```

The directory is `ocaml-<name>`; the opam package and library are `<name>`.

## `dune-project`

```lisp
(lang dune 3.21)

(using mdx 0.4)

(name <name>)

(implicit_transitive_deps false)

(generate_opam_files true)

(source
 (uri https://tangled.org/<handle>/ocaml-<name>))

(license ISC)
(authors "Thomas Gazagnaire")
(maintainers "Thomas Gazagnaire <thomas@gazagnaire.org>")

(package
 (name <name>)
 (synopsis "One line, no trailing period, no marketing")
 (description "A paragraph on what the library does.")
 (tags (org:blacksun <topic>))
 (depends
  (ocaml (>= 4.14))
  (observe :with-dev-setup)
  (alcotest :with-test)
  (alcobar :with-test)
  (mdx :with-test)))
```

Use `(uri ...)`, never `(github ...)`: the github form produces broken URLs
here. `(implicit_transitive_deps false)` is house standard: every module you
reference must be a declared dependency.

## `lib/dune`

```lisp
(library
 (name <name>)
 (public_name <name>)
 (libraries <deps>))

(mdx
 (files <name>.mli)
 (libraries <name>))
```

The `(mdx ...)` stanza must live in the *same* dune file as the `.mli` it
covers; it is not recursive. See the `mdx` skill.

Write the `.mli` first, as the API you want odoc readers to see:

```ocaml
(** One-line module synopsis. *)

(** {1 Section} *)

val function_name : param:type -> type
(** [function_name ~param] does X. *)
```

## `test/`

```lisp
(test
 (name test)
 (libraries <name> alcotest))
```

```ocaml
(* test/test.ml *)
let () = Alcotest.run "<name>" Test_<name>.suite
```

```ocaml
(* test/test_<name>.ml -- vectors quoted from the RFC or spec *)
let test_case1 () =
  Alcotest.(check string) "description" expected actual

let suite = [
  "Category", [
    Alcotest.test_case "case 1" `Quick test_case1;
  ];
]
```

Tests encode the spec, not the code: cite the section number and copy the
spec's vectors verbatim. Use exact expected values, never loose ranges. See the
`ocaml-testing` skill for the discipline and the `cram` skill for CLI
transcripts.

## `fuzz/`

`fuzz/` is a sibling of `test/`. The full layout, the merlint rules it must
satisfy, and the AFL wiring are in the `fuzz` skill; the minimum is:

```lisp
(executable
 (name fuzz)
 (libraries <name> alcobar))

(rule
 (alias runtest)
 (enabled_if (<> %{profile} afl))
 (deps fuzz.exe)
 (action (run %{exe:fuzz.exe})))

(rule
 (alias fuzz)
 (enabled_if (= %{profile} afl))
 (deps fuzz.exe)
 (action
  (progn
   (run %{exe:fuzz.exe} --gen-corpus corpus)
   (run afl-fuzz -V 60 -i corpus -o _fuzz -- %{exe:fuzz.exe} @@))))
```

```ocaml
(* fuzz/fuzz.ml *)
let () = Alcobar.run "<name>" [ Fuzz_<name>.suite ]
```

## Dotfiles

`.ocamlformat` pins the version the whole repo formats with:

```
version = 0.29.0
```

`.gitignore` covers build artifacts (`_build/`, `*.install`, `dune.lock/`), the
local switch (`_opam/`), editor and OS noise (`.DS_Store`, `*.swp`, `.vscode/`,
`.idea/`), and the private local files that are never committed: `TODO.md` and
`UPSTREAM.md`.

`LICENSE.md` is ISC for new work. A package forked from upstream keeps the
upstream's license verbatim: see the `fork-package` skill.

## Dependencies

Reach for the in-repo package, not the upstream it forked from:

| Need | Use |
|------|-----|
| Hashes (MD5, SHA-1, SHA-2), HMAC | `hash` |
| AES, EC, PQ, RNG | `nox-crypto`, `nox-crypto-ec`, `nox-crypto-pq`, `nox-crypto-rng` |
| JSON | `nox-json` |
| Pretty-printing | `fmt` |
| CLI | `cmdliner` |
| CLI logging and tracing setup | `observe` (see the `ocaml-observe` skill) |
| Terminal styling, tables, progress | `console` (see the `console` skill) |
| Concurrency and IO | `eio` |
| Byte streams | `bytesrw` |
| Unit tests / fuzz tests | `alcotest` / `alcobar` |

## Pre-commit hooks

```sh
precommit init          # both hooks; -n to preview
precommit status        # check what is installed; -r . for a whole directory
```

This installs a pre-commit hook running `dune fmt` on staged OCaml files, a
commit-msg hook that rejects emoji and strips `Co-Authored-By: Claude` lines,
and an `.ocamlformat` if one is missing. `precommit init --hooks fmt` or
`--hooks ai` installs only one; `precommit check -r .` finds AI attribution
already in history.

## Publishing

For a standalone repo outside the monorepo:

```sh
opam switch create . --empty     # dune pkg manages deps
eval $(opam env)
dune pkg lock && dune build && dune test
```

Then create the remote and wire the push URL to your own namespace:

```sh
tangled repo create --knot git.recoil.org --description "..." ocaml-<name>
git remote add origin https://tangled.org/<handle>/ocaml-<name>.git
git remote set-url --push origin git@git.recoil.org:<handle>/ocaml-<name>
git push -u origin main
```

To bring it into the monorepo, `monopam add <git-url>` grafts it in as a
subtree. See the `monopam` skill.

## Done when

- `dune build`, `dune test`, and `dune fmt` are clean, and `dune exec -- merlint
  <dir>` passes.
- `lib/<name>.mli` is a curated public API with odoc comments, mdx-checked.
- `test/` has spec-cited vectors; `fuzz/` has a non-empty suite.
- `dune-project` carries synopsis, description, tags, license, and `(uri ...)`
  source; the generated `.opam` is committed.
- README documents related work and credits what this builds on.
