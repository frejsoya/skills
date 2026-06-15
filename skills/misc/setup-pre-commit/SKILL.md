---
name: setup-pre-commit
description: Set up a git pre-commit hook for an OCaml/dune project that runs ocamlformat, dune build, and dune test before each commit. Use when user wants to add pre-commit hooks, enforce ocamlformat, or add commit-time formatting/build/test checks.
---

# Setup Pre-Commit Hooks (OCaml)

## What This Sets Up

- A git **pre-commit hook** (plain `.git/hooks/pre-commit`, no extra runtime)
- **ocamlformat** check on staged files (fails the commit if anything is unformatted)
- **dune build** (the type-checker is the first line of defense)
- **dune test** (`dune runtest`)

## Steps

### 1. Detect the project shape

Confirm it's a dune project: look for `dune-project` at the repo root. Note the
package manager in use — **opam** (`*.opam`, `_opam/`) or **dune-project**
dependencies. If there's no `dune-project`, ask the user before proceeding.

### 2. Ensure ocamlformat is available

Check for a `.ocamlformat` file at the repo root. If missing, create a minimal one
(pin the version so CI and local agree):

```
version = 0.27.0
profile = default
```

Make sure the tool is installed: `opam install ocamlformat` (or it's in the
project's dev dependencies). Tell the user if it isn't installed.

### 3. Create `.git/hooks/pre-commit`

Write this file and make it executable (`chmod +x .git/hooks/pre-commit`):

```sh
#!/bin/sh
set -e

# 1. Format check on staged .ml/.mli files only (fast)
staged=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.mli?$' || true)
if [ -n "$staged" ]; then
  for f in $staged; do
    if ! ocamlformat --check "$f" >/dev/null 2>&1; then
      echo "✗ $f is not formatted. Run: dune fmt" >&2
      exit 1
    fi
  done
fi

# 2. Build (type-check) and 3. test
dune build
dune runtest
```

**Adapt**: If the project has no tests yet, omit the `dune runtest` line and tell
the user. If the repo is large and `dune build`/`dune runtest` are slow, mention
that the hook may take a while and offer to scope it down.

### 4. Prefer `dune fmt` for fixing

Tell the user: when the hook rejects a commit, run `dune fmt` (or
`dune build @fmt --auto-promote`) to auto-format, then re-stage and commit.

> Note: `.git/hooks/` is **not** version-controlled. If the team wants the hook
> shared, commit the script to `scripts/pre-commit` and either symlink it
> (`ln -sf ../../scripts/pre-commit .git/hooks/pre-commit`) or set
> `git config core.hooksPath scripts/hooks`. Recommend this for multi-dev repos.

### 5. Verify

- [ ] `.git/hooks/pre-commit` exists and is executable
- [ ] `.ocamlformat` exists at the repo root
- [ ] `ocamlformat`, `dune` are available on PATH (`dune --version`)
- [ ] Run `dune build && dune runtest` once manually to confirm a clean baseline

### 6. Commit

Stage the changed/created files and commit with message:
`Add pre-commit hook (ocamlformat + dune build + test)`.

This runs through the new hook — a good smoke test that everything works.

## Notes

- The hook builds before testing because in OCaml the type-checker catches most
  errors; a failing `dune build` should stop the commit immediately.
- `ocamlformat --check` only inspects formatting; it never rewrites files, so the
  hook stays read-only and predictable.
- For shared/CI parity, pin the ocamlformat `version` in `.ocamlformat`.
