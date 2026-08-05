---
name: git-rewrite
description: "Rewriting git history without a TTY and without touching the working tree, so concurrent agents in the same checkout are unaffected. Use to squash, reorder, drop, reword or split commits, tidy a messy branch into a reviewable series, drop path globs from history, or verify a rewrite. Leads with git-x subcommands and git replay / commit-tree plumbing; working-tree workflows only inside a dedicated worktree."
---

# Rewriting Git History (Concurrency-Safe)

Classic rewrite tools are unusable here for two reasons: `git rebase -i` and
`git add -p` need an interactive editor, and `git rebase` / `reset --hard` /
`checkout` rewrite the working tree, clobbering any other agent editing this
checkout.

The fix is to rewrite at the *object database* level and swing the branch ref
atomically at the end. The only `.git/` mutations are content-addressed object
writes (additive, always safe) and one atomic ref update. `HEAD`, the index, and
the files stay exactly as another agent left them.

## Three foundations, in priority order

1. **Rewrite a branch you are not checked out on.** `git update-ref
   refs/heads/other-branch ...` only swings a ref; this working tree is
   untouched.
2. **Use plumbing that operates on objects, not the index or working tree.**
   `git commit-tree`, `update-ref`, `merge-tree --write-tree`, `replay`.
3. **If you must use porcelain that touches files, do it in a dedicated
   worktree** and remove it when done.

## Tools

| Tool | Working tree? | TTY? | For |
|------|---------------|------|-----|
| `git-x tree drop -p GLOB` | No | No | Drop path globs from history (W1) |
| `git-x commit reword <SHA> -m MSG` | No | No | Change a message in place |
| `git-x commit drop <SHA>` | No | No | Remove a commit, re-parent descendants |
| `git-x commit split <SHA>` | No | No | Split a bundled commit by top-level dir |
| `git-x commit squash <SHA>...` | No | No | Collapse commits into one |
| `git-x commit sort BASE --by-<axis>` | No | No | Stable-reorder to cluster by axis |
| `git-x commit create -m MSG PATH...` | Read-only | No | Create a commit from named paths or `file.ml:Module.value` source addresses (not a rewrite; see concurrent-claude) |
| `git replay` | No | No | Rebase entirely in objects; emits ref updates |
| `git commit-tree` / `mktree` | No | No | Build commit/tree objects |
| `git merge-tree --write-tree` | No | No | 3-way merge to a tree, no checkout |
| `git update-ref [--stdin]` | No | No | Atomic branch tip update |
| `git range-diff` / `rev-list` / `cat-file` | No | No | Inspect and verify |
| ocaml-git `Repository` API | No | No | All of the above from OCaml (W5) |
| `git worktree add` + porcelain | Isolated | Depends | Last resort (W6) |

Every `git-x` subcommand accepts a full 40-char SHA or a 4+ char hex prefix
(odd or even length), disambiguated against loose and packed objects; an
ambiguous prefix errors with the candidate list.

Not on this list, and not to be used in a shared checkout: `git rebase -i`,
`git rebase` without `--no-checkout`, `git checkout`, `git reset --hard`,
`git stash`, `git add -p`, `git commit --amend` on the current branch.

## Always leave a recovery path

<!-- $MDX skip -->
```sh
git branch backup/feature-$(date +%s) feature
```

Restoring is `git update-ref refs/heads/feature backup/feature-<timestamp>`:
atomic, no working-tree change. `git reflog` records every ref change for ~90
days as a second net, but backup branches are the primary undo.

## What a good series looks like

Atomic (each commit compiles and tests green, so `git bisect` and reverts
work), focused (one logical change each), ordered for reading (mechanical before
semantic, refactors before the feature they enable), self-documenting (see the
`git-commit` skill), with no fixup noise and no unrelated drive-by edits.

Slice a large patch by layer (lib + bin + test), by concern (refactor + feature
+ bugfix), by file or subdirectory, by dependency direction (add primitive ->
switch call sites -> delete old), or by impact size.

## W1. Drop paths from history

