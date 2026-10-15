# OxCaml Changes: unreleased (after 5.2.0minus-39)

**`5.2.0minus-39` is the latest released OxCaml.** Everything in this
file describes unreleased tags and main-branch development:

- **Part I** — `5.2.0minus-39` → `5.2.0minus-40` (2026-06-09, the final
  unreleased tag on the OCaml 5.2 base).
- **Part II** — `5.2.0minus-40` → `5.4.0-ox1` (the upstream OCaml 5.4
  merge) → `5.4.0-ox2` (2026-07-02), plus post-ox2 main.

Do not assume any feature below is available on a released compiler.

---

# Part I: 5.2.0minus-39 to 5.2.0minus-40

40 first-parent merges. Headlines:

### `[@@flatten_floats]` becomes optional (#6106)

At minus-39, mixed `float`+`float#` records *require*
`[@@flatten_floats]`. From minus-40 the attribute is optional: such
records typecheck without it, and the default representation is
**non-flat** (the boxed `float` field is stored as a pointer).
`[@@flatten_floats]` opts back into flat storage. Non-flat mixed
records gain unboxed versions (`t#` works); `[@@flatten_floats]`
records still do not.

```ocaml
type t_non_flat = { f : float; u : float# }
(* minus-39: error; minus-40+: ok, f stored as pointer, t_non_flat# exists *)

type t_flat = { f : float; u : float# } [@@flatten_floats]
(* both: ok, f stored flat; no t_flat# *)
```

### Fields and constructor args of kind `any` (#5461, #6173)

Record fields, constructor arguments, inline-record fields, and
unboxed-record fields may have kind `any`. Gated by
`-extension layouts_beta` (under plain `layouts` it is an error).

```ocaml
type ('a : any) t = { fst : 'a; mutable snd : 'a }   (* accepted (beta) *)
let fst (t : int t) = t.fst      (* ok: instantiated at a representable type *)
let fst (type a : any) (t : a t) = t.fst
(* Error: Fields being projected must be representable. *)
```

