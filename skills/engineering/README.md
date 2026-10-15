# Engineering

Skills I use daily for code work.

- **[codebase-design](./codebase-design/SKILL.md)** — Shared discipline and vocabulary for designing deep modules: small interfaces, clean seams, testable through the interface.
- **[diagnosing-bugs](./diagnosing-bugs/SKILL.md)** — Disciplined diagnosis loop for hard bugs and performance regressions: build a feedback loop that goes red on this bug → minimise → hypothesise → instrument → fix → regression-test.
- **[domain-modeling](./domain-modeling/SKILL.md)** — Actively build and sharpen a project's domain model by challenging terms, stress-testing with scenarios, and updating `GLOSSARY.md` and ADRs inline.
- **[fork-package](./fork-package/SKILL.md)** — Fork a third-party OCaml package in an unpac workspace: fsx- naming on an opam clash, preserved upstream license and credit, the house fork warning, patches branch as the upstream queue.
- **[grill-with-docs](./grill-with-docs/SKILL.md)** — Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates `GLOSSARY.md` and ADRs inline.
- **[implement](./implement/SKILL.md)** — Build the work described by a spec or set of tickets, driving `/tdd` at pre-agreed seams and closing out with `/review-diff` before committing.
- **[implement-spec](./implement-spec/SKILL.md)** — Implement a whole spec on one integration branch. Works the tickets as a task graph, running implementer subagents across the ready frontier for maximum concurrency, then closes out with `/review-diff`.
- **[improve-codebase-architecture](./improve-codebase-architecture/SKILL.md)** — Find deepening opportunities in a codebase, informed by the domain language in `GLOSSARY.md` and the decisions in `docs/adr/`.
- **[init-ocaml](./init-ocaml/SKILL.md)** — Create a new OCaml package with the house layout: dune-project metadata, lib/test/fuzz structure, standard dotfiles, and pre-commit hooks.
- **[merlint](./merlint/SKILL.md)** — Run the `merlint` linter as the final review gate on any OCaml change; fix what it reports instead of silencing it.
- **[ocaml-protocols](./ocaml-protocols/SKILL.md)** — Module shape for stateful OCaml wire-protocol libraries: I/O-free state machine core, incoming/outgoing verbs, adapter sub-libraries, Alcobar fuzzing.
- **[pr](./pr/SKILL.md)** — The shape a pull request body should take: a summary as the smallest visual that makes the change clear, before/after evidence that it works, and a merge-danger call (one-way or two-way door, plus blast radius).
- **[prototype](./prototype/SKILL.md)** — Build a throwaway prototype to flesh out a design — either a runnable terminal app for state/business-logic questions, or several radically different UI variations toggleable from one route.
- **[research](./research/SKILL.md)** — Investigate a question against high-trust primary sources and capture the findings as a cited Markdown file in the repo, run as a background agent.
- **[retro](./retro/SKILL.md)** — Suggest improvements to the coding agent's environment (navigation, automated checks, coding standards, steering files, tooling) after a session, most severe first.
- **[review-diff](./review-diff/SKILL.md)** — Two-axis review of the diff since a fixed point: **Standards** (does it follow the repo's coding standards, plus a Fowler smell baseline?) and **Spec** (does it faithfully implement the originating issue/spec?), run as parallel sub-agents.
- **[tdd](./tdd/SKILL.md)** — Types-first test-driven development for OCaml: design the `.mli` and make illegal states unrepresentable, then red-green-refactor the residual behavior (Alcotest examples or QCheck properties) one vertical slice at a time.
- **[to-spec](./to-spec/SKILL.md)** — Turn the current conversation into a spec and publish it to the issue tracker.
- **[to-tickets](./to-tickets/SKILL.md)** — Break any plan, spec, or conversation into a set of tracer-bullet tickets, each declaring its blocking edges, whether as text in a local file or as native blocking links on a real tracker.
- **[triage](./triage/SKILL.md)** — Triage issues through a state machine of triage roles.
- **[unpac](./unpac/SKILL.md)** — Managing vendored dependencies as git branches with unpac: vendor, patch in edit sessions, merge into project worktrees, update from upstream, promote, export, push.
- **[wayfinder](./wayfinder/SKILL.md)** — Plan a huge chunk of work (more than one agent session can hold) as a shared map of decision tickets on the issue tracker, resolved one at a time until the way to the destination is clear.
- **[wizard](./wizard/SKILL.md)** — Generate an interactive bash wizard that walks a human through steps only they can perform: provisioning infrastructure, setting up credentials or CI secrets, walking an unfamiliar third-party dashboard, or running a one-off migration or cutover.
