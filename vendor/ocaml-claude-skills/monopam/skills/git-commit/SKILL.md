---
name: git-commit
description: "Writing high-signal git commit messages in the MirageOS / Solo5 / Irmin house style. Use when writing a new commit message, reviewing or rewording an existing one, or drafting a multi-commit series. Distilled from maintainer practice, not generic GitHub advice. The commit skill is the per-commit checklist around this; git-rewrite is how to apply a reword."
---

# Git Commit Messages

The diff answers *what changed*. The message exists to answer everything else,
for the next reader: a human in 2030, an LLM scanning history, you in six
months.

```
<scope>: <imperative summary, no trailing period>

<body wrapped at ~72 cols explaining the why and any non-obvious context.
Fenced code blocks for errors, log output, or diff snippets that illuminate
the change.>

<optional bullet list of sub-changes, when the commit genuinely does several
related things>

Fix #1234
Co-authored-by: Name <email@example.com>
```

## Subject

The single most important line: it appears in `git log --oneline`, PR lists,
blame views, and bisect output.

- **Imperative mood.** "Add X", "Fix Y", "Remove Z", never "Added", "Adds",
  "Fixes". It completes *"If applied, this commit will..."*.
- **Scope prefix**, lowercase, then a colon: the package, subsystem, or
  component. `irmin-pack: introduce V1 commit objects`, `xen: wait for console
  backend to process data`, `build: consistently use $@ in silent rules`.
- **<= 72 characters** (50 is the comfortable target), **no trailing period**.
- **Be specific.** `irmin-pack: add support for user-defined indexing
  strategies` beats `update indexing`. `fix off-by-one locations in
  mirage/main.ml` beats `fix bug`.
- **No issue numbers in the subject** unless the project demands it; use
  trailers.
- **Match the existing log's capitalisation** after the colon. Consistency
  within a project wins over any rule here.

Never: `wip`, `update`, `fix bug`, `cleanup`, `address review comments`, `misc
changes`, `various fixes`, `quick fix`, `temp`, `hack`, or any emoji. If it is a
hack, say which hack and why.

## Body

Skip it only when the subject genuinely says everything (a typo fix, a
dependency bump with the version in the subject). Otherwise write at least a
short paragraph.

**No essays.** Length is not depth, and a twelve-paragraph message covering the
journey, the rejected alternatives, and the philosophical implications is harder
to use than five lines that state the why and stop.

- A short paragraph (2-5 sentences) covers most commits. A bullet list for
  genuine sub-changes. That is the whole body.
