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
  linux: static   # static (Alpine + musl) or linuxbrew (Homebrew on Linux)

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
| `macos_only` | `false` | Binary builds on macOS only, so ship no Linux bottle |

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

## Release

`bottler release` runs the whole pipeline: `dune build @install`, package each
binary as a `.tar.gz` bottle, upload to S3 under a dated name plus a rolling
`latest` alias, clone or pull the tap, generate or update the formulas with
their SHA256 checksums, then commit and push the tap. `--dry-run` shows the plan
without touching the bucket or the tap.

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

**Checksums not updating**: the updater looks for platform markers (`on_arm
do`, `on_intel do`, `on_linux do`) in the formula. A hand-edited formula may no
longer match them.

**Upload reported success but the bottle is missing**: S3 `PutObject` has
returned `Ok` on silent failures, so `upload` verifies the object afterwards.
A verification failure here is real; re-run rather than trusting the first `Ok`.