For dropping everything matching one or more path globs (stray `.cmi` / `.bak`
/ `.DS_Store`, or a whole directory), `git-x tree drop` walks all commits
reachable from the matching refs, rewrites each tree, re-parents, and swaps the
branch tips at the end.

<!-- $MDX skip -->
```sh
git branch backup/main-$(date +%s) main       # always

git-x tree drop -p '*.cmi' -p '*.bak' --dry-run   # stats per ref, writes nothing
git-x tree drop -p '*.cmi' -p '*.bak'             # defaults to refs/heads/*
git-x tree drop -p '*.cmi' -r refs/heads/main     # one branch
git-x tree drop -p 'old_pkg/**'                   # a directory, recursively
```

Glob semantics (via `Re.Glob`): a pattern without `/` matches the basename at
any depth (`*.cmi` matches `lib/foo.cmi`); a pattern with `/` is full-path,
where `*` does not cross `/` and `**` does.

**Empty-commit pruning.** A commit is dropped and its children re-parented over
it if and only if the predicate dropped at least one entry from it *and* the
resulting tree equals the parent's. Deliberately empty commits (`--allow-empty`
for tags, CI triggers, milestones) survive, because the predicate never touched
them. Root commits and merges with diverging parents are never dropped.

**The index is deliberately left alone**, because it is shared state with agents
running `git add`. So `git status` afterwards shows dropped paths as `A` (still
in the index, no longer in HEAD): harmless until you reconcile, once no other
agent is active:

<!-- $MDX skip -->
```sh
git rm --cached path/to/dropped/file ...   # drop the specific stale entries
git read-tree HEAD                         # or refresh the whole index vs HEAD
```

## W2. Single-commit surgery

Each of these operates purely on the object database and atomically swings the
ref. (Bare `git-x commit -m MSG PATH...` with no subcommand is commit
*creation*, a different operation: see the `concurrent-claude` skill.)

<!-- $MDX skip -->
```sh
# Reword. Descendants are re-parented onto the new commit. Errors if the SHA
# is not reachable from --ref (default refs/heads/main).
git-x commit reword <SHA> -m "better message describing the why"

# Drop. Refuses root and merge commits, which need explicit topology decisions.
git-x commit drop <SHA>

# Split a bundled `git commit -a` into one commit per top-level entry whose
# contents changed. Their union reproduces the original tree exactly; all
# inherit the original author and message, so reword them individually after.
git-x commit split <SHA>

# Squash. SHAs in any order (topo-sorted internally). Keeps the newest commit's
# tree, author and committer; without -m, messages are joined ancestor-first.
# Non-contiguous SHAs replay intervening commits via in-memory 3-way merge;
# a conflict aborts cleanly. Refuses merge commits.
git-x commit squash <sha1> <sha2> <sha3> -m "feat: combined change"

# Sort (BASE, head] to cluster same-key commits. Stable: original order is
# preserved within a cluster. Conflicts abort without touching the ODB or ref.
git-x commit sort <base-sha> --by-dir       # top-level directory
git-x commit sort <base-sha> --by-prefix    # conventional-commits prefix
git-x commit sort <base-sha> --by-author
git-x commit sort <base-sha> --by-trailer Co-Authored-By
```

### The tidy pipeline: split -> sort -> squash

For a messy branch touching many monorepo packages:

<!-- $MDX skip -->
```sh
# 1. un-bundle commits that touched multiple packages
for sha in $(git log --format=%H base..feature); do
  git-x commit split $sha 2>/dev/null || true
done

# 2. cluster same-directory commits adjacent
git-x commit sort $base --by-dir --ref refs/heads/feature

# 3. fold each cluster into one atomic commit per package
git-x commit squash <pkg1-shas...> -m "pkg1: unified change" \
  --ref refs/heads/feature

# 4. reword each squashed commit to describe the why properly
git-x commit reword <squashed> -m "..."
```

## W3. Plumbing fallbacks

Reach for these when `git-x` is unavailable or you need control it doesn't
expose. `git replay` emits `update refs/heads/<branch> <new> <old>` lines that
`git update-ref --stdin` applies atomically; a mid-replay failure updates no ref.

