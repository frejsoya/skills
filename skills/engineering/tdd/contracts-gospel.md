# Contracts & Invariants with Gospel

Types-first design pushes invariants the *type system* can express into the types
(variants, abstract types, GADTs). But many invariants types **can't** capture:

- "the result is the maximum element of the array"
- "`pop` returns the head and shortens the stack by one"
- numeric preconditions (`requires n > 0`)
- framing — *which* state a function may mutate (`modifies s`)
- which exceptions are raised and under what condition

[Gospel](https://github.com/ocaml-gospel/gospel) is a tool-agnostic behavioural
specification language for exactly these. Contracts live as `(*@ ... *)` comments
**on the `.mli`** — the same interface this skill already treats as the source of
truth — so the spec sits right next to the signature it constrains.

```ocaml
val max_array : int array -> int
(*@ m = max_array a
    requires a.length > 0
    ensures  forall i. 0 <= i < a.length -> a.elems[i] <= m
    ensures  exists i. 0 <= i < a.length /\ a.elems[i] = m *)
```

Stateful modules get a **model** plus framing:

```ocaml
type 'a t
(*@ mutable model : 'a sequence *)

val push : 'a -> 'a t -> unit
(*@ push a s
    modifies s
    ensures  s = Sequence.cons a (old s) *)

val pop : 'a t -> 'a
(*@ a = pop s
    modifies s
    ensures  a = Sequence.hd (old s)
    ensures  s = Sequence.tl (old s)
    raises   Empty -> old s = Sequence.empty = s *)
```

## Where it fits in the ladder

This skill's correctness order becomes **types → specs → tests/proofs**:

1. **Types** make illegal states unrepresentable (compiler proves it, free).
2. **Gospel contracts** state the invariants types can't — and `gospel check
   foo.mli` type-checks the specs themselves and keeps them in sync with the
   interface. Even unverified, they sharpen the docs (no ambiguity about
   pre/postconditions) and `odoc` renders them.
3. **Verify the contracts** with a Gospel consumer, then hand-write tests only for
   what's left.

## Tools that consume the spec (pick by cost/criticality)

- **[Ortac](https://github.com/ocaml-gospel/ortac)** — Runtime Assertion Checking.
  Turns the Gospel `.mli` into checks. Two modes worth knowing:
  - **QCheck-STM plugin** — auto-generates a model-based **state-machine test**:
    random call sequences checked against the spec's model. This is the big win —
    you get property/STM tests *derived from the contract* instead of hand-writing
    them (cf. [property-testing.md](property-testing.md)).
  - **wrapper plugin** — emits a drop-in module with the same interface that
    asserts every pre/postcondition at runtime; good for fuzzing or monitoring.
- **[Cameleer](https://github.com/ocaml-gospel/cameleer)** — semi-automated
  **deductive verification** (via Why3). Reach for it on small, critical cores
  where a *proof* (not just tests) is worth the effort.
- **[Why3gospel](https://github.com/ocaml-gospel/why3gospel)** — verify a Why3
  proof refines the Gospel spec before extraction.

## When to reach for Gospel

- **Yes**: data-structure libraries (stacks, maps, ring buffers), parsers,
  anything with a clean abstract **model**, numeric/ordering preconditions, or a
  small core where correctness really matters.
- **Maybe**: a single tricky function — a Gospel contract + Ortac/QCheck-STM can
  replace a pile of hand-written cases.
- **Not yet**: glue code, I/O-heavy shells, throwaway prototypes. The model would
  be as complex as the code.

## Relationship to the rest of this skill

- It's **additive**, not a replacement: keep making illegal states unrepresentable
  first; Gospel covers the residue, Alcotest/QCheck cover what you don't spec.
- The `.mli`-first discipline pays double here: a contract is only as good as the
  interface it annotates.
- Ortac/QCheck-STM and hand-written QCheck/Crowbar are **complementary** — derived
  STM tests for the modelled behaviour, hand-written properties/examples for the
  rest.

Gospel, Ortac, Cameleer are all `opam install`-able (`gospel`, `ortac`,
`cameleer`).
