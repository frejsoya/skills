---
name: ocaml-observe
description: "The observe library: cmdliner terms and one-call setup for CLI logging with RUST_LOG-style configuration. Use when adding logging to an OCaml CLI, wiring -q/-v/-vv/-vvv verbosity flags, enabling JSON structured output, tracing a protocol to a file, or configuring test logging via TEST_LOG."
---

# observe

`observe` provides cmdliner terms for logging configuration with RUST_LOG-style
syntax. Depend on `observe`; add `json-logs` too if you want `--json` support.

`Observe.setup "myapp"` is a `Term.t` you apply alongside your own arguments; it
installs the reporter as a side effect of evaluation.

```ocaml
open Cmdliner

let run () =
  Logs.info (fun m -> m "Application started");
  (* your code *)
  Logs.info (fun m -> m "Done")

let cmd =
  let info = Cmd.info "myapp" ~doc:"My application" in
  Cmd.v info Term.(const run $ Observe.setup "myapp")

let main () = exit (Cmd.eval cmd)
```

That one term gives the binary its whole logging surface:

<!-- $MDX skip -->
```sh
myapp -q                           # quiet: errors only
myapp                              # default: warnings
myapp -v                           # info
myapp -vv                          # debug
myapp -vvv                         # debug + *.tracing sources enabled

myapp --log=info                   # set level directly
myapp --log=info,http:debug        # info globally, debug for http
myapp --log=conpool:warning        # warning for conpool only

MYAPP_LOG=debug myapp              # same syntax via the environment

myapp --json                       # structured JSON lines
myapp --json --log-tag=env=prod    # add custom tags
myapp --log-trace protocol.log     # protocol trace to a file
```

## Levels

| Flag | Level | `*.tracing` sources |
|------|-------|---------------------|
| `-q` | Error | silenced |
| (none) | Warning | silenced |
| `-v` | Info | silenced |
| `-vv` | Debug | silenced |
| `-vvv` | Debug | enabled |

Warning is the right default: info is too verbose for production. Name tracing
sources `<something>.tracing` and they stay silent until `-vvv`, which is what
makes protocol-level tracing safe to leave compiled in. Give each module its own
`Logs.Src` so per-source overrides are useful.

## Log specs

`--log` and `$APP_LOG` take RUST_LOG syntax: a global level, per-source
overrides, or both.

<!-- $MDX skip -->
```sh
level                    # global level
level,src:level          # global + per-source
src:level,src:level      # per-source only (global default kept)
```

Levels are `error`, `warning`, `info`, `debug`. So `debug` sets everything to
debug, `info,http:debug` puts http alone at debug, and
`warning,conpool:debug,tls:info` layers two overrides on a warning default.

## JSON output

With `--json`, records are emitted as JSON lines:

```json
{"timestamp":"2025-01-29T12:00:00Z","level":"info","src":"myapp","msg":"Started","hostname":"server1","pid":1234}
```

`--log-tag KEY=VALUE` (repeatable) adds fields. Prefer JSON in production, where
aggregation matters more than readability.

The reporter is replaceable, and `--json` can be removed from the interface
entirely:

```ocaml
(* Use default json-logs reporter *)
let _ = Observe.setup "myapp"

(* Custom JSON reporter *)
let my_reporter ~app:_ ~base:_ () =
  (* custom implementation *)
  Logs_fmt.reporter ()

let _ = Observe.setup ~json_reporter:(Some my_reporter) "myapp"

(* Disable --json flag entirely *)
let _ = Observe.setup ~json_reporter:None "myapp"
```

## Tests

```ocaml
let () = Observe.setup_test ~level:Logs.Debug ()
(* then run your test suite, e.g. Alcotest.run "mylib" suite *)
```

`TEST_LOG` overrides it with the same spec syntax, which is how you get a quiet
suite by default and full detail on the one source you are debugging:

<!-- $MDX skip -->
```sh
TEST_LOG=warning dune test
TEST_LOG=warning,conpool:debug dune test
```

## Individual terms

When `setup` is too coarse, the terms compose directly:

| Value | Type | Flag |
|-------|------|------|
| `Observe.quiet` | `bool Term.t` | `-q` / `--quiet` |
| `Observe.verbosity` | `bool list Term.t` | `-v`; list length is the level |
| `Observe.log name` | `string option Term.t` | `--log`, with `$NAME_LOG` |
| `Observe.json` | `bool Term.t` | `--json` |
| `Observe.log_tags` | `(string * string) list Term.t` | `--log-tag KEY=VALUE` |
| `Observe.log_trace` | `string option Term.t` | `--log-trace FILE` |

```ocaml
let my_setup =
  let open Cmdliner.Term in
  const (fun _quiet _verbosity _log_spec _json _tags _trace_file ->
    (* custom setup logic *)
    ())
  $ Observe.quiet
  $ Observe.verbosity
  $ Observe.log "myapp"
  $ Observe.json
  $ Observe.log_tags
  $ Observe.log_trace
```

The pieces behind `setup` are also public:

```ocaml
(* Parse a log spec string *)
let global, overrides = Observe.parse_log_spec "info,http:debug"
(* global = Some Info, overrides = [("http", Some Debug)] *)

(* Apply per-source overrides *)
let () = Observe.apply_source_overrides [("http", Some Logs.Debug)]

(* Enable/disable *.tracing sources *)
let () = Observe.configure_tracing_sources ~enable:false
```

`Observe.level_of_verbosity ~quiet ~verbosity` maps the flags to a
`Logs.level option` (quiet is Error; `[]` is Warning; `[_]` Info; two or more
Debug), and `Observe.enable_tracing ~verbosity` is true from `-vvv` up.

## A complete CLI

```ocaml
open Cmdliner

let log_src = Logs.Src.create "myapp"
module Log = (val Logs.src_log log_src : Logs.LOG)

let run _setup input output =
  Log.info (fun m -> m "Processing %s -> %s" input output);
  (* process files *)
  Log.info (fun m -> m "Done")

let input_arg =
  Arg.(required & pos 0 (some file) None & info [] ~docv:"INPUT")

let output_arg =
  Arg.(required & pos 1 (some string) None & info [] ~docv:"OUTPUT")

let cmd =
  let info = Cmd.info "myapp" ~doc:"Process files" in
  Cmd.v info Term.(const run $ Observe.setup "myapp" $ input_arg $ output_arg)

let main () = exit (Cmd.eval cmd)
```
