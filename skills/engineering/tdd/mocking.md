# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes - prefer a test DB)
- Time/randomness (take a clock capability — swap `Eio_mock.Clock` in tests — or a `Random.State.t`)
- File system (sometimes)

Don't mock:

- Your own modules
- Internal collaborators
- Anything you control

In OCaml you rarely need a mocking *library*. The language gives you cleaner
seams: pass a function in, parameterise over a module signature, or apply a
functor with a fake implementation.

**Under Eio, this is the default posture, not extra work.** Effects (network,
clock, filesystem, randomness) arrive as **capabilities** obtained once at the
program's edge — `Eio.Stdenv.net env`, `Eio.Stdenv.clock env`,
`Eio.Stdenv.fs env` — and handed to the modules that need them. That *is*
dependency injection by construction: a test builds the same module with a fake
clock or stub network, no mock library. Code is direct-style, so a faked
operation just returns a plain value.

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

Give each external operation its own value, and let the **module itself be the
seam**. Capture the underlying client/capability when the module is *built* —
don't thread it through every call.

```ocaml
(* GOOD: clean per-operation interface; nothing about the transport leaks in *)
module type API = sig
  val get_user     : id -> user
  val get_orders   : user_id -> order list
  val create_order : order_data -> order
end

(* Production captures the client once, at construction *)
module Http_api (C : sig val client : Http_client.t end) : API = struct
  let get_user id   = Http_client.get C.client (user_path id) |> parse_user
  let get_orders id = Http_client.get C.client (orders_path id) |> parse_orders
  let create_order d = Http_client.post C.client orders_path d |> parse_order
end

(* Test supplies a hand-written fake — same signature, no transport at all *)
module Fake_api : API = struct
  let get_user _   = { id = 1; name = "Alice" }
  let get_orders _ = []
  let create_order _ = { id = 99; status = Pending }
end
```

The `Http_client.t` is itself created once at startup from `Eio.Stdenv.net env`;
it flows into `Http_api` there, not through each function.

Compare the generic alternative:

```ocaml
(* BAD: one generic call — faking it needs conditional logic inside the fake *)
module type API = sig
  val request : endpoint -> meth -> body -> response
end
```

The specific-operation approach means:

- Each fake returns one specific type — no `Obj.magic`, no catch-all variants
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- The compiler tells you when a fake is missing an operation
