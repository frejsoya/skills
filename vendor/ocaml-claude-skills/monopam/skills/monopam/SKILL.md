---
name: monopam
description: "Managing an OCaml monorepo of git subtrees with monopam: pull upstream changes in, push your changes back to each package's own remote, add or remove packages, check what is out of sync, lint deps, publish to the opam overlay, and collaborate through the verse. Use for any monopam command, sync-state question, or push failure."
---

# Monopam

Monopam manages OCaml packages in one tree. Each subdirectory is a subtree of an
external git repository: you **edit everything in `mono/`**, then `pull` to bring
upstream changes in and `push` to write your changes out.

`push` writes to *your* configured remotes; monopam never pushes to someone
else's canonical repo. There is no `sync` command; the explicit `pull` / `push`
pair matches the git mental model.

## Daily workflow

```bash
monopam status                    # what's out of sync
monopam pull                      # fetch + merge upstream into mono/
# ... edit, then build and test ...
dune build && dune test
git add <pkg>/ && git commit -m "pkg: ..."
monopam lint                      # missing/unused opam deps
monopam push                      # export to each subtree's remote
```

**Commit before pushing**: `push` only exports committed changes. Stage
explicit paths, never `git add -A`; when other sessions share the checkout, use
`git-x commit create -m MSG <pkg>/` (see the `concurrent-claude` skill).

## Commands

| Command | Purpose |
|---------|---------|
| `monopam status` | Sync state of every package |
| `monopam diff [PACKAGE]...` | Diff between monorepo and upstream (`--incoming`) |
| `monopam pull [PACKAGE]...` | Fetch and merge upstream changes into `mono/` |
| `monopam fetch [PACKAGE]` | Fetch without merging (inspect first) |
| `monopam push [PACKAGE]...` | Push committed changes to your remotes |
| `monopam add SOURCE [DIR]` | Graft in a package from a git URL or opam name |
| `monopam remove DIR` | Detach a subtree from the project |
| `monopam init` | Initialize or refresh a workspace |
| `monopam clone URL [DIR]` | Clone a teammate's workspace and bootstrap subtrees |
| `monopam lint [SUBTREE]...` | Check declared deps against META requires (`--fix`) |
| `monopam quality [PACKAGE]` | Check packages against their `x-quality` policy |
| `monopam test [DIR]...` | Run tests across the monorepo |
| `monopam clean` | Remove empty commits from history |
| `monopam publish [PACKAGE]...` | Publish to the opam overlay |
| `monopam verse COMMAND` | Collaborate with verse members |

Most commands take `--dry-run`, `--color=WHEN`, and the observability flags
(`--log=SPEC` with `MONOPAM_LOG`, `-q`, `--trace=FILE`).

`monopam lint` builds a library-to-package index from installed META files and
compares each package's META requires against its opam depends in both
directions, reporting missing and unused deps. **It requires `dune build` to
have run first.** `monopam quality` checks the policy declared in
`*.opam.template` via `x-quality: ["build" "test" ...]` and fails on any missing
feature.

### Verse (collaboration)

```bash
monopam verse status [--all]         # status of verse members
monopam verse members                # list registry members
monopam verse diff [REPO|SHA]        # what collaborators have; --patch for full diffs
monopam verse pull HANDLE [REPO]     # pull commits from a member's forks
monopam verse cherry-pick SHA        # take one commit
monopam verse fork PACKAGE           # fork a package from a member
```

To incorporate a collaborator's work: `monopam verse diff` to see what's
available, `monopam verse pull <handle>` to fetch it, then `monopam pull` to
merge into `mono/`.

## Reading `monopam status`

| Marker | Meaning | Action |
|--------|---------|--------|
| `local:=` | Monorepo and checkout in sync | - |
| `local:+N` | Monorepo has N commits the checkout lacks | `monopam push --local` |
| `local:-N` | Checkout has N commits the monorepo lacks | `monopam pull` |
| `local:sync` | Trees diverged, no automatic direction | `monopam pull` then `monopam push` |
| `remote:=` | Checkout and upstream in sync | - |
| `remote:+N` | N commits to push | `monopam push` |
| `remote:-N` | N commits to pull | `monopam pull` |

Status reports **opam package names**, not directory names. Most directories are
`ocaml-<name>` while the package is `<name>` (`ocaml-console` holds
`console.opam`), so look for the short name.

## Workspace

```
~/tangled/
├── mono/                    # YOUR monorepo (work here)
├── src/                     # YOUR fork checkouts
├── opam-repo/               # YOUR opam overlay
└── verse/
    ├── alice.bsky.social/   # Alice's monorepo
    └── bob.example.com/
```

## URLs

Get these wrong and push fails in confusing ways.

**`dune-project` source: always `(uri ...)`, never `(github ...)`.**

```lisp
(source (uri https://tangled.org/<handle>/ocaml-<name>))   ; correct
(source (github user/repo))                                ; wrong: breaks URLs
(source (uri git@git.recoil.org:handle/repo))              ; wrong: SSH form
                                                           ; URL-encodes to git%40...
```

**Git remotes** fetch over HTTPS and push over SSH to *your* namespace:

```bash
git remote add origin https://tangled.org/<handle>/ocaml-<name>.git
git remote set-url --push origin git@git.recoil.org:<handle>/ocaml-<name>
```

**Opam `dev-repo`:** `git+https://tangled.org/<handle>/ocaml-<name>.git`

## Adding a new package

Create it in `src/` following the `init-ocaml` skill (with the `(uri ...)`
source), create the remote, wire the push URL, add an opam overlay entry under
`opam-repo/packages/<name>/<name>.dev/`, then graft it in:

```bash
tangled repo create --knot git.recoil.org --description "..." ocaml-<name>
cd mono/ && monopam add <git-url>
```

To work on a package owned by a verse member, `monopam verse fork <pkg>` first,
then edit in `mono/` and `monopam push` to your fork.

## Troubleshooting

**`local:sync`**, the subtree and checkout diverged and monopam can't pick a
direction. `monopam pull`, then `monopam push`.

**Merge conflicts after `pull`**: resolve in `mono/`, stage the resolved files
by name (not `-A`), commit, then `monopam push` only if you want to publish the
resolution.

**Push rejected, non-fast-forward**: someone got there first. `monopam pull`,
rebuild, test, retry. If the upstream history diverged intentionally (after a
`git filter-repo`), `monopam push --force` overrides.

**"Repository not found" on push**: check the repo exists on tangled, then
check the push URL: `git -C ../src/<pkg> remote get-url --push origin` should be
`git@git.recoil.org:<handle>/<pkg>`.

**"access denied: user not allowed"**, the push URL points at someone else's
namespace. `git -C ../src/<pkg> remote set-url --push origin
git@git.recoil.org:<your-handle>/<pkg>`.

**A checkout is missing**: `src/<repo>` hasn't been cloned. `monopam pull`
clones missing checkouts as part of its normal flow.

**"Dirty packages" / "working tree has modifications"**: commit first;
`monopam status` shows what is outstanding.

**Stale opam-repo entries**: after a rename or removal, an old overlay
directory keeps reporting sync issues. Check `ls ../opam-repo/packages/` and
remove the dead entry.

**Empty cherry-pick from verse**; the changes are already incorporated;
`cd ../src/<pkg> && git cherry-pick --skip`.
