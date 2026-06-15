# Good and Bad Tests

Examples use [Alcotest](https://github.com/mirage/alcotest) and dune (`dune runtest`),
but the principles hold for OUnit, `ppx_expect`, or any OCaml test runner.

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```ocaml
(* GOOD: Tests observable behavior *)
let test_checkout_with_valid_cart () =
  let cart = Cart.empty |> Cart.add product in
  let result = Checkout.run ~cart ~payment:payment_method in
  Alcotest.(check string) "status is confirmed" "confirmed" result.status
```

Characteristics:

- Tests behavior users/callers care about
- Goes through the public interface (`.mli`) only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```ocaml
(* BAD: Tests implementation details *)
let test_checkout_calls_payment_process () =
  let spy = Payment_spy.create () in
  let _ = Checkout.run ~cart ~payment:(Payment_spy.client spy) in
  Alcotest.(check (list (float 0.))) "process called with total"
    [ cart.total ] (Payment_spy.calls spy)
```

Red flags:

- Mocking internal collaborators / building spies to count calls
- Reaching into a module's private state (only exposed for the test)
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of the interface

```ocaml
(* BAD: Bypasses interface to verify *)
let test_create_user_saves_to_db () =
  let _ = create_user { name = "Alice" } in
  let row = Db.query "SELECT * FROM users WHERE name = ?" [ "Alice" ] in
  Alcotest.(check bool) "row exists" true (Option.is_some row)

(* GOOD: Verifies through interface *)
let test_create_user_makes_user_retrievable () =
  let user = create_user { name = "Alice" } in
  let retrieved = get_user user.id in
  Alcotest.(check string) "name matches" "Alice" retrieved.name
```

## A note on types

OCaml's type checker already proves a lot of what dynamic-language tests have to
assert at runtime (shapes, exhaustiveness, nullability via `option`). Don't write
tests that just re-check the types — let the compiler do that. Spend tests on
*behavior*: the logic the types can't capture.

## Error convention: `result`/`option` vs. exceptions

Decide this **when you design the `.mli`**, because it changes both the interface
and how you test it. The OCaml community convention:

- **Expected, recoverable failures** the caller should handle — return
  `(_, error) result` or `option`. They're part of the interface, so the type
  forces the caller to deal with them, and you test them as ordinary return values:

  ```ocaml
  let test_checkout_rejects_empty_cart () =
    match Checkout.run ~cart:Cart.empty ~payment with
    | Error `Empty_cart -> ()  (* expected *)
    | Ok _ -> Alcotest.fail "empty cart should not check out"
  ```

- **Programmer errors / broken invariants** that should never happen if callers
  obey the contract — raise an exception (`invalid_arg`, `assert false`, a custom
  `exception`). These are bugs, not control flow. Test them with
  `Alcotest.check_raises` only when the *contract itself* promises to raise.

Don't mix the two: a function that returns `result` for some bad input and raises
for other bad input has an interface nobody can hold in their head. Pick one
posture per failure mode and state it in the `.mli`.

Mechanically, prefer `result` over exceptions for domain errors — it makes the
failure visible in the type, which is the whole point of types-first design.
