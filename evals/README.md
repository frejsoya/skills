# Skill review suite

Three layers, cheapest first. Run the deterministic layer on every change; run the
LLM layers before a release or after a big edit.

## 1. Deterministic checks — `make eval` (no LLM, CI-gated)

`scripts/skills-eval.sh`. `make eval` runs them all; each is also a target:

- **`make integrity`** — repo invariants (errors fail CI): `plugin.json` entries
  resolve; engineering/productivity skills are in `plugin.json` + linked in
  README; bucket READMEs list every skill; `trigger-cases.md` expected skills
  exist; skill names are unique across fork + vendored.
- **`make check`** (lint) — structural + hygiene. **Errors**: missing/malformed
  frontmatter, `name` ≠ directory. **Warnings**: no "Use when …" trigger,
  description > 1024 chars / not capitalized / no period / first-person, unknown
  frontmatter keys, trigger-overlap, SKILL.md > 500 lines, untagged code blocks,
  non-OCaml residue (`Lwt`/`jest`/`pnpm`/`.tsx`), and OCaml anti-patterns
  (`Obj.magic`/`Printf.`) inside `ocaml` code blocks.
- **`make links`** — broken links, dead anchors, links not one level deep,
  non-executable referenced scripts, orphan supporting docs.
- **`make vendor-check`** — `sources/*.lock` well-formed; vendored tree matches
  its pinned commit (catches hand-edits/drift).
- **`make metrics`** — per-skill table (size, files, code blocks, desc length,
  trigger) + totals.
- **`make check-ocaml`** *(opt-in, needs an OCaml toolchain)* — parses `ocaml`
  blocks; see the MDX note below for executing runnable blocks.

These also catch *integrity* problems — a missing skill directory shows up as a
count drop in `metrics` (this is how we caught a working-tree regression once).

### OCaml code blocks — `make check-ocaml` (opt-in) and MDX

Two complementary checks for the OCaml in our examples:

- **`make check-ocaml`** — *syntax-checks* `ocaml` code blocks via `ocamlformat`
  (or `ocamlc -stop-after parsing`). Illustrative **fragments** (those containing
  `...`, `<placeholders>`, or "pseudo-code") are skipped — only self-contained
  blocks are parsed. Opt-in because it needs an OCaml toolchain; it skips cleanly
  if none is installed, so it's not in the CI gate.

- **MDX** (`ocaml-mdx`, via dune's `(mdx)` stanza) — the way to *execute and
  verify* runnable blocks (compile + check output), not just parse them. It only
  works on blocks authored as runnable (compilable, with expected output and a
  context/prelude for placeholder types like `user`/`id`). To adopt it:
  1. Mark a block runnable by giving it real, self-contained code (no `...`);
     mark everything else `<!-- $MDX skip -->` so MDX ignores fragments.
  2. Add a tiny dune harness (a `dune-project` + a prelude defining shared types
     and an `(mdx (files …))` stanza pointing at the skill `.md`), then
     `dune runtest` verifies the blocks.
  This repo is markdown-only today, so MDX is the recommended path *when* a skill
  grows genuinely runnable examples — `check-ocaml` covers the fragment case now.

## 2. Routing eval — [`trigger-cases.md`](./trigger-cases.md)

The description is the only thing the agent sees when choosing a skill, so the
highest-value qualitative check is **does the right skill fire for a real
prompt?** `trigger-cases.md` is a table of `prompt → expected skill`. Run it by
handing the case list to an agent that can see the installed skill descriptions
and asking which it would invoke; score matches. Add a row whenever you add a
skill or hit a real-world mis-route.

## 3. LLM-judge rubric — [`RUBRIC.md`](./RUBRIC.md)

A scored rubric for *content* quality (clarity, actionability, correctness,
progressive disclosure, OCaml idiom). Point an agent at a skill + the rubric and
have it produce a scorecard with concrete fix suggestions. Use it on skills the
deterministic layer can't judge (prose quality, contradictions, idiom).

## What "good" means here

A good skill: fires for the right prompts and only those (layer 2); is concise,
concrete, and internally consistent (layer 3); and is well-formed and idiomatic
(layer 1). All three layers reference the repo's own authoring standard in
`skills/productivity/write-a-skill/SKILL.md`.
