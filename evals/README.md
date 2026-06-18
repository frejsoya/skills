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
- **`make metrics`** — per-skill table (size, files, **~token budget**, code
  blocks, desc length, trigger) + totals, including how many skills exceed ~5k
  tokens. `integrity` also reports **routing-eval coverage** (how many skills have
  a positive trigger case).
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

## 4. Model-graded routing evals — waza (`make waza`)

We run [microsoft/waza](https://github.com/microsoft/waza) suites that *execute*
the skills and grade **routing** (does the right skill fire for a prompt?). Each
engineering forked skill has a suite under `evals/<skill>/`:

```
evals/<skill>/
  eval.yaml                    # skill: <name>, config (executor/model), metrics, tasks glob
  tasks/positive-trigger.yaml  # prompt that SHOULD invoke the skill
  tasks/negative-trigger.yaml  # confusable prompt that should route elsewhere / nowhere
```

Routing is asserted with waza's **`skill_invocation`** grader
(`required_skills`, `mode: any_order|exact_match`, `allow_extra`). Tasks are
derived from [`trigger-cases.md`](./trigger-cases.md) — that table stays the
human-readable index; these YAML suites are the executable form.

**Run it (no per-file editing — override via Make vars, passed as `waza run` flags):**

```sh
make waza                                   # all suites, executor=mock (free, no calls)
make waza EXECUTOR=copilot-sdk MODEL=claude-haiku-4-5   # real run
make waza-calibrate SUITE=tdd EXECUTOR=copilot-sdk MODEL=claude-haiku-4-5  # one suite, verbose, to read cost first
waza compare a.json b.json                  # compare two models' results
```

Vars: `EXECUTOR` (`mock`|`copilot-sdk`), `MODEL` (provider's model id), `TRIALS`,
`SUITE`. The eval.yaml files default to `executor: mock` / `model: claude-haiku-4-5`;
the flags override them so you never hand-edit 9 files.

### Cost & calibration

The suite is **18 tasks** (9 skills × positive+negative) × `TRIALS`. Graders are
deterministic (`skill_invocation`) — no extra model calls. A full run is a few
dollars at most (≈$1–3 on Sonnet, well under $1 on Haiku). **Calibrate first:**
`make waza-calibrate` runs one suite verbose and writes token usage to
`.waza-calibrate-<suite>.json` — multiply by 18 (× trials).

### Provider profiles

- **mock** (default) — no credentials, no cost; CI uses this.
- **GitHub Copilot** (incl. the free tier) — `EXECUTOR=copilot-sdk`, `GITHUB_TOKEN`
  set; pick a model the plan serves.
- **Anthropic / Ollama / Azure via an OpenAI-compatible proxy** — `EXECUTOR=copilot-sdk`
  with `COPILOT_BASE_URL` pointing at the proxy (e.g. LiteLLM in front of the
  Anthropic API, or local Ollama on `:11434/v1`). Pay only the provider's token
  cost; Ollama is free/unlimited.

**Adding a skill's suite:** copy an existing `evals/<skill>/` (or `waza new eval
<skill>`), set `skill:`, and write positive/negative prompts. `make integrity`
reports routing coverage so gaps are visible.

The deterministic suite (§1–3) stays the fast first gate; waza is the deep,
model-in-the-loop gate that lets you evaluate skill changes for routing drift.

## What "good" means here

A good skill: fires for the right prompts and only those (layer 2); is concise,
concrete, and internally consistent (layer 3); and is well-formed and idiomatic
(layer 1). All three layers reference the repo's own authoring standard in
`skills/productivity/write-a-skill/SKILL.md`.
