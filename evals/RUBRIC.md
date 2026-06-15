# Skill quality rubric (LLM judge)

Hand an agent **one skill** (its `SKILL.md` + supporting files) plus this rubric,
and ask it to emit a scorecard. Score each dimension **0 / 1 / 2** and give a
one-line justification + a concrete fix when the score is below 2.

| # | Dimension | 0 | 1 | 2 |
|---|---|---|---|---|
| 1 | **Trigger clarity** | No "Use when"; can't tell when to fire | Has a trigger but vague or overlaps another skill | First sentence = what; second = specific "Use when …" with keywords/contexts |
| 2 | **Actionability** | Vague advice, no steps | Some steps but gaps | Concrete steps/checklists an agent can follow without guessing |
| 3 | **Progressive disclosure** | One giant SKILL.md, or details inlined | Mostly fine, some bloat | SKILL.md concise; depth in linked files one level deep |
| 4 | **Correctness & idiom** | Wrong or non-idiomatic (e.g. OO/TS residue, stray `Lwt`, non-idiomatic OCaml) | Minor idiom slips | Idiomatic OCaml; types-first; no contradictions |
| 5 | **Concreteness** | No examples | Examples thin or untested-looking | Real, compilable-looking examples that match the prose |
| 6 | **Consistency** | Terms drift; time-sensitive claims | Minor drift | Stable terminology; no "as of 2026" rot; aligns with `CONTEXT.md` |

**Total /12.** ≥ 10 ship · 7–9 revise the flagged dimensions · < 7 rework.

## Output format

```
## <skill-name> — <total>/12
1 Trigger        2  —
2 Actionability  1  — steps 3–4 assume the reader knows X; spell it out
...
Verdict: revise (fix #2, #5)
```

## Notes for the judge

- Judge against the repo's own standard in
  `skills/productivity/write-a-skill/SKILL.md` (description format, < ~100-line
  SKILL.md ideal, references one level deep).
- For OCaml skills, "correct & idiomatic" means: `.mli`-first, make illegal states
  unrepresentable, `result` for recoverable errors, Eio direct-style, `dune`
  tooling — and **no** `Lwt`, jest, or OO vocabulary.
- Vendored skills (`vendor/`) may be scored for reference but aren't ours to edit;
  fixes go upstream.
- Don't reward length. A 2 on actionability is about *coverage of the task*, not
  word count.
