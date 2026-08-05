---
name: console
description: "The console library: terminal styling and layout widgets for OCaml CLIs. Use when adding coloured or styled output, tables, trees, bordered panels, or live progress displays and spinners to a command-line tool."
---

# Console

Type-safe terminal styling (colours, attributes) and layout widgets (tables,
trees, panels, live progress) for OCaml CLIs. Add `console` to the
executable's `(libraries ...)`, and `console-eio` as well for interactive
progress displays.

## Styles and colours

Styles compose with `+` and apply to any `'a Fmt.t`:

```ocaml
open Console

let print_success () =
  let style = Style.(bold + fg Color.green) in
  Fmt.pr "%a@." (Style.styled style Fmt.string) "Success!"
```

Attributes: `bold`, `faint`, `italic`, `underline`, `blink`, `reverse`,
`strikethrough`, `fg color`, `bg color`, `none`.

```ocaml
open Console

(* Predefined ANSI colors *)
let red = Color.red
let green = Color.green
let bright_blue = Color.bright_blue

(* RGB colors *)
let orange = Color.rgb 255 165 0

(* Hex colors *)
let purple = Color.hex "#8B5CF6"

(* 256-color palette *)
let color_42 = Color.palette 42
```

Predefined: `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`,
`white`, plus a `bright_` variant of each.

## Spans

A span is a styled text segment. Concatenate with `++`; `Span.width` gives the
display width, excluding ANSI escapes.

```ocaml
open Console

let span =
  Span.(
    styled Style.bold "Error: " ++
    text "File not found: " ++
    styled Style.(fg Color.cyan) "/path/to/file")

let print_span () =
  Fmt.pr "%a@." Span.pp span;         (* with ANSI codes *)
  Fmt.pr "%a@." Span.pp_plain span    (* without *)

let width = Span.width span
```

Constructors: `text`, `styled`, `empty`, `space`, `newline`, `concat` / `++`.

## Tables

Build from rows, or incrementally with `add_row` / `add_row_strings`.

```ocaml
open Console

let columns = [
  Table.column "Name";
  Table.column ~align:`Right ~min_width:10 "Price";
  Table.column ~align:`Center ~style:Style.(fg Color.green) "Status";
]

let table =
  Table.of_rows ~border:Border.rounded ~header_style:Style.bold
    columns
    [
      [ Span.text "Widget"; Span.text "$9.99"; Span.text "In Stock" ];
      [ Span.text "Gadget"; Span.text "$19.99"; Span.text "Low" ];
    ]

let table' =
  Table.v ~border:Border.single columns
  |> Table.add_row [ Span.text "Widget"; Span.text "$9.99"; Span.text "In Stock" ]
  |> Table.add_row_strings [ "Gadget"; "$19.99"; "Low" ]

let print_tables () =
  Table.pp Format.std_formatter table;
  Table.pp Format.std_formatter table'
```

