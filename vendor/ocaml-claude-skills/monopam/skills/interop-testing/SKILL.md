---
name: interop-testing
description: "Cross-implementation interop tests for protocol and codec libraries: committed traces generated once from an external oracle (Go, Rust, Python, Docker, NASA tools) and replayed at test time. Use when adding a test against a reference implementation, wiring the REGEN=1 dune build @traces rule, or auditing an existing interop test for staleness, inlined upstream code, or non-reproducible regen."
---

# Interop Testing

Reference implementation: `ocaml-sgp4/test/interop/gmat/`.

## Principles

**1. Generate once, replay always.** Traces are committed to git. `dune test`
runs from the traces and never invokes the external tool, so the suite works
without the oracle's toolchain installed.

**2. Never copy upstream code into the generator.** The generator must call the
upstream tool's public API, CLI, or Docker image, never reimplement,
transcribe, or "inline for convenience" the algorithm being verified. Three
reasons:

- **You cannot validate correctness.** The point of an interop test is an
  *independent* oracle. A re-implementation tests the generator against itself,
  or codifies a subtle transcription bug.
- **Silent staleness.** When upstream fixes a bug, an inline copy keeps
  producing the old answers with no signal. The pipeline must trace back to the
  upstream binary so re-running picks up upstream changes.
- **Not reproducible.** A re-implementation living only in the generator can be
  edited locally without a trace; the oracle is no longer pinned.

If the public API "doesn't expose" what you want to test, that test is probing
internals rather than interop behavior. **Drop the test, don't inline it**:
move it to a unit test in the package that owns the algorithm, and let the
operations-level traces cover the same ground end-to-end.

**3. Reproducible without local checkouts.** The regen script must not depend on
`$FOO_HOME` pointing at a personal clone. Pin the upstream through the
language's package manager: `go.mod` with a tagged or pseudo-version;
`Cargo.toml` with a tagged crate or `git = ..., rev = ...`; `requirements.txt`
with `==X.Y.Z`; a Docker image pinned by content-addressed digest. Anyone with
the toolchain on PATH gets identical bytes.

**4. One trigger: `REGEN=1 dune build @traces`.** No `make regen`, no
`./regenerate.sh` outside dune. The `REGEN=1` gate is load-bearing, not
convenience: it is what keeps the traces *pure source* during a normal
`dune test`.

**5. Standard trace formats.** Never invent a custom binary trace format.

**6. Python deps live in a venv.** Never `pip install --break-system-packages`.

## Layout

One subdirectory per oracle. Two oracles for the same library live as siblings,
each with their own `scripts/` and `traces/`.

<!-- $MDX skip -->
```
<package>/test/interop/<tool>/
├── scripts/         # generator artifacts; regen-time only
│   ├── generate.sh  # the dune action target
│   ├── go.mod       # or Cargo.toml + src/main.rs, or generate.py + requirements.txt
│   └── ...
├── traces/          # committed tool output, standard format
│   ├── dune         # the gated promote rule
│   └── operations.csv
├── test.ml          # reads traces, asserts our impl
└── dune             # test stanza + traces alias
```

## The dune wiring

The traces must be **pure source** during `dune test` yet **promote targets**
during regen. One `(mode promote)` rule cannot be both; dune rebuilds a promote
target whenever something depends on it, so a test with `(source_tree traces)`
would run the oracle on every build. The fix is to gate the rule's *existence*
on `REGEN=1`, so for a normal build the rule does not exist and the traces are
plain source.

Parent `dune`: the test stanza plus a thin alias deferring to `traces/`:

```scheme
(test
 (name test)
 (libraries <lib> nox-csv alcotest)
 (deps
  (source_tree traces)
  (source_tree scripts)))

; Regenerate the committed traces: REGEN=1 dune build @traces
(rule
 (alias traces)
 (deps
  (alias traces/regen))
 (action
  (progn)))
```

`traces/dune`: the gated promote rule, living where its targets sit:

```scheme
(rule
 (alias regen)
 (mode promote)
 (enabled_if
  (= %{env:REGEN=0} 1))
 (targets operations.csv ...)        ; every committed trace file
 (deps
  (source_tree ../scripts))
 (action
  (run bash ../scripts/generate.sh .)))   ; "." = output dir
```

- `(enabled_if (= %{env:REGEN=0} 1))`, the rule exists only under `REGEN=1`, so
  a normal `dune test` reads the trace files hermetically as committed source.
- `(mode promote)`: under `REGEN=1` the generated targets are copied back into
  the source tree, rewriting the committed traces in place.
- `(targets ...)`: list every committed trace file. For a directory of many
  files, use `(targets (dir .))` with `(using directory-targets X.Y)` in
  `dune-project`.
- The generator runs with cwd at the build `traces/` dir and writes to the
  output dir passed as `$1`.

## The generator wrapper

`scripts/generate.sh` is a tiny dispatcher: check the toolchain is present, hand
off to the language-native build, write to the output directory in `$1`
(defaulting to `../traces` for a direct `bash generate.sh`). The binary itself
uses **only** the upstream's public API.

Under the rule the `scripts/` copy is read-only, so any toolchain that writes
inside it must be pointed at a writable build-local path: `VENV_DIR` for
Python's venv, `CARGO_TARGET_DIR` for Rust. Go and Docker need nothing extra
(their caches live under `$HOME`, and Docker writes through the mounted output
dir).

<!-- $MDX skip -->
```bash
#!/bin/bash
# Go oracle
set -euo pipefail
command -v go >/dev/null || { echo "go not on PATH" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRACE_DIR="$(cd "${1:-$SCRIPT_DIR/../traces}" && pwd)"

cd "$SCRIPT_DIR"
go mod download
go run generate.go "$TRACE_DIR"
```

