---
name: codebase-design
description: Shared vocabulary for designing deep modules. Use when the user wants to design or improve a module's interface, find deepening opportunities, decide where a seam goes, make code more testable or AI-navigable, or when another skill needs the deep-module vocabulary.
---
<!-- override: adapted from mattpocock/skills skills/engineering/codebase-design (MIT, Copyright (c) 2026 Matt Pocock). Tracks upstream via sources/overrides/overrides.lock.
Local changes (keep these when merging upstream):
- "Module" vocabulary maps to OCaml constructs (module, functor, library; not class/package), with an "In OCaml" table (compilation unit, `.mli`, functor seams, adapters) and the tells of a shallow module.
- Testability examples are OCaml; adds "make illegal states unrepresentable" and Gospel contracts for invariants (points at the `tdd` skill's contracts-gospel.md).
- Rejected framing talks about the `.mli` signature instead of the TypeScript `interface` keyword.
- DESIGN-IT-TWICE.md: the sub-agent output names the `.mli` as the interface.
-->

# Codebase Design

Design **deep modules**: a lot of behaviour behind a small interface, placed at a clean seam, testable through that interface. Use this language and these principles wherever code is being designed or restructured. The aim is leverage for callers, locality for maintainers, and testability for everyone.

## Glossary

Use these terms exactly: don't substitute "component," "service," "API," or "boundary." Consistent language is the whole point.

**Module**: anything with an interface and an implementation. Deliberately scale-agnostic: a function, a module/functor, a library, or a tier-spanning slice. _Avoid_: unit, component, service, class.

**Interface**: everything a caller must know to use the module correctly: the type signature, but also invariants, ordering constraints, error modes, required configuration, and performance characteristics. _Avoid_: API, signature (too narrow, they refer only to the type-level surface).

**Implementation**: what's inside a module, its body of code. Distinct from **Adapter**: a thing can be a small adapter with a large implementation (a Postgres repo) or a large adapter with a small implementation (an in-memory fake). Reach for "adapter" when the seam is the topic; "implementation" otherwise.

**Depth**: leverage at the interface. The amount of behaviour a caller (or test) can exercise per unit of interface they have to learn. A module is **deep** when a large amount of behaviour sits behind a small interface, **shallow** when the interface is nearly as complex as the implementation.

**Seam** _(Michael Feathers)_: a place where you can alter behaviour without editing in that place; the *location* at which a module's interface lives. Where to put the seam is its own design decision, distinct from what goes behind it. _Avoid_: boundary (overloaded with DDD's bounded context).

