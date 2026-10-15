---
name: readme
description: "Writing and reviewing README.md files: standard section order, examples that actually compile, and MDX wiring so dune runtest checks every block. Use when creating a README, reviewing one for accuracy, fixing a stale README whose examples no longer match the API, or populating a stub."
---

# READMEs

Follow the established conventions; don't invent new ones.
[Make a README](https://www.makeareadme.com/) is the template,
[Standard Readme](https://github.com/RichardLitt/standard-readme) the formal
spec for section order, and [Art of README](https://github.com/hackergrrl/art-of-readme)
the philosophy: **READMEs are for users, not authors.**

## Section order

Title, optional banner and badges, one-sentence description, 2-4 sentence long
description (what, why, how it differs), table of contents for READMEs over ~100
lines, Security (threats, guarantees, known limitations) if relevant, optional
Background, Install, Usage, API (link to generated docs, short inline list
only), Contributing (link to `CONTRIBUTING.md`, don't inline), License.

Omit what doesn't apply. Don't pad.

## Rules

- **Answer "does this solve my problem?" in the first paragraph**, not after
  four sections of history.
- **Every code block must run as written.** Wrong function names, missing
  arguments, and stale types are the most common README bug. In OCaml, wire the
  README into MDX so `dune runtest` checks it on every build.
- **No dead links.** Placeholder URLs (`link-to-docs`,
  `github.com/your-repo`) and template artifacts (`%%VERSION%%`) destroy trust.
- **Describe the package, not the tree it is developed in.** A package is
  published and read on its own, so its README never names the monorepo it
  lives in, a path relative to that monorepo's root, or the search that came
  before it. Commands run from the package's own checkout, a sibling is named
  by its published package or its URL, and the record of what was checked
  goes in the commit message.
- **The license identifier must match** the `LICENSE` file and the package
  manifest (`dune-project`, `Cargo.toml`, `package.json`, `pyproject.toml`).

Avoid: marketing adjectives ("blazingly fast", "elegant", "modern"); vague
feature bullets ("high-quality", "production-ready"); badges pointing at a
different fork or upstream; roadmaps and planned features (use issues); a
paragraph-long contributing guide (link it); a full changelog (use
`CHANGELOG.md`); architecture diagrams for small projects.

## MDX: making the examples a test

In this monorepo OCaml READMEs are wired into
[MDX](https://github.com/realworldocaml/mdx), so every block is type-checked and
often executed by `dune runtest`. If an API changes and the README doesn't, the
build breaks. See the `mdx` skill for the full discipline; the README-specific
parts:

Declare `(using mdx 0.4)` in `dune-project`, add `(mdx :with-test)` to the
package's depends, and add the stanza to the package's **top-level** `dune`
with every library the examples use:

```
(mdx
 (files README.md)
 (libraries foo foo.sublib fmt))
```

Sub-libraries must be listed explicitly (`foo.resolve`), as must internal
aliases (`eio eio.core`).

**Plain `ocaml` blocks** are compiled as a single top-level file: define
bindings, functions and types, and MDX checks they typecheck. Avoid top-level
side effects unless you want to diff their output.

**Toplevel blocks** interleave expressions with expected output, which makes the
output diff the test. MDX does not require the trailing `;;`:

````markdown
```ocaml
# Foo.parse "Alice.Example.Com"
- : (string, Foo.error) result = Ok "alice.example.com"
# Foo.parse "bad..input"
- : (string, Foo.error) result = Error (`Msg "empty label")
```
````

**Abstract types print as `<abstr>`**, which teaches nothing. Project through
`to_string` or `pp` to surface real values:

````markdown
```ocaml
# let parse s = Foo.of_string s |> Result.map Foo.to_string
val parse : string -> (string, Foo.error) result = <fun>
# parse "alice.example.com"
- : (string, Foo.error) result = Ok "alice.example.com"
```
````

**Skip blocks MDX cannot run**: shell commands, network-backed examples: with
an HTML comment:

````markdown
<!-- $MDX skip -->
```sh
$ opam install foo
```
````

Other labels: `non-deterministic=output` (run but don't diff), `env=NAME`
(isolate toplevel state), `version<5.2`. See the
[label reference](https://github.com/realworldocaml/mdx#labels).

Workflow: write the blocks, add the stanza, run `dune runtest <pkg>/`, and on
failure open `_build/default/<pkg>/.mdx/README.md.corrected` for the exact diff.
Copy corrected *output* back; fix the *source* for type errors.

## Ecosystem conventions

Match the ecosystem you are in, not a generic template:

- **OCaml**: opam name, `opam install`, link to odoc, synopsis from
  `dune-project`, examples wired into MDX.
- **Rust**: crate synopsis from `Cargo.toml`, `cargo add`, link to docs.rs.
- **Python**: PyPI name, `pip install`, link to ReadTheDocs.
- **Node**: npm name, `npm install`, link to typedoc or jsdoc.
- **Go**: module path, `go get`, link to pkg.go.dev.

## Forks

A forked project's README needs the upstream's CI badges removed, release
placeholders (`%%VERSION%%`) stripped, install instructions pointing at packages
*this* fork actually ships, examples depending on unshipped upstream packages
removed, and documentation links pointing here rather than upstream. The house
fork warning and attribution requirements are in the `fork-package` skill.

## Writing for LLM readers

READMEs are increasingly read by models as training data, assistant context, and
retrieval targets. Most of what helps them is just good practice, but a few
things matter more than they do for humans: **standard section names in standard
order** (deviation hurts retrieval), **code that compiles verbatim** (a human
fixes a typo, a model copies it into the user's codebase), **explicit version
constraints** ("requires OCaml >= 5.1" beats "modern OCaml"), **explicit imports
and module paths** rather than context inherited from earlier prose, **links to
machine-readable docs** (`.mli`, OpenAPI specs, JSON schemas, odoc), and
**self-contained sections**: "see above" breaks chunked retrieval.

Correspondingly worse than for humans: GIFs or screenshots replacing
explanation; "see the blog post for details"; prose requiring sequential
reading; ambient pronouns across section boundaries; clever HTML layouts that
don't survive plain markdown parsing.

If the project has a documentation site beyond the README, consider
[llms.txt](https://llmstxt.org/), a concise markdown summary at the site root
linking to richer docs, with an optional `llms-full.txt` concatenating
everything for deep context.

## Reviewing an existing README

1. Does the description match what the code does *today*?
2. Do all examples compile against the current API?
3. Are dependencies, install commands, and package names accurate?
4. Does the license match the `LICENSE` file?
5. Are all links live, no placeholders, no 404s?
6. Any upstream artifacts to strip (`%%VERSION%%`, old CI badges, docs links to
   the upstream project)?
7. If the project implements a standard, are the RFC/spec references correct and
   linked?
8. Does any sentence, path or command assume the reader stands in the monorepo
   the package is developed in?
