---
name: tdd
description: Types-first test-driven development for OCaml. Design the .mli and make illegal states unrepresentable first, then red-green-refactor the residual behavior (Alcotest examples or QCheck properties). Use when user wants to build features or fix bugs using TDD, mentions "red-green-refactor", wants integration/property tests, or asks for test-first development.
---

# Test-Driven Development

## Types first, then tests (OCaml)

In OCaml the type system is the **primary** correctness mechanism — tests are the
secondary one. Before writing a single test, do the design work the compiler can
then enforce for free:

1. **Design the `.mli` first.** The signature *is* the interface. Writing it
   before the implementation forces the "what should the public surface be?"
   decision up front, where it's cheap.
2. **Make illegal states unrepresentable.** Reach for variants, abstract types,
   records with the right fields, and (where they earn it) GADTs / phantom types
   so that bad input *doesn't typecheck*. Every invariant you push into a type is
   a test you never have to write — and can never forget to write.
3. **Specify the invariants types can't encode.** For preconditions, postconditions,
   models, framing (`modifies`), and exception conditions, consider a
   [Gospel](https://github.com/ocaml-gospel/gospel) contract on the `.mli` — then
   let **Ortac/QCheck-STM** derive the tests, or **Cameleer** prove them. See
   [contracts-gospel.md](contracts-gospel.md). Optional, but it often replaces a
   pile of hand-written cases on data-structure / parser / numeric code.
4. **Then TDD the residual behavior** — the logic neither types nor contracts
   cover. That's what the rest of this skill covers.

So the correctness order is **types → specs → tests**. The rule of thumb: **if a
test would only be re-checking a shape, nullability, or exhaustiveness, delete the
test and tighten the type instead** — and if it's re-checking a stated
pre/postcondition, let a Gospel consumer generate it. Spend the red-green loop on
behavior the compiler and contracts don't already pin down.

## Philosophy

**Core principle**: Tests should verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't.

**Good tests** are integration-style: they exercise real code paths through public APIs. They describe _what_ the system does, not _how_ it does it. A good test reads like a specification - "user can checkout with valid cart" tells you exactly what capability exists. These tests survive refactors because they don't care about internal structure.

**Bad tests** are coupled to implementation. They mock internal collaborators, test values that aren't exported from the `.mli`, or verify through external means (like querying a database directly instead of using the interface). The warning sign: your test breaks when you refactor, but behavior hasn't changed. If you rename an internal function and tests fail, those tests were testing implementation, not behavior.

See [tests.md](tests.md) for examples, [property-testing.md](property-testing.md) for QCheck/Crowbar (often the better tool for pure functions), [contracts-gospel.md](contracts-gospel.md) for specifying & verifying invariants with Gospel, and [mocking.md](mocking.md) for mocking guidelines.

## Anti-Pattern: Horizontal Slices

**DO NOT write all tests first, then all implementation.** This is "horizontal slicing" - treating RED as "write all tests" and GREEN as "write all code."

This produces **crap tests**:

- Tests written in bulk test _imagined_ behavior, not _actual_ behavior
- You end up testing the _shape_ of things (data structures, function signatures) rather than user-facing behavior
- Tests become insensitive to real changes - they pass when behavior breaks, fail when behavior is fine
- You outrun your headlights, committing to test structure before understanding the implementation

**Correct approach**: Vertical slices via tracer bullets. One test → one implementation → repeat. Each test responds to what you learned from the previous cycle. Because you just wrote the code, you know exactly what behavior matters and how to verify it.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```

## Workflow

### 1. Planning

When exploring the codebase, use the project's domain glossary so that test names and interface vocabulary match the project's language, and respect ADRs in the area you're touching. Use the build/test/format commands in `docs/agents/commands.md` if it exists (run `test` after each cycle); otherwise fall back to the `dune` defaults shown here.

Before writing any code:

- [ ] Draft the `.mli` / module signature first; make illegal states unrepresentable in the types
- [ ] Decide the error convention for this interface (`result`/`option` vs. exceptions — see [tests.md](tests.md))
- [ ] Confirm with user what interface changes are needed
- [ ] Confirm with user which behaviors to test (prioritize the logic the types *can't* capture)
- [ ] Identify opportunities for [deep modules](deep-modules.md) (small interface, deep implementation)
- [ ] Design interfaces for [testability](interface-design.md)
- [ ] List the behaviors to test (not implementation steps)
- [ ] Get user approval on the plan

Ask: "What should the public interface (`.mli`) look like? Which behaviors are most important to test?"

**You can't test everything.** Confirm with the user exactly which behaviors matter most. Focus testing effort on critical paths and complex logic, not every possible edge case.

### 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:   Write test for first behavior → test fails
GREEN: Write minimal code to pass → test passes
```

This is your tracer bullet - proves the path works end-to-end.

### 3. Incremental Loop

For each remaining behavior:

```
RED:   Write next test → fails
GREEN: Minimal code to pass → passes
```

Rules:

- One test at a time
- Only enough code to pass current test
- Don't anticipate future tests
- Keep tests focused on observable behavior
- For a **pure** function, prefer a property (a law over all inputs) to a pile of
  examples — see [property-testing.md](property-testing.md). A property can be your
  RED step just like an example can.

### 4. Refactor

After all tests pass, look for [refactor candidates](refactoring.md):

- [ ] Extract duplication
- [ ] Deepen modules (move complexity behind simple interfaces)
- [ ] Tighten the `.mli` — make types abstract, drop what callers don't need
- [ ] Consider what new code reveals about existing code
- [ ] Run tests after each refactor step

**Never refactor while RED.** Get to GREEN first.

## Checklist Per Cycle

```
[ ] Test describes behavior, not implementation
[ ] Test uses public interface only
[ ] Test would survive internal refactor
[ ] Code is minimal for this test
[ ] No speculative features added
```
