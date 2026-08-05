---
name: perf
description: "Making OCaml programs fast with obs: capture a run, read the budget and verdict, drill the dominant cost, and re-measure differentially. Use to find why a program is slow or allocates too much, tell GC-bound from CPU- or IO-bound, rank allocation hotspots, sample a hot function, query a trace as SQL, or instrument a library with Probe spans."
---

# Performance with obs

Measure, don't guess. `obs` runs your program, splits wall-clock into waiting /
GC / CPU, states a verdict, and points at the dominant cost. Every "what's slow"
hunch is wrong about half the time: if you cannot point at a trace line or a
specific allocation, you are still guessing.

`obs` is not on `PATH`; invoke it through dune:

```sh
dune exec -- obs run -- ./bench.exe <args>
```

Benchmarks must run release-profile binaries; numbers from a dev build are not
valid.

## The loop

**1. Capture and triage.** One command gives the budget, the verdict, and ranked
findings. `--out BASE` keeps the bundle so you can drill it.

```sh
dune exec -- obs run --out /tmp/run -- ./bench.exe <args>
dune exec -- obs report /tmp/run          # replay the same report offline
```

**2. Read the verdict, then drill only the regime it names.** Drilling an axis
the verdict did not name is how sessions get wasted.

| Verdict | Drill with |
|---------|-----------|
| GC-bound (allocation) | `obs hotspots /tmp/run.memtrace/<pid>.ctf` |
| CPU-bound (a hot function) | `obs run --sample 10 -- ./bench.exe <args>` |
| syscall / IO-bound | the timeline: drop `/tmp/run.pb` into <https://ui.perfetto.dev> |
| contention / fiber | the named wait: `obs run --sqlite /tmp/run.db`, then `obs query /tmp/run.db contention` |

**3. Drill to a `file:line`**, make the smallest behaviour-preserving change,
and **re-measure differentially**: re-run `obs run` and confirm the budget moved
as predicted, or `obs hotspots --baseline before.ctf after.ctf` for allocation.
If allocation dropped but wall-clock didn't, the workload was not GC-bound: go
back to step 2.

Commit each removed hotspot separately with before/after numbers, so the win is
auditable and a regression bisects to one change.

## Reading the report

```text
== BUDGET ==
wall=323.58ms waiting=5.14ms (2%) gc=310.91ms (96%) cpu=7.21ms (2%)

== VERDICT ==
GC-bound. 96% of wall-clock is in GC; allocates too much.

== FINDINGS ==
#1 [gc] allocates too much: 96% of wall in GC
    FIX: run: obs hotspots /tmp/run.memtrace/<pid>.ctf
    payoff=-310.91ms (-96%) confidence=estimate
```

Finding kinds: `gc` (allocation, drill with `obs hotspots`), `cpu` (a hot
operation, drill with `--sample`), `syscall` (blocking calls), `contention` (a
named Mutex/Stream/Promise wait), `fiber` (a fiber almost always suspended).

Allocation is a proxy for GC pressure, not for wall-clock. If the trace duration
is far shorter than wall-clock and CPU looks high, distrust the budget: a quiet
ring reads as CPU. Confirm a real spin with `--sample`.

## The bundle

`obs run --out BASE` writes `BASE.fxt`, `BASE.pb`, and
`BASE.memtrace/<pid>.ctf`, plus `BASE.cpu.xml` when sampling. Without `--out` it
uses `.obs/<id>/` and updates `.obs/latest`.

- **`.fxt`**: scheduler, GC, fibers, contention, probe spans. This is what the
  report is built from: the wall-clock budget split, GC time and cycle counts,
  waiting split by syscall cause, per-object contention, and root-fiber
  exclusion.
- **`.ctf`**, one memtrace allocation trace per process using `Observe.setup`
  (which honors `MEMTRACE`).
- **`.cpu.xml`**: the native on-CPU stack profile.
- **`.pb`**: the Catapult/Perfetto sidecar, for <https://ui.perfetto.dev>.
  **`obs report` does not read it.**

