# Skills

Agent skills for OCaml and functional-programming work. Four upstream skill
sets are vendored verbatim and pinned; the local skills and the OCaml
adaptations of upstream ones live in `skills/`. One `make install` symlinks all
of them into every agent on the machine.

## What's here

**Vendored upstreams** ([`vendor/`](./vendor/README.md)): pinned to a commit,
never hand-edited, refreshed with `make vendor-update`.

- Matt Pocock's [`mattpocock/skills`](https://github.com/mattpocock/skills):
  engineering *discipline* and productivity workflow skills (grilling, domain
  modeling, specs and tickets, wayfinding, PR bodies, handoffs, teaching).
- Anil Madhavapeddy's [`ocaml-dev`](https://github.com/avsm/ocaml-claude-marketplace)
  plugin: OCaml *domain* skills (eio, effects, result, cmdliner, jsont, testing,
  code-style, oxcaml).
- Thomas Gazagnaire's [`monopam`](https://tangled.org/gazagnaire.org/ocaml-claude-skills)
  plugin: monorepo *workflow* skills (cram, mdx, git-commit, git-rewrite,
  ocaml-functors, interop-testing, perf, todo) plus the console and
  ocaml-observe library skills.
- DreambigOu's [`ELI5`](https://github.com/DreambigOu/ELI5): *explanation*
  pitched at a named audience (an age, a grade, a job role, a family member).

**Ours** ([`skills/`](./skills/)): skills written here (`unpac`, `fork-package`,
`merlint`, `review-diff`), and **overrides**: OCaml adaptations of upstream
skills (`tdd`, `prototype`, `codebase-design`, `diagnosing-bugs`, `triage`, …)
that keep tracking their upstream through
[`sources/overrides/overrides.lock`](./sources/overrides/overrides.lock) and are
three-way merged on every `make vendor-update`. Provenance, pins and the
override mechanism are documented in [`sources/`](./sources/README.md).

### The OCaml flavour

The overrides move the engineering skills away from TypeScript/Node defaults
toward OCaml + dune:

- **tdd** designs the `.mli` first and makes illegal states unrepresentable,
  then red-greens the residual behaviour with Alcotest or QCheck, using
  functors and Eio capabilities for dependency injection.
- **prototype** drives a pure OCaml module from a terminal app, or from a
  Dream + htmx page when a non-developer has to feel the model.
- **codebase-design** maps module, interface, seam and adapter onto `.mli`
  files, functors and module signatures.
- **diagnosing-bugs** builds its feedback loop from `dune runtest`, `utop` and
  `OCAMLRUNPARAM=b`.