**Adapter**: a concrete thing that satisfies an interface at a seam. Describes *role* (what slot it fills), not substance (what's inside).

**Leverage**: what callers get from depth. More capability per unit of interface they learn. One implementation pays back across N call sites and M tests.

**Locality**: what maintainers get from depth. Change, bugs, knowledge, and verification concentrate in one place rather than spreading across callers. Fix once, fixed everywhere.

## In OCaml

The abstract terms above land on concrete language constructs. OCaml's module system is one of the cleanest embodiments of this vocabulary, so use it directly:

| Term | OCaml construct |
|---|---|
| **Module** | A compilation unit (`foo.ml` + `foo.mli`), a `module`, or a `functor`. |
| **Interface** | The `.mli` / `module type` signature **plus** the contract: invariants the abstract `type t` upholds, exceptions raised, `result`/`option` error modes, evaluation order, complexity. The signature names only part of the Interface; the rest can be made explicit and machine-checkable with [Gospel](https://github.com/ocaml-gospel/gospel) contracts (see the `tdd` skill's `contracts-gospel.md`) instead of living only in prose. |
| **Implementation** | The `.ml` body behind the signature. |
| **Depth** | A short `.mli` over a substantial `.ml`. An abstract `type t` that hides a rich representation is the canonical deep move. |
| **Seam** | A `functor` parameter, a `module type` a caller is written against, or a first-class module / function argument. Behaviour varies by which module you apply or pass, without editing the consumer. |
| **Adapter** | A concrete `module` that satisfies a `module type` at a seam: `module Pg : STORE` vs `module Mem : STORE`. |

**Tells that a module is shallow in OCaml:** the `.mli` leaks the concrete representation (`type t = { ... }` instead of `type t`); every value in the `.ml` is re-exported one-to-one; the signature is as long as the body. **Tells that a seam is real:** at least two modules satisfy the same `module type` (production + test fake); one functor instantiation is a hypothetical seam, two is a real one.

## Deep vs shallow

**Deep module** = small interface + lots of implementation:

```
┌─────────────────────┐
│   Small Interface   │  ← Few values, simple params
├─────────────────────┤
│                     │
│  Deep Implementation│  ← Complex logic hidden
│                     │
└─────────────────────┘
```

**Shallow module** = large interface + little implementation (avoid):

```
┌─────────────────────────────────┐
│       Large Interface           │  ← Many values, complex params
├─────────────────────────────────┤
│  Thin Implementation            │  ← Just passes through
└─────────────────────────────────┘
```

When designing an interface, ask:

- Can I reduce the number of values the `.mli` exposes?
- Can I simplify the parameters?
- Can I hide more complexity inside?

## Principles

- **Depth is a property of the interface, not the implementation.** A deep module can be internally composed of small, mockable, swappable parts; they just aren't part of the interface. A module can have **internal seams** (private to its implementation, used by its own tests) as well as the **external seam** at its interface.
- **The deletion test.** Imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep.
- **The interface is the test surface.** Callers and tests cross the same seam. If you want to test *past* the interface, the module is probably the wrong shape.
- **One adapter means a hypothetical seam. Two adapters means a real one.** Don't introduce a seam unless something actually varies across it.

## Designing for testability

Good interfaces make testing natural. In OCaml the interface *is* the `.mli` (or a module signature): keep it small and the implementation deep.

1. **Accept dependencies, don't create them.**

   ```ocaml
   (* Testable *)
   let process_order ~order ~payment_gateway = ...

   (* Hard to test *)
   let process_order ~order =
     let gateway = Stripe_gateway.create () in
     ...
   ```

2. **Return results, don't mutate.** Prefer pure functions returning new values over functions that mutate in place and return `unit`. Pure functions are trivially testable: input in, value out.

   ```ocaml
   (* Testable *)
   val calculate_discount : cart -> discount

   (* Hard to test *)
   val apply_discount : cart -> unit
   ```

3. **Make illegal states unrepresentable.** Use variants and records so the type system rules out bad input before a test ever has to. A narrow type is a narrower test surface.

   ```ocaml
   (* Instead of a string status that could be anything *)
   type status = Pending | Confirmed | Cancelled
   ```

4. **Small surface area.** Fewer values exposed in the `.mli` = fewer things to test; fewer parameters = simpler test setup. If it's not in the `.mli`, it's an implementation detail: don't test it directly.

5. **State the invariants types can't.** When a precondition, postcondition, model, or framing fact matters but the type can't carry it, write it as a [Gospel](https://github.com/ocaml-gospel/gospel) contract on the `.mli` rather than burying it in prose. It stays type-checked, in sync, and machine-verifiable (see the `tdd` skill's `contracts-gospel.md`).

## Relationships

- A **Module** has exactly one **Interface** (the surface it presents to callers and tests).
- **Depth** is a property of a **Module**, measured against its **Interface**.
- A **Seam** is where a **Module**'s **Interface** lives.
- An **Adapter** sits at a **Seam** and satisfies the **Interface**.
- **Depth** produces **Leverage** for callers and **Locality** for maintainers.

## Rejected framings

- **Depth as ratio of implementation-lines to interface-lines** (Ousterhout): rewards padding the implementation. We use depth-as-leverage instead.
- **"Interface" as just the OCaml `.mli` signature or a module's exposed values**: too narrow: interface here includes every fact a caller must know (invariants, error behavior, ordering), not only what the signature names.
- **"Boundary"**: overloaded with DDD's bounded context. Say **seam** or **interface**.

## Going deeper

- **Deepening a cluster given its dependencies**, see [DEEPENING.md](DEEPENING.md): dependency categories, seam discipline, and replace-don't-layer testing.
- **Exploring alternative interfaces**, see [DESIGN-IT-TWICE.md](DESIGN-IT-TWICE.md): spin up parallel sub-agents to design the interface several radically different ways, then compare on depth, locality, and seam placement.
