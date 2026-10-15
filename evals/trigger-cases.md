# Routing / trigger eval

Does the right skill fire for a real prompt? Hand this case list to an agent that
can see the installed skill descriptions, ask **"which single skill (if any) would
you invoke?"** for each prompt, and compare to *expected*. Score = matches / total.

A miss means the *description* is wrong (too vague, overlapping, or missing a
trigger) — fix the description, not the case. `—` means no skill should fire.

| # | Prompt | Expected skill |
|---|---|---|
| 1 | "Let's build this feature test-first." | tdd |
| 2 | "Design the `.mli` before we implement the parser." | tdd |
| 3 | "This function is wrong on empty input — help me debug it." | diagnose |
| 4 | "The benchmark regressed 3x since last week." | diagnose |
| 5 | "I don't know this part of the code; give me a map." | zoom-out |
| 6 | "These two modules are too coupled — how do I restructure?" | improve-codebase-architecture |
| 7 | "Turn this conversation into a PRD." | to-prd |
| 8 | "Break this plan into issues we can pick up." | to-issues |
| 9 | "Triage the incoming bug reports." | triage |
| 10 | "Let me play with this state machine before I commit to it." | prototype |
| 11 | "Set up the issue tracker / project commands for these skills." | — (no skill; configured in AGENTS.md/CLAUDE.md) |
| 13 | "Stress-test my design — grill me on it." | grill-me |
| 14 | "Compact this session so another agent can continue." | handoff |
| 15 | "Write a new skill for working with Mirage." | write-a-skill |
| 16 | "Talk like a caveman to save tokens." | caveman |
| 17 | "How should I model errors — result or exceptions?" | tdd |
| 18 | "Add Eio-based concurrency with switches and fibers." | eio (vendored) |
| 19 | "Design a cmdliner CLI for this tool." | cmdliner (vendored) |
| 20 | "Profile allocations — where are the hotspots?" | perf (vendored) |
| 21 | "Encode/decode this record to JSON safely." | jsont (vendored) |
| 22 | "Set up a new OCaml project with dune, opam, and CI." | init-ocaml |
| 23 | "Fuzz-test the parser for crashes on bad input." | fuzz (vendored) |
| 24 | "What's the weather tomorrow?" | — |
| 26 | "Lint this OCaml project before I open the PR." | merlint |
| 25 | "Rename this variable." | — |
| 28 | "Vendor this opam package and merge it into my project." | unpac |
| 29 | "Publish my patched fork of this library under our own name." | fork-package |
| 30 | "Explain this rate-limiting change to my manager." | eli5 (vendored) |
| 31 | "ELI5 what a database index is." | eli5 (vendored) |

## Known-hard cases (watch for mis-routes)

- **3 vs 17**: "wrong on empty input" → `diagnose` (a bug), but "how *should* I
  model errors" → `tdd` (design). If both fire, the descriptions overlap.
- **10 (prototype) vs 1 (tdd)**: "play with it / try a design" is prototype;
  "build it properly / test-first" is tdd.
- **18–23** should beat the generic `tdd`/`diagnose` for OCaml-library tasks —
  if a generic skill wins, the specific skill's description needs sharper
  keywords. (23 routes to the vendored Alcobar `fuzz` from ocaml-claude-skills;
  the marketplace's Crowbar `fuzz` is excluded.)
- **30/31 vs 5 (zoom-out) vs teach**: all three "explain" something. A *named
  audience* (my manager, my mom, a 5th grader, ELI5) → `eli5`; "I don't know
  this code, give me a map" → `zoom-out`; "teach me X over time" → `teach`
  (stateful workspace). If `zoom-out` wins on 30, the audience keyword is not
  carrying enough weight.