Pair the skills with an OCaml MCP server so the agent gets type-aware navigation
and build diagnostics instead of shelling out blind:
[`tmattio/ocaml-mcp`](https://github.com/tmattio/ocaml-mcp) (Dune + Merlin), or
bridge `ocaml-lsp-server` via a generic LSP→MCP adapter.

## Install

Every skill (local and vendored) is installed by symlinking, so the repo stays
the source of truth and editing a `SKILL.md` here is live immediately:

```sh
make install         # symlink all skills into your agent skills dir(s)
make skills-status   # show what's installed and where it points
make list-skills     # list every skill this repo provides
make uninstall       # remove the symlinks this repo created
```

Install populates a shared store (`~/.agents/skills` by default) and ensures each
agent dir (`~/.claude/skills`, `~/.pi/agent/skills`) forwards into it; any real
directories it would replace are moved to a timestamped `.skills-backup-*`. It's
idempotent: re-run after a `git pull` or `make vendor-update`. Override the
target with `make install SKILLS_DIR=~/.claude/skills`, or skip the vendored
skills with `INCLUDE_VENDOR=0`. Restart the agent to pick up changes.

Run `make` with no target for the full command list.

> [!NOTE]
> Skills like `/to-tickets`, `/to-spec`, and `/triage` expect to know your repo's
> issue tracker and triage label vocabulary. Provide that context in your
> `AGENTS.md`/`CLAUDE.md` (e.g. an `## Agent skills` section), or just tell the
> agent when you run them.

## Layout

```
skills/            ours: local skills and overrides, in buckets
  engineering/       daily code work
  productivity/      daily non-code workflow tools (none local yet)
vendor/<name>/     each upstream set, verbatim, with its license beside it
sources/           one <name>.lock per upstream (URL, subdir, pinned commit,
                   declared excludes), overrides/ with the override lock and
                   the upstream base snapshot of every override
scripts/           install, eval and override-merge scripts behind the Makefile
evals/             deterministic checks and routing evals (make eval, make waza)
```

## Updating the upstreams

```sh
make vendor-status   # the pinned commit of each vendored set
make vendor-diff     # what each upstream changed since its pin
make vendor-update   # re-sync every set to upstream main, rewrite the locks,
                     # and merge upstream changes into the skills/ overrides
make eval            # integrity + lint + links + vendor-check + metrics
```

A `make vendor-update` that touches an overridden skill leaves `<<<<<<<` markers
where upstream and local edits overlap; the merge output says how to resolve
them, and `make integrity` fails until they are gone. To pin a specific commit
instead of upstream main: `make vendor-update-<name> REF=<sha>`.

## Reference

### Engineering (local)

Skills written here, and OCaml-adapted overrides of upstream skills.

- **[codebase-design](./skills/engineering/codebase-design/SKILL.md)** — Shared discipline and vocabulary for designing deep modules: small `.mli`, clean seams, testable through the interface. *(override)*
- **[diagnosing-bugs](./skills/engineering/diagnosing-bugs/SKILL.md)** — Disciplined diagnosis loop for hard bugs and performance regressions: build a feedback loop that goes red on this bug → minimise → hypothesise → instrument → fix → regression-test. *(override)*
- **[fork-package](./skills/engineering/fork-package/SKILL.md)** — Fork a third-party OCaml package in an unpac workspace: fsx- naming on an opam clash, preserved upstream license and credit, the house fork warning, patches branch as the upstream queue.
- **[implement](./skills/engineering/implement/SKILL.md)** — Build the work described by a spec or set of tickets, driving `/tdd` at pre-agreed seams and closing out with `/review-diff` before committing. *(override)*
- **[implement-spec](./skills/engineering/implement-spec/SKILL.md)** — Implement a whole spec on one integration branch. Works the tickets as a task graph, running implementer subagents across the ready frontier for maximum concurrency, then closes out with `/review-diff`. *(override)*
- **[init-ocaml](./skills/engineering/init-ocaml/SKILL.md)** — Create a new OCaml package with the house layout: dune-project metadata, lib/test/fuzz structure, standard dotfiles, and pre-commit hooks. *(override)*
- **[merlint](./skills/engineering/merlint/SKILL.md)** — Run the `merlint` linter as the final review gate on any OCaml change; fix what it reports instead of silencing it.
- **[ocaml-protocols](./skills/engineering/ocaml-protocols/SKILL.md)** — Module shape for stateful OCaml wire-protocol libraries: I/O-free state machine core, incoming/outgoing verbs, adapter sub-libraries, Alcobar fuzzing. *(override)*
- **[prototype](./skills/engineering/prototype/SKILL.md)** — Build a throwaway prototype to flesh out a design — either a terminal app over a pure OCaml module for state/business-logic questions, or several radically different Dream + htmx UI variations toggleable from one route. *(override)*
- **[review-diff](./skills/engineering/review-diff/SKILL.md)** — Two-axis review of the diff since a fixed point: **Standards** (does it follow the repo's coding standards, plus a Fowler smell baseline?) and **Spec** (does it faithfully implement the originating issue/spec?), run as parallel sub-agents.
- **[tdd](./skills/engineering/tdd/SKILL.md)** — Types-first test-driven development for OCaml: design the `.mli` and make illegal states unrepresentable, then red-green the residual behavior (Alcotest examples or QCheck properties) one vertical slice at a time. *(override)*
- **[to-spec](./skills/engineering/to-spec/SKILL.md)** — Turn the current conversation into a spec and publish it to the issue tracker. *(override)*
- **[to-tickets](./skills/engineering/to-tickets/SKILL.md)** — Break any plan, spec, or conversation into a set of tracer-bullet tickets, each declaring its blocking edges, whether as text in a local file or as native blocking links on a real tracker. *(override)*
- **[triage](./skills/engineering/triage/SKILL.md)** — Triage issues through a state machine of triage roles. *(override)*
- **[unpac](./skills/engineering/unpac/SKILL.md)** — Managing vendored dependencies as git branches with unpac: vendor, patch in edit sessions, merge into project worktrees, update from upstream, promote, export, push.
- **[wayfinder](./skills/engineering/wayfinder/SKILL.md)** — Plan a huge chunk of work (more than one agent session can hold) as a shared map of decision tickets on the issue tracker, resolved one at a time until the way to the destination is clear. *(override)*

### Productivity (local)

None yet. The productivity skills all come verbatim from `mattpocock/skills`
(below).

### Vendored from mattpocock/skills

Verbatim at [`vendor/mattpocock-skills/`](./vendor/mattpocock-skills/).
Upstream's own [README](https://github.com/mattpocock/skills#readme) explains
the thinking behind them.

- **[domain-modeling](./vendor/mattpocock-skills/skills/engineering/domain-modeling/SKILL.md)** — Actively build and sharpen a project's domain model by challenging terms, stress-testing with scenarios, and updating `GLOSSARY.md` and ADRs inline.
- **[grill-with-docs](./vendor/mattpocock-skills/skills/engineering/grill-with-docs/SKILL.md)** — Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates `GLOSSARY.md` and ADRs inline.
- **[improve-codebase-architecture](./vendor/mattpocock-skills/skills/engineering/improve-codebase-architecture/SKILL.md)** — Find deepening opportunities in a codebase, informed by the domain language in `GLOSSARY.md` and the decisions in `docs/adr/`.
- **[pr](./vendor/mattpocock-skills/skills/engineering/pr/SKILL.md)** — The shape a pull request body should take: a summary as the smallest visual that makes the change clear, before/after evidence that it works, and a merge-danger call.
- **[research](./vendor/mattpocock-skills/skills/engineering/research/SKILL.md)** — Investigate a question against high-trust primary sources and capture the findings as a cited Markdown file in the repo, run as a background agent.
- **[retro](./vendor/mattpocock-skills/skills/engineering/retro/SKILL.md)** — Suggest improvements to the coding agent's environment (navigation, automated checks, coding standards, steering files, tooling) after a session, most severe first.
- **[wizard](./vendor/mattpocock-skills/skills/engineering/wizard/SKILL.md)** — Generate an interactive bash wizard that walks a human through steps only they can perform: provisioning infrastructure, credentials or CI secrets, an unfamiliar third-party dashboard, a one-off migration.
- **[chief-of-staff](./vendor/mattpocock-skills/skills/in-progress/chief-of-staff/SKILL.md)** — Pursue a long-running goal in a single session by co-ordinating subagents.
- **[claude-handoff](./vendor/mattpocock-skills/skills/in-progress/claude-handoff/SKILL.md)** — Hand the current conversation off to a fresh background agent that picks up the work immediately, seeded with a handoff summary via `claude --bg`.
- **[grill-me](./vendor/mattpocock-skills/skills/productivity/grill-me/SKILL.md)** — Get relentlessly interviewed about a plan or design until every branch of the decision tree is resolved.
- **[grilling](./vendor/mattpocock-skills/skills/productivity/grilling/SKILL.md)** — Interview the user relentlessly about a plan, decision, or idea until every branch of the design tree is resolved.
- **[handoff](./vendor/mattpocock-skills/skills/productivity/handoff/SKILL.md)** — Compact the current conversation into a handoff document so another agent can continue the work.
- **[teach](./vendor/mattpocock-skills/skills/productivity/teach/SKILL.md)** — Teach the user a new skill or concept over multiple sessions, using the current directory as a stateful teaching workspace.
- **[to-questionnaire](./vendor/mattpocock-skills/skills/productivity/to-questionnaire/SKILL.md)** — Turn a decision you can't answer alone into a Markdown questionnaire for the one person who can.
- **[wait-what](./vendor/mattpocock-skills/skills/productivity/wait-what/SKILL.md)** — Fire this the moment a message doesn't land. The agent re-pitches it with the context you're missing, in plain English, using your `GLOSSARY.md` vocabulary.
- **[writing-for-agents](./vendor/mattpocock-skills/skills/productivity/writing-for-agents/SKILL.md)** — Writing documents for agents: skills, AGENTS.md/CLAUDE.md, and any doc an agent reaches by a pointer.

Not vendored: `ask-matt` and `setup-matt-pocock-skills` (they route to and
configure upstream's own set), `code-review` (`review-diff` owns review here),
and the `misc` and unfinished `in-progress` skills.

### Vendored OCaml sets

- [`vendor/ocaml-claude-marketplace/ocaml-dev/skills/`](./vendor/ocaml-claude-marketplace/ocaml-dev/skills/) — the `ocaml-dev` plugin (ISC).
- [`vendor/ocaml-claude-skills/monopam/skills/`](./vendor/ocaml-claude-skills/monopam/skills/) — the `monopam` plugin (ISC).
- [`vendor/eli5/eli5/skills/`](./vendor/eli5/eli5/skills/) — ELI5 (MIT).

`make list-skills` prints every skill with the path it is served from; where
two sets ship the same name, `make install` keeps the first in discover order
(local skills, then vendors sorted by name) and says what it skipped.

## Licenses

Each vendored set stays under its upstream's license, kept next to it:

- `mattpocock/skills`: MIT, [`vendor/mattpocock-skills/LICENSE`](./vendor/mattpocock-skills/LICENSE)
- `ocaml-dev`: ISC, [`vendor/ocaml-claude-marketplace/LICENSE`](./vendor/ocaml-claude-marketplace/LICENSE)
- `monopam`: ISC, [`vendor/ocaml-claude-skills/LICENSE.md`](./vendor/ocaml-claude-skills/LICENSE.md)
- `ELI5`: MIT, [`vendor/eli5/eli5/LICENSE`](./vendor/eli5/eli5/LICENSE)

An override is a derived work of the upstream skill it adapts; the
`<!-- override: -->` comment at the top of its `SKILL.md` names that upstream
and its license.
