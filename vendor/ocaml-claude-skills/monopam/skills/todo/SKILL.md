---
name: todo
description: "Working a package's TODO.md test-first: triage the metadata, claim an item, demonstrate it with a failing test, commit the test alone, implement, retire the entry. TODO.md files are private local files, never committed. Use to process TODO items, move misplaced root entries into their package, judge whether an item is still real, or turn a vague TODO into a concrete failing test."
---

# Working a TODO.md

TODO.md files (one per package, plus the root one) hold **active work only**:
completed items simply leave the file, and the work itself lives in git history.
They are **private local files**: gitignored, never committed, never
`git add -f`'d. Mirroring them elsewhere is a project-setup concern handled
out-of-band, not part of this loop.

Code and tests commit through the `commit` skill; TODO.md edits are plain file
edits with no commit step.

## Picking an item

With a package argument, work only that package: its own `TODO.md`
(`/todo ocaml-ssh` works `ocaml-ssh/TODO.md`) plus any root entries concerning
it. The argument may name a specific item (`/todo ocaml-ssh flow control`).

Without an argument, list every TODO.md (`find . -name TODO.md -not -path
'*/_build/*'`; they are gitignored, so git won't list them), skim, and pick
from context: prefer the package this session is already in, otherwise the item
you can demonstrate and land with the most confidence.

## Capture as you go

Every session feeds these files. Working one item you will notice problems
outside its scope: a missing validation, duplicated logic, a stale doc, a
suspicious edge case. File each, then return to the item you claimed.

- **Adjacent findings only.** Anything the current item actually needs is in
  scope and gets done now. Filing a TODO is never a license to ship a hack or
  skip a step the item requires.
- **Self-contained entries.** `file:line`, what is odd, why it matters, an
  absolute date. Actionable by a reader with no access to this session.
  Package-specific findings go in that package's `TODO.md` (create it with the
  house header if needed); cross-package ones in the root file.

Wrong hunches are fine: step 2 below retires entries that don't reproduce, and a
filed false positive is cheaper than re-discovering a real oddity three sessions
later.

## Hygiene first

Don't start on any item while the files themselves are messy. First pass, every
time:

- **Move misplaced root items home.** A root entry concerning a single package
  belongs in `<pkg>/TODO.md`; move it verbatim, creating the file with the house
  header (title, "active work only" note, then entries) if needed. The root file
  keeps only genuinely cross-cutting items: multi-package sweeps, repo-wide
  conventions, tooling.
- **Drop obviously stale entries** while moving: an item describing code that no
  longer exists, or work `git log` shows already landed. When in doubt, keep it;
  step 2 settles it properly with a test.
- **Normalize in place.** Entries stay self-contained, with absolute dates, not
  "next week".

This is pure local file editing; there is nothing to commit. If the files are
already clean, go straight to the loop.

## The loop, per item

**Claim the item before touching any code.** Other sessions work the same
checkout and the marker is how they know to skip it. Mark a checkbox entry `[-]`
(in files using the `[ ]`/`[~]`/`[x]` legend) or prefix a prose heading
(`## [-] Lexer livelock: ...`), and append a dated claim line
(`Claimed 2026-06-12.`). An entry already marked `[-]` belongs to another
session: pick a different one. If you stop without finishing, remove the marker
and trim the entry to what remains.

Read the whole entry first, plus any spec, RFC, or code it references. Open the
spec before writing the test.

### 1. Demonstrate the gap with a failing test

Write a test that fails *today* because the item is real. The test encodes the
spec, not the current code; a stub that passes is not a demonstration.

- **Unit test** for a logic bug or missing behaviour: exact expected values,
  spec-cited by section number, vectors copied verbatim.
- **Fuzz/property test** (see the `fuzz` skill) for an invariant that should
  hold over all inputs: roundtrip, no-crash, bounds.
- **Interop test** (see the `interop-testing` skill) when the claim is wire
  compatibility with an external oracle.

### 2. If you cannot make it fail, retire the item

Read the code and `git log` on the relevant files to find out which case it is:

- **Already fixed**: keep the test if it earns its place as a regression test
  (commit it, citing the fixing commit); delete the entry.
- **Bad idea or not reproducible**: delete the entry, noting nothing. The file
  holds active work only.

Either way the item leaves TODO.md now. No zombie entries.

### 3. If it is real but hard to test, restructure first

When the only obstacle is testability: a state machine fused to IO, no
injection point for a clock, a private function with no observable boundary:
make a focussed architectural move that exposes the behaviour: split the pure core
from the IO, add the missing primitive in the right library, expose a typed
event. Browse the repo before adding anything; the primitive often already
exists under an idiosyncratic name. The restructure is its own commit, before
the test. Never bend the test to reach around bad structure, and never test via
fragile internals.

### 4. Commit the failing test alone

Use the `commit` skill. The test commits before any implementation and the split
must be visible in review. Title it as a spec test (`cfdp: spec test for the
sender EOF file checksum`).

The implementation is best done in a **fresh session**, ideally a different
model, so nothing from the test-writing context can rationalize loosening the
test. When this loop runs both steps in one session, run `/compact` right after
the test commit to approximate that boundary: compaction drops the test-writing
reasoning, so the implementation works from the committed test and the code
rather than from memories of why the test was written.

From here the test is frozen, read-only spec. If it later looks wrong, stop and
re-derive it from the spec; never edit it to match the code.

### 5. Implement, retire, commit

Drive by TDD: run the committed test, watch it fail, write the minimum code to
pass, refactor. Fix the code, never the test. Commit the implementation.

Then delete the completed entry from TODO.md. If only part landed, trim the
entry to exactly what remains, and make sure the remainder is still actionable
on its own. This edit is local only; it never appears in a commit.

## Ending

Run `/compact` between items: once an entry is retired, the reasoning that
landed it is dead weight, and each item should start from the TODO entry and the
code rather than leftover context.

Stop when the file is empty, when the remaining items are blocked on input only
the user can provide (say which and why), or when an item's scope explodes
beyond the session: in which case plan it properly in the entry itself, then
stop.
