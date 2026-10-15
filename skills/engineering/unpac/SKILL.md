---
name: unpac
description: Managing vendored dependencies as git branches with unpac — vendor opam packages or git repos with full history, patch them in edit sessions, merge them into project worktrees, update from upstream, promote projects to shared libraries, export standalone repos, and push. Use for any unpac command, workspace-state question, or merge/update/edit failure.
---

# Unpac

Unpac maintains third-party dependencies as **git branches with full history**
in one bare repo, fanned out into worktrees. Each vendored package gets three
tiers — `opam/upstream/<pkg>` (tracks the original repo), `opam/vendor/<pkg>`
(clean snapshot, the merge base), `opam/patches/<pkg>` (your modifications) —
so upstream updates and local patches merge without conflict. The `git`
backend mirrors this as `git/{upstream,vendor,patches}/<name>`.

You never edit vendored code in place: **open an edit session** (`unpac opam
edit`, which checks the patches branch out into a worktree), commit there,
close it (`done`), then **merge into the project** where you build.

## Workspace

```text
mono/
├── git/                     # the bare repository (all branches live here)
├── main/                    # main worktree: unpac.toml (repos, compiler, vendored list)
├── project/<name>/          # one worktree per project, on branch project/<name>
└── opam/
    ├── patches/<pkg>/       # open edit session (worktree; exists only while editing)
    ├── vendor/<pkg>/        # read-only reference worktree for the same session
    └── upstream/<pkg>/      # upstream reference worktree, created when needed
```

## Daily workflow

```bash
unpac status --no-readme         # workspace overview (without --no-readme it
                                 #   regenerates AND COMMITS the README on main)
unpac opam add mylib --solve     # vendor a package + its dependency closure
unpac opam merge mylib myapp     # merge its patches branch into project/myapp
cd project/myapp && dune build   # build in the project worktree
```

Patching a vendored package:

```bash
unpac opam edit mypkg            # opens opam/patches/mypkg (+ vendor reference)
cd opam/patches/mypkg            # edit files...
git add -A && git commit -m 'my fix'
unpac opam done mypkg            # close the session (removes both worktrees)
unpac opam diff mypkg            # vendor → patches delta
unpac opam merge mypkg myapp     # land it in the project
```

Updating from upstream:

```bash
unpac opam outdated              # pins behind the newest release tag
unpac opam update mypkg          # merge upstream into vendor and patches tiers
unpac opam merge mypkg myapp     # re-merge into each project that uses it
```

## Commands

| Command | Purpose |
|---------|---------|
| `unpac status [--short] [--no-readme]` | Workspace overview: projects, packages, patch counts, pins, merge state |
| `unpac log [-n N] [--json]` | Audit log of unpac operations (timestamped, incl. nested git commands) |
| `unpac opam add PKG [--solve]` | Vendor from an opam repo or git URL (`--solve`: with dependencies) |
| `unpac opam init NAME` | Create a new *local* package (no upstream; `url='local'`) |
| `unpac opam edit / done PKG` | Open / close a patches edit session |
| `unpac opam diff PKG` | Diff vendor → patches |
| `unpac opam merge PKG PROJECT [--solve\|--all]` | Merge patches branch(es) into a project |
| `unpac opam update PKG [--latest]` | Pull upstream changes through the three tiers |
| `unpac opam outdated / list / info` | Pin freshness / inventory / one package's detail |
| `unpac opam promote PROJECT --as NAME` | Graduate a project into a vendored dependency |
| `unpac opam repo add / config compiler` | Opam repositories and solver compiler version |
| `unpac git add URL [--subdir DIR]` | Vendor an arbitrary git repo (needs `git-filter-repo` on PATH) |
| `unpac project new / list / info` | Create and inspect project worktrees |
| `unpac project set-remote / push` | Publish one project to its own repository |
| `unpac export NAME --from-patches` + `export-push` | Standalone repo with files at root, for publishing a library |
| `unpac monorepo OUTPUT` | Export a self-contained buildable monorepo |
| `unpac push REMOTE [--dry-run] [--force]` | Push **all** unpac branches to a remote |

## Reading `unpac status`

- **Projects** list their worktree, dirty state, and how many opam/git
  packages are merged in.
- **Packages** show `Patches` (commit count on top of vendor — `0` means
  unmodified), `Pin` (the vendored tag; `-` for local or untagged), `Repo`
  (which opam repository it came from), and `Merged into` (which projects
  carry it; `-` means vendored but unused).
- `unpac opam outdated` is the freshness check: pin behind the newest
  release tag.

By default `unpac status` regenerates the workspace README **and commits it to
main**; agents and scripts should pass `--no-readme`.

## Project lifecycle

Projects are branches (`project/<name>`) checked out as worktrees where you
merge dependencies and build. Multiple projects share the vendored packages;
each merges the patches branches independently. When a project matures into a
reusable library: `unpac opam promote myproject --as mylib` (or `unpac project
promote mylib --backend opam`), then merge `mylib` into other projects like
any vendored package. To publish it standalone: `unpac export mylib --backend
opam --from-patches`, `export-set-remote`, `export-push`, and `unpac opam
set-upstream mylib <url>` so future `unpac opam update` can pull changes back.

## Reviewing history

On a project branch, `git log --first-parent` shows project-local commits
without the vendored packages' imported history — but the `Merge
opam/patches/<pkg>` commits themselves still appear (first-parent suppresses
the second parent's history, not the merge commit). What a merge brought in:
`git diff <merge>^1 <merge>`. What you changed in a package: `unpac opam diff`.
What unpac itself did and when: `unpac log`.

## Troubleshooting

**`edit` fails: branch already checked out** — an edit session is already
open (an `opam/patches/<pkg>/` worktree exists). If it's yours, go work there;
if you didn't open it, someone else did — don't `unpac opam done` or
`git worktree remove` it out from under them.

**Unexpected commit on main titled "README"** — that's `unpac status` without
`--no-readme`; it's benign, not another agent.

**Merge conflicts on `opam merge`** — resolve in the project worktree, stage
the resolved files, and commit the merge there; the vendored tiers are
untouched. Never resolve by rewriting `opam/{upstream,vendor,patches}/*`
branches by hand — they are unpac's merge bases, and a manual rewrite breaks
every future `update` and `merge`. unpac leaves
`backup/<pkg>-{upstream,vendor,patches}` branches before destructive updates;
they are the recovery path, don't delete them.

**Package changes don't show up in the project** — merging is explicit:
`unpac opam done` only closes the session; run `unpac opam merge <pkg>
<project>` for each project that should see the new patches.

**`unpac git add` fails on filter-repo** — the git backend requires
`git-filter-repo` installed and on PATH.

**`update` on a promoted local package fails** — local packages have no
upstream (`URL: local` in `unpac opam info`); set one first with
`unpac opam set-upstream <pkg> <url>`.

**Before `unpac push`** — it touches every unpac branch on the remote; run
`--dry-run` first, and reserve `--force` for intentionally rewritten history.