- Prose quoting your reasoning at length ("I tried X but it didn't work because
  Y, then I considered Z...") belongs in a PR description or a design doc. The log
  is a *reference*, not a narrative.
- "Additionally", "moreover", "it should also be noted that" are padding. Cut.
- Optimise for the reviewer in 2030 scanning `git log --oneline | grep` who
  needs the answer in ten seconds.

The exception is a genuinely complex change (a subtle algorithmic fix, a
security boundary change, a protocol decision) where the body must carry real
load. Even then: short summary paragraph, then evidence in code blocks, then the
one or two non-obvious notes. Never a wall of text.

Mechanics: blank line after the subject (mandatory, `git log` formatters depend
on it); wrap prose at ~72 characters (long URLs, code blocks and stack traces
may exceed it); active voice, present tense, consistent within a project (either
imperative "Add a compact hashset" or descriptive "This commit allows the user
to..."); markdown fences for errors, log output, and shell sessions; bullets only
for genuine enumerations, never for a single item.

**Self-contained.** Don't make the reader chase another commit, a Slack thread,
or a tracker ticket. Summarise the prior context inline.

## Bug fixes

A fix must let the next reader understand the bug without running the code:
**show the symptom** (paste the panic, the wrong output, the failing test, the
warning, in a code block), **explain the root cause** in a sentence or two,
**note the regression point** if known ("this is a regression introduced in
167d14fbc489"), and **mention the test** if you added one.

```
component: fix hang when X with empty Y

Calling foo(deadline) with a deadline that has passed results in
HVT_HYPERCALL_POLL passing a struct itimerspec with an it_value of
zero in both fields to timerfd_settime(), which disarms the timer,
which causes the subsequent call to epoll_pwait() to hang forever
if no other file descriptors have been registered with the waitset.

Fix this case cheaply by foregoing 1 ns of precision and always
setting the LSB of it_value.tv_nsec to 1.
```

## Refactors and boring commits

A pure refactor must say what motivates it **now**: "pulled out a hashset
because the previous fold was O(n^2)"; "renamed `Direct` to `Hash` (and
`Indirect` to `Offset`) to remove the ambiguity about what 'direct' means in the
new pointer scheme". If it enables a future change, name that change.

Dependency and build commits legitimately have a one-line body or none
(`irmin: add a lower bound on Mtime.1.0.0`). But when there is a *reason*, a
known incompatibility, an obscure feature: state it:

```
irmin: mark as incompatible with Odoc.2.0.{1,2}

These versions fail when attempting to build Irmin's documentation:
[stack trace pasted]

See https://github.com/ocaml/odoc/issues/793.
```

## Trailers and cross-references

Trailers go at the bottom, after a blank line, one `Key: value` per line:
`Fix #1234` / `Closes #1234` only when the issue should auto-close;
`Co-authored-by: Name <email>` for pair work or an accepted patch;
`Signed-off-by:` for DCO projects (Solo5, kernel-style); `(cherry picked from
commit <sha>)` preserved when cherry-picking.

One-off thanks go in prose, not trailers: `Spotted by @user`.

**No marketing trailers.** No `Generated with Claude Code`, no
`Co-Authored-By: Claude` unless explicitly asked, no emoji rows.

Inside the body, reference precisely: other commits by short SHA plus summary
("see cca542832085, which did the same but for tree values"), never "the
previous commit", which rots after a rebase. Issues and PRs as `#1234` on
GitHub, full URL for another project. Specs by section: "per RFC 9421 §2.1".
External links work well as footnotes:

```
As discussed in [1], the preferred way of registering event channel
upcalls is via HVMOP_set_evtchn_upcall_vector.

[1] https://lists.example.org/archives/2020-06/msg00010.html
```

## Language and tone

**ASCII only.** No em dashes, smart quotes, fancy arrows, or check marks: write
`"..."`, `->`, `[x]`. Plain ASCII survives every terminal, blame view, and grep.
Do not substitute ` -- ` for an em dash either; it reads as AI text just as
plainly. Recast with a comma, a colon, a semicolon, parentheses, or a full stop.

No marketing language ("blazingly fast", "elegant", "production-ready"): say
what the code does, with numbers. No hedges: either you know or you don't, and
if you are uncertain say *what* is uncertain ("lightly tested only; not sure if
this conflicts with platform memory holes that plain KVM may map into guest
memory"). No autobiographical asides. No comments about reviewers: "address
review feedback" is a *fixup*, not a commit; squash it before merge and reword
the surviving commit to reflect the final state.

## Series

Each commit is atomic: it compiles, tests pass, the project is coherent.
Reviewers and `git bisect` depend on it. Order them so a reviewer can read
top-to-bottom: mechanical changes first, semantic last, or the reverse,
whichever tells the clearest story. Cross-reference sparingly; each commit
should still stand alone. A "while I was here" cleanup is its own commit.

## Amend or new commit?

**Amend** when the commit is local, unpublished, and you are fixing a typo, a
missing file, or the wording, and its content is otherwise correct.

**New commit** when the previous commit was already published, when a hook
failed (the commit didn't happen, so `--amend` would modify the *prior* commit
and corrupt history), or when the change is logically distinct.

**Never `--amend` a published commit** without coordination: it forces a
force-push and breaks every reviewer's checkout. To rewrite commits already
made, use the `git-rewrite` skill.

## Reviewing a message

1. Does the subject finish *"If applied, this commit will..."*?
2. Is the scope correct and minimal?
3. Could someone five years from now, with no access to the tracker or Slack,
   understand the body?
4. Is every error, log, and code block fenced?
5. ASCII only, ~72-col wrap, blank line after the subject?
6. No `wip`, no emoji, no marketing or Claude-Code trailers?
7. Bug fix: symptom *and* root cause stated? Refactor: motivation stated?
8. Series: does it read commit-by-commit?
