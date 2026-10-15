---
name: oxcaml-unboxed
description: "OxCaml unboxed types for heap-free storage including float#, int32#, unboxed records, mixed blocks, and or_null"
---

# OxCaml Unboxed Types: Detailed Guide

Unboxed types store values directly without heap allocation or pointer
indirection. They provide C-like performance for numeric code while maintaining
OCaml's type safety.

## Built-in Unboxed Types

### Numeric Types

| Boxed | Unboxed | Kind | Size | Literal |
|-------|---------|------|------|---------|
| `float` | `float#` | `float64` | 64-bit | `#3.14` |
| `int32` | `int32#` | `bits32` | 32-bit | `#42l` |
| `int64` | `int64#` | `bits64` | 64-bit | `#100L` |
| `nativeint` | `nativeint#` | `word` | native | `#50n` |
| `float32` | `float32#` | `float32` | 32-bit | `#1.0s` |
| `int8` | `int8#` | `bits8` | 8-bit | `#42s` |
| `int16` | `int16#` | `bits16` | 16-bit | `#42S` |
| `int` | `int#` | `untagged_immediate` | native | `#42m` (untagged) |
| - | `char#` | `bits8` | 8-bit | `#'a'` |
| `bool` | `bool#` | `bits8` | 8-bit | `#true` / `#false` |
| `unit` | `unit#` | `void` | 0 | `#()` |