Follow-up fixes: sort variables for `any` fields (#6145) and
constructor patterns (#6156), representation refinements (#6143),
topological jkind computation for recursive groups (#6177, #6209).

### `[@atomic]` field restrictions (#6131, #6124)

```ocaml
type t = { mutable f : float# [@atomic] }
(* Error: Atomic record fields must have layout value. *)

type t = { mutable f : float [@atomic]; u : float# }
(* Error: Atomic record fields are not permitted in mixed blocks. *)

type u = t_atomic#
(* Error: The type "t_atomic" has no unboxed version.
   Hint: Records with [@atomic] fields don't get unboxed versions. *)
```

The layout restriction is a soundness fix (some non-`value` cases
previously slipped through single-field and inline records).

### Experimental preemption becomes usable (#5913)

Building on the minus-39 groundwork (#4881), the handler API lands.
**Status: experimental, default-off, opt-in per fiber.**

New API in `Stdlib.Effect`:

```ocaml
type _ Effect.t += Preemption : unit t   (* performed when preempted *)
type tick_outcome = Preempt | Continue

module Deep.Preemptible : sig
  type ('a, 'b) handler =
    { retc : ...; exnc : ...; effc : ...;
      tickc : unit -> tick_outcome }     (* must be signal-safe *)
  val match_with : ('c -> 'a) -> 'c -> ('a, 'b) handler -> 'b
  val try_with :
    on_tick:(unit -> tick_outcome) -> ('b -> 'a) -> 'b
    -> 'a effect_handler -> 'a
end
module Shallow.Preemptible : sig ... (* continue_with etc. *) end
```

And in `Stdlib.Domain`:

```ocaml
val Domain.Tick.with_ :
  interval_usec:int -> (t @ local -> 'r) @ local once -> 'r
```

Run a computation via `Deep.Preemptible.match_with`/`try_with` with a
tick handler, and make the runtime tick via
`Domain.Tick.acquire ~interval_usec` or the scoped `Tick.with_`. On a
tick, handlers are consulted root-fiber-first; the first to return
`Preempt` gets a `Preemption` effect performed in its fiber. Unhandled
`Preemption` effects resume transparently. Preemption effectively
requires `--enable-poll-insertion` (allocation-free loops are
otherwise never preempted).

New C surface: `caml_continuation_is_preemption`,
`caml_continuation_gc_regs` (`fiber.h`);
`caml_domain_setup_preemption` / `caml_domain_reset_preemption`
(`domain.h`); `caml_process_pending_actions_flags{,_exn}`
(`signals.h`). Note `caml_domain_preempt_self` briefly existed and was
deleted — do not reference it.

### C API: stack-allocation regions (#6142)

```c
typedef intnat caml_region_t;
CAMLextern caml_region_t caml_region_begin(void);
CAMLextern void caml_region_end(caml_region_t);
```

Lets C code open/close a stack-allocation region so stack allocations
made by OCaml callbacks returning `local` values are freed at
`caml_region_end`. At region end there must be no remaining GC-root
reachable references into the region (clear `CAMLlocal` roots to
`Val_unit` first). Failing to end a region is fine — the next
`caml_region_end` closes all regions begun after it, so no need to call
it before `caml_raise`.

### Other Part-I changes

- **`OXCAML_RUNTIME` preprocessor symbol** (#6203):
  `runtime/caml/config.h` defines `#define OXCAML_RUNTIME 1` so C stubs
  can distinguish OxCaml from stock OCaml.
- **GC**: `Gc.quick_stat` is faster (#6139; a skipped-domain bug was
  fixed by #6164 before the tag). `OCAMLRUNPARAM=d=<too-large>` no
  longer aborts; the value is clamped (#6215).
- **Frametables go to `.rodata` by default** (#6094):
  `-frametables-in-rodata` / `-no-frametables-in-rodata`.
- **Match-in-match optimisation** (#4374): `-flambda2-match-in-match`
  (default off); `-flambda2-expert-cont-specialization-budget` is
  **renamed** to `-flambda2-expert-cont-specialization-threshold`.
- Soundness/panic fixes: `or_null` array segfault (#6185); array types
  with bottom-kind elements rejected (#6134).
- `ocamlnat`/`expect.opt` gained `-dunique-ids`, `-dno-unique-ids`,
  `-dlocations`, `-dno-locations` (#6159).
- **Magic number** 578 → 579 (#6204).
- Internals: normal-form morphisms (#5453), n-way join fixes (#6170),
  cfg-merge-blocks equality fix (#6223), fexpr completions
  (#6122, #5837), `%obj_xxx` primitive cleanup (#6080), the #5771
  array-element-kind meet fix (net-reverted by #6220).

---

# Part II: 5.2.0minus-40 to 5.4.0-ox2

This part covers two big steps in one window:

1. **`5.4.0-ox1`** (2026-06-12) is exactly one commit past `5.2.0minus-40`:
   the merge of **upstream OCaml 5.4** ("Merge upstream 5.4", #5325). The
   compiler's base moves from OCaml 5.2 to OCaml 5.4.0, bringing all
   upstream 5.3 and 5.4 features with it. `Sys.ocaml_version` is now
   `"5.4.0+ox"`.
2. **`5.4.0-ox2`** (2026-07-02) adds 98 PRs of OxCaml development on the
   new base, including the retirement of runtime 4.

The version naming scheme changed: `5.2.0minus-N` → `5.4.0-oxN`.

## At a glance

- **New OCaml base: 5.4.0.** Upstream 5.3/5.4 features arrive:
  **effect handler syntax** (`| effect E, k ->` in `match`/`try`),
  **atomic record fields** (`mutable f : int [@atomic]`,
  `[%atomic.loc]`, `Atomic.Loc`), **`Stdlib.Iarray`**, array-literal
  type-based disambiguation (`[| |]` can be `iarray`/`floatarray`),
  short functor types `(X : A) -> B`, UTF-8 identifiers, new stdlib
  modules `Pqueue`, `Pair`, `Repr`, and much more.
- **`effect` is a keyword by default** — code using it as an identifier
  breaks. Escape hatches: `-keywords 5.2` per file, `OCAMLPARAM
  keywords=5.2`, or `./configure --enable-keyword-edition=5.2`.
- **Runtime 4 is retired** (ox2, #6218): `runtime4/`, `systhreads4/`,
  `debugger4/` deleted; `--disable-runtime5` is a hard configure error.
- **New predefined type `'a box`** (ox2, #5342): `float# box = float`,
  `r# box = r` — the boxed version of an unboxed type, usable at kind
  `any`.
- **All-void variant constructors need
  `[@immediate_all_void_constructor]`** (ox2, #6256) — previously-valid
  `A of unit#` now errors without it.
- **Effect handlers force the enclosing function nonportable and
  stateful** (ox2, #6230) — effect cases no longer allowed in
  `portable`/`stateless` functions.
- **SIMD primitives on `float array`/`float iarray` removed** (ox2,
  #6128); use `floatarray` or `float# array` variants.
- **`val poly_` in signatures** (ox2, #6287); empty `let poly_` is now
  an error (#6195). Warning 217 removed; warning 219 added.
- **New unboxed-number names `int64_u`, `int32_u`, `nativeint_u`**
  (ox2, #6321) — predefined aliases; `int64#` etc. are slated for
  eventual removal, prefer the `_u` names.
- **Custom `[@@or_null]` payload shapes generalized** (ox2, #5830).
- **Raw-pointer primitives** `%unsafe_get_ext_ptr` /
  `%unsafe_set_ext_ptr` (ox2, #6350).
- **`[@@@implicit_kind]` now works in structures** (ox2, #6114).
- **Scannable axes on abstract and arbitrary kinds** (ox2, #5874,
  #6367).
- New flags: `-open-cmi`, `-experimental-optimizations`,
  `-keywords <version>`; new installed tool **`ocamlfilt`** (symbol
  demangler).
- **Magic numbers**: 579 → 580 (ox1) → 581 (ox2). Rebuild everything;
  ppx/tooling must be rebuilt against the 5.4-based compiler.

---

## Part 1: The upstream OCaml 5.4 merge (5.4.0-ox1)

### Effect handler syntax (upstream 5.3)

Deep effect handlers are now expressible directly in `match` and `try`:

```ocaml
type _ Effect.t += Poke : unit Effect.t

let f c i =
  match c i with
  | v -> v
  | exception Not_found -> 0
  | effect Poke, k -> Effect.Deep.continue k ()
```

OxCaml caveat (from ox2, #6230): a function containing effect cases is
forced **nonportable and stateful**:

```
Error: The pattern match with effect cases is "nonportable"
       but is expected to be "portable" ...
```

### `effect` is a keyword (upstream 5.3 + OxCaml keyword editions)

By default all keywords are enabled, so `effect` as an identifier no
longer parses. Three mitigations:

- `-keywords 5.2` (per compilation; also `ocamldep`/`ocamlprof`);
- `OCAMLPARAM=keywords=5.2`;
- OxCaml-only: bake the default into the compiler with
  `./configure --enable-keyword-edition=5.2` (supports e.g.
  `5.2+effect`).

OxCaml's own keywords (`borrow_`, `exclave_`, `kind_`, `local_`,
`poly_`, `stack_`, …) are unconditional regardless of edition.

### Atomic record fields (upstream 5.4)

Now an upstream feature (OxCaml had a variant of this already):

```ocaml
type t = { mutable readers : int [@atomic] }
let loc = [%atomic.loc t.readers]      (* : int atomic_loc *)
```

`Stdlib.Atomic.Loc` provides operations on `'a atomic_loc`, with
OxCaml mode/jkind annotations layered on. OxCaml restrictions from the
minus-40 window still apply: atomic fields must be layout `value`, no
mixed blocks, no unboxed version of the record.

### Immutable arrays and `[| |]` disambiguation (upstream 5.4)

- `'a iarray` and **`Stdlib.Iarray`** are now upstream.
  `Stdlib_stable.Iarray` remains as a compat shim
  (`include Stdlib.Iarray`, "re-oxidised" with modes/layouts);
  `Stdlib_stable.IarrayLabels` is retained (upstream has no labels
  version).
- **Array literals disambiguate by expected type**: `[| e1; e2 |]` can
  now mean `array`, `iarray`, or `floatarray` depending on context
  (default `array`; non-principality warning under `-principal`).
- OxCaml's `[: ... :]` literal syntax remains an OxCaml extension
  (enabled by default).

### Other upstream 5.3/5.4 language features

- **Short dependent functor types**: `(X : A) -> B` without the
  `functor` keyword, integrated with OxCaml mode annotations.
- **UTF-8 source files** and Latin-9-compatible Unicode identifiers.
- **Labeled tuples** are upstream in 5.4 — OxCaml already reconciled to
  the upstream version at minus-40, so no further change here.
- Better error messages throughout (5.3's "The constant "42" has
  type..." style, quoted identifiers, realigned hints) — expect-test
  output changes wholesale.
- New warning for `t as 'a` with unused `'a`
  (`unused-type-declaration`).
- **Link-order checking** for `.cma`/`.cmxa` creation and native
  linking (upstream 5.3) — can surface new errors in existing builds.
- Signature-avoidance tightening (upstream 5.4): programs that relied
  on silently-created abstract module types can newly fail.

### Upstream stdlib additions

New modules: **`Iarray`**, **`Pqueue`** (priority queues), **`Pair`**,
**`Repr`** (`Repr.phys_equal`/`Repr.compare` as explicit replacements
for `==`/polymorphic compare).

Notable additions to existing modules: `Char.Ascii`; `Gc.ramp_up`;
`String.edit_distance` / `String.spellcheck`; `Result.Syntax` (`let*`),
`Result.product`, `Result.error_to_failure`; `Dynarray` gains
`unsafe_to_iarray`, `equal`, `compare`, `mem`, `find_index`, etc. (and
moved to an unboxed representation in 5.3); `List.take`/`drop`/
`take_while`/`drop_while`/`singleton`; `Seq.filteri`, `Seq.singleton`;
`Either.get_left`/`get_right`; `Bool.logand`/`logor`/`logxor`;
`Queue.drop`; `Sys.poll_actions`, `Sys.signal_to_string`;
`Domain.self_index`; `Thread.set_current_thread_name`; `Unix.sigwait`.

Behavior changes to existing functions:

- `List.take`/`drop` no longer raise on negative n.
- `List.sort_uniq` keeps the *first* occurrence of duplicates.
- `Uchar.hash` is no longer `Uchar.to_int` — persisted
  `Hashtbl.Make(Uchar)` tables need rebuilding.
- `Filename.get_temp_dir_name` uses system calls on Windows.

OxCaml re-oxidised the merged stdlib: signatures carry modes and jkinds
(e.g. `Iarray`: `type (+'a : any mod separable) t`, `[@@layout_poly]`;
`List.take : ('a : value_or_null). ...`; `@@ portable` module
headers). Upstream-conformant code works unchanged.

### What OxCaml deliberately diverges on

- **Multiple domains remain off by default**: `--enable-multidomain`
  still gates them; `Domain.spawn` still carries the
  `do_not_spawn_domains` alert pointing at `Multicore`.
- Keyword editions (above) are an OxCaml-only escape hatch.
- `[: ... :]` iarray literals stay an OxCaml extension.
- `Stdlib_stable` compat layer kept (plus OxCaml-only modules:
  `Float32`, `Int8`/`Int16`, `Or_null`, `Idx_imm`/`Idx_mut`, …).

---

## Part 2: OxCaml development in 5.4.0-ox2

### Runtime 4 retired (#6218)

**BREAKING for build configuration.** `runtime4/` (~60k lines),
`otherlibs/systhreads4/`, and `debugger4/` are deleted.

- `./configure --disable-runtime5` is now a **hard error**: "OxCaml 5.4
  does not support runtime4 and must be configured with
  --enable-runtime5". `--enable-runtime5` is accepted as a no-op.
- `Config.runtime5` still exists and is always `true`; the `%runtime5`
  primitive always evaluates true.
- ocamltest predicates `runtime4`/`runtime5` were removed — delete them
  from TEST blocks.

### New predefined type: `'a box` (#5342)

A predefined covariant type constructor `box` (parameter kind `any`,
result kind `value`) that denotes the boxed version of a type and
reduces during unification:

```ocaml
float# box = float          int32# box = int32
int64# box = int64          nativeint# box = nativeint
int# box = int              'a ref# box = 'a ref
#(int64# * string) box = int64# * string

type r = { x : int }        (* r# box = r *)
type ('a : any) b = 'a box  (* float# b = float *)
```

No extension flag or new syntax needed. Nominality is preserved: for
`type u = #{ x : int }`, `u box` is *not* compatible with a distinct
record type of the same shape. Float records (which have no unboxed
version) don't unify with `_ box`. Unreduced applications print as
e.g. `int box`.

### All-void constructors need an attribute (#6256)

**BREAKING.** A constructor whose arguments are all void (or products
of voids) must now be annotated:

```ocaml
type t =
  | A of unit# [@immediate_all_void_constructor]
  | B of unit# * #(unit# * unit#) [@immediate_all_void_constructor]
  | C                (* nullary: unaffected *)
  | D of int         (* non-void: unaffected *)
```

Without the attribute: `Error: All arguments of the constructor "A"
are void, so it must be annotated with
"[@immediate_all_void_constructor]".` The annotation opts into a
planned representation change (tagged immediate → empty block).

### Custom `[@@or_null]` shapes generalized (#5830)

Still exactly two constructors (one nullary, one unary), but the
payload can now be anything:

```ocaml
type no_param = A | B of int [@@or_null]
type ('a, 'b) multi = Nope | Yep of ('a list * 'b) [@@or_null]
type fn = No_fn | Fn of (unit -> unit) @@ portable [@@or_null]
type f = No_float | Fl of float [@@or_null]
    (* result kind loses non_float/separable *)
```

Still rejected: >2 constructors, multi-argument payloads
(`B of int * int`), GADT constructors.

### Raw-pointer primitives (#6350, #6295)

New compiler primitives for off-heap access (no stdlib module — declare
the `external`s yourself):

```ocaml
external get_ext_ptr : ('a : any). int64# @ local -> 'a @ local
  = "%unsafe_get_ext_ptr" [@@layout_poly]
external set_ext_ptr : ('a : any). int64# @ local -> 'a @ local -> unit
  = "%unsafe_set_ext_ptr" [@@layout_poly]
(* also %unsafe_get_ext_ptr_imm *)
```

These take a raw address in an `int64#` (base+offset with NULL base) —
a supported replacement for `Obj.magic` pointer tricks. On bytecode
they compile but raise `Failure` at runtime. Writes to scannable
fields go through `caml_modify` on native. Separately, the
pre-existing interior-pointer primitives `%unsafe_get_ptr` /
`%unsafe_set_ptr` / `%unsafe_get_ptr_imm` (taking `#(base, offset)`)
are now implemented on bytecode too (#6295).

### Kinds and layout polymorphism

- **`[@@@implicit_kind]` in structures** (#6114): the floating
  attribute, previously signature-only, now works in structures and at
  the module toplevel:

  ```ocaml
  module M = struct
    [@@@implicit_kind: ('elt : bits64)]
    let f : 'elt -> 'elt array = fun x -> [| x |]
  end
  ```

  Implicit kinds are lexical defaults, not part of the interface; they
  don't survive `include`.

- **Scannable axes on abstract kinds** (#5874):

  ```ocaml
  module type S = sig
    kind_ k
    val get : ('a : k separable). 'a array -> 'a
  end
  ```

- **Scannable axes on arbitrary kinds** (#6367): parenthesized kinds,
  products, `mod`-kinds, `with`-kinds all accept a trailing axis:
  `type t : (value & value) non_pointer` (with warning 184
  `ignored-kind-modifier` where the axis has no effect). Parsetree
  jkind-annotation shape changed — relevant to ppx authors.

- **`val poly_` in signatures** (#6287): layout-polymorphic value
  descriptions:

  ```ocaml
  val poly_ mk : 'a -> 'b -> #('a * 'b)
  val poly_ mk2 : ('a : immediate) 'b. 'a -> 'b -> #('a * 'b)
  ```

  New **warning 219** `Useless_valpoly` when there are no
  layout-polymorphic variables. Combining `poly_` with `layout_`
  quantifiers is an error.

- **Empty `let poly_` is now an error** (#6195), not warning 217
  (which was removed): `Error: This binding has no layout variables,
  so "poly_" has no effect.`

- **New predefined aliases** (#6321): `int64_u = int64#`,
  `int32_u = int32#`, `nativeint_u = nativeint#`. Intent: these will
  later become abstract and the `#`-suffixed names will be deleted
  (they aren't true unboxed versions of the custom-block types) —
  **prefer the `_u` names in new code**. Spellcheck hints now suggest
  them (`Did you mean "int32" or "int32_u"?`).

### SIMD: float-array primitives removed (#6128)

**BREAKING for SIMD users.** All `%caml_float_array_get128/set128`
(and `get256/512`, unaligned `u` variants, and every
`_indexed_by_int8#/…/nativeint#` variant) on **`float array` and
`float iarray`** were removed — they can't work under
`--disable-flat-float-array`. The `floatarray`
(`%caml_floatarray_*`) and `float# array`
(`%caml_unboxed_float_array_*`) equivalents remain. Migrate externals
accordingly.

### Semantics alignment and smaller fixes

- **Bytecode deep-copies unboxed-product elements** on array/idx
  reads and writes (#6123), matching native semantics (previously
  mutation through one "copy" was observable through another on
  bytecode only).
- `Stdlib_stable.IarrayLabels.unsafe_init_local` is now
  `[@zero_alloc]`-compatible (#6147).
- `eval.mli` is installed with the compiler (#6207), fixing Merlin
  jump-to-definition for the metaprogramming `Eval` library.
- systhreads/preemption stability fixes: Tick handle released on
  normal thread termination (#6331), division-by-zero guard in the
  tick hook (#6329), no preemption continuation in the bytecode
  runtime (#6333), zombie-thread fix (#6345), dynamic-binding cache
  flushed on async unwind across fibers (#6341).
- Better error on corrupted `.cmxa` files (#6221); O(N²) linker
  module-tracking fixed — faster large links (#5807).
- The compiler itself is now built with `-O3` (#5778) — a faster
  compiler binary; no change to user flags.

### Compiler flags (ox1 → ox2)

| Flag | Purpose |
|------|---------|
| `-open-cmi <file.cmi>` | Like `-open`, but reads the signature from the given `.cmi` rather than resolving a module on the include path. Also in `ocamldep`. (#6013) |
| `-experimental-optimizations` | Enable a bundle of experimental codegen optimizations not yet on by default (currently: prologue shrink-wrap, x86 peephole, `SPLIT_AROUND_LOOPS`, `AFFINITY`, CFG merge-blocks / value-propagation / dead-trap-handler elimination, …). Subject to change; also an `OCAMLPARAM` key. (#6174) |
| `-keywords <version>[+kw]` | (from the 5.4 merge) select the keyword edition, e.g. `-keywords 5.2` to un-reserve `effect`. |
| `-dbranch-relaxation-max-displacement <n>` | Debug-only branch-relaxation testing knob. (#6309) |

Default flips: `-cfg-eliminate-dead-trap-handlers` is now **on** by
default (#6267).

New configure option (at ox1): `--enable-keyword-edition=X.Y[+kw]`.

New env vars: `OPT_FUEL_RECORD` / `OPT_FUEL_THRESHOLD` /
`OPT_FUEL_FAIL` for bisecting which optimization step miscompiles
(#5651, with `tools/fuel_bisect.py`).

### Tooling

- **`ocamlfilt`** (#5100): a pure-OCaml symbol demangler, installed to
  bin (`ocamlfilt` / `ocamlfilt.byte`). Handles pre-5.3 flat, post-5.3
  flat, and structured mangling schemes with auto-detection; reads
  symbols from argv or stdin.
- Effect implementation offsets emitted as ELF notes (#6274) and fiber
  ids recorded for magic-trace (#6032) — profiler support.

---

## Breaking changes and upgrade guide (minus-40 → ox2)

### 1. Recompile the world

Magic numbers went 579 → 580 (ox1) → 581 (ox2); the AST magic also
changed, so **ppx rewriters and anything reading
cmi/cmt/cmx must be rebuilt** against the 5.4-based compiler.
Version-sniffing code (dune constraints, ppx) must accept
`5.4.0+ox`.

### 2. `effect` keyword collisions

Rename identifiers called `effect`, or pass `-keywords 5.2` /
configure with `--enable-keyword-edition=5.2`.

### 3. Runtime 4 is gone

Drop `--disable-runtime5` from any configure invocation (now a hard
error) and delete `runtime4`/`runtime5` ocamltest predicates from
tests.

### 4. Annotate all-void constructors

Add `[@immediate_all_void_constructor]` to every variant constructor
whose arguments are all void.

### 5. Effect handlers vs. portability

`match`/`try` with `effect` cases makes the enclosing function
nonportable and stateful. Restructure `portable`/`stateless` code that
contained handlers (e.g. move the handler outside the portable
function).

### 6. SIMD on `float array`

Replace `%caml_float_array_*` externals with `floatarray` or
`float# array` variants.

### 7. `let poly_` with no layout variables

Now an error — delete the pointless `poly_`. If you matched on warning
217, it no longer exists; 219 is the new signature-side equivalent.

### 8. Expect tests / error-message churn

Upstream 5.3/5.4 rewrote many error messages ("The constant ... has
type", quoted `"identifiers"`, realigned hints). Re-promote expect
tests wholesale.

### 9. Stdlib behavior changes

`List.sort_uniq` (first duplicate wins), `List.take`/`drop` (no raise
on negative), `Uchar.hash` (rebuild persisted `Hashtbl.Make(Uchar)`
tables).

### 10. Link-order checking

Upstream 5.3 enforces dependency order when creating archives and
linking; previously-tolerated misordered builds can now fail.

### Upgrade checklist

1. **Rebuild everything** including ppx and tools (magic 579 → 581;
   version 5.2 → 5.4).
2. **Fix `effect` identifier collisions** or pin a keyword edition.
3. **Drop runtime4** from configure scripts and test predicates.
4. **Add `[@immediate_all_void_constructor]`** where required.
5. **Move effect handlers out of `portable`/`stateless` functions.**
6. **Migrate float-array SIMD externals.**
7. **Prefer `int64_u`/`int32_u`/`nativeint_u`** over `int64#` etc. in
   new code (the `#` names are slated for removal).
8. **Re-promote expect tests** for new error-message formats.
9. **Audit `List.sort_uniq`/`Uchar.hash` uses** for the upstream
   behavior changes.
10. **Enjoy the new toys**: effect syntax, `Iarray`, `Pqueue`, `Repr`,
    `'a box`, `val poly_`, `-open-cmi`, `ocamlfilt`.

---

## Compiler internals (condensed)

- **Flambda 2**: bottom-environment handling in join/reaper (#6348,
  #6349), poison values in terms (#6273), CSE of immutable array
  loads (#6300), switch-arg equations (#6373), classic-mode
  approximation fix for tagged immediates (#6283), inlining counts
  calls as removed operations (#5991), `Map.find_or_null` adoption
  (#6290). The "meet for array element kinds" fix (#5771) remains
  net-reverted.
- **ikinds**: recursive payload ikinds (#6199), temporary type
  declarations (#6201), abstract-kind substitution fix (#5998, in the
  -40 window), out-of-fuel note suppressed for ikind errors (#6197),
  nondep jkind bug (#6271).
- **Backend**: arm64 branch-relaxation fixes (#6309, #6311, #6388),
  unaligned 128-bit load/store on arm64 (#6388), monotone backwards
  jumps in the x86 binary emitter (#6025), ud2 guards for data in
  text (#6129), ZMM28 save/restore (#6252), macOS/amd64 runtime
  symbol fix (#9eca/#6320).
- **Representation plumbing**: `value_kind` recomputation for
  variable-representation constructors (#6307), inline records with
  `any` fields (#6240), layout bug for aliases in matching (#6152),
  `Punspecializedarray` array kind (#6101), small numbers as hidden
  env types (#6232).
- **Docs** (`jane/doc`): kind-syntax grammar refresh — `void`,
  `bits8/16`, `vec256/512`, `*_or_null` abbreviations, `any_non_null`
  removed (#6353); borrow-vs-stack-allocation interactions documented
  in `_07-uniqueness/borrow.md` (#6160): `exclave_` values cannot
  escape a `borrow_` region; implicit-kinds doc updated for
  structures (#6114).