Column options: `align` (`` `Left `` default, `` `Center ``, `` `Right ``),
`min_width`, `max_width` (truncates), `style` (applies to every cell).

```text
╭───────┬─────╮
│ Name  │ Age │
├───────┼─────┤
│ Alice │  30 │
│ Bob   │  25 │
╰───────┴─────╯
```

## Borders

```ocaml
open Console

let borders = [
  Border.none;     (* no border *)
  Border.ascii;    (* +--+  |  +--+ *)
  Border.single;   (* ┌──┐  │  └──┘ *)
  Border.double;   (* ╔══╗  ║  ╚══╝ *)
  Border.rounded;  (* ╭──╮  │  ╰──╯ *)
  Border.heavy;    (* ┏━━┓  ┃  ┗━━┛ *)
  Border.hidden;   (* spaces, maintains layout *)
]

let styled_border = Border.with_style Style.(fg Color.blue) Border.rounded
```

Prefer the Unicode borders; fall back to `Border.ascii` on limited terminals.

## Trees

```ocaml
open Console

let tree =
  Tree.of_tree
    (Tree.Node
       ( Span.text "src",
         [
           Tree.Node (Span.text "lib", [ Tree.Node (Span.text "console.ml", []) ]);
           Tree.Node (Span.text "test", [ Tree.Node (Span.text "test.ml", []) ]);
         ] ))

let print_tree () = Tree.pp Format.std_formatter tree
```

```text
src
├── lib
│   └── console.ml
└── test
    └── test.ml
```

`Tree.v` renders any custom type through a node function:

```ocaml
type dir = { name : string; children : dir list }

let root_dir = {
  name = "src";
  children = [ { name = "console.ml"; children = [] } ];
}

let custom_tree =
  Tree.v
    (fun render dir ->
      Tree.Node (Span.text dir.name, List.map render dir.children))
    root_dir
```

Guides: `Tree.unicode_guide` (default) or `Tree.ascii_guide`.

## Panels

```ocaml
open Console

let panel =
  Panel.v
    ~border:Border.rounded
    ~title:(Span.styled Style.bold "Status")
    ~subtitle:(Span.text "Updated: 2025-01-29")
    ~padding:2
    ~width:40
    (Span.text "All systems operational")

let metrics_panel =
  Panel.lines
    ~title:(Span.text "Metrics")
    [
      Span.text "CPU: 45%";
      Span.text "Memory: 2.3 GB";
      Span.text "Disk: 120 GB";
    ]

let print_panel () = Panel.pp Format.std_formatter panel
```

## Durable progress (`Console.Display`)

A display deliberately has two projections: immutable, append-only event
history and an immutable snapshot of the tasks running now. On a terminal only
the bounded activity snapshot is redrawn; task logs and terminal outcomes stay
in scrollback. Under a pipe, only that permanent history is emitted.

`Console_eio.run` is the ordinary constructor. It owns terminal restoration,
succeeds unfinished tasks on normal return, and cancels them if the callback
raises. Tasks are owned by one display; finishing a parent settles its children
first, and the first `succeed` / `fail` / `cancel` outcome wins. Repeated outcome
events are harmless.

`Console_eio.run` passes a `Display.t`; semantic task and history operations use
it, while static widgets are ordinary pretty-printers. A nested
`Console_eio.run` joins the current display, so separately composed libraries
cannot claim the terminal twice. `Display.dumb ()` is the advanced
non-interactive start context for core tests.

```ocaml
let interactive draw =
  Eio_main.run @@ fun env ->
  let clock = Eio.Stdenv.clock env in
  Console_eio.run ~clock @@ fun display -> draw display
```

```ocaml
open Console

let download ~clock ~total_bytes read_chunk =
  Console_eio.run ~clock ~header:"Downloading" @@ fun display ->
  let task = Display.task ~log_lines:3 display "payload.tar" in
  let rec loop cur =
    match read_chunk () with
    | Some n ->
        let cur = Int64.add cur n in
        Display.set_bytes task ~cur ~total:total_bytes;
        Display.log task (Fmt.str "received %Ld bytes" n);
        loop cur
    | None -> Display.succeed task ~message:"payload.tar done"
  in
  loop 0L;
  Display.set_result display (`Ok "done")
```

`set_count task ~cur ~total` is the item-counter equivalent (`3/8`).
`Display.log task "line"` always appends a permanent event; `~log_lines:n` only
controls how many recent lines are mirrored in the activity snapshot.
`Display.event display "line"` records a session-level event. The Eio runner
owns ticking and scoped `Logs` routing automatically.

Tasks nest semantically:

```ocaml
let build ~clock packages =
  Console_eio.run ~clock ~header:"Building" @@ fun display ->
  List.iter
    (fun pkg ->
      let step = Display.task display pkg in
      let compile = Display.task ~parent:step display "compile" in
      Display.succeed compile;
      Display.succeed step ~message:(pkg ^ " built"))
    packages;
  Display.set_result display (`Ok "all built")
```

Use `fail` for a failed task and `cancel` for work intentionally abandoned.
There is no remove-or-clear operation: an outcome is part of the history.
`Display.history` and `Display.activity` expose the two semantic projections
without exposing mutable display internals.

### Advanced row layout: the `Line` DSL

The default row infers spinner, bar, count, rate and elapsed presentation from
semantic progress updates. Only applications with genuinely unusual density
should assemble a row from pieces; pieces that do not apply render as nothing.

```ocaml
open Console

let sync_style =
  let bar_style =
    Display.Line.(
      v ~color:Color.magenta
        [ spinner; text " "; label; text "  "; bar 24; text " ";
          percent; text " "; count; text " "; rate; spacer; elapsed ])
  in
  bar_style
```

Pieces: `spinner`, `label`, `bar n`, `percent`, `count`, `rate`, `elapsed`,
`text s`, `accent s`, `spacer` (absorbs slack, right-justifying what follows).
`Display.Line.default` is built from these. Pass `~bar` to `task`, or to `run`
for the session default. A layout may contain at most one `label` and `spacer`.

### Themes

Themes fix the glyphs and accent palette: `Theme.default`, `unicode`, `dos`,
`matrix`, `rainbow` (rows cycle the spectrum, the bar becomes a colour
gradient). Bar fills are `` `Blocky ``, `` `Smooth ``, or `` `Rainbow ``.
`Panel.rain panel` is the built-in Matrix digital-rain animation value.

### Non-TTY output

Under a pipe or `~mode:`` `History ``, events are append-only: every log and
terminal outcome, followed by the optional summary and result. Same code, no
cursor moves and no escape codes.

## A complete CLI

```ocaml
open Console
open Cmdliner

let show_status services =
  let columns = [
    Table.column "Service";
    Table.column ~align:`Center "Status";
    Table.column ~align:`Right "Uptime";
  ] in
  let rows = List.map (fun (name, status, uptime) ->
    let status_span = match status with
      | `Up -> Span.styled Style.(fg Color.green) "UP"
      | `Down -> Span.styled Style.(fg Color.red) "DOWN"
    in
    [ Span.text name; status_span; Span.text uptime ]
  ) services in
  let status_table = Table.of_rows ~border:Border.rounded columns rows in

  let status_panel = Panel.v
    ~title:(Span.styled Style.bold "Service Status")
    (Span.text (Table.to_string status_table))
  in
  Panel.pp Format.std_formatter status_panel

let cmd =
  let info = Cmd.info "status" ~doc:"Show service status" in
  Cmd.v info Term.(const show_status $ const [
    ("web", `Up, "3d 12h");
    ("db", `Up, "7d 2h");
    ("cache", `Down, "0h");
  ])

let main () = exit (Cmd.eval cmd)
```
