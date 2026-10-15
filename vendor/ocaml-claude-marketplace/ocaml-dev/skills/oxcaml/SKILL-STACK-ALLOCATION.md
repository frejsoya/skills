---
name: oxcaml-stack-allocation
description: "OxCaml stack allocation patterns using local_, stack_, and exclave_ for GC-free value allocation"
---

# OxCaml Stack Allocation: Detailed Guide

Stack allocation allows values to be allocated on the stack instead of the heap,
avoiding GC overhead. The tradeoff is that stack-allocated values cannot escape
their defining scope.

## Core Concepts

### Local vs Global

- **Global** values live on the heap and can be stored anywhere, returned from
  functions, and live indefinitely
- **Local** values live on the stack and must not escape their defining scope

### The Region Model

Local allocations do **not** go on the OS call stack: they live on a
separate, dynamically-grown local stack laid out like the minor heap.
Each function call opens a *region* on it; local values are allocated
in the current region and freed when it ends.

```
┌─────────────────────────┐
│ Caller's region         │
│ ┌─────────────────────┐ │
│ │ exclave_ allocations│ │  ← Allocated here with exclave_
│ └─────────────────────┘ │
├─────────────────────────┤
│ Callee's region         │
│ ┌─────────────────────┐ │
│ │ local_ allocations  │ │  ← Allocated here with local_/stack_
│ └─────────────────────┘ │
└─────────────────────────┘
```

---

## Syntax

### Creating Local Values

```ocaml
(* Mode the binding local (inference may stack-allocate;
   only stack_ forces it) *)
let local_ x = (1, 2, 3)

(* Explicit: force stack allocation *)
let y = stack_ (1, 2, 3)

(* With type annotation *)
let local_ (z : int * int) = (1, 2)
```

### Local Parameters

```ocaml
(* Accept local argument *)
let process (data @ local) =
  (* data is stack-allocated, cannot be stored globally *)
  Array.fold_left (+) 0 data

(* Can also accept global (subtyping) *)
let _ = process heap_array  (* OK *)
```

### Returning Local Values

```ocaml
(* exclave_ allocates in CALLER's frame and returns *)
let make_pair x y = exclave_
  stack_ (x, y)

(* Caller receives a local value *)
let use () =
  let local_ p = make_pair 1 2 in
  fst p + snd p
```

---

## The `exclave_` Construct

`exclave_` is the key to returning stack-allocated values. It:
1. Allocates the result in the caller's stack frame
2. Returns that allocation to the caller
3. Must be at tail position

### Valid exclave_ Patterns

```ocaml
(* Direct allocation *)
let f x = exclave_ stack_ (x, x)

(* Calling another exclave function *)
let g x = exclave_ make_pair x x

(* Conditional - both branches must be exclave-compatible *)
let h x = exclave_
  if x > 0 then stack_ (x, 1)
  else stack_ (0, 0)

(* Match - all branches must be exclave-compatible *)
let i x = exclave_
  match x with
  | Some v -> stack_ (v, v)
  | None -> stack_ (0, 0)
```

### Invalid exclave_ Patterns

```ocaml
(* ERROR: exclave_ not at tail position *)
let bad x =
  let y = exclave_ stack_ (x, x) in  (* Not tail! *)
  fst y

(* OK (not an error): exclave_ ends the current region immediately,
   so everything after it — including this stack_ allocation — happens
   in the CALLER's region and may be returned *)
let fine x = exclave_
  let local_ temp = stack_ (x, x) in
  temp
```

---

## Local References

References can be stack-allocated for mutable accumulators:

```ocaml
let sum_array arr =
  let local_ total = ref 0 in
  for i = 0 to Array.length arr - 1 do
    total := !total + arr.(i)
  done;
  !total  (* Return the int, not the ref *)
```

**Refs (and mutable fields, and arrays) may themselves be local, but
their *contents* must be `global`** — `acc := stack_ (...)` is a mode
error. To accumulate local data, use `let mutable`, which can hold
local values:

### Building Local Lists

```ocaml
let collect_positives arr =
  let mutable acc = [] in
  for i = 0 to Array.length arr - 1 do
    if arr.(i) > 0 then
      acc <- stack_ (arr.(i) :: acc)
  done;
  (* Process locally, return global result *)
  List.fold_left (+) 0 acc
```

---

## Local Data Structures

### Local Lists

```ocaml
(* Build list on stack *)
let make_list n = exclave_
  let rec go acc i =
    if i = 0 then acc
    else go (stack_ (i :: acc)) (i - 1)
  in
  go [] n

(* Process local list *)
let sum_local (lst @ local) =
  let rec go acc = function
    | [] -> acc
    | x :: xs -> go (acc + x) xs
  in
  go 0 lst
```

### Local Arrays

```ocaml
(* Stack-allocated array *)
let with_temp_array n f =
  let local_ arr = Array.make n 0 in
  f arr
  (* arr deallocated when function returns *)
```

