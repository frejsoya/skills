---
name: concurrent-claude
description: "Working safely when several Claude instances, other agents, or humans edit this monorepo at once. Use to detect that another agent is active, pick an isolation strategy (worktree, branch, subdirectory), commit without sweeping up a neighbour's staged files, or recover after concurrent edits have already happened."
---

# Concurrent Agents in One Checkout

The monorepo has 150+ packages behind a shared git tree, build cache, opam
switch, and `.claude/` config. Two instances running against it race on every
one of those.

**Default to one `git worktree` per agent.** Everything else below is either
weaker or a recovery procedure for when worktrees weren't used.

The most insidious failure is a silent overwrite: Claude reads a file, edits a
line, writes it back, and another instance's change in between is gone with no
error and no conflict. The harness tracks modification times to refuse stale
edits *within one session*, but it does not see edits from a different instance.

## Detect: am I alone?

Run this on entry to any nontrivial editing session, and again before pushing or
starting a long operation.

```sh
git status --short                       # someone else's WIP?

ls -la .git/{MERGE_HEAD,REBASE_HEAD,CHERRY_PICK_HEAD,BISECT_LOG} 2>/dev/null
                                         # another rebase/merge in flight?
ls -la _build/.lock 2>/dev/null          # dune build lock held?
pgrep -af 'claude.*code|claude-code' | grep -v $$   # best-effort, misses SSH
```

Signals another agent is live: uncommitted changes you didn't introduce; file
mtimes from the last few minutes you don't recognise; a `backup/...-<timestamp>`
branch you didn't create; a WIP commit authored seconds ago.

If any hold, **stop and tell the user** before proceeding. Do not silently
overwrite, reset, or stash.

## Isolation strategies

**1. A worktree per agent (the default).** A separate working directory on the
same `.git`, with its own branch, index, and `_build/`. Two worktrees cannot
race on file edits, dune builds, or HEAD.

```sh
git worktree add ../mono-feature-a -b feature-a
cd ../mono-feature-a && claude
git worktree remove ../mono-feature-a     # when done
```

Isolated: working tree, index/HEAD, `_build/`, file watchers and language
servers. Still shared: `.git/objects` (safe, additive and content-addressed),
`.git/refs/` (mostly safe, git serialises ref updates), remote branches, the
opam switch, and `.claude/settings.json` if symlinked. The Claude Code
`EnterWorktree` tool and the `isolation: "worktree"` agent parameter automate
this for subagents.

**2. Disjoint subdirectories, same checkout.** Two tasks touching genuinely
unrelated packages can share a checkout concurrently, provided neither touches
`dune-project`, `root.opam.template`, `sources.toml`, `llms.txt`, top-level
`CLAUDE.md`, or `.claude/`; neither runs `dune build` at the *root*; neither
runs `monopam pull` / `push`; and both commit with `git-x commit create -m MSG
<pkg>/`. Lightest weight, most fragile: a single overlap silently loses one
side. Reserve it for clearly disjoint work, with the user's buy-in.

**3. A branch per agent, one at a time.** When you must share a working tree.
Commit before switching (`git switch` with uncommitted work loses it), accept
that `_build/` churns on every flip, and understand this is *serial*, not
parallel: two instances must not run at once in this setup.

**4. Time-multiplex.** The safest of all. If the work doesn't need to be
parallel, don't make it parallel. Two sequential sessions finish in the same
wall time when the user is the review bottleneck anyway.

Choosing between them: work that doesn't need true concurrency takes strategy 4;
disjoint packages with no shared root files can take strategy 2; anything
overlapping or touching root files takes strategy 1, always; a hard constraint
of one machine and one editor takes strategy 3.

## Commit coordination

`.git/index` is one shared file: whatever any agent staged is what `git commit`
records, so two interleaved `git add` / `git commit` sequences either sweep each
other's files into the wrong commit or collide on `index.lock`.

`git-x commit create` exists for exactly this:

```sh
git-x commit create -m "fix parser" lib/parser.ml lib/parser.mli
git-x commit create -m "port to eio" ocaml-foo/     # directory scope
git-x commit create -n ocaml-foo/                   # dry run: list, don't commit
git-x commit create --hook-dir ocaml-foo -m "port to eio" ocaml-foo/
```

It commits the working-tree state of exactly the named paths (adds, edits, and
deletions), building the commit on the object database as an overlay over the
branch tip's tree. A directory commits everything under it; a path missing from
the working tree commits as a deletion; and a **source address**
(`file.ml:Module.value`) commits only that one definition. Other agents' staged
files are not swept in and stay staged for them. The branch ref advances by compare-and-swap under git's ref lock and
rebuilds on a concurrently moved tip, so parallel commits serialise instead of
losing one. Afterwards the index is refreshed for exactly the committed paths,
so `git status` shows them clean without touching anything another agent staged.

Three caveats:

