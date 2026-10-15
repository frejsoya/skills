---
name: merlint
description: Runs the merlint linter as the final code review gate on any OCaml change. Use when finishing an OCaml task, before declaring OCaml work done, when asked to lint or review OCaml or run merlint, or when fixing a merlint E-code.
---

# Merlint

`merlint` is an opinionated whole-project OCaml linter (Merlin + typedtree + dune).
It exists because agents write plausible-but-sloppy OCaml at speed.

**Rule: an OCaml task is not done until `merlint scan` is clean.** Run it as the
last step of every change, the same way you run `dune runtest`. If `merlint` is
not installed, say so and suggest `opam pin add merlint
https://github.com/samoht/merlint.git` (not yet on opam) — don't block the task
on it.

## The loop

Run from the directory containing `dune-project` — from a subdirectory merlint
misdetects the root and silently analyzes **zero files** (false green).

```sh
dune build @check   # refresh .cmt/.cmti first — see below
merlint scan        # exit 0 clean, exit 1 issues
merlint help E105   # rationale + good/bad examples for a reported code
```

Fix, re-run, repeat until clean. On a codebase with pre-existing issues outside
your change, get the paths you touched clean (`merlint scan lib/foo/`) and report
the rest — don't repo-sweep uninvited.

## Two things that will bite you

**Stale build artefacts.** Typedtree-backed rules need fresh `.cmt`/`.cmti`. If
they're missing, merlint prints a `stale .cmt/.cmti` warning and **silently skips
those rules** — a green run that only checked half the rules. Always
`dune build @check` first (or `merlint scan --build`).

**Never silence instead of fixing.** The rules encode a real style guide; a hit is
usually a design smell, not a linter quirk. Suppression attributes like
`[@warning "-..."]` are themselves caught by E110; dune `-w` flags dodge that rule
but are just as wrong. Raising a threshold or adding an exclusion in
`merlint.toml` is a project-level decision — propose it to the user with a
reason, don't do it to make your own diff pass.

## Narrowing a large report

```sh
merlint scan lib/ bin/             # scope to paths
merlint scan --bail                # first issue only, tight edit loop
merlint scan --rules E405          # one code
merlint scan --rules all-E110-E205 # all except these
merlint scan --json                # {code,title,category,message,location} per issue
merlint help config                # merlint.toml format reference
merlint help                       # list every rule code
```

Work structural → documentation → naming → complexity: adding an `.mli` (E505)
changes what's public, which changes the E4xx/E3xx findings.

## Fit with other tools

`ocamlformat` checks formatting, merlint checks rules — no overlap. CI gate:
`dune build @check && dune runtest && merlint scan`.
