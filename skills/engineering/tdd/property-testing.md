# Property-Based Testing (QCheck)

For pure OCaml functions, a property test is often **more idiomatic and more
powerful** than a handful of example-based cases. Instead of asserting on one
input/output pair, you state a law that must hold for *all* inputs and let
[QCheck](https://github.com/c-cube/qcheck) generate hundreds, shrinking any
failure to a minimal counterexample.

Reach for a property test when the function is pure and you can name an invariant.
Reach for an example test (Alcotest) when you're pinning one specific,
business-meaningful case ("a £0 cart is free shipping").

## When properties beat examples

- **Round-trips**: `decode (encode x) = x` for all `x`.
- **Invariants**: `List.length (sort xs) = List.length xs`; sorting is idempotent.
- **Algebraic laws**: associativity, commutativity, identity elements.
- **Oracle / differential**: a fast implementation agrees with a slow obvious one.
- **"Never crashes"**: a parser returns `Ok`/`Error` but never raises on any input.

## Shape

```ocaml
let test_encode_decode_roundtrip =
  QCheck.Test.make ~count:1000 ~name:"decode (encode x) = x"
    QCheck.(list small_int)
    (fun xs -> decode (encode xs) = xs)

(* Run under Alcotest via the QCheck_alcotest bridge *)
let () =
  Alcotest.run "codec"
    [ "properties", List.map QCheck_alcotest.to_alcotest [ test_encode_decode_roundtrip ] ]
```

## In the TDD loop

A property can be your RED step just like an example can: state the law, watch it
fail (or shrink to a counterexample that reveals a missing case), make it pass.
Properties pair especially well with **types-first** design — once illegal states
are unrepresentable, the remaining bugs live in *logic*, and logic is exactly what
laws describe.

## Don't over-reach

- A property whose body re-implements the function is testing nothing. The law
  must be *independent* of the implementation (a round-trip, an oracle, an invariant).
- If you can't name a law, that's fine — write the example test. Not everything
  has a clean algebraic property.

## QCheck vs. Crowbar — use both, they don't always overlap

The two property tools have **different search strategies**, so they find
different bugs:

- **QCheck** — *random* generation + shrinking. Cheap to write, runs anywhere (no
  special build), great for laws over structured data you can describe with a
  generator. Reach for it by default in the red-green loop.
- **Crowbar** — *coverage-guided* fuzzing (drives AFL via `afl-persistent`) **and**
  can run as a plain QCheck-style property without a fuzzer. Because AFL mutates
  toward new code paths, it excels at the inputs random generation rarely hits:
  deep parser states, boundary conditions, crash/assert-safety on adversarial
  bytes. Reach for it when the function eats untrusted input or has a gnarly state
  space.

Rule of thumb: **QCheck for laws, Crowbar for crash-safety and edge discovery.**
They're complementary, not redundant — a round-trip property is worth running
under *both* (QCheck in CI for speed, Crowbar in a fuzzing session for depth).

For Crowbar setup, generators, and AFL wiring, see the vendored
[`fuzz` skill](../../../vendor/ocaml-claude-marketplace/ocaml-dev/skills/fuzz/SKILL.md).

## Derive properties from a spec instead of writing them

If the module has a clean abstract **model**, you can skip hand-writing many of
these properties: annotate the `.mli` with a [Gospel](https://github.com/ocaml-gospel/gospel)
contract and let **Ortac/QCheck-STM** generate a model-based state-machine test
from it. The contract becomes the single source of truth; the property tests are
derived and stay in sync. See [contracts-gospel.md](contracts-gospel.md). Use this
*alongside* hand-written QCheck/Crowbar for behaviour you don't (or can't) model.