<!-- $MDX skip -->
```sh
# Drop a commit: replay everything after $bad_sha onto its parent.
git replay --onto "$bad_sha"^ "$bad_sha" feature | git update-ref --stdin

# Reword: build a new commit object, then replay the rest onto it.
tree=$(git rev-parse "$sha"^{tree})
parent=$(git rev-parse "$sha"^)
author_env=$(git log -1 --format='GIT_AUTHOR_NAME=%an
GIT_AUTHOR_EMAIL=%ae
GIT_AUTHOR_DATE=%aI' "$sha")
new_sha=$(env $(echo "$author_env" | xargs) \
  git commit-tree "$tree" -p "$parent" -m 'scope: better message')
git replay --onto "$new_sha" "$sha" feature | git update-ref --stdin

# Squash a fixup into its target: merge the trees, rebuild, replay the rest.
merged_tree=$(git merge-tree --write-tree "$target"^ "$target" "$fixup")
new_target=$(git commit-tree "$merged_tree" -p "$target"^ \
  -m "$(git log -1 --format='%B' "$target")")
git replay --onto "$new_target" "$target" feature \
  | grep -v "$fixup" | git update-ref --stdin
```

Prefer `git-x commit squash` over that last form: the `grep -v` step is fragile
when several fixups share a short SHA prefix.

`--onto X commit branch` means "replay all commits in `commit..branch` on top of
`X`, skipping `commit` itself".

Arbitrary hand-crafted reorders are the one case plumbing handles badly: `git
replay` cannot both `--advance` and `--onto` when the moved commit is in the
middle, so it becomes a chain of replays through a temp ref. If `git-x commit
sort`'s clustering axes don't fit and the branch has more than ~5 commits, W6 is
clearer.

## W4. Verify

<!-- $MDX skip -->
```sh
# content equivalence: does the new tip have the same tree as the old?
[ "$(git rev-parse new_tip^{tree})" = "$(git rev-parse old_tip^{tree})" ] \
  && echo OK || echo "TREES DIFFER"

# commit-by-commit comparison
git range-diff old_tip new_tip
```

`range-diff` works on any two ranges and never touches the working tree. It is
the universal "did my rewrite preserve intent?" check.

## W5. ocaml-git equivalents

For OCaml programs in this monorepo (per the ocaml-git rule, only push/pull/fetch
may shell out), the `git` package exposes the same primitives. Object writes are
content-addressed and idempotent; `write_ref` is the atomic ref update. Neither
touches the working tree.

```ocaml
let rewrite_commit ~fs ~sha ~tree ~parents ~author ~committer ~message =
  Eio.Switch.run @@ fun sw ->
  let repo = Git_eio.Repository.open_repo ~sw ~fs (Fpath.v ".") in

  (* read a commit *)
  let commit =
    match Git_eio.Repository.read repo sha with
    | Ok (Git.Value.Commit c) -> c
    | _ -> failwith "expected a commit"
  in
  Fmt.pr "old commit: %a@." Git.Commit.pp commit;

  (* build a new commit object *)
  let new_commit =
    Git.Commit.v ~tree ~parents ~author ~committer ~extra:[] (Some message)
  in
  let new_sha = Git_eio.Repository.write_commit repo new_commit in

  (* atomically update a ref *)
  Git_eio.Repository.write_ref repo "refs/heads/feature" new_sha
```

Path-glob filtering (the `git-x tree drop` algorithm) is `Git.Filter.refs`:

```ocaml
let filter_paths repo =
  let pred = Git_eio.Filter.glob [ "*.cmi"; "*.bak" ] in
  let stats =
    Git_eio.Filter.refs repo pred ~patterns:[ "refs/heads/*" ]
  in
  Fmt.pr "%a@." Git_eio.Filter.pp_stats stats
```

Single-commit rewrites live in `Git.Rewrite`. Each takes the repository, the
SHA(s), and the ref to update, returning the new tip plus a `rewrite_stats`
record.

```ocaml
let reword repo ~commit ~message ~ref_name =
  Git_eio.Rewrite.reword_commit repo ~commit ~message ~ref_name
```

```ocaml
let drop repo ~commit ~ref_name =
  Git_eio.Rewrite.drop_commit repo ~commit ~ref_name ()
```

