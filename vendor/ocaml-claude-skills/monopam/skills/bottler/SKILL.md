---
name: bottler
description: "Building and releasing Homebrew bottles from the dune monorepo with the bottler CLI. Use when adding a package to the homebrew tap, building or releasing bottles, configuring S3 storage or tap settings, provisioning CI upload credentials, reclaiming bucket space, or debugging a formula that won't pour."
---

# bottler

Builds, uploads, and releases Homebrew bottles from a dune monorepo. It
generates Ruby formulas with platform-specific SHA256 checksums, uploads bottles
to S3-compatible storage, and manages the tap repository.

Uploads go **directly to S3** (Scaleway, Sigv4-signed via `S3_eio`); there is no
rclone in the upload path.

## Commands

| Command | Purpose |
|---------|---------|
| `bottler release [NAME]...` | Full pipeline: build, upload, update tap (`--dry-run`) |
| `bottler build [NAME]...` | Build bottles for the current platform |
| `bottler upload [FILE]...` | Upload bottles to object storage |
| `bottler formula [NAME]...` | Generate the Ruby formulas (`--checksums=DIR`) |
| `bottler install [NAME]...` | Release, then install or upgrade via brew (`--local`) |
| `bottler config` | Show the parsed configuration |
| `bottler doctor` | Check tools and credentials |
| `bottler login` | Set up Scaleway credentials |
| `bottler keys` | Provision upload-only Scaleway credentials for CI |
| `bottler list` | List every formula in the shared tap |
| `bottler remove NAME` | Remove a formula from the shared tap |
| `bottler usage` | Report storage usage of the bottles bucket |
| `bottler gc` | Delete old bottle versions from the bucket |
| `bottler init` | Create the Bottler project helper files (`--dir`, `--force`) |

All commands take `--config=FILE` (default `homebrew.yml`) and `--color=WHEN`.
`bottler build prune merlint` and `bottler release precommit` restrict the run to
named packages.

## Configuration

`homebrew.yml` at the monorepo root. The package list key is **`packages:`**.

```yaml
handle: gazagnaire.org
mono_url: https://tangled.org/gazagnaire.org/ocaml-git.git

storage:
  bucket: homebrew-bottles      # S3 bucket
  region: fr-par                # S3 region
  profile: homebrew-monopam     # Scaleway profile name
  # endpoint: defaults to https://s3.{region}.scw.cloud

tap:
  clone_url: https://github.com/samoht/homebrew-monopam.git
  push_url: git@github.com:samoht/homebrew-monopam
  # local_path: "../homebrew-monopam"

build:
  linux: static     # static (Alpine + musl) or linuxbrew (Homebrew on Linux)
  switch: lto-5.4.1 # opam switch the --profile=release build runs under

packages:
  - name: merlint                       # formula name and installed binary name
    target: merlint/bin/main.exe        # dune executable, relative to the root
    description: "Opinionated OCaml linter powered by Merlin"
```

`target` is the path to the dune executable relative to the monorepo root;
bottler looks for the built binary at `_build/default/{target}`.

Optional per-package fields:

| Field | Default | When to set |
|-------|---------|-------------|
| `homepage` | derived | Custom homepage URL |
| `head_deps` | `[]` | Runtime deps for `--HEAD` builds |
| `conflicts_with` | `[]` | Homebrew formulas installing a clashing binary |
| `entitlements` | `[]` | macOS entitlement keys to ad-hoc codesign with at install time |
| `requires` | unset | Platform the binary needs: `os` (`macos`/`linux`) and `arch` (`arm64`/`x86_64`) |
| `version_scheme` | unset | Raise when a release's version string sorts below the one it replaces |
| `former_names` | `[]` | Names the package published under before, redirected to this one |

```yaml
  - name: prune
    target: prune/bin/main.exe
    description: "Dead code remover for OCaml .mli files"
    conflicts_with:
      - graphviz             # both install a `prune` binary

  - name: crow
    target: ocaml-crow/bin/main.exe
    description: "Crowbar campaign orchestrator for AFL fuzzing"
    head_deps:
      - name: afl++          # must be a real Homebrew formula name
        type: recommended    # or "build"
```

Only non-restricted entitlements work with an ad-hoc signature, so
`entitlements` covers the codesigning a binary needs to run at all, not
capabilities requiring a real Apple identity.

A formula builds from source on any machine with no matching bottle, so a
package that serves one platform declares it. `requires` becomes the formula's
`depends_on` lines and brew refuses everywhere else:

```yaml
  - name: vz
    target: ocaml-vz/bin/vz_cli.exe
    description: "Boot a Linux VM with a user-mode slirp network, no sudo"
    requires:
      os: macos             # macos or linux
      # arch: arm64         # arm64 or x86_64
```

