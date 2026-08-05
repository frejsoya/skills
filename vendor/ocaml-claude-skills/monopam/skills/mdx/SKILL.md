---
name: mdx
description: "MDX executable doc examples for OCaml monorepo packages. Use when adding examples to a README.md or .mli odoc block, extending an (mdx ...) stanza, fixing a doc example that fails to typecheck, or deciding which dune file the stanza belongs in."
---

# MDX

`(mdx ...)` extracts code blocks from documentation and feeds them to the
compiler, so `.mli` odoc examples (`{[ ... ]}`) and README ` ```ocaml ` blocks
typecheck against the real API and stale examples break the build.

The bar is **executable specifications of the public API**, not merely "checked
code". Typechecking catches stale names; `assert`s and recorded toplevel output
catch wrong explanations, which is what makes documentation a contract.

## The cardinal rule: one `(mdx ...)` per dune file

`(files ...)` is **not recursive**. Verified against dune 3.22
(`src/dune_rules/mdx.ml:285-298`): globs match **basenames only**, and the file
walk uses `Source_tree.files_of`, which returns only the **immediate children**
of the dune file's directory.

So `(files lib/parsing/link.mli)` or `(files **/*.mli)` in a root dune file
silently match nothing. Dune does not error; it just covers no files.

```
ocaml-foo/
  dune              # (mdx (files README.md) ...)
  lib/
    dune            # (library ...) + (mdx (files foo.mli bar.mli) ...)
    eio/dune        # (library ...) + (mdx (files foo_eio.mli) ...)
    parsing/dune    # (library ...) + (mdx (files link.mli) ...)
```

Three stanzas, each next to the files it covers (see `ocaml-toml/lib/dune` +
`ocaml-toml/lib/eio/dune`, `ocaml-json/lib/dune`). There is no toplevel stanza
covering subdirectory `.mli` files: the implementation precludes it, so don't
spend time trying paths or globs with directory components.

## What a good example is

- **One idea.** A single function or workflow, not a tour of the module.
- **Complete.** No free variables, no `(* ... *)` ellipses, no `~priv:...`
  placeholders. `~priv:...` is not OCaml syntax and will not parse.
- **Smaller than the API it documents.**
- **Realistic.** Real codec input, a real config record; never `Obj.magic 0` or
  `assert false` stubs.
- **Deterministic.** Same output every run on every machine.
- **Shows the result.** An `assert`, recorded toplevel output, or a print the
  reader can compare against the prose.

Per surface: `.mli` gets short API-focused examples (3-10 lines) next to the
documented `val`; `README.md` gets end-to-end examples, preferably toplevel
sessions so the output diff is the test; `.mld` gets conceptual recipes, still
executable unless the snippet is genuinely a syntax sketch.

## Behavior, not just types

`ignore (Foo.parse "...")` typechecks and teaches nothing. Assert the result:

```ocaml
(** {[
    let item = Foo.parse {|name = "demo"|} in
    assert (Foo.name item = "demo");
    assert (Foo.kind item = `String)
    ]} *)
```

The assertions are the documentation: input, return value and post-condition in
one block. If the behavior changes, the build breaks at the doc.

For toplevel sessions the recorded output plays the same role:

````markdown
```ocaml
# Foo.parse {|name = "demo"|} |> Foo.name;;
- : string = "demo"
```
````

## `let run () = ...` is for side effects only

mdx compiles each block as a standalone unit, so it must be self-contained. Wrap
in `let run () = ...` when the example would otherwise *execute* something
undesirable at build time:

| Example does | Wrap? |
|--------------|-------|
| Builds values, types, codecs, schemas | No: top-level bindings |
| Reads/writes an in-memory structure | No: top-level bindings |
| `Eio_main.run`, network, file I/O | Yes |
| Blocks, prompts, or prints | Yes |

```ocaml
(** {[
    open Eio.Std
    open Requests

    let run () =
      Eio_main.run @@ fun env ->
      Switch.run @@ fun sw ->
      let session = v ~sw env in
      let response = get session "https://example.com" in
      Printf.printf "Status: %d\n" (Response.status_code response)
    ]} *)
```

Inside the wrapper the same rules hold: bind every name (or take it as a
parameter, `let run ~env ~sw = ...`), handle every branch, and end with an
observable effect rather than `ignore (...)`.

**Modules and functors belong at the top level**, not hidden inside `let module
... in` to keep the example "one expression":

```ocaml
(** {[
    (* Good: reads like real code in a user's project. *)
    module S = Irmin.SHA256

    module Heap = Irmin.Heap.Mem (struct
      type hash = Digestif.SHA256.t
      type block = string
      let equal = Digestif.SHA256.equal
    end)

    let heap = Heap.v ()
    ]} *)
```

## Determinism

No real network, no wall-clock time (`Ptime.epoch` or an injected `~clock`, not
`Ptime_clock.now ()`), no unseeded randomness (PKCE, nonces, UUIDs need a
deterministic source), no ambient filesystem, no `Sys.getenv` /
`Sys.os_type`-conditional output. A non-deterministic example is a manual test;
move it to a real test file.

## `open` discipline

Default to **qualified names**: `Toml.Value.parse_int "42"` teaches where
`parse_int` lives; after `open Toml.Value` it doesn't. `open` only where the API
is designed for it (`open Eio.Std` is the canonical idiom for `Switch`,
`Promise`, `Fiber`).

The exception is a `.mli` inside package `Foo` whose example uses many `Foo.X` /
`Foo.Y` references: `open Foo` once at the top of the block reads better than
repeating the prefix on every line, and the reader still sees the import
surface.

```ocaml
(** Prefer:
    {[
    open Claude

    let cfg =
      Options.default
      |> Options.with_model `Sonnet_4_5
      |> Options.with_permission_mode Permissions.Mode.Accept_edits
    ]} *)
```

This applies to packages whose top-level module groups several submodules a
typical example uses together (`Claude`, `Irmin`, `Cmdliner`), not to packages
with one dominant module where the qualified form is already short
(`Toml.parse`, `Sse.Parser.create`).

## Public names, real instances

Examples consume the public API: no private modules (`Foo__internal.bar`), no
test helpers, no implementation paths. If the only way to write the example is
to reach into internals, the public API is incomplete: extend it.

Use the prebuilt instances the library ships rather than stub codecs. Stub `dec`
/ `enc` (`fun _ -> S.Named []`, `fun _ -> ""`) ship **broken** code: a reader who
copies it gets a non-roundtripping codec and silent data loss.

```ocaml
(** Avoid: invites copy-paste of a broken codec.
    {[
    let json = S.node ~name:"application/json"
                 ~dec:(fun _ -> S.Named []) ~enc:(fun _ -> "") ()
    ]} *)

(** Better: use the prebuilt codec the library ships.
    {[
    let json = Irmin_json.schema
    ]} *)
```

If no prebuilt fits and a self-contained custom codec would balloon the doc, the
example wants to live in `test/test_<feature>.ml` with a one-sentence pointer
from the `.mli`.

## Use `Fmt`, not `Format` / `Printf`

The repo standardises on `fmt`: `Fmt.pr` / `Fmt.epr` / `Fmt.str`. Library `pp`
values are typed `_ Fmt.t` and compose with `%a` through a `Fmt` formatter;
`Format.printf "%a"` does not typecheck against the abstract arrow without a
`cmi` from the formatter library. Mixing `Printf` with `pp_*` values is the most
common rough edge.

```ocaml
(** Prefer:  {[ Fmt.pr "%a@." Lib.pp_value v ]} *)
(** Avoid:   {[ Format.printf "%a@." Lib.pp_value v ]} *)
```

## Copy-paste discipline

A reader copies the block into a fresh file, adds the libraries from the dune
stanza, and it compiles. So: all names bound or fully qualified, all `open`s in
the block, no dependence on prose above it ("assume a session named `s`"), and
every import present in `(libraries ...)`.

```dune
(mdx
 (files link.mli)
 (libraries
  requests              ; the package itself
  requests.parsing      ; the sub-library this dune builds
  nox-http              ; for Http.Response, Http.Headers
  eio
  eio.core              ; Eio.Std, Eio.Switch
  eio.unix              ; Eio_unix.Stdenv
  eio_main))            ; Eio_main.run
```

Common clusters: `eio eio.core eio.unix eio_main` for any Eio example;
`logs logs.fmt logs.cli`; `cmdliner`; the package's own sub-libraries when
examples cross module boundaries.

## API-design pressure

If a simple thing is hard to show in a few lines, that is usually the API's
fault, and **changing the API is the right fix**: don't normalize boilerplate
by burying it in a wrapper. In order of preference: add a high-level entry point
bundling the common case (`Lib.with_session @@ fun s -> ...`,
`Lib.parse_string`, a default config) and document *that*; reorder arguments or
add defaults so the call reads left-to-right with the interesting bits first;
inline a one-shot convenience if it belongs in the library.

If the API is genuinely low-level and the boilerplate is real (an Eio mainloop,
a TLS handshake), flag it for ergonomics work and document at the level above
("see `Lib.with_session` for the common case") rather than reproducing the
boilerplate in every example. A clumsy example is the API asking to be
redesigned.

## Fixing a broken example

```sh
dune runtest <package>/<dir>/ 2>&1 | tail -30
```

The error appears as a diff against `.mdx/<file>.corrected`:

```
@@ -23,7 +23,11 @@
       | None -> List.rev acc
-    ]}
+    ][
+{err@mdx-error[
+Line 6, characters 9-15:
+Error: The module Switch is an alias for module Eio__core.Switch, which is missing
+]err}]}
```

| Error | Fix |
|-------|-----|
| `The module X is an alias for Y.X, which is missing` | Add the library defining `Y.X` (often a sub-library) |
| `Unbound module Foo` | Add the library exposing `Foo`, or `open` it |
| `Unbound value bar` | The example referenced an undeclared binding; bind it |
| `Eio_unix.Stdenv ... abstract because no corresponding cmi` | Add `eio.unix` |

## Anti-patterns

- **Skipping a block.** `<!-- $MDX skip -->` on an OCaml example defeats the
  purpose: the docs claim the API works that way and nothing checks it. If it
  can't typecheck, either the example is wrong or the API is too clumsy to
  demonstrate. Fix one of them. (Skipping shell blocks is fine.)
- **Pseudocode inside `{[ ]}`.** Either rewrite with concrete bindings and an
  assertion, or drop the example markers and write prose. Don't ship example
  syntax around code that won't compile.
- **`_`-prefixing unused bindings.** If a value is unused, the example isn't
  using the API. Print, assert, or return it. `_`-prefixing is for internal code
  where genuine unuse is acceptable.
- **A toplevel stanza with subdirectory paths.** Silently covers nothing; see
  the cardinal rule.
- **Missing `(using mdx 0.4)`** in `dune-project`, which makes dune reject the
  stanza with "Unknown stanza". Most packages here have it; new ones do not.

## Coverage

A package is covered when every `.mli` containing `{[` is listed in the
`(mdx ...)` stanza **in its own dune file**, and `README.md` is listed in the
package root's stanza. Audit one package:

```sh
for d in $(find P -name "*.mli" -not -path "*/_build/*" \
           | xargs grep -l '{\[' | xargs -n1 dirname | sort -u); do
  echo "=== $d ==="
  ls "$d"/*.mli 2>/dev/null | xargs grep -l '{\[' | xargs -n1 basename
  echo "covered:"
  awk '/^\(mdx/,/^\)/' "$d/dune" 2>/dev/null | grep -oE '[a-zA-Z0-9_.-]+\.mli'
done
```

When adding a public `.mli` with examples, extend the stanza in the same dune
file in the same change. Don't ship docs whose claim isn't checked.