```ocaml
let split repo ~commit ~ref_name =
  Git_eio.Rewrite.split_commit repo ~commit ~ref_name
```

```ocaml
let squash repo ~commits ?message ~ref_name () =
  Git_eio.Rewrite.squash_commits repo ~commits ?message ~ref_name ()
```

```ocaml
let sort repo ~base ~axis ~ref_name =
  Git_eio.Rewrite.sort_commits repo ~base ~axis ~ref_name ()
```

Use these when the rewrite is part of a larger OCaml workflow; use the `git-x`
CLI for one-shot shell operations.

## W6. Fallback: rewrite in a dedicated worktree

When the operation genuinely needs porcelain that touches files (a split needing
`git add -p` semantics, an `--exec` test run across the series), isolate it. The
main checkout is untouched throughout and other agents never see an intermediate
state; the branch ref update propagates back automatically.

<!-- $MDX skip -->
```sh
git worktree add ../mono-rewrite feature
cd ../mono-rewrite
# ... rewrite freely, e.g. GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true \
#     git rebase -i --autosquash
git range-diff feature@{1} feature
cd -
git worktree remove ../mono-rewrite
```

### Reset + replay (worktree only)

When a branch is badly messy: dead-end experiments, scattered fixups,
intermediate states that don't compile: rebuilding the series from the working
tree with full hindsight beats patching it commit by commit. Hindsight tells you
which abstractions ended up needed (introduce them first), which experiments
were dead ends (skip them), and the right bottom-up order, and lets every
message be written from the final perspective.

This needs a working tree, so it happens inside the W6 worktree:

<!-- $MDX skip -->
```sh
# (on branch `feature` inside ../mono-rewrite)
git reset --soft "$(git merge-base feature main)"

# unstage everything. NEVER `git restore` without --staged: that discards work.
git restore --staged .

git add path/to/refactor && git commit -m "scope: refactor ..."
git add path/to/feature  && git commit -m "scope: feat ..."

git diff feature@{1}                # should be empty
git range-diff feature@{1} HEAD
```

## Pushing a rewritten branch

<!-- $MDX skip -->
```sh
git fetch origin feature            # detect concurrent remote activity first

git log origin/feature..feature     # what we have that the remote doesn't
git log feature..origin/feature     # what the remote has that we don't

git push --force-with-lease origin feature
```

Never force-push a shared branch (`main`, release branches), and never
force-push blindly when the remote has moved: investigate first. Coordinate
through the user.

## Choosing a workflow

| Operation | First choice | Fallback |
|-----------|--------------|----------|
| Drop path globs (cmi, bak, dirs) | W1 `git-x tree drop` | - |
| Reword a commit | W2 `git-x commit reword` | W3 plumbing |
| Drop a commit | W2 `git-x commit drop` | W3 `git replay --onto` |
| Split a bundled commit | W2 `git-x commit split` | - |
| Reorder by cluster | W2 `git-x commit sort` | W3 / W6 |
| Squash a fixup or range | W2 `git-x commit squash` | W3 / W6 |
| Tidy a messy multi-package branch | W2 split -> sort -> squash | W6 reset + replay |
| Arbitrary hand-crafted reorder | W3 or W6 | - |
| Part of a larger OCaml tool | W5 `Git.Rewrite` / `Git.Filter` | - |
| Verify the result | W4 range-diff + tree equality | - |

Two prior questions gate all of it: a shared branch (`main`, a release branch)
means stop and rewrite on a branch of your own; another agent active in this
checkout means every workflow must be no-checkout (W1-W5) or confined to a
worktree (W6).

## Two warnings that save work

- **`git restore <file>` without `--staged` discards uncommitted changes.**
  Always include `--staged` when you only mean to unstage. `stash` / `checkout`
  / `restore` for discarding work are forbidden in this codebase.
- **No-checkout rewrites still rewrite history.** They are safe for concurrent
  *file editing*, not for *collaborators on the branch*. If someone else has
  commits on `feature` you haven't seen, rewriting it still loses their work
  when you push. Fetch and inspect first.
