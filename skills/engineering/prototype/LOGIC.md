# Logic Prototype

A tiny interactive terminal app that lets the user drive a state model by hand. Use this when the question is about **business logic, state transitions, or data shape** — the kind of thing that looks reasonable on paper but only feels wrong once you push it through real cases.

## When this is the right shape

- "I'm not sure if this state machine handles the edge case where X then Y."
- "Does this data model actually let me represent the case where..."
- "I want to feel out what the API should look like before writing it."
- Anything where the user wants to **press buttons and watch state change**.

If the question is "what should this look like" — wrong branch. Use [UI.md](UI.md).

## Process

### 1. State the question

Before writing code, write down what state model and what question you're prototyping. One paragraph, in the prototype's README or a comment at the top of the file. A logic prototype that answers the wrong question is pure waste — make the question explicit so it can be checked later, whether the user is watching now or returning to it AFK.

### 2. Pick the language

Use whatever the host project uses. If the project has no obvious runtime (e.g. a docs repo), ask.

Match the project's existing conventions for tooling — don't add a new package manager or runtime just for the prototype.

### 3. Isolate the logic in a portable module

Put the actual logic — the bit that's answering the question — behind a small, pure interface that could be lifted out and dropped into the real codebase later. The TUI around it is throwaway; the logic module shouldn't be.

The right shape depends on the question:

- **A pure reducer** — `val step : state -> action -> state`, with `action` a variant. Good when actions are discrete events and state is a single value. OCaml's exhaustive matching on `action` is exactly the property you're stress-testing.
- **A state machine** — model states as a variant (`type state = Idle | Running of ... | Done`) and transitions as `val transition : state -> event -> state`. Good when "which actions are even legal right now" is part of the question — illegal transitions become a `_ -> Error ...` arm you can see.
- **A small set of pure functions** over a plain data type. Good when there's no implicit current state — just transformations.
- **A module with an abstract `type t`** when the logic genuinely owns ongoing internal state — keep the mutation behind the `.mli`.

Pick whichever shape best fits the question being asked, *not* whichever is easiest to wire to a TUI. Keep it pure: no I/O, no terminal code, no `Fmt.pr`/printing for control flow. The TUI opens it and calls into it; nothing flows the other direction.

This is what makes the prototype useful past its own lifetime. When the question's been answered, the validated reducer / machine / function set can be lifted into the real module — the TUI shell gets deleted.

### 4. Build the smallest TUI that exposes the state

Build it as a **lightweight TUI** — on every tick, clear the screen (`Fmt.pr "\027[2J\027[H"` / equivalent) and re-render the whole frame. The user should always see one stable view, not an ever-growing scrollback.

Each frame has two parts, in this order:

1. **Current state**, pretty-printed and diff-friendly (one field per line). Write a small `Fmt.t` pretty-printer (`val pp_state : state Fmt.t`) rather than dumping a record — it keeps the rendering declarative and reusable. Use `Fmt.styled` for emphasis: `Fmt.(styled `Bold string)` for field names or section headers, `Fmt.(styled `Faint string)` for less important context (timestamps, IDs, derived values). `Fmt` handles the ANSI escapes for you; no need for a separate styling library.
2. **Keyboard shortcuts**, listed at the bottom: `[a] add user  [d] delete user  [t] tick clock  [q] quit`. Bold the key, dim the description, or vice-versa — whatever reads cleanly.

Behaviour:

1. **Initialise state** — a single in-memory object/struct. Render the first frame on start.
2. **Read one keystroke (or one line)** at a time, dispatch to a handler that mutates state.
3. **Re-render** the full frame after every action — don't append, replace.
4. **Loop until quit.**

The whole frame should fit on one screen.

### 5. Make it runnable in one command

Add an entry to the project's existing task runner (a dune `executable` stanza, `Makefile`, `justfile`). The user should run `dune exec <prototype-name>` or equivalent — never need to remember a path.

If the host project has no task runner, just put the command at the top of the prototype's README.

### 6. Hand it over

Give the user the run command. They'll drive it themselves; the interesting moments are when they say "wait, that shouldn't be possible" or "huh, I assumed X would be different" — those are the bugs in the _idea_, which is the whole point. If they want new actions added, add them. Prototypes evolve.

### 7. Capture the answer and the prototype

Once the prototype has answered its question, capture the answer (ask the user what it taught them, or write it down yourself if you watched the session), then capture the prototype the way the [SKILL](SKILL.md) describes. The logic-specific mapping: the validated reducer / machine / function set lifts into the real module (the decision, absorbed); the TUI shell rides along to the throwaway branch that keeps the prototype as a primary source, still runnable there with one `dune exec`.

## Variant: a demo a non-developer can drive

When the person who has to feel the model is not a developer (a designer, a PM, a domain expert), swap the TUI for a small web page over **the same pure module**: a Dream server started by `dune exec`, rendering HTML, with htmx buttons that post an action and swap in the re-rendered state. No JavaScript build, no client-side copy of the logic.

Write it in the domain's language, not the code's, and lay it out top to bottom:

1. **Title and one-line explanation** of what the demo lets you explore (the question from step 1).
2. **Current state** as a readable panel (labelled fields, not a raw dump), re-rendered after every click, with what just changed called out.
3. **Free-play buttons**: one per action, always available.
4. **Guided walkthroughs**: one tab per scenario (happy path, a tricky edge case, an attempt at something illegal), each a short plain-language description plus the ordered buttons to press. Starting a walkthrough resets to a known initial state.

Everything else in this file still applies: the logic module stays pure and liftable, and the page is the throwaway shell.

## Anti-patterns

- **Don't add tests.** A prototype that needs tests is no longer a prototype.
- **Don't wire it to the real database.** Use an in-memory store unless the question is specifically about persistence.
- **Don't generalise.** No "what if we wanted to support X later." The prototype answers one question.
- **Don't blur the logic and the TUI together.** If the reducer / state machine references `Fmt.pr`, prompts, or terminal escape codes, it's no longer portable. Keep the TUI as a thin shell over a pure module.
- **Don't reimplement the logic in JavaScript for the demo.** The page calls the OCaml module through htmx; a second copy in the browser is no longer the thing being validated.
- **Don't ship the TUI shell into production.** The shell is optimised for being driven by hand from a terminal. The logic module behind it is the bit worth keeping.
