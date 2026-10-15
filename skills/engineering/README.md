# Engineering

Skills I use daily for code work.

- **[diagnose](./diagnose/SKILL.md)** — Disciplined diagnosis loop for hard bugs and performance regressions: reproduce → minimise → hypothesise → instrument → fix → regression-test.
- **[grill-with-docs](./grill-with-docs/SKILL.md)** — Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates `CONTEXT.md` and ADRs inline.
- **[triage](./triage/SKILL.md)** — Triage issues through a state machine of triage roles.
- **[improve-codebase-architecture](./improve-codebase-architecture/SKILL.md)** — Find deepening opportunities in a codebase, informed by the domain language in `CONTEXT.md` and the decisions in `docs/adr/`.
- **[merlint](./merlint/SKILL.md)** — Run the `merlint` linter as the final review gate on any OCaml change; fix what it reports instead of silencing it.
- **[tdd](./tdd/SKILL.md)** — Types-first test-driven development for OCaml: design the `.mli` and make illegal states unrepresentable, then red-green-refactor the residual behavior (Alcotest examples or QCheck properties) one vertical slice at a time.
- **[to-issues](./to-issues/SKILL.md)** — Break any plan, spec, or PRD into independently-grabbable GitHub issues using vertical slices.
- **[to-prd](./to-prd/SKILL.md)** — Turn the current conversation context into a PRD and submit it as a GitHub issue.
- **[zoom-out](./zoom-out/SKILL.md)** — Tell the agent to zoom out and give broader context or a higher-level perspective on an unfamiliar section of code.
- **[prototype](./prototype/SKILL.md)** — Build a throwaway prototype to flesh out a design — either a runnable terminal app for state/business-logic questions, or several radically different UI variations toggleable from one route.
- **[unpac](./unpac/SKILL.md)** — Managing vendored dependencies as git branches with unpac: vendor, patch in edit sessions, merge into project worktrees, update from upstream, promote, export, push.
- **[fork-package](./fork-package/SKILL.md)** — Fork a third-party OCaml package in an unpac workspace: fsx- naming on an opam clash, preserved upstream license and credit, the house fork warning, patches branch as the upstream queue.
- **[init-ocaml](./init-ocaml/SKILL.md)** — Create a new OCaml package with the house layout: dune-project metadata, lib/test/fuzz structure, standard dotfiles, and pre-commit hooks.
- **[ocaml-protocols](./ocaml-protocols/SKILL.md)** — Module shape for stateful OCaml wire-protocol libraries: I/O-free state machine core, incoming/outgoing verbs, adapter sub-libraries, Alcobar fuzzing.