<!-- $MDX skip -->
```bash
#!/bin/bash
# Python oracle. The venv must live somewhere writable; the rule points
# VENV_DIR at the build dir.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRACE_DIR="$(cd "${1:-$SCRIPT_DIR/../traces}" && pwd)"

VENV="${VENV_DIR:-$SCRIPT_DIR/.venv}"
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
fi
"$VENV/bin/python3" "$SCRIPT_DIR/generate.py" "$TRACE_DIR"
```

<!-- $MDX skip -->
```bash
#!/bin/bash
# Rust oracle. CARGO_TARGET_DIR (set by the rule) keeps the build out of the
# read-only scripts/ copy.
set -euo pipefail
command -v cargo >/dev/null || { echo "cargo not on PATH" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRACE_DIR="$(cd "${1:-$SCRIPT_DIR/../traces}" && pwd)"

cd "$SCRIPT_DIR"
cargo build --release
"${CARGO_TARGET_DIR:-target}/release/<binary-name>" "$TRACE_DIR"
```

<!-- $MDX skip -->
```bash
#!/bin/bash
# Docker oracle. Pin the image by digest, NOT by tag.
set -euo pipefail
command -v docker >/dev/null || { echo "docker not on PATH" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TRACE_DIR="$(cd "$SCRIPT_DIR/../traces" && pwd)"

IMAGE="ghcr.io/<owner>/<image>@sha256:<digest>"

docker run --rm \
  -v "$SCRIPT_DIR:/work/scripts:ro" \
  -v "$TRACE_DIR:/work/traces" \
  "$IMAGE" \
  /work/scripts/generate-inside-container.sh
```

The matching cache redirects in `traces/dune`:

<!-- $MDX skip -->
```scheme
(action (setenv VENV_DIR .venv (run bash ../scripts/generate.sh .)))
(action (setenv CARGO_TARGET_DIR target (run bash ../scripts/generate.sh .)))
```

## Trace formats

| Domain | Format | Extension |
|--------|--------|-----------|
| Orbits | CCSDS OEM (KVN) | `.oem` |
| Messages | CCSDS KVN/XML | `.kvn` / `.xml` |
| Binary frames | raw binary + hex companion | `.bin` + `.hex` |
| Checksums / MACs | CSV (name, input_hex, output_hex) | `.csv` |
| Codec pairs | CSV (name, input_hex, encoded_hex) | `.csv` |
| Time codes | CSV (params, encoded_hex) | `.csv` |
| Stateful op sequences | CSV (fixture, step, op, arg, expected) | `.csv` |
| Key-value | JSON | `.json` |

Binary traces always get a `.hex` companion (one hex line per record) so they
are reviewable in a git diff.

Use the monorepo's parsers rather than hand-rolling one, where it makes sense (a
one-column hex file doesn't need CSV): `nox-csv` for CSV, `nox-xml` / `kvn` for
KVN and XML, `nox-json` for JSON, `yamlt` for YAML.

## `test.ml`

Define a record type and a `Csv.Row` codec per trace file, then `Csv.decode_file`.

```ocaml
(** <Tool> interop tests for <lib>.

    Traces generated by: <tool> <pinned-version>
    Regenerate: REGEN=1 dune build @traces *)

let trace path = Filename.concat "traces" path

type frame_row = {
  name : string;
  input_hex : string;
  expected_hex : string;
}

let frame_codec =
  Csv.(Row.(
    obj (fun name input_hex expected_hex ->
        { name; input_hex; expected_hex })
    |> col "name" string ~enc:(fun r -> r.name)
    |> col "input_hex" string ~enc:(fun r -> r.input_hex)
    |> col "expected_hex" string ~enc:(fun r -> r.expected_hex)
    |> finish))

let test_frames () =
  let rows = match Csv.decode_file frame_codec (trace "frames.csv") with
    | Ok rows -> rows
    | Error msg -> Alcotest.failf "CSV: %s" msg
  in
  List.iter (fun (r : frame_row) ->
    (* compare our impl against r.expected_hex *)
    Printf.printf "%s: %s -> %s\n" r.name r.input_hex r.expected_hex
  ) rows
```

## Documenting upstream bugs

When an interop test reveals a bug in the oracle rather than in our code, record
it in the test file's top-level docstring so the omission is discoverable.
Include the version, the symptom, why the trace was omitted or adjusted, and
whether an upstream issue was filed. When upstream fixes it, re-run the regen
and un-skip the traces.

```ocaml
(** ...
    {b Known upstream bugs (<tool> <version>):}

    - {b FooPdu.pack()} uses native endian instead of big-endian for the bar
      field. Traces omitted. No upstream issue filed as of <date>. *)
```

## Adding a new interop test

1. Create `test/interop/<tool>/` with the layout above.
2. Write `scripts/generate.sh` plus the language-native side. It takes the
   output dir as `$1` and keeps its toolchain cache build-local.
3. The generator uses only the upstream's public API. If you can't express the
   test that way, drop it.
4. Pin the upstream version in the package manifest. No `$FOO_HOME`.
5. Wire the parent `dune` alias and the gated `traces/dune` promote rule.
6. `REGEN=1 dune build @traces`, then review
   `git diff <package>/test/interop/<tool>/traces`.
7. Write `test.ml` reading the traces.
8. Confirm `dune test` (no `REGEN`) passes from traces alone, with the oracle's
   toolchain unavailable or unused.
9. Add `.venv/`, `target/`, `.gen/` to `.gitignore`.
10. Commit traces, scripts, and test together.
