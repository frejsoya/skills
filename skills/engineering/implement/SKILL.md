---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---
<!-- override: adapted from mattpocock/skills skills/engineering/implement (MIT, Copyright (c) 2026 Matt Pocock). Tracks upstream via sources/overrides/overrides.lock.
Local changes (keep these when merging upstream):
- Close out with `review-diff`, not `code-review` (which is not vendored here).
-->

Implement the work described by the user in the spec or tickets.

If the user passes a ticket reference, fetch it from the issue tracker and state its title before starting. If the reference is ambiguous, ask.

Call the Skill tool with "tdd" where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, call the Skill tool with "review-diff" to review the work.

Commit your work to the current branch.
