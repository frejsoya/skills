---
name: ocaml-functors
description: "The one mandatory shape for parameterizing an OCaml module over a backend or implementation: an input module type, an abstract result type with flat accessors, and a Make (B : S) : sig val v : B.t -> t end constructor. Use whenever a component is parameterized over a type or implementation (hash, codec, store, backend). Never first-class module arguments, never records of closures."
---

# OCaml Functor Patterns

There is exactly **one** shape for a parameterized module. Use it every time;
don't reach for first-class module arguments, records of closures, objects, or
any variation.

## The rule

Never pass an implementation as a value:

```ocaml
(* BAD -- first-class module argument *)
val v : (module BACKEND with type t = 's and type hash = 'h) -> 's -> t

(* BAD -- record of closures *)
type t = { find : hash -> block option; put : hash -> block -> unit }
```

Always parameterize with a functor over a module type. Three parts, no others:

1. **An input `module type`**: the backend SPI: an abstract handle type plus
   its operations.
2. **An abstract result `type t`** exposing only **flat accessors**
   `val f : t -> ...`. Never an exposed record, never nested modules.
3. **`module Make (B : S) : sig val v : B.t -> t end`**, the only way to build
   a `t`. `v` is the canonical constructor name.

## Worked example: `irmin/lib/heap.mli`

The content-addressable heap is parameterized over its storage backend. This is
the shape; copy it.

```ocaml
(* 1. the backend SPI: an abstract handle [t] + its operations *)
module type BACKEND = sig
  type t
  type hash
  type block

  val find  : t -> hash -> block option
  val put   : t -> hash -> block -> unit
  val mem   : t -> hash -> bool
  val batch : t -> (hash * block) list -> unit
  val ref   : t -> string -> hash option
  val cas_ref : t -> string -> test:hash option -> set:hash option -> bool
end

(* 2. the abstract result + flat accessors (no exposed record) *)
type ('h, 'v) t
val find : ('h, 'v) t -> 'h -> 'v option
val mem  : ('h, _) t -> 'h -> bool
val to_seq : ('h, 'v) t -> ('h * 'v) Seq.t

(* 3. the Make.v constructor *)
module Make (B : BACKEND) : sig
  val v : B.t -> (B.hash, B.block) t
end
```

A backend (a Git object store, an in-memory hashtable) implements `BACKEND`;
`Make (Git_backend).v state` packs it into the abstract heap; callers use only
`find` / `mem` / `to_seq`. The representation never leaks, and the backend can
change without touching a caller.

Apply it at module level. Never thread `(module B)` through a function:

```ocaml
module Git_heap = Heap.Make (Git_backend)
let h = Git_heap.v state
```

## Threading types

Carry the backend's types into the result with type parameters or `with type`,
so the compiler keeps `Git_heap`'s hash equal to `Git_backend`'s:

```ocaml
module Make (B : BACKEND) : sig
  val v : B.t -> (B.hash, B.block) t   (* B's types appear in the result *)
end
```

## Multiple parameters

The same shape, chained. Static configuration is just another input module:

```ocaml
module Make (H : HASH) (S : STORE with type hash = H.t) : sig
  val v : S.t -> t
end

(* config carried by a module; [v] may then take unit *)
module Make (C : Config) : sig val v : unit -> t end
```

## Runtime extension: a combinator, never the record

When a result must be extended at runtime: a query catalog gaining a derived
table per CTE, say: keep the representation internal and expose a combinator
returning a fresh `t`:

```ocaml
(* GOOD -- derive a new t through a combinator *)
val with_table : t -> string -> columns:string list -> rows:value list list -> t

(* BAD -- exposing a record so callers override a field *)
type t = { columns : string -> string list; ... }
let cat' = { cat with columns = ... }   (* leaks the representation *)
```
