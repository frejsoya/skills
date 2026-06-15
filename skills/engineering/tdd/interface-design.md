# Interface Design for Testability

Good interfaces make testing natural. In OCaml the interface *is* the `.mli`
(or a module signature) — keep it small and the implementation deep.

1. **Accept dependencies, don't create them**

   ```ocaml
   (* Testable *)
   let process_order ~order ~payment_gateway = ...

   (* Hard to test *)
   let process_order ~order =
     let gateway = Stripe_gateway.create () in
     ...
   ```

2. **Return results, don't mutate**

   Prefer pure functions returning new values over functions that mutate in place
   and return `unit`. Pure functions are trivially testable: input in, value out.

   ```ocaml
   (* Testable *)
   val calculate_discount : cart -> discount

   (* Hard to test *)
   val apply_discount : cart -> unit
   ```

3. **Make illegal states unrepresentable**

   Use variants and records so the type system rules out bad input before a test
   ever has to. A narrow type is a narrower test surface.

   ```ocaml
   (* Instead of a string status that could be anything *)
   type status = Pending | Confirmed | Cancelled
   ```

4. **Small surface area**
   - Fewer values exposed in the `.mli` = fewer things to test
   - Fewer parameters = simpler test setup
   - If it's not in the `.mli`, it's an implementation detail — don't test it directly

5. **State the invariants types can't.** When a precondition, postcondition,
   model, or framing fact matters but the type can't carry it, write it as a
   [Gospel](https://github.com/ocaml-gospel/gospel) contract on the `.mli` rather
   than burying it in prose. It stays type-checked, in-sync, and machine-verifiable
   — see [contracts-gospel.md](contracts-gospel.md).