```sh
obs run [--out BASE] [--sqlite FILE] [--sample SECONDS] [--catapult FILE] -- CMD
obs report [TRACE|ID]...          # no args = .obs/latest
obs hotspots NEW.ctf              # or: --baseline OLD.ctf NEW.ctf
obs query BASE.db [QUERY] [--sql SQL]
```

`obs report` takes a bare `BASE` (reading `BASE.fxt` plus
`BASE.memtrace/*.ctf`), a bare `ID` (reading `.obs/ID/...`), or explicit `.fxt`
and `.ctf` paths.

Useful `run` flags beyond the four above: `--tcp PORT` accepts producers over
TCP so a remote host or a solo5 unikernel guest can stream with
`OBS_COLLECTOR=tcp:HOST:PORT`; `--sample-trigger PATH` delays the sampling
window until `PATH` exists, which aligns it with a measured phase inside a
long-lived child such as a VM launcher; `--grace SECONDS` (default 0.5) keeps
collecting after the child exits to drain stragglers; and `--sort KEY`
(`self|total|count|p99|alloc`), `--min PCT`, `--all` control the span table.

**`--sample` takes SECONDS, not a count** (default 6, `0` disables). It records
a native on-CPU profile using xctrace's Time Profiler on macOS and perf on
Linux, saves it to `BASE.cpu.xml`, and prints the top leaf functions after the
report.

`obs` stdout carries only the report (or, under `--json`, only the JSON
document); child output and progress go to stderr, so `obs run --json ... | jq`
stays parseable.

## Drilling allocation

`obs hotspots FILE.ctf` ranks every allocation site by its share of total
sampled bytes: the ceiling on any fix, by Amdahl's law. Each site is reported
as DIAGNOSIS, EVIDENCE (count x bytes-per-alloc), FIX, and PAYOFF, biggest
payoff first. Read it top-down and fix the #1.

The output is deterministic for the same trace and plain ASCII when piped, so it
ingests cleanly.

```sh
obs hotspots /tmp/run.memtrace/<pid>.ctf [--top N] [--min PCT] [--sort KEY] [--json]
obs hotspots --baseline before.ctf after.ctf
```

The fix-iterate loop is: profile, fix the #1 site, profile again, and pass the
old trace to `--baseline` to confirm that site shrank and watch the new leader
appear. Repeat until the top payoff is trivial.

The `== SUMMARY ==` block reports the executable, pid, total allocated bytes and
sample count, `promoted` (the fraction of bytes surviving to the major heap),
and a `dropped` line counting sub-cut sites and their combined share: check
that last one before concluding the top sites are the whole story.

## Querying a trace as SQL

`--sqlite FILE` writes the trace in Perfetto's `trace_processor` schema
(`slice` / `counter` / `thread` / `process`), openable in `sqlite3`, Datasette,
or any SQLite tool. `obs query BASE.db` with no query name lists the canonical
queries; a name runs one; `--sql` runs ad-hoc SQL.

## Instrumenting a library

Declare spans and counters once, at module level, with flat scalar fields.
Emission is a no-op and allocates nothing until a capture starts, so it costs
nothing in production.

```ocaml
let request =
  Probe.span "mylib.request"
    Probe.Fields.(obj (fun path -> path)
      |> field "path" string ~enc:(fun path -> path) |> seal)

let handle t path = Probe.with_span request path @@ fun () -> ...
```

Instrument the **library, not the caller**, at **operation granularity**: one
span per request, file, or build step, never per function, so every consumer's
captures attribute time and allocation to names like `mylib.request`. Counters
(`Probe.counter` + `Probe.record`) are for sampled measurements such as queue
depths. Eio applications call `Observe_eio.setup` (or `Probe_eio.install` once)
so span context is fiber-accurate. Add `observe` to the bench executable's
libraries, and keep it out of the library's runtime deps.