### Local Records

```ocaml
type point = { x : float; y : float }

let make_point x y = exclave_
  stack_ { x; y }

let distance (p1 @ local) (p2 @ local) =
  let dx = p1.x -. p2.x in
  let dy = p1.y -. p2.y in
  Float.sqrt (dx *. dx +. dy *. dy)
```

---

## Common Patterns

### Process Locally, Return Globally

```ocaml
let find_max arr =
  if Array.length arr = 0 then None
  else begin
    (* let mutable can hold local values; a ref could not *)
    let mutable best = stack_ (0, arr.(0)) in
    for i = 1 to Array.length arr - 1 do
      if arr.(i) > snd best then
        best <- stack_ (i, arr.(i))
    done;
    (* Return global result *)
    Some (fst best)
  end
```

### Temporary Pairs for Multiple Returns

```ocaml
let divmod a b = exclave_
  stack_ (a / b, a mod b)

let use () =
  let local_ result = divmod 17 5 in
  Printf.printf "%d r %d\n" (fst result) (snd result)
```

### Local Closures

Closures capturing local data are themselves local:

```ocaml
let with_counter f =
  let local_ count = ref 0 in
  let local_ incr () = count := !count + 1 in
  f incr;
  !count

let result = with_counter (fun incr ->
  incr (); incr (); incr ()
)  (* result = 3 *)
```

---

## Pitfalls and Solutions

### Pitfall: Storing Local in Global Structure

```ocaml
(* ERROR: Cannot store local in global list *)
let bad () =
  let global_list = ref [] in
  let local_ x = (1, 2) in
  global_list := x :: !global_list  (* Error! *)
```

**Solution**: Copy to heap or restructure:

```ocaml
let good () =
  let global_list = ref [] in
  let x = (1, 2) in  (* Allocate globally *)
  global_list := x :: !global_list
```

### Pitfall: Returning Local from Non-Tail Position

```ocaml
(* ERROR: exclave_ not at tail *)
let bad x =
  let result = exclave_ stack_ (x, x) in
  fst result
```

**Solution**: Restructure to put exclave_ at tail:

```ocaml
let good x = exclave_
  stack_ (x, x)

let use x =
  let local_ p = good x in
  fst p
```

### Pitfall: Local Escaping via Closure

```ocaml
(* ERROR: Closure captures local *)
let bad () =
  let local_ x = ref 0 in
  let f () = !x in  (* f captures x *)
  f  (* Cannot return f - it contains local ref *)
```

**Solution**: Use `let mutable` or ensure closure is also local:

```ocaml
let good () =
  let mutable x = 0 in
  (* mutable variables don't create closures *)
  for i = 1 to 10 do x <- x + i done;
  x
```

### Pitfall: Storing Local Values in Refs or Mutable Fields

```ocaml
(* ERROR: ref contents must be global, even if the ref is local *)
let bad () =
  let local_ acc = ref [] in
  acc := stack_ (1 :: !acc)   (* "local but expected to be global" *)
```

**Solution**: Use `let mutable`, which may hold local values:

```ocaml
let good () =
  let mutable acc = [] in
  acc <- stack_ (1 :: acc);
  List.length acc
```

---

## Performance Considerations

### When to Use Stack Allocation

- Short-lived intermediate values
- Accumulators in loops
- Temporary pairs/tuples for multiple returns
- Processing pipelines where data flows through

### When NOT to Use Stack Allocation

- Values that need to be stored in long-lived data structures
- Values returned from deeply nested call chains
- Very large allocations (limited stack space)
- Values shared across threads

### Local Stack Growth

Local allocations live on a separate local stack that grows dynamically
(not the ~8MB OS thread stack), so large local allocations won't crash —
but they hold memory for the whole region and forgo the minor heap's
locality benefits. Prefer the heap for very large or long-lived data:

```ocaml
(* Dubious: a huge region-lifetime allocation *)
let dubious () =
  let local_ huge = Array.make 1_000_000 0 in
  ...
```

---

## Integration with Other Features

### With Unboxed Types

```ocaml
(* Unboxed types in local records - very efficient *)
type local_point = { x : float#; y : float# }

let make_point x y = exclave_
  stack_ { x = Float_u.of_float x; y = Float_u.of_float y }
```

### With Zero-Alloc

```ocaml
(* Stack allocation satisfies zero_alloc *)
let[@zero_alloc] process x y =
  let local_ p = stack_ (x, y) in
  fst p + snd p
```

### With Comprehensions

List comprehensions build their *intermediate* structures on the local
stack for efficiency, but the resulting list is always **global**
(heap-allocated) — you cannot get a local list out of a comprehension.

See also: [SKILL-MODES.md](SKILL-MODES.md) for the full mode system,
[SKILL-UNBOXED.md](SKILL-UNBOXED.md) for unboxed types.