Set both keys for a single-platform package. An arm64 Linux machine meets
`arch: arm64` on its own and an Intel Mac meets `os: macos` on its own, so one
key alone leaves the other machine falling through to the source build. A value
brew does not know fails the config load.

Brew compares version strings token by token, so a package moving from a
`YYYYMMDD-<sha>` stamp to a semver such as `0.1.0` reads as a downgrade and
`brew upgrade` skips it. Set `version_scheme: 1` on that package and brew
treats the new formula as newer whatever the strings say. Leave it unset on a
package that never carried a date stamp.

## Renaming and removing a package

Publishing writes a formula per declared package, so a package dropped from
`packages:` leaves its formula published and unmaintained. Both cases are
declared, and each gets the Homebrew mechanism made for it.

A **rename** is `former_names` on the package that replaced it. Bottler records
the old name in the tap's `formula_renames.json` and deletes its formula. Both
steps are needed for the redirect to work: brew consults that file before it
looks for a formula, and its tap audit reports an old name that still has a
file as a conflict.

```yaml
  - name: irm
    target: irmin/bin/main.exe
    description: "Content-addressable store with Git support"
    former_names:
      - irmin              # brew install <tap>/irmin now loads irm
```

A **removal** is a top-level `removed:` entry. The formula is not deleted:
brew keeps answering the name with the reason and the date, which is more than
"no available formula" tells anyone. `date` must be `YYYY-MM-DD` and `because`
is a verb phrase, since brew prints it after "`<name>` has been disabled
because it", followed by an exclamation mark.

```yaml
removed:
  - name: space
    date: 2026-04-15
    because: "is no longer built from this monorepo"
```

The retired formula keeps the description and version it published, read back
from the formula already in the tap, so nothing here restates what was served
and a name that tap never published is left alone.

Both sets are derived from the declared packages and nothing else. A formula on
disk that this `homebrew.yml` does not name belongs to another source sharing
the tap and is never touched. `bottler release --dry-run` prints the renames,
the deletions and the retirements alongside the build list.

## Release

`bottler release` runs the whole pipeline: `dune build @install`, package each
binary as a `.tar.gz` bottle, upload to S3 under a dated name plus a rolling
`latest` alias, clone or pull the tap, generate or update the formulas with
their SHA256 checksums, then commit and push the tap. `--dry-run` shows the plan
without touching the bucket or the tap, including what it would do to the
tap's formula set.

Bottles are built **for the current platform only**, so run `bottler release` on
each target machine:

| Platform | Bottle suffix |
|----------|---------------|
| macOS ARM64 | `arm64_sonoma` |
| macOS Intel | `sonoma` |
| Linux x86_64 | `x86_64_linux` |
| Linux ARM64 | `arm64_linux` |

`build.linux` picks how Linux bottles are produced: `static` builds against
Alpine and musl, `linuxbrew` builds under Homebrew on Linux.

`build.switch` names the opam switch the release build runs under, and it is
required: there is no default. The release profile links with `-use-lto` and
the root `dune` refuses a compiler that lacks the flag, so a release built
under the local dev switch produces no bottle at all. `bottler build` runs
`opam exec --switch <build.switch> -- dune build --profile=release`, and
`bottler doctor` checks up front that the switch exists and that its `ocamlopt`
takes `-use-lto`. A config with no `build.switch` (or no `build:` at all) is a
decode error naming the missing member.

Formulas are Ruby files in the tap's `Formula/` directory supporting
per-platform bottle downloads, `--HEAD` builds from source via opam and dune,
custom dependencies, and automatic checksums. The class name derives from the
package name: `my-tool` becomes `MyTool`.

For a real `brew` pour to work the formula needs a stable `url`, otherwise it is
HEAD-only.

## Credentials and storage upkeep

```sh
bottler login     # interactive Scaleway credential setup
bottler keys      # upload-only credentials for CI
bottler doctor    # verify tools and credentials
bottler usage     # how much the bucket is holding
bottler gc        # delete superseded bottle versions
```

Secrets never reach the parsed config, so `bottler config` output is safe to
paste or log.

## Troubleshooting

**"Executable not found for X, skipping"**: the binary wasn't built. Check
`dune build @install` succeeds, `_build/default/{target}` exists, and `target`
is correct in `homebrew.yml`.

**"the release profile needs a compiler with -use-lto"**: the release build ran
under a switch whose compiler lacks the flag. Point `build.switch` at the LTO
switch and re-run `bottler doctor`.

**Checksums not updating**: the updater looks for platform markers (`on_arm
do`, `on_intel do`, `on_linux do`) in the formula. A hand-edited formula may no
longer match them.

**Upload reported success but the bottle is missing**: S3 `PutObject` has
returned `Ok` on silent failures, so `upload` verifies the object afterwards.
A verification failure here is real; re-run rather than trusting the first `Ok`.
