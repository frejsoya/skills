# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes - prefer a test DB)
- Time/randomness (pass an `Eio.Time.clock` or a `Random.State.t` in)
- File system (sometimes)

Don't mock:

- Your own modules
- Internal collaborators
- Anything you control

In OCaml you rarely need a mocking *library*. The language gives you cleaner
seams: pass a function in, parameterise over a module signature, or apply a
functor with a fake implementation.

**Under Eio, this is the default posture, not extra work.** Effects (network,
clock, filesystem, randomness, stdenv) arrive as **capabilities** you pass
explicitly — `env#net`, `env#clock`, `env#fs`. That *is* dependency injection by
construction: a test passes a fake clock or a stub `net`, no mock library and no
monad. Code is direct-style (no `_ Lwt.t`), so a faked operation just returns a
plain value.

## Designing for Mockability

**1. Pass effects in as functions or values**

Inject external dependencies rather than constructing them internally:

```ocaml
(* Easy to fake: the caller supplies `charge` *)
let process_payment ~order ~(charge : amount -> (receipt, error) result) =
  charge order.total

(* Hard to fake: client built from the environment inside *)
let process_payment ~order =
  let client = Stripe.create (Sys.getenv "STRIPE_KEY") in
  Stripe.charge client order.total
```

In a test you just pass a pure stub: `process_payment ~order ~charge:(fun _ -> Ok fake_receipt)`.

**2. Parameterise over a module signature (functor) for larger boundaries**

When a boundary has several operations, capture it as a signature and let the
caller supply real or fake module:

```ocaml
module type PAYMENTS = sig
  val charge : amount -> (receipt, error) result
  val refund : receipt -> (unit, error) result
end

module Checkout (P : PAYMENTS) = struct
  let run ~cart = P.charge cart.total
end

(* Production: Checkout(Stripe)   Test: Checkout(Fake_payments) *)
```

**3. Prefer specific operations over one generic fetcher**

Give each external operation its own function instead of a single generic call
with conditional logic:

```ocaml
(* GOOD: each operation is independently fakeable.
   Direct-style Eio: the network capability is passed in, no `_ Lwt.t`. *)
module type API = sig
  val get_user     : net:_ Eio.Net.t -> id -> user
  val get_orders   : net:_ Eio.Net.t -> user_id -> order list
  val create_order : net:_ Eio.Net.t -> order_data -> order
end

(* BAD: faking requires conditional logic inside the fake *)
module type API = sig
  val request : net:_ Eio.Net.t -> endpoint -> meth -> body -> response
end
```

The specific-operation approach means:

- Each fake returns one specific type — no `Obj.magic`, no catch-all variants
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- The compiler tells you when a fake is missing an operation
