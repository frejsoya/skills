---
name: code-style
description: "OCaml coding style and refactoring patterns. Use when the user asks to tidy, clean up, refactor, or improve OCaml code, reviewing code quality, enforcing naming conventions, or reducing complexity."
---

# OCaml Code Style

## Core Philosophy

1. **Interface-First**: Design `.mli` first. Clean interface > clever implementation.
2. **Modularity**: Small, focused modules. Compose for larger systems.
3. **Simplicity (KISS)**: Clarity over conciseness. Avoid obscure constructs.
4. **Explicitness**: Explicit control flow and error handling. No exceptions for recoverable errors.
5. **Purity**: Prefer pure functions. Isolate side-effects at edges.
6. **NEVER use Obj.magic**: Breaks type safety. Always a better solution.

## Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Files | `lowercase_underscores` | `user_profile.ml` |
| Modules | `Snake_case` | `User_profile` |
| Types | `snake_case`, primary type is `t` | `type user_profile`, `type t` |
| Values | `snake_case` | `find_user`, `create_channel` |
| Variants | `Snake_case` | `Waiting_for_input`, `Processing_data` |

**Function naming**:
- `find_*` returns `option` (may not exist)
- `get_*` returns value directly (must exist)

**Avoid**: Long names with many underscores (`get_user_profile_data_from_database_by_id`).

## Refactoring Patterns

### Option/Result Combinators

```ocaml
(* Before *)
match get_value () with Some x -> Some (x + 1) | None -> None

(* After *)
Option.map (fun x -> x + 1) (get_value ())
```

Prefer: `Option.map`, `Option.bind`, `Option.value`, `Result.map`, `Result.bind`

### Monadic Syntax (let*/let+)

```ocaml
(* Before - nested matches *)
match fetch_user id with
| Ok user -> (match fetch_perms user with Ok p -> Ok (user, p) | Error e -> Error e)
| Error e -> Error e

(* After *)
let open Result.Syntax in
let* user = fetch_user id in
let+ perms = fetch_perms user in
(user, perms)
```

### Pattern Matching Over Conditionals

```ocaml
(* Before *)
if x > 0 then if x < 10 then "small" else "large" else "negative"

(* After *)
match x with
| x when x < 0 -> "negative"
| x when x < 10 -> "small"
| _ -> "large"
```

## Function Design

**Keep functions small**: Under 50 lines. One purpose per function.

**Avoid deep nesting**: Max 4 levels of `match`/`if`. Extract helpers.

**High complexity signal**: Many branches = split into focused helpers.

```ocaml
(* Bad - high complexity *)
let check x y z =
  if x > 0 then if y > 0 then if z > 0 then ... else ... else ... else ...

(* Good - factored *)
let all_positive x y z = x > 0 && y > 0 && z > 0
let check x y z = if not (all_positive x y z) then "invalid" else ...
```

## Error Handling

**Use `result` for recoverable errors**. Exceptions only for programming errors.

**Never catch-all**:
```ocaml
(* Bad *)
try f () with _ -> default

(* Good *)
try f () with Failure _ -> default
```

**Don't silence warnings**: Fix the issue, don't use `[@warning "-nn"]`.

## Library Preferences

| Instead of | Use | Why |
|------------|-----|-----|
| `Str` | `Re` | Better API, no global state |
| `Printf` | `Fmt` | Composable, type-safe |
| `yojson` (manual) | `jsont` | Type-safe codecs |

## Module Hygiene

**Abstract types**: Keep `type t` abstract. Expose smart constructors.

```ocaml
(* Good - .mli *)
type t
val create : name:string -> t
val name : t -> string
val pp : t Fmt.t
```

**Avoid generic names**: Not `Util`, `Helpers`. Use `String_ext`, `Json_codec`.

## API Design

**Avoid boolean blindness**:
```ocaml
(* Bad *)
let create_widget visible bordered = ...
let w = create_widget true false  (* What does this mean? *)

(* Good *)
type visibility = Visible | Hidden
let create_widget ~visibility ~border = ...
```

## Comments and Documentation

Documentation is written in the voice of a POSIX manual page. Implementations
carry no comments where the code speaks for itself. Load the `doc-style` skill
before writing or rewording any comment. It is the full standard and the list
below is only its summary.

The short form:

- A function's doc opens `[f x y] is ...`, on the line after the `val`.
- Full sentences ending in a full stop. No fragments.
- No colons or em dashes joining clauses. Use separate sentences.
- Nothing about the implementation. Only what the caller can observe.
- No `This function`, `Note that`, `simply`, `helper for`, `internally`.
- Every optional argument states its default.
- Delete implementation comments that restate the code, section banners, and
  commented-out code.
- Documentation lives in the `.mli`. An `.ml` with an `.mli` carries no
  `(** ... *)` comments.

```ocaml
(* Bad *)
(** Parses the string: splits on commas and builds the record — fast. *)
val parse : string -> t

(* Good *)
val parse : string -> t
(** [parse s] is the record encoded in [s]. Parsing is linear in the length of
    [s]. *)
```

## Red Flags

- Match that just rewraps: `Some v -> Some (f v) | None -> None`
- Nested Result/Option matches → use let*/let+
- Deep if/then/else → pattern matching
- Missing `pp` function on types
- Unlabeled boolean parameters
- `Obj.magic` anywhere
- Doc comments that describe the implementation rather than the behaviour
- Comments inside an implementation that restate the code
- A colon or em dash joining clauses in a doc comment
- An exported value with no doc comment
