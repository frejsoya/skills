<p>
  <a href="https://www.aihero.dev/s/skills-newsletter">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://res.cloudinary.com/total-typescript/image/upload/v1777382277/skills-repo-dark_2x.png">
      <source media="(prefers-color-scheme: light)" srcset="https://res.cloudinary.com/total-typescript/image/upload/v1777382277/skill-repo-light_2x.png">
      <img alt="Skills" src="https://res.cloudinary.com/total-typescript/image/upload/v1777382277/skill-repo-light_2x.png" width="369">
    </picture>
  </a>
</p>

# Skills For Real Engineers

[![skills.sh](https://skills.sh/b/mattpocock/skills)](https://skills.sh/mattpocock/skills)

My agent skills that I use every day to do real engineering - not vibe coding.

> **Provenance — every skill is external; see [`sources/`](./sources/).** This
> repo composes four upstreams that differ only by *edit policy*:
> - **`skills/`** — a **diverged fork** of [`mattpocock/skills`](https://github.com/mattpocock/skills)
>   (tracked via the `upstream` remote), adapted for OCaml/FP. We edit these;
>   pull upstream improvements with `git merge upstream/main` (`make fork-status`).
> - **`vendor/`** — skill sets **vendored verbatim** (pinned, never hand-edited;
>   `make vendor-update`): Anil Madhavapeddy's OCaml `ocaml-dev` plugin,
>   Thomas Gazagnaire's [`monopam`](https://tangled.org/gazagnaire.org/ocaml-claude-skills)
>   plugin, and DreambigOu's [`ELI5`](https://github.com/DreambigOu/ELI5).
>
> There's no "ours vs theirs" — both are upstreams. Provenance and locks for each
> live under [`sources/`](./sources/README.md).
>
> **OCaml / functional-programming flavor.** The fork adapts the engineering
> skills away from TypeScript/Node defaults toward OCaml + dune:
> - **tdd** examples use Alcotest + `dune runtest`, with `.mli` signatures,
>   functors, and first-class modules for dependency injection.
> - **prototype** uses `dune exec` task-runner conventions and OCaml idioms.
> - **improve-codebase-architecture** / **review** reference `.mli`, dune, and
>   ocamlformat config instead of `tsconfig`/eslint/prettier.
>
> The fork covers engineering *discipline* (tdd, diagnose, triage, architecture);
> the vendored `ocaml-dev` set covers OCaml *domain* skills (eio, effects, result,
> cmdliner, jsont, testing, code-style, oxcaml);
> the vendored `monopam` set covers monorepo *workflow* skills (cram, mdx,
> git-commit, git-rewrite, ocaml-functors, interop-testing, perf, todo, plus
> library skills for console and ocaml-observe); and vendored `eli5`
> covers *explanation* — pitching a topic, a diff, or an error at a named
> audience (age, grade, job role, family member).
>
> **Recommended infrastructure.** Install an OCaml MCP server so the agent gets
> type-aware navigation and build diagnostics instead of shelling out blind:
> [`tmattio/ocaml-mcp`](https://github.com/tmattio/ocaml-mcp) (Dune + Merlin), or
> bridge `ocaml-lsp-server` via a generic LSP→MCP adapter.

## Using these skills

Install every skill (the forked set + the vendored OCaml ones) into your agent by
symlinking — the repo stays the source of truth, so editing a `SKILL.md` here is
live immediately:

```sh
make install         # symlink all skills into your agent skills dir(s)
make skills-status   # show what's installed and where it points
make list-skills     # list every skill this repo provides
make uninstall       # remove the symlinks this repo created
```

Install populates a shared store (`~/.agents/skills` by default) and ensures each
agent dir (`~/.claude/skills`, `~/.pi/agent/skills`) forwards into it; any real
directories it would replace are moved to a timestamped `.skills-backup-*`. It's
idempotent — re-run after a `git pull` or `make vendor-update`. Override the
target with `make install SKILLS_DIR=~/.claude/skills`, or skip the vendored
skills with `INCLUDE_VENDOR=0`. Restart the agent to pick up changes.

Run `make` with no target for the full command list.

Developing real applications is hard. Approaches like GSD, BMAD, and Spec-Kit try to help by owning the process. But while doing so, they take away your control and make bugs in the process hard to resolve.

These skills are designed to be small, easy to adapt, and composable. They work with any model. They're based on decades of engineering experience. Hack around with them. Make them your own. Enjoy.

If you want to keep up with changes to these skills, and any new ones I create, you can join ~60,000 other devs on my newsletter:

[Sign Up To The Newsletter](https://www.aihero.dev/s/skills-newsletter)

## Quickstart (30-second setup)

1. Run the skills.sh installer:

```bash
npx skills@latest add mattpocock/skills
```

2. Pick the skills you want, and which coding agents you want to install them on.

3. Bam - you're ready to go.

> [!NOTE]
> Skills like `/to-tickets`, `/to-spec`, and `/triage` expect to know your repo's issue tracker and triage label vocabulary. Provide that context in your `AGENTS.md`/`CLAUDE.md` (e.g. an `## Agent skills` section), or just tell the agent when you run them.

## Why These Skills Exist

I built these skills as a way to fix common failure modes I see with Claude Code, Codex, and other coding agents.

### #1: The Agent Didn't Do What I Want

> "No-one knows exactly what they want"
>
> David Thomas & Andrew Hunt, [The Pragmatic Programmer](https://www.amazon.co.uk/Pragmatic-Programmer-Anniversary-Journey-Mastery/dp/B0833F1T3V)

**The Problem**. The most common failure mode in software development is misalignment. You think the dev knows what you want. Then you see what they've built - and you realize it didn't understand you at all.

This is just the same in the AI age. There is a communication gap between you and the agent. The fix for this is a **grilling session** - getting the agent to ask you detailed questions about what you're building.

**The Fix** is to use:

- [`/grill-me`](./skills/productivity/grill-me/SKILL.md) - for non-code uses
- [`/grill-with-docs`](./skills/engineering/grill-with-docs/SKILL.md) - same as [`/grill-me`](./skills/productivity/grill-me/SKILL.md), but adds more goodies (see below)

These are my most popular skills. They help you align with the agent before you get started, and think deeply about the change you're making. Use them _every_ time you want to make a change.

### #2: The Agent Is Way Too Verbose

> With a ubiquitous language, conversations among developers and expressions of the code are all derived from the same domain model.
>
> Eric Evans, [Domain-Driven-Design](https://www.amazon.co.uk/Domain-Driven-Design-Tackling-Complexity-Software/dp/0321125215)

**The Problem**: At the start of a project, devs and the people they're building the software for (the domain experts) are usually speaking different languages.

I felt the same tension with my agents. Agents are usually dropped into a project and asked to figure out the jargon as they go. So they use 20 words where 1 will do.

**The Fix** for this is a shared language. It's a document that helps agents decode the jargon used in the project.

<details>
<summary>
Example
</summary>

Here's an example [glossary](https://github.com/mattpocock/course-video-manager/blob/076a5a7a182db0fe1e62971dd7a68bcadf010f1c/GLOSSARY.md), from my `course-video-manager` repo. Which one is easier to read?

- **BEFORE**: "There's a problem when a lesson inside a section of a course is made 'real' (i.e. given a spot in the file system)"
- **AFTER**: "There's a problem with the materialization cascade"

This concision pays off session after session.

</details>

This is built into [`/grill-with-docs`](./skills/engineering/grill-with-docs/SKILL.md). It's a grilling session, but that helps you build a shared language with the AI, and document hard-to-explain decisions in ADR's.

It's hard to explain how powerful this is. It might be the single coolest technique in this repo. Try it, and see.

> [!TIP]
> A shared language has many other benefits than reducing verbosity:
>
> - **Variables, functions and files are named consistently**, using the shared language
> - As a result, the **codebase is easier to navigate** for the agent
> - The agent also **spends fewer tokens on thinking**, because it has access to a more concise language

### #3: The Code Doesn't Work

> "Always take small, deliberate steps. The rate of feedback is your speed limit. Never take on a task that’s too big."
>
> David Thomas & Andrew Hunt, [The Pragmatic Programmer](https://www.amazon.co.uk/Pragmatic-Programmer-Anniversary-Journey-Mastery/dp/B0833F1T3V)

**The Problem**: Let's say that you and the agent are aligned on what to build. What happens when the agent _still_ produces crap?

It's time to look at your feedback loops. Without feedback on how the code it produces actually runs, the agent will be flying blind.

**The Fix**: You need the usual tranche of feedback loops: static types, browser access, and automated tests.

For automated tests, a red-green-refactor loop is critical. This is where the agent writes a failing test first, then fixes the test. This helps give the agent a consistent level of feedback that results in far better code.

I've built a **[`/tdd`](./skills/engineering/tdd/SKILL.md) skill** you can slot into any project. It encourages red-green-refactor and gives the agent plenty of guidance on what makes good and bad tests.

For debugging, I've also built a **[`/diagnosing-bugs`](./skills/engineering/diagnosing-bugs/SKILL.md)** skill that wraps best debugging practices into a simple loop.

### #4: We Built A Ball Of Mud

> "Invest in the design of the system _every day_."
>
> Kent Beck, [Extreme Programming Explained](https://www.amazon.co.uk/Extreme-Programming-Explained-Embrace-Change/dp/0321278658)

> "The best modules are deep. They allow a lot of functionality to be accessed through a simple interface."
>
> John Ousterhout, [A Philosophy Of Software Design](https://www.amazon.co.uk/Philosophy-Software-Design-2nd/dp/173210221X)

**The Problem**: Most apps built with agents are complex and hard to change. Because agents can radically speed up coding, they also accelerate software entropy. Codebases get more complex at an unprecedented rate.

**The Fix** for this is a radical new approach to AI-powered development: caring about the design of the code.

This is built in to every layer of these skills:

- [`/to-spec`](./skills/engineering/to-spec/SKILL.md) quizzes you about which modules you're touching before creating a spec

And crucially, [`/improve-codebase-architecture`](./skills/engineering/improve-codebase-architecture/SKILL.md) helps you rescue a codebase that has become a ball of mud. I recommend running it on your codebase once every few days.

### Summary

Software engineering fundamentals matter more than ever. These skills are my best effort at condensing these fundamentals into repeatable practices, to help you ship the best apps of your career. Enjoy.

## Reference

### Engineering

Skills I use daily for code work.

- **[codebase-design](./skills/engineering/codebase-design/SKILL.md)** — Shared discipline and vocabulary for designing deep modules: small interfaces, clean seams, testable through the interface.
- **[diagnosing-bugs](./skills/engineering/diagnosing-bugs/SKILL.md)** — Disciplined diagnosis loop for hard bugs and performance regressions: build a feedback loop that goes red on this bug → minimise → hypothesise → instrument → fix → regression-test.
- **[domain-modeling](./skills/engineering/domain-modeling/SKILL.md)** — Actively build and sharpen a project's domain model by challenging terms, stress-testing with scenarios, and updating `GLOSSARY.md` and ADRs inline.
- **[fork-package](./skills/engineering/fork-package/SKILL.md)** — Fork a third-party OCaml package in an unpac workspace: fsx- naming on an opam clash, preserved upstream license and credit, the house fork warning, patches branch as the upstream queue.
- **[grill-with-docs](./skills/engineering/grill-with-docs/SKILL.md)** — Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates `GLOSSARY.md` and ADRs inline.
- **[implement](./skills/engineering/implement/SKILL.md)** — Build the work described by a spec or set of tickets, driving `/tdd` at pre-agreed seams and closing out with `/review-diff` before committing.
- **[implement-spec](./skills/engineering/implement-spec/SKILL.md)** — Implement a whole spec on one integration branch. Works the tickets as a task graph, running implementer subagents across the ready frontier for maximum concurrency, then closes out with `/review-diff`.
- **[improve-codebase-architecture](./skills/engineering/improve-codebase-architecture/SKILL.md)** — Find deepening opportunities in a codebase, informed by the domain language in `GLOSSARY.md` and the decisions in `docs/adr/`.
- **[init-ocaml](./skills/engineering/init-ocaml/SKILL.md)** — Create a new OCaml package with the house layout: dune-project metadata, lib/test/fuzz structure, standard dotfiles, and pre-commit hooks.
- **[merlint](./skills/engineering/merlint/SKILL.md)** — Run the `merlint` linter as the final review gate on any OCaml change; fix what it reports instead of silencing it.
- **[ocaml-protocols](./skills/engineering/ocaml-protocols/SKILL.md)** — Module shape for stateful OCaml wire-protocol libraries: I/O-free state machine core, incoming/outgoing verbs, adapter sub-libraries, Alcobar fuzzing.
- **[pr](./skills/engineering/pr/SKILL.md)** — The shape a pull request body should take: a summary as the smallest visual that makes the change clear, before/after evidence that it works, and a merge-danger call (one-way or two-way door, plus blast radius).
- **[prototype](./skills/engineering/prototype/SKILL.md)** — Build a throwaway prototype to flesh out a design — either a runnable terminal app for state/business-logic questions, or several radically different UI variations toggleable from one route.
- **[research](./skills/engineering/research/SKILL.md)** — Investigate a question against high-trust primary sources and capture the findings as a cited Markdown file in the repo, run as a background agent.
- **[retro](./skills/engineering/retro/SKILL.md)** — Suggest improvements to the coding agent's environment (navigation, automated checks, coding standards, steering files, tooling) after a session, most severe first.
- **[review-diff](./skills/engineering/review-diff/SKILL.md)** — Two-axis review of the diff since a fixed point: **Standards** (does it follow the repo's coding standards, plus a Fowler smell baseline?) and **Spec** (does it faithfully implement the originating issue/spec?), run as parallel sub-agents.
- **[tdd](./skills/engineering/tdd/SKILL.md)** — Types-first test-driven development for OCaml: design the `.mli` and make illegal states unrepresentable, then red-green-refactor the residual behavior (Alcotest examples or QCheck properties) one vertical slice at a time.
- **[to-spec](./skills/engineering/to-spec/SKILL.md)** — Turn the current conversation into a spec and publish it to the issue tracker.
- **[to-tickets](./skills/engineering/to-tickets/SKILL.md)** — Break any plan, spec, or conversation into a set of tracer-bullet tickets, each declaring its blocking edges, whether as text in a local file or as native blocking links on a real tracker.
- **[triage](./skills/engineering/triage/SKILL.md)** — Triage issues through a state machine of triage roles.
- **[unpac](./skills/engineering/unpac/SKILL.md)** — Managing vendored dependencies as git branches with unpac: vendor, patch in edit sessions, merge into project worktrees, update from upstream, promote, export, push.
- **[wayfinder](./skills/engineering/wayfinder/SKILL.md)** — Plan a huge chunk of work (more than one agent session can hold) as a shared map of decision tickets on the issue tracker, resolved one at a time until the way to the destination is clear.
- **[wizard](./skills/engineering/wizard/SKILL.md)** — Generate an interactive bash wizard that walks a human through steps only they can perform: provisioning infrastructure, setting up credentials or CI secrets, walking an unfamiliar third-party dashboard, or running a one-off migration or cutover.

### Productivity

General workflow tools, not code-specific.

- **[chief-of-staff](./skills/productivity/chief-of-staff/SKILL.md)** — Pursue a long-running goal in a single session by co-ordinating subagents.
- **[claude-handoff](./skills/productivity/claude-handoff/SKILL.md)** — Hand the current conversation off to a fresh background agent that picks up the work immediately, seeded with a handoff summary via `claude --bg`. User-invoked.
- **[grill-me](./skills/productivity/grill-me/SKILL.md)** — Get relentlessly interviewed about a plan or design until every branch of the decision tree is resolved.
- **[grilling](./skills/productivity/grilling/SKILL.md)** — Interview the user relentlessly about a plan, decision, or idea until every branch of the design tree is resolved.
- **[handoff](./skills/productivity/handoff/SKILL.md)** — Compact the current conversation into a handoff document so another agent can continue the work.
- **[teach](./skills/productivity/teach/SKILL.md)** — Teach the user a new skill or concept over multiple sessions, using the current directory as a stateful teaching workspace.
- **[to-questionnaire](./skills/productivity/to-questionnaire/SKILL.md)** — Turn a decision you can't answer alone into a Markdown questionnaire for the one person who can (filled in async, or together over a meeting).
- **[wait-what](./skills/productivity/wait-what/SKILL.md)** — Fire this the moment a message doesn't land. The agent re-pitches it with the context you're missing, in plain English, using your `GLOSSARY.md` vocabulary.
- **[writing-for-agents](./skills/productivity/writing-for-agents/SKILL.md)** — Writing documents for agents: skills, AGENTS.md/CLAUDE.md, and any doc an agent reaches by a pointer.

