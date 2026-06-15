# OxCaml Changes: 5.2.0minus-31 to 5.2.0minus-38

This document summarizes the key changes between OxCaml versions 5.2.0minus-31
and 5.2.0minus-38. The opam package is `oxcaml-compiler.5.2.0minus38`, still
shipping `ocaml-variants.5.2.0+ox` on top of an upstream OCaml 5.4.0
bootstrap.

## At a glance

For users tracking the headline changes:

- **Runtime metaprogramming graduated alpha → beta** (#5843). Quotes and
  splices (`<<e>>` / `$(e)`) are now usable with `-extension-universe beta`
  instead of `alpha`. `[%eval]` is gone — it's a normal function
  `Eval.eval : 'a expr -> 'a eval` in a new `eval` library.
- **New mode lattices**: visibility/statefulness and contention/portability
  became **diamonds**, with `write`/`writing` (#5608) and
  `corrupted`/`corruptible` (#5713) joining the existing chains.
  `observing` has been **renamed to `reading`** (#5712).
- **Runtime 5 is now the default** for `./configure` (#5780). The
  per-domain "tick thread" moved into the runtime itself (#5349), with a new
  `OCAMLRUNPARAM='T=<microsec>'` knob.
- **Block-index array syntax was deleted**. `.(0)`, `.:(0)`, `.L(i)`,
  `.l(i)`, `.S(i)`, `.s(i)`, `.n(i)` no longer parse; create indices via
  `Stdlib_stable.Idx_mut.unsafe_create_into_array` /
  `Idx_imm.unsafe_create_into_iarray` (#5556).
- **`Idx_*.unsafe_get`/`unsafe_set` renamed** to `.get`/`.set`. Reading and
  writing via an existing index is no longer marked `unsafe_`; only the
  creation step into an array is (#5556).
- **`bits64_internal` and other `_internal` kind escape hatches were
  removed** (#5490). The opt-out introduced in -31 is gone.
- **Custom `or_null` types**: you can attach `[@@or_null]` to any
  two-constructor variant `Nope | Yep of 'a` to get the same non-allocating
  null encoding as built-in `'a or_null` (#5668).
- **`-O4` = `-O3` + reaper** (#5574). The reaper pass now has a numeric
  optimisation level.
- **Mode-only expression constraints**: `(e : @ modes)` parses — you no
  longer need the `: _ @ modes` workaround (#5602).
- **`with kind_` constraints** on signatures (#5629), completing the
  abstract-kinds work.

---

## Major Language Features

### Runtime metaprogramming: alpha → beta (#5843)

The runtime-metaprogramming extension graduates from `alpha` to `beta`.

```sh
# Before
ocamlopt -extension-universe alpha ...

# Now
ocamlopt -extension-universe beta ...
```

Behaviour is the same as in -31 but considerably stricter: quote and splice
typing is now sound with respect to kinds, modes, and (largely) GADTs, so
some code that previously type-checked may need annotations.

`[%eval]` as an extension point is gone (#5657). It's now a normal
function in a new `otherlibs/eval` library:

```ocaml
(* Old *)
let n = [%eval: int] <[ 42 ]>

(* New *)
let n = Eval.eval <[ 42 ]>    (* val eval : 'a expr -> 'a eval *)
```

Two new compiler flags drive linking:

- `-requires-metaprogramming` is set on units that call `Eval.eval`. The
  flag is recorded in their `.cmx`/`.cmxa`.
- `-uses-metaprogramming` must be passed when linking a binary that
  contains any such unit. It auto-links `unix`, `ocamlcommon`,
  `ocamloptcomp`, and `jit` (but not `eval.cmxa` itself). The linker
  errors if a unit's `requires_metaprogramming` flag is set but the
  binary wasn't linked with `-uses-metaprogramming`.

If you depend on the library by name in `META`, dune, or manifest files,
rename it: **`camlinternaleval` → `eval`**.

Other user-visible changes in the same area:

- **`let poly_` is now type-checked** rather than parsed-and-erroring
  (#5513). Layout-poly instantiation goes through a new
  `Texp_apply_layout` node (#5634); the new `-Ix <dir>` flag (#5654)
  marks include directories whose `.cmx`s are guaranteed available
  (eventually for layout-poly).
- **Quotes of expansive expressions** are at mode `once` (#5698).
- **Mode annotations under quotes** are supported (#5670); kinding and
  moding of quotes/splices are now sound (#5636, #5697).
- **REPL fixes**: `#metaprog` directive issue (#5801); graceful errors
  for unsupported language features under quotes (#5823).

### New modes: `write`/`writing` and `corrupted`/`corruptible`

OxCaml's mode lattices were extended from three-element chains into
**diamonds**:

```
contention:                visibility:
    contended                  immutable
        |                          |
 shared | corrupted          read | write
        |                          |
    uncontended               read_write

portability:               statefulness:
   nonportable                 stateful
        |                          |
shareable | corruptible     reading | writing
        |                          |
    portable                   stateless
```

- **`write` visibility / `writing` statefulness** (#5608) are the duals of
  `read` and `reading`: `write` permits *write-only* access to mutable
  fields, `writing` closures may write but not read closed-over mutable
  state.
- **`corrupted` contention / `corruptible` portability** (#5713) are the
  analogues on the parallelism axes: a `corrupted` value can be written
  by other threads but not read; a `corruptible` function only closes
  over corrupted values.
- **`observing` is renamed to `reading`** for symmetry with `writing`
  (#5712).

Examples:

```ocaml
(* read/write are incomparable: both are submodes of read_write, both
   are supermodes of immutable *)
let mostly_const : int ref @ write -> unit = fun r ->
  r := 0      (* allowed: write is permitted *)
  (* let _ = !r in ... — would be an error *)

(* A modality combining read and write yields immutable (their join). *)
type 'a t = { field : 'a @@ write }
let f : 'a t @ read -> 'a @ immutable = fun t -> t.field
```

The implication table in `_05-modes/syntax.md` grew accordingly:

| this         | implies this  |
|--------------|---------------|
| `reading`    | `shareable`   |
| `writing`    | `corruptible` |
| `stateful`   | `nonportable` |
| `write`      | `corrupted`   |
| `read_write` | `uncontended` |

The mode grammar is now:

```
contention   ::= uncontended | shared | corrupted | contended
portability  ::= portable | corruptible | shareable | nonportable
visibility   ::= read_write | read | write | immutable
statefulness ::= stateless | writing | reading | stateful
```

The new `jane/doc/extensions/_05-modes/reference.md` documents how
modality application and mode crossing interact with diamond axes:
applying a modality to a future mode takes the **meet**, applying to a
past mode takes the **join**.

### Mode-only expression constraints (#5602)

You can now write a mode constraint on an expression without naming a
type:

```ocaml
(* Old: had to write a placeholder type *)
let x = (e : _ @ portable) in ...

(* New *)
let x = (e : @ portable) in ...

(* Combined as before *)
let x = (e : int @ portable) in ...
```

### Custom `or_null` types (#5668)

User code can declare its own two-constructor null-encoded variants. Add
`[@@or_null]` to a type whose constructors are a no-payload "null" case
and a single-payload "this" case:

```ocaml
type 'a maybe = Nope | Yep of 'a [@@or_null]
type 'a flipped = Yep_first of 'a | Nope_last [@@or_null]
```

These get the same non-allocating null encoding as the built-in `'a
or_null`. Compile-time checks reject shapes that aren't expressible. A
type can also be re-exported with `[@@or_null_reexport]`; combining
`[@@or_null]` and `[@@or_null_reexport]` on the same declaration is an
error.

### `with kind_` constraints (#5629)

Module-type signatures can now refine abstract kind declarations from an
included signature:

```ocaml
module type S = sig kind_ k end
module type S1 = S with kind_ k = value mod portable
module type S2 = S with kind_ k := value mod global   (* destructive *)
```

Combined with kind declarations in recursive modules (#5517) and the
`kind_of_` family of attributes, this completes the abstract-kinds work
that began in earlier tags.

### `[@unpacked]` for product arguments in C stubs (#5610)

When passing unboxed product types to C, `[@unpacked]` requests the
"all fields as separate C arguments" calling convention instead of
boxing the product first.

### Pointerness scannable axis (#5484)

`non_pointer` joins `non_float`/`separable`/etc. as a scannable axis,
giving the lattice
`non_pointer < non_pointer64 < non_float < separable < maybe_separable`.
The intro doc (`_03-unboxed-types/01-intro.md`) was rewritten to explain
the value-layout lattice carefully.

Consequence: `immediate` is now layout `value non_pointer` (and crosses
all modal axes); `immediate64` is `value non_pointer64`. The docs no
longer call them "sublayouts of `value`" — they are **subkinds**. If you
have expect tests that quote the printed kind of `immediate`, those
need updating.

### Block-index array syntax replaced by primitives (#5556)

The language-level array-block-index forms are **gone**:

| Old syntax              | New API                                           |
|-------------------------|---------------------------------------------------|
| `.(i)`                  | `Idx_mut.unsafe_create_into_array i`              |
| `.:(i)`                 | `Idx_imm.unsafe_create_into_iarray i`             |
| `.L(i)` / `.l(i)` / `.S(i)` / `.s(i)` / `.n(i)` | `Idx_*.unsafe_create_into_*_indexed_by_int64` (and friends) |
| `.foo`, `.idx_mut(i)`, `.idx_imm(i)`, `.#bar` | **unchanged** (record fields & block-index access still use syntax) |

Reading and writing through an existing index lost its `unsafe_` prefix:

```ocaml
(* Old *)
let first () : (int array, int) idx_mut = (.(0))
let bump pts i = Idx_mut.unsafe_set pts i (Idx_mut.unsafe_get pts i + 1)

(* New *)
let first () : (int array, int) idx_mut =
  Stdlib_stable.Idx_mut.unsafe_create_into_array 0
let bump pts i =
  Stdlib_stable.Idx_mut.set pts i (Stdlib_stable.Idx_mut.get pts i + 1)
```

The `unsafe_` lives only at array-index *creation*, which is the only
operation that can be out of bounds. The full new surface (from
`Stdlib_stable.Idx_mut`/`Idx_imm`):

```ocaml
type ('a : value_or_null, 'b : any) t = ('a, 'b) idx_mut

val get : 'a -> ('a, 'b) idx_mut -> 'b               (* %get_idx *)
val set : 'a -> ('a, 'b) idx_mut -> 'b -> unit       (* %set_idx *)

val unsafe_create_into_array : int -> ('a array, 'a) idx_mut
val unsafe_create_into_array_indexed_by_int8    : int8#    -> _
val unsafe_create_into_array_indexed_by_int16   : int16#   -> _
val unsafe_create_into_array_indexed_by_int32   : int32#   -> _
val unsafe_create_into_array_indexed_by_int64   : int64#   -> _
val unsafe_create_into_array_indexed_by_nativeint : nativeint# -> _
```

`Idx_imm` is the read-only counterpart for immutable arrays.

The first parameter of indices is now `value_or_null` (#5559), and you
can deepen `value_or_null` indices (#5735).

### Removal of `bits64_internal` and other `_internal` kinds (#5490)

The `_internal` escape hatch introduced in `5.2.0minus-31` to opt
*out* of the implicit `mod external_` on non-`value` base kinds has
been **removed**. Non-`value` base kinds always imply `mod external_`
now, with no way back. If you migrated to `bits64_internal` (etc.)
between -31 and -32, you must un-migrate: there is simply no
replacement, and the combination "`float64`-layout, not `mod
external_`" is no longer expressible in a kind annotation. The
`_06-kinds/non-modal.md` doc was rewritten accordingly.

---

## Runtime / Parallelism

### Runtime 5 is now the default (#5780)

`./configure` with no explicit runtime flag now selects **runtime5**.
Previously you had to pass `--enable-runtime5`. To get runtime4 build,
pass `--disable-runtime5` explicitly. The opam package for
`5.2.0minus-38` configures with:

```
--enable-runtime5 --enable-stack-checks
--enable-poll-insertion --enable-multidomain
```

### Tick thread moved into the runtime (#5349)

The per-domain "tick thread" — which existed only in `systhreads` to
call `thread_yield()` every 50 ms — has moved into `runtime/domain.c`
and now runs at a much higher default frequency (250µs, matching the
parallel scheduler's heartbeat). External-interrupt hooks are replaced
by tick hooks, called every tick rather than only when systhreads
decided to interrupt the GC. Lays groundwork for runtime-driven fiber
preemption.

Configurable via `OCAMLRUNPARAM`:

```sh
OCAMLRUNPARAM='T=250' ./prog    # 250 µs tick interval (default)
OCAMLRUNPARAM='T=50000' ./prog  # 50 ms, like pre-#5349
```

Follow-ups in the same window:

- **`fork()` safety** (#5829): tick thread state is reset in the child
  process, so `Unix.fork` from a multithreaded program continues to work.
- **`epoll_wait` `EINTR`** no longer fatal-errors (cf4805a312).
- **Onload-compatibility workaround** (#6016): sets `tick_use_usleep`
  when Onload is detected, sidestepping high CPU on systems with
  libraries that hook `epoll_wait`.

### Parallelism / Multicore

- **`Domain.max_domain_count`** added (#5522).
- **`Gc.Memprof.enlist_all_domains`** added (#5644) — wires a memprof
  callback into every existing and future domain. (Originally named
  `participate_globally`; landed as `enlist_all_domains`.)
- **`Atomic.make_contended`** now works on `runtime4` (equivalent to
  `Atomic.make` there) so library code can use the stdlib API
  unconditionally (#5640).
- **`Multicore` keeps domains alive** (#5638), addressing long join
  times caused by the ticker thread.
- **`Multicore.resource`** type is now `value_or_null` (#5579).
- **Memprof parallel-stop races** fixed (#5600).

---

## Stdlib / Stdlib_stable

- **`Bigarray.Genarray.create`** and friends return values at mode
  `@ unique` (#5767), so freshly-allocated bigarrays can flow through
  uniqueness pipelines.
- **More `local` annotations** in `Bigarray.Array1` (`sub`,
  `change_layout`, etc. are now `@local_opt`) (#5505).
- **Iarray fixes** synced from `iarray.ml` to `iarrayLabels.ml` (#5683).
- **`Idx_mut` / `Idx_imm`** see "Block-index array syntax replaced" above.

---

## Compiler Flags

OxCaml-specific flags live in `driver/oxcaml_args.ml`; the new
optimisation level, `-Ix`, and metaprogramming linking flags live in
`driver/main_args.ml`.

| Flag | Purpose |
|------|---------|
| `-O4` | `-O3` plus the reaper pass. Flambda 2 only. (#5574) |
| `-Ix <dir>` | Like `-I`, but signals that `.cmx` files in `<dir>` are guaranteed available. Lays groundwork for layout-poly. (#5654) |
| `-thunkify-compilation-unit-initialization` | Wrap each unit's init in a closure. Used by `wasm_of_ocaml` to shrink the init function. (#5720) |
| `-requires-metaprogramming` | Record in `.cmx`/`.cmxa` that this unit needs the metaprogramming support libraries. (#5657) |
| `-uses-metaprogramming` | Mark a final binary as supporting metaprogramming; replaces the old `Camlinternaleval` linker auto-detection. (#5657) |
| `-x86-peephole-optimize` / `-no-x86-peephole-optimize` | Enable/disable the x86-specific peephole pass. (#5639) |
| `-no-x86-peephole-remove-mov-to-dead-register` | Selectively disable one x86 peephole. (#5639) |
| `-no-x86-peephole-remove-redundant-cmp` | Selectively disable one x86 peephole. (#5639) |
| `-no-x86-peephole-combine-add-rsp` | Selectively disable one x86 peephole. (#5639) |
| `-cfg-merge-blocks` / `-no-cfg-merge-blocks` | Merge equivalent CFG blocks. (#5597) |
| `-cfg-value-propagation-flow` / `-no-cfg-value-propagation-flow` | Propagate values across blocks in the CFG simplifier. (#5562) |
| `-reaper-max-unbox-size <n>` | Cap how many fields the reaper will unbox from one block. (#5572) |

The undocumented debug flag `-dflexpect-to` was **removed**.

### Environment variables

- `OXCAML_NAME_MANGLING={flat,structured}` selects the symbol-mangling
  scheme (#5097, #5099). Default `flat`. See "Name mangling" below.
- `OCAMLRUNPARAM` gained `T=<microseconds>` for the in-runtime tick
  thread (#5349).

---

## Documentation Updates

User-visible changes to `jane/doc/extensions/`:

- **New**: `_05-modes/reference.md` — modality application via meet/join,
  mode crossing on diamond axes.
- **Modes intro and syntax** updated for `write`/`corrupted`/`reading`
  with new diamond diagrams and an extended implication table.
- **Unboxed types intro** (`_03-unboxed-types/01-intro.md`) rewritten to
  spell out the value-layout lattice (nullability + separability + new
  pointerness axis), and how `immediate` / `immediate64` relate to it.
- **Block indices** (`_03-unboxed-types/03-block-indices.md`) reflect the
  syntax → `unsafe_create_into_*` migration and the `.get`/`.set` rename.
- **Kinds docs renumbered** (#5448): `intro.md` → `01-intro.md`,
  `syntax.md` → `02-syntax.md`, `non-modal.md` → `03-non-modal.md`,
  `types.md` → `04-types.md`, `implicit.md` → `05-implicit.md`. The
  leading number is hidden from Jekyll links (#5515).
- **Kinds syntax** doc was substantially expanded (#5448), with a full
  syntax reference.
- **Non-modal bounds** (`_06-kinds/03-non-modal.md`) rewritten — the
  `_internal` documentation is gone (because the suffix is gone).

---

## Breaking changes and upgrade guide

Address in roughly this order.

### 1. Rename `observing` → `reading`

```ocaml
(* Old *)
let f : 'a -> 'b @ observing = ...
(* New *)
let f : 'a -> 'b @ reading = ...
```

### 2. Migrate block-index array syntax

```ocaml
(* Old *)
let i : (int array, int) idx_mut = (.(0))
let v = Idx_mut.unsafe_get arr i
let () = Idx_mut.unsafe_set arr i (v + 1)

(* New *)
let i : (int array, int) idx_mut =
  Stdlib_stable.Idx_mut.unsafe_create_into_array 0
let v = Stdlib_stable.Idx_mut.get arr i
let () = Stdlib_stable.Idx_mut.set arr i (v + 1)
```

For immutable arrays use `Idx_imm.unsafe_create_into_iarray`. The
`int{8,16,32,64}#`/`nativeint#`-indexed variants use the suffixed
`_indexed_by_*` functions.

### 3. Remove `*_internal` kind annotations

`bits64_internal`, `bits32_internal`, etc. no longer exist. Non-`value`
base kinds always imply `mod external_`. If you genuinely need a
`bits*`-layout type that *isn't* `mod external_`, that combination is no
longer expressible — restructure to use `value` instead.

### 4. Runtime metaprogramming: alpha → beta

If you were enabling metaprogramming with `-extension-universe alpha`,
switch to `beta`. Be prepared for stricter kind/mode/staging checks —
some annotations that were previously inferred may need to be explicit.

### 5. `Eval.eval` replaces `[%eval]`

```ocaml
(* Old *)
let n = [%eval: int] <[ 42 ]>

(* New *)
let n = Eval.eval <[ 42 ]>
```

The library was renamed from `camlinternaleval` to `eval`. Update
`META`/`dune`/manifest references. Compile units using `Eval.eval` with
`-requires-metaprogramming`; link binaries containing such units with
`-uses-metaprogramming`. The linker errors if these don't match.

### 6. Runtime 5 is the default

`./configure` with no flag now picks runtime5. If you specifically need
runtime4, pass `--disable-runtime5` explicitly.

### 7. Tick-thread defaults

`thread_yield()` is now driven from the runtime at a 250µs default, not
50ms. Code that polled `Sys.time` from systhreads in tight loops may see
slightly different scheduling. Use `OCAMLRUNPARAM='T=50000'` to restore
the old 50ms behaviour.

### 8. Regalloc defaults flipped

- `SPLIT_AROUND_LOOPS` is now on by default (#5761). To restore: pass
  `-regalloc-param SPLIT_AROUND_LOOPS:false`.
- Prologue shrink-wrap is on by default (#5762). To restore: pass
  `-no-cfg-prologue-shrink-wrap`.

### 9. `ocamlformat` upgraded to 0.29.0 (#5777)

The tree was reformatted. `oxcaml-dev.opam` has the right constraint.
Downstream projects may wish to bump for diff-friendly merges.

### 10. `-dflexpect-to` removed

The combined `-drawfexpr` + `-dfexpr` dump flag is gone. Use
`-dfexpr-annot` or `-drawfexpr` separately.

### 11. `immediate` / `immediate64` vocabulary

The intro doc no longer calls them "sublayouts of `value`"; they are
**subkinds**. The layouts are `value non_pointer` and
`value non_pointer64`. Expect tests that quote the printed kind of
`immediate` need updating.

### 12. Magic numbers bumped (four times)

`.cmi`/`.cmo`/`.cmx`/`.cma`/`.cmxa`/`.cmt`/`.cms` magic numbers were
bumped at -32 (#5500), -34 (#5624), -35 (#5741), and -37 (#5868).
Files produced by `5.2.0minus-31` cannot be loaded by `5.2.0minus-38`
and vice versa — recompile from clean.

### Upgrade checklist

1. **Recompile from clean** — magic numbers bumped four times.
2. **Rename `observing` → `reading`** in mode annotations.
3. **Migrate block-index array syntax** to
   `Idx_*.unsafe_create_into_*` and `.get` / `.set`.
4. **Remove `*_internal` kind annotations.** No replacement exists.
5. **If you use runtime metaprogramming**: switch
   `-extension-universe alpha` → `beta`; replace `[%eval]` with
   `Eval.eval`; pass `-requires-metaprogramming` /
   `-uses-metaprogramming` appropriately; rename library references
   `camlinternaleval` → `eval`. Re-typecheck for stricter
   kind/mode/staging.
6. **If you ship for runtime4**: make `./configure` pass
   `--disable-runtime5` explicitly.
7. **If you have careful regalloc profiling**: the
   `SPLIT_AROUND_LOOPS` and prologue-shrink-wrap defaults flipped.
8. **If you build for wasm**: consider
   `-thunkify-compilation-unit-initialization`.
9. **If you have tooling that reads `.cmx`s**: a new
   `requires_metaprogramming` flag is recorded in the export info.

---

## Compiler internals

The rest of this document is implementation detail. Most users will not
need to know about these unless they are tracking compiler performance,
hacking on the compiler itself, or hitting a backend bug.

### Static evaluator and slambda (metaprogramming infrastructure)

A new `slambda` IR (#5430) sits between `lambda` and `flambda`/bytecode.
Compile-time computations are evaluated as `slambda` and "fractured"
into a runtime half (#5544). The first real evaluator landed in #5512,
returning evaluated compile-time values; static modules (#5724)
arrived shortly after. `slambdaeval` knows about missing record
fields, integer/float/string primitives, etc. `Eval.eval` itself was
trimmed to ~26 lines in the post-merge review (#5739).

### Reaper

The reaper pass — a Flambda 2 dead-field-and-arg eliminator that can
also unbox arguments — saw heavy work:

- **`-O4` shortcut** (#5574) and **max-unbox-size cap** (#5572).
- Local-fields support enabled at `-O4` (#5619); CI for reaper +
  local value slots (#5588).
- `dep_solver` split (#5776, #5787); generic datalog helpers extracted
  (#5576).
- Correctness fixes: rewrite of let-bound vars (#9313947ca7),
  exception-param protection (#5563), constants in rewritten types
  (#5391), unused fields of symbols (#5540), changing block
  representation (#5604), local-field deadlock (#5648), `cannot_unbox0`
  ordering (#5528), mutable-load fix (#5547, #5655), occur check (#5537),
  too-many-args fix (#5633), unbound-vars fix (#5725).
- Diagnostics polish: `COULD NOT IDENTIFY` gated behind a debug flag
  (#5518); stamp suppression (#5573, #5700); rename
  `coaccessor`/`coconstructors` (#5681); cleanups (#5539, #5744, #5748);
  better errors (#5521, #5611); profile calls (#5759); `assert false`
  → `fatal_errorf` (#5549); `Not_found` → fatal error (#5595).
- Hack for `zero_alloc` with local fields (#5593); reaper does not
  export top-level functions in cmx (#5590); `-dreaper` does the
  intuitive thing (#5764).

### Flambda 2 / optimizer

- **N-way join**: extra params for created variables (#5751); fix join
  of symbol projections (#5745); missing-cmx variables exist in all
  envs (#5679); untagged const-false for nullability (#5718).
- **Code-age relation** is more conservative for missing cmxes (#5553);
  canonical types for `make_suitable_for_environment` (#5566).
- **Inlining**: void parameters in classic mode (#5555); fallback
  inlining heuristic; do not lift continuations that may refer to
  non-lifted ones (#5689).
- **Lifted constants in Data Flow** internalised (#5368).
- **Fexpr**: small-int + naked-float blocks (#5441); code offsets
  (#5652); missing primitives (#5772); index removal (#5440);
  `fexpr_reference_suffix` in ocamltest (#5565).
- **Effects**: `%makearray_dynamic` no longer duplicates effects
  (#5459).
- **Reduce `caml_modify`s** for parameterised unboxed records (#5736).
- **Patricia trees**: callback modules to emulate function
  specialisation (#5770); additional `union_total` family (#5803).
- **Traverse module** reviews (#5789, #5797); fix
  `Traversals.at_least_this_closure` (#5529).
- **Split pass**: typo (#5538); loop-optimisation bug (#5542);
  recursive-flag update (#5819); occur check (#5537).
- **Simplify**: generic sort variables (#5704); kind errors in
  `Type_grammar.must_be_singleton` (#5852); lpoly generalize (#5792);
  recursive flag (#5819).
- **Profiling**: counter for cmx loading (#5861); linker scan-file loop
  (#5808).

### CFG / codegen

#### x86 / amd64

- **x86 peephole pass** (#5639): dead-`mov` elimination,
  redundant-`cmp` elimination, adjacent-`add rsp` combining;
  doubly-linked-list refactor of `asm_code`.
- **More `lea` usage**: `add`/`sub` with immediates (#5695);
  multiplications by 3/5/9 and to reduce register moves (#5475).
- **Eliminate useless shifts** in string/bytes indexed access (#5746).
- **Sign-extension optimisations** (#5535, #5550).
- **x86 binary emitter**: missing encodings + better errors (#5653);
  shift-with-memory-dest + CL operand assertion fix (#5369).
- **CFG constant propagation**: integer (#5545), float (#5546),
  predecessor terminator (#5562); merge equivalent blocks (#5597).
- **Validator** uses equality functions (#5581, #5002).
- **Regalloc**: interference edges between multiple outputs (#5706);
  IRC bit-matrix bounds (#5526) and overallocation (#5527); IRC
  complexity threshold (#5705); remove unused spilling heuristics
  (#5637); `SPLIT_AROUND_LOOPS` default-on (#5761); only reload, do
  not spill loop-invariant regs (#5514); useless-spill fix (#5429,
  #5524, #5432); prologue shrink-wrap default-on (#5762).
- **Gather instructions**: clear mask reg (#5567); ensure distinct
  operands (#5589); robust regalloc fix (#5609).

#### arm64

- **Derive instruction sizes robustly** (#5499).
- Codegen tests for materialised bits (#5727), shifts/constants/cmov
  (#5531), intrinsics/builtins (#5489), bytes/string unboxed indexing
  (#5561), GitHub-issue regressions (#5523), `[%%expect_asm]` bad
  codegen (#5447).

#### Common backend

- **Share emitter code** for data items between amd64 and arm64
  (#5794).
- **`Regs` is the source of truth** for physical registers (#5308).
- **Function sections + DWARF enabled** (#4934); always emit
  compilation unit DIE (#5412); both `--debug-prefix-path` and
  `--fdebug-prefix-path` accepted (#5418); CFI tests (#5409); `llvm-mc`
  enabled, debug info not stripped (#5571).
- **`Lregion` for `Texp_antiquotation`** (#5645); **new `Lfor`
  compilation strategy** (#5728); fix tail-call stack-overflow move
  (#5591, #5594); `Cfg_with_layout.insert_block` simplified (#5723);
  CFG merge-blocks stale predecessors (#5708).

### Name mangling (#5097, #5099)

A reversible structured symbol-mangling scheme was added behind a
configure/env switch (`OXCAML_NAME_MANGLING={flat,structured}`,
default `flat`). It currently applies only to functions with a code
id; module entry points, frame tables, GC roots, and similar still use
flat mangling (switching those requires coordinated runtime changes —
see the CR in `Cmm_helpers.make_symbol`). Selection is via
`./configure --with-name-mangling-scheme=<scheme>` and the
`NAME_MANGLING_SCHEME` make variable; the test suite picks it up via
`OXCAML_NAME_MANGLING=$(NAME_MANGLING_SCHEME)`. Parameterised
libraries always use flat. Encoder/decoder live in
`utils/structured_mangling.ml`.

### Bytecode

- **Deep-copy unboxed product fields** on accesses (#5386) — bytecode
  was sharing references where native code copies.
- **Recursive mixed-block allocation size** fix in bytecode (#5754).
- **DWARF disabled for the toplevel** (#5486).
- **`ocamldebug`'s `debug_printers`** fixed and test-run in CI debug
  builds (#5465).

### Modes / kinds / type-checker internals

- External modalities in `with`-bounds (#5601); missing mode-crossing on
  functional record update (#5564).
- `comonadic_to_monadic_X` bug (#5446); regularised meet/join with-const
  terminology (#5451); 0-indexed→1-indexed variable pairs in `mode.ml`
  (#5445); `mode.ml` `Per_axis` no partial applications (#5470); local
  `Solver` module renamed to `S` (#5471).
- Verbose jkind printing fix (#5449); fewer extra newlines in jkind
  errors (#5578); `Jkind.Sort.new_var` return type (#5658); `~level`
  removed from jkind APIs (#5615).
- Canonical layout-poly value description (#5498); sort genvar
  assertion workaround (#5620); `moregeneral` always restores
  `current_level` (#5816) and regeneralises layout vars on error
  (#5691); short-circuit `instance_poly_for_jkind` (#5406);
  `is_null` naked in flambda2-types (#5642); scraped type for
  nullability in `value_kind` (#5592); `update_level` ignores `level`
  when `contents = Some _` (#5791).
- Separability soundness (#5510); unboxed-GADT jkind projection
  (#5580/#5626); inline-record `Texp_ident` / `Tpat_var` / `Tpat_alias`
  (#5520, #5437); explicit `compare` instead of
  `equal_obj`/`equal_morph` (#5799); explicit morphism comparison
  (#5452); param-vs-ret mode fix (#5596); `serialize val_lpoly` +
  `val_type` together (#5835).

### Runtime / GC

- Minor major-GC ephemeron marking fix (#5450).
- Old pacing policy removed (#5497).
- Prefetch added to `pool_sweep` (#5476); `sizeclasses.h` dep tweak
  (#5455); unnecessary `get_header_val` removed (#5454).

### Build, CI, and tooling

- **`ocamlformat` 0.29.0** (#5777) tree-wide reformat; correct
  constraint in `oxcaml-dev.opam` (#5854); chamelon ocamlformat
  consistency (#5387, #5519).
- **dune 3.20.2** pinned in CI (#5684); fix build with dune 3.22
  (#5686); **chamelon dune integration** (#5423); chamelon physical→
  structural equality fix (#5519); cleanup minimizer in legacy mode
  (#5756).
- **macOS** compilation fixes (#5714, #5525, #5765); pin `nix` to
  v2.33.0 (#5536); more portable shebangs (#5865).
- **`mlexamples` tests** moved into the testsuite (#5346); enumerate
  test directories properly (#5675); disable `test_dropped_events`
  runtime-events test (#5669); disable test on nixos (#5822); fix test
  calling `/bin/bash` (#5530).
- Remove line numbers from assertion failures (#5782); CFI tests
  (#5409); missing files in `compiler-libs-installation.sexp` (#5709).
- Parser-change nag updated to include fixing `ppxlib` (#5501, #5507).
- Metrics workflow retries push on failure (#5548); license headers
  (#5570); "Skip 80ch" label fix (#5468); empty "Build debug target"
  action removed (#5472).

### Magic number bumps

- `5.2.0minus-32` (#5500) — block-index syntax → primitive transition.
- `5.2.0minus-34` (#5624) — modes diamond, abstract-kinds part 2.5.
- `5.2.0minus-35` (#5741) — slambda / fracturing.
- `5.2.0minus-37` (#5868) — final consolidation before -38.
