# Byte-packed codecs on ocaml-wire

The four layers of this skill describe structured formats: a document a person
can open, with a `Value` AST and a `Loc.Error` facade. A byte-packed binary
format (a packet header, a frame, a page, a record) is described with
ocaml-wire (`Wire`), the external combinator library that derives both the
OCaml codec and the EverParse `.3d` schema, and from it a verified C
validator. Its README and `wire.mli` document field handles, staging, the
integer carriers and byte-budget arrays; these rules add what the tree
expects of every package that uses it.

## One description drives the runtime

The `Wire` codec is the library's encode and decode, not documentation beside
a hand-written byte path. `to_string`, `of_string`, `encode` and `decode` go
through `Wire.Codec.encode` / `Wire.Codec.decode` over the codec; in-place
reads and patches go through `Codec.get` / `Codec.set`, unstaged once at the
top level. No `Bytes.set_uint8`, `Bytes.get_uint16_be` or `String.sub` path
sits alongside: a second definition drifts from the `.3d` and from the C
validator, and no test sees it.

## Build a codec once

Constructing and staging a codec costs far more than the values it decodes,
so a codec is a top-level value, never rebuilt per call with a runtime length
baked in through `~size:(int n)`.

- A field that runs to the end of the body is `Wire.all_bytes`, which keeps
  the codec constant.
- A length known only at call time is a parameter: declare
  `Wire.Param.input "budget" uint16be` once, size the field with
  `Param.expr`, and per call bind it into `Codec.env codec` with `Param.bind`
  before `Codec.decode_exn ~env`.
- A byte-budget `repeat` consumes its whole budget, so trailing padding the
  format calls filler (DHCP's Pad options after End) is cut off before the
  decode rather than parsed element by element.

## Closing a validation hole

To make the C validator reject a bad discriminant, not only the OCaml reader:

- a plain integer field with no domain-error pre-check takes `Wire.enum`,
  which names the values as a type in the `.3d`;
- a bitfield, or a field whose value a staged getter reads first to return a
  domain error (an unknown frame type), takes `~self_constraint`. An enum
  lives in the type, so the staged getter would raise `Parse_error` instead
  of returning the raw value.

When the reader maps a value to a domain error only after a full decode, any
constraint makes the decode fail first and the domain error becomes a generic
parse error: read the discriminant with a staged getter before the
constrained decode and return the domain error there. Write the failing test
on the raw codec first, then regenerate the C and check the differential
(`dune build @<pkg>/c/runtest`) reports no mismatch.

## EverParse refusing arithmetic

`Error 19: Cannot verify u32 multiplication` on a byte-size array sized
`field * n` means the field's constraint is too loose to prove the product
fits 32 bits: the range genuinely describes a payload longer than any 32-bit
length. Tighten the field's `~self_constraint` until the product is provably
in range (a count bounded by 255 times 64 is at most 16320); the tool is
right to refuse. A `uint64` length sizing a span needs `to_uint32` on the
reference plus a 32-bit bound on the field (`~self_int64`), or the same
error appears. A `~self_int64` constraint does not project to a doc-mode
`.3d`, so a full-width integer check there stays OCaml-side.

## Regenerating the C

`wire.3d` finds `3d.exe` on `PATH`, then at `$HOME/.local/everparse/bin/3d.exe`;
check both before saying the toolchain is missing. A package's `c/` directory
commits the `.3d`, the generated C and `EverParse*.h`. A plain `dune build`
uses the committed C and never runs `3d.exe`. After a codec change, `dune
promote` takes the new `.3d` once the drift check reports it, and
`BUILD_EVERPARSE=1 dune build @<pkg>/c/3d` regenerates the C into the tree.
The `c/runtest` differential runs the current codec's corpus against the
committed validator, so stale C fails there. Committed generated files are
read-only: `chmod +w` before patching one by hand.

## Errors

A byte-packed codec takes no `Loc.Error` facade and no `nox-loc` dependency:
there is no line or column to point at, and `wire` sits under unikernel
packages that must not carry layout machinery. Its error type is a closed
polymorphic variant or a variant (`[ `Truncated | `Out_of_range ]`): precise,
matchable and dependency-free. An open row (`[> `Bad_crc ]`) leaks a type
variable into every caller; close it. One signature exposes one error type:
translate `Wire.parse_error` into the package's own type at the boundary
rather than letting both escape. A standalone binary file format a person
inspects as a document (VCDIFF, Parquet) may use the `Loc.Error` facade; it is
not the template for a wire codec.
