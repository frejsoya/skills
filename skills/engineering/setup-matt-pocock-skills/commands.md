# Project commands

How the engineering skills build, test, and format this repo. Skills (`tdd`,
`diagnose`, `prototype`, `triage`) read this file instead of assuming `dune`
directly — keep it accurate and they stay accurate.

This is the seed template. Replace the commands with whatever this repo actually
uses (a `Makefile`/`justfile` wrapper, package-scoped dune targets, etc.).

## Commands

| Purpose | Command | Notes |
|---|---|---|
| **build** | `dune build` | Fast type-check pass: `dune build @check`. |
| **test** | `dune runtest` | Scope when slow: `dune runtest test/foo`. |
| **format** | `dune fmt` | Check-only (CI/pre-commit): `dune build @fmt`. |
| **promote** | `dune promote` | Accepts expect/cram output — **ask the user before running**; it rewrites checked-in expectations. |
| **repl** | `dune utop lib` | Interactive exploration of a library. |
| **run** | `dune exec ./bin/main.exe --` | Run an executable with args after `--`. |

## Conventions

- The **type-checker is the first signal.** A failing `dune build` should stop
  work before tests are even considered.
- Prefer the check-only format command in hooks/CI (`dune build @fmt`); use
  `dune fmt` to actually rewrite.
- `dune promote` and any other command that **edits checked-in files** is
  ask-first, never automatic.
- If a `Makefile`/`justfile` wraps these (e.g. `make test`), record the wrapper
  here as the canonical command and keep the underlying dune command in the Notes
  column.