- **Prefer the explicit `create` subcommand.** Bare `git-x commit <paths>`
  defaults to `create`, but cmdliner group routing reads a leading word matching
  a subcommand name (`drop`, `sort`, `squash`, `split`, `reword`, `create`) as
  that subcommand, so a path literally named `drop` is only safe under
  `git-x commit create`.
- **The index refresh is best-effort.** The commit has already landed via the
  object DB and ref CAS, so if `.git/index` is momentarily locked the refresh is
  skipped. That is cosmetic staleness, never a lost commit; `git-x status`
  compares the working tree against HEAD and is unaffected.
- **Hooks still run.** `git-x commit create` runs `pre-commit` and `commit-msg`.
  When the pre-commit hook is a whole-tree formatter or linter, a neighbour's
  in-flight unformatted file *elsewhere* can make it reject your otherwise-clean
  commit. Scope it with `--hook-dir <dir>` (or `GIT_X_HOOK_DIR`): the hook still
  runs at the work-tree root, but `<dir>` reaches it as its first argument and
  as `$GIT_X_HOOK_DIR`, so a hook that honours it can confine its formatter or
  linter to that subtree (`merlint "$GIT_X_HOOK_DIR"`, `dune build
  @"$GIT_X_HOOK_DIR"/fmt`). That is the right fix, never `--no-verify`. The
  commit-msg hook is unaffected: it operates on the message, not a subtree.

Without `git-x`: run `git diff --cached --name-only` first to see what others
staged, then commit with an explicit pathspec (`git commit -m MSG -- <paths>`).
This still races on `index.lock` (retry), but at least scopes the commit.

## Push, build, and settings coordination

**Push is the riskiest concurrent operation.** Never force-push a branch another
agent might be on, even `--force-with-lease` can lose work when you are not the
only writer. Before pushing, `git fetch && git log @{u}..HEAD` to see if you are
ahead and `git log HEAD..@{u}` to see if the remote moved past you. `monopam
push` touches every subtree's remote, so only one agent runs it at a time across
all worktrees; coordinate through the user.

**Build:** `dune build` at the root locks `_build/` for the whole tree. Build
inside the package you own (`dune build ocaml-foo/`) or use separate worktrees.
`opam install` mutates the shared switch; two agents needing different versions
need different switches.

**`.claude/settings.json`** is shared across every instance on this checkout.
Change it from one instance and let the others pick it up; for per-agent
overrides, use a separate worktree.

## History rewrites

`git rebase -i`, `git rebase`, `git reset --hard`, and `git checkout` of an old
commit all move HEAD and rewrite the working tree, clobbering another agent's
in-progress edits. When another agent is active, use the `git-rewrite` skill's
no-checkout workflows instead: they operate purely on the object database
(`git replay`, `git commit-tree` + `update-ref`, `git merge-tree --write-tree`,
or the ocaml-git `Repository` API) and swing the branch ref atomically at the
end.

For rewrites that genuinely need a working tree (per-hunk staging, `--exec` runs
across a series, the soft-reset-and-rebuild technique), use a dedicated worktree
so the main checkout stays untouched. The ref update propagates back
automatically.

## Recovery: another agent already touched my files

`git status` shows changes you didn't make, or the harness reports a file you
read was modified externally. **Do not** `git checkout` / `git restore` /
`git reset --hard` to clean up; that discards their work.

1. `git status` and `git diff`: see exactly what changed. Pause your edits.
2. `git log -p --since='10 minutes ago' --all`: was a commit made, by whom
   (`%an`), with what message?
3. `git reflog`: what HEAD movements happened?
4. **Tell the user** what you found and ask whether the other changes should be
   kept, merged, or whether you should step aside.
5. **Do not act until they decide.**

If the edits are in *different* files, the safe path is usually to commit theirs
separately (`git-x commit create -m "wip: capture work from concurrent session"
<their files>`, which leaves anything else they staged alone) and continue with
yours; the user sorts the WIP commit out later. If they are in the *same* file,
merge by hand: read both diffs and decide which lines belong. Don't trust either
version blindly.

## Hot files in this monorepo

`monopam push` / `pull` (operate on every subtree), `root.opam.template` and
`sources.toml` (every agent adding a package conflicts here), `llms.txt`
(touched by every browse-before-coding task), `CLAUDE.md` / `CLAUDE.local.md`,
root `_build/`, the opam switch, and `.claude/settings.json`. Keep changes to
these minimal, commit promptly, and serialise them through the user.

## Rules of thumb

- One instance per worktree. It costs one command and buys complete isolation.
- If something feels like it might race, it will.
- Detect before editing; `git status` is cheap.
- Never use destructive cleanup (`stash`, `checkout`, `reset --hard`) to resolve
  unfamiliar uncommitted state. Investigate, then ask.
- State your scope out loud: "I'm working on `ocaml-foo`, branch `feature-foo`."
  Agents don't talk to each other; the user is the bus.