The `bool#` and `unit#` entries are **new in 5.2.0minus-31** (PRs #5166
and #5156, respectively).

### Creating Unboxed Values

```ocaml
(* Literals use # prefix *)
let x : float# = #3.14159
let y : int32# = #42l
let z : int64# = #1_000_000L
let w : float32# = #2.5s
let c : char# = #'x'
let b : bool# = #true           (* or #false *)
let u : unit# = #()

(* From boxed values *)
let a : float# = Float_u.of_float 3.14
let b : int32# = Int32_u.of_int32 42l
```

### Unboxed Booleans (5.2.0minus-31+)

`bool#` has kind `bits8 mod everything`. It's a true primitive — no
allocation, no boxing, and constructors `#true` / `#false` work in both
expressions and patterns:

```ocaml
let classify (b : bool#) : int =
  match b with
  | #false -> 0
  | #true  -> 1

(* Flat in records *)
type flag = { enabled : bool#; count : int }
```

Use `bool#` where you previously reached for `int8#` as a boolean
surrogate — the intent is clearer and the compiler can specialise.

### Unboxed Unit (5.2.0minus-31+)

`unit#` has kind `void mod everything` and no runtime representation:

```ocaml
let discard (x : unit#) : int =
  match x with
  | #() -> 0

let noop () : unit# = #()
```

Typical uses: eliminating a final-continuation argument in generic
code; filler in kind products where something is required but carries
no information; modelling C-style `void` returns without boxing.

---

## Unboxed Records

Records with all unboxed fields are stored flat without indirection:

```ocaml
(* Unboxed record syntax: #{ } *)
type vec3 = #{ x : float#; y : float#; z : float# }

(* Create *)
let v : vec3 = #{ x = #1.0; y = #2.0; z = #3.0 }

(* Access uses .# *)
let get_x (v : vec3) : float# = v.#x

(* Pattern matching *)
let magnitude #{ x; y; z } =
  Float_u.sqrt (
    Float_u.add (Float_u.mul x x)
      (Float_u.add (Float_u.mul y y) (Float_u.mul z z))
  )
```

### Unboxed Record Characteristics

- No heap allocation for the record itself
- Passed by value (copied) to functions
- Cannot be recursive (no self-references)
- All fields must have known layout

---

## Unboxed Tuples

```ocaml
(* Unboxed tuple syntax: #( ) *)
type pair = #(float# * int32#)

let p : #(float# * int32#) = #(#1.0, #42l)

(* Destructure *)
let #(f, i) = p

(* In function signatures *)
let process : #(float# * float#) -> float# = fun #(a, b) ->
  Float_u.add a b
```

---

## Mixed Blocks

Records can mix boxed and unboxed fields. The C-visible layout version
is **v6** as of 5.2.0minus-39 (v5 in minus-31..38, v4 before that):

```ocaml
let _ = Stdlib_upstream_compatible.mixed_block_layout_v6
```

C code that asserts on mixed-block layout needs the matching macro:
`Assert_mixed_block_layout_v6`. v6 = all-value/void records are
uniform blocks, and all-`float64` records are mixed blocks by default.

### Records Mixing `float` and `float#` (changed in 5.2.0minus-39)

On the released 5.2.0minus-39, a record mixing boxed `float` and
unboxed `float#` **requires `[@@flatten_floats]`** — declaring one
without it is a hard error, and with it the boxed `float` fields are
stored flat inline (as pre-39 did automatically). Such records get no
unboxed (`t#`) version:

```ocaml
type t = { f : float; u : float# }
(* Error at minus-39: missing [@@flatten_floats] *)

type t_flat = { f : float; u : float# } [@@flatten_floats]
(* f stored flat inline; no t_flat# *)
```

UNRELEASED (minus-40+): the attribute becomes optional — unannotated
mixed records store the boxed `float` as a pointer and *do* get an
unboxed version.

All-`float64` records (`{ x : float#; y : float# }`) are mixed blocks
by default; `[@@represent_as_float_array]` restores the old
float-array representation (errors unless every field is `float64`).
Both attributes are part of the representation for module inclusion.

### `[@atomic]` Field Restrictions (UNRELEASED, 5.2.0minus-40+)

Atomic record fields must have layout `value`, are not permitted in
mixed blocks, and records with `[@atomic]` fields get no unboxed
version.

### All-Void Constructors (UNRELEASED, 5.4.0-ox2+)

A variant constructor whose arguments are all void must be annotated:

```ocaml
type t =
  | A of unit# [@immediate_all_void_constructor]
  | C
```

Without the attribute it is an error (preparation for a representation
change from tagged immediate to empty block).


```ocaml
type particle = {
  name : string;        (* boxed, on heap *)
  mass : float#;        (* unboxed, inline *)
  velocity : float#;    (* unboxed, inline *)
  charge : int32#;      (* unboxed, inline *)
}

let electron = {
  name = "electron";
  mass = #9.109e-31;
  velocity = #0.0;
  charge = #(-1l);
}
```

### Memory Layout

```
┌─────────────────────────────────┐
│ Header                          │
├─────────────────────────────────┤
│ name (pointer to string)        │  ← Boxed field
├─────────────────────────────────┤
│ mass (float64, 8 bytes)         │  ← Unboxed, inline
├─────────────────────────────────┤
│ velocity (float64, 8 bytes)     │  ← Unboxed, inline
├─────────────────────────────────┤
│ charge (int32, 4 bytes + pad)   │  ← Unboxed, inline
└─────────────────────────────────┘
```

---

## The `or_null` Type

A non-allocating option for **value** types. The argument must be a
non-null *value* type — despite living in the unboxed-types extension,
`float# or_null` and other unboxed arguments are **rejected**
(`type ('a : value) or_null`):

```ocaml
type 'a or_null = Null | This of 'a

(* No allocation: Null is encoded without a box *)
let find (arr : string array) idx : string or_null =
  if idx >= 0 && idx < Array.length arr then
    This arr.(idx)
  else
    Null

(* Pattern match *)
let get_or_default result default =
  match result with
  | Null -> default
  | This x -> x
```

### or_null vs option

```ocaml
(* option allocates the Some constructor *)
let f x : string option = Some x    (* Allocates! *)

(* or_null doesn't allocate *)
let g x : string or_null = This x   (* No allocation *)
```

### Custom `[@@or_null]` Types (5.2.0minus-38+, generalized in 5.4.0-ox2)

Any two-constructor variant (one nullary, one unary) can opt into the
same non-allocating null encoding:

```ocaml
type 'a maybe = Nope | Yep of 'a [@@or_null]

(* Since 5.4.0-ox2, the payload shape is unconstrained: *)
type no_param = A | B of int [@@or_null]
type ('a, 'b) multi = Nope | Yep of ('a list * 'b) [@@or_null]
type fn = No_fn | Fn of (unit -> unit) @@ portable [@@or_null]
```

Still rejected: more than two constructors, multi-argument payloads
(`B of int * int`), and GADT constructors. Re-export with
`[@@or_null_reexport]` (mutually exclusive with `[@@or_null]`).

---

## Unboxed and Untagged Arrays

Arrays of unboxed and untagged types are packed for memory efficiency:

```ocaml
(* Unboxed float array - tightly packed *)
let floats : float# array = [| #1.0; #2.0; #3.0 |]

(* Access *)
let first = floats.(0)  (* Returns float# *)

(* Unboxed int32/int64 arrays *)
let ints32 : int32# array = [| #1l; #2l; #3l |]
let ints64 : int64# array = [| #1L; #2L; #3L |]

(* Untagged small int arrays (NEW in 5.2.0minus-25) *)
let bytes : int8# array = [| #0s; #1s; #255s |]
let shorts : int16# array = [| #0S; #1S; #32767S |]
let ints : int# array = [| #0m; #1m; #42m |]   (* int# literal suffix is m *)
let chars : char# array = [| #'a'; #'b'; #'c' |]
```

### Array Memory Layout

| Array Type | Bytes per Element | Notes |
|------------|-------------------|-------|
| `float# array` | 8 | Dedicated array tag, packed |
| `float32# array` | 4 | Dedicated array tag, packed |
| `int64# array` | 8 | Dedicated array tag, packed |
| `int32# array` | 4 | Dedicated array tag, packed |
| `int# array` | native word | Untagged, packed |
| `int16# array` | 2 | Untagged, packed |
| `int8# array` | 1 | Untagged, packed |
| `char# array` | 1 | Same as int8# array |

The untagged int arrays use special block tags to encode the exact length
when the element count doesn't fill a whole word.

---

## Operations on Unboxed Types

### Float Operations (Float_u module)

```ocaml
open Stdlib_stable.Float_u

let compute x y =
  let sum = add x y in
  let product = mul x y in
  let root = sqrt sum in
  div root product
```

### Int32 Operations (Int32_u module)

```ocaml
open Stdlib_stable.Int32_u

let hash x y =
  let a = mul x #31l in
  add a y
```

### Conversion Functions

```ocaml
(* To/from boxed *)
let box (x : float#) : float = Float_u.to_float x
let unbox (x : float) : float# = Float_u.of_float x

(* Between sizes *)
let widen (x : int32#) : int64# = Int64_u.of_int32 (Int32_u.to_int32 x)
```

---

## Kinds and Unboxed Types

Unboxed types have non-`value` kinds:

```ocaml
(* Kind annotations *)
type ('a : float64) float_container = { f : 'a }
type ('a : bits32) int32_container = { i : 'a }

(* Polymorphic over layout *)
type ('a : any) wrapper = { data : 'a }  (* Accepts any layout *)
```

### Kind Constraints

```ocaml
(* Function polymorphic over float64 kind *)
val process : ('a : float64). 'a -> 'a

(* Can be called with float# *)
let result = process #3.14
```

---

## Common Patterns

### High-Performance Numeric Loop

```ocaml
let dot_product (a : float# array) (b : float# array) : float# =
  let len = Array.length a in
  let mutable acc = #0.0 in
  for i = 0 to len - 1 do
    acc <- Float_u.add acc (Float_u.mul a.(i) b.(i))
  done;
  acc
```

### Unboxed Pair Return

```ocaml
let minmax (arr : float# array) : #(float# * float#) =
  let mutable min_val = arr.(0) in
  let mutable max_val = arr.(0) in
  for i = 1 to Array.length arr - 1 do
    let v = arr.(i) in
    if Float_u.compare v min_val < 0 then min_val <- v;
    if Float_u.compare v max_val > 0 then max_val <- v
  done;
  #(min_val, max_val)
```

### Nullable Lookup

`or_null` only accepts value types, so a nullable *unboxed* result
needs a validity flag or sentinel instead:

```ocaml
type cache = {
  data : float# array;
  valid : bool array;
}

(* Returns #(found, value); value only meaningful when found *)
let lookup (c : cache) idx : #(bool * float#) =
  if idx >= 0 && idx < Array.length c.data && c.valid.(idx) then
    #(true, c.data.(idx))
  else
    #(false, #0.0)
```

### Mixed Block with Methods

```ocaml
type complex = {
  re : float#;
  im : float#;
}

let complex_add a b = {
  re = Float_u.add a.re b.re;
  im = Float_u.add a.im b.im;
}

let complex_mul a b = {
  re = Float_u.sub (Float_u.mul a.re b.re) (Float_u.mul a.im b.im);
  im = Float_u.add (Float_u.mul a.re b.im) (Float_u.mul a.im b.re);
}
```

---

## C Interop

### External Declarations

```ocaml
(* Unboxed externals - no boxing overhead *)
external sin : (float[@unboxed]) -> (float[@unboxed]) =
  "caml_sin_float" "sin" [@@unboxed] [@@noalloc]

(* With float# directly *)
external fast_sin : float# -> float# =
  "boxed_sin" "unboxed_sin"
```

### C Implementation

```c
#include <caml/mlvalues.h>

// Unboxed version - called directly
double unboxed_sin(double x) {
  return sin(x);
}

// Boxed wrapper
CAMLprim value boxed_sin(value v) {
  return caml_copy_double(unboxed_sin(Double_val(v)));
}
```

---

## Small-Int Bit Intrinsics (5.2.0minus-31+)

`ctz`, `clz`, and `popcnt` are now available for `int8#` and `int16#`
(#5393). On x86 the runtime exposes:

- `caml_popcnt_int16`
- `caml_lzcnt_int16`
- `caml_bmi_tzcnt_int16`

Use these in conjunction with packed `int8# array` / `int16# array`
storage to keep bit-level loops in register-resident code paths.

---

## Small-Int Indexing (5.2.0minus-31+)

Arrays, strings, bigstrings, and bytes can now store `int8`/`int16#`
values and be indexed by `int8#` / `int16#` (#4779). New primitives:

- `%caml_bytes_geti8`, `%caml_bytes_geti16` (sign-extending reads)
- `get8` / `set8` / `set16` family with `*_indexed_by_*` variants

---

## Pitfalls

### Cannot Use Unboxed in Polymorphic Context

```ocaml
(* ERROR: 'a defaults to kind value *)
let id x = x
let _ = id #3.14  (* Type error! *)

(* FIX: Add kind annotation *)
let id (type a : float64) (x : a) = x
let _ = id #3.14  (* OK *)
```

### Cannot Store Unboxed in Option — or in or_null

```ocaml
(* ERROR: option expects value kind *)
let bad : float# option = Some #3.14

(* ALSO AN ERROR: or_null expects value kind too *)
let bad2 : float# or_null = This #3.14

(* FIX: box at the boundary, or use an unboxed tuple with a flag *)
let good : float option = Some (Float_u.to_float #3.14)
let good2 : #(bool * float#) = #(true, #3.14)
```

### Unboxed Records Are Copied

```ocaml
type point = #{ x : float#; y : float# }

let modify (p : point) : point =
  (* This creates a new point, doesn't modify p *)
  #{ x = Float_u.add p.#x #1.0; y = p.#y }
```

---

## Performance Tips

1. **Use unboxed types in hot loops** - eliminates allocation
2. **Prefer `let mutable` over `ref` for unboxed accumulators**
3. **Use unboxed arrays for numeric data**
4. **Use `or_null` instead of `option` for nullable value types**
   (unboxed types are not accepted by either)
5. **Use `[@unboxed]` on external declarations**

See also: [SKILL-KINDS.md](SKILL-KINDS.md) for the kind system,
[SKILL-ZERO-ALLOC.md](SKILL-ZERO-ALLOC.md) for allocation-free code.
