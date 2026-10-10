---
name: supernpu-pipeline-visualization
description: Generate SuperNPUBench gfsim PipeView/Konata and SwimLane/Perfetto pipeline traces from an existing ELF. Use when the user asks for a pipeline diagram, instruction timeline, PE utilization view, or trace-based performance investigation; do not use for numerical accuracy checks.
---

# SuperNPU pipeline visualization

Generate a trace from an existing, identified ELF, then open it with the matching visualizer. This is a timing-model analysis workflow: it does not compile kernels or validate numerical output.

## Preflight

- Work in WSL. Run `gfsim` from the SuperScalarModel repository root because `--conf fourpe` resolves repository-relative configuration.
- Record the ELF absolute path and SHA256, model commit and `gfsim` binary identity, full command, PE configuration, L2 mode, and output paths.
- Confirm the ELF's intended PE mode from its launch contract. For 4PE use `--conf fourpe --pto-v02 true`; do not substitute gfrun's `softcore.multiThreadNum` option.
- Build `gfsim` only if it is absent or stale for the selected model source. Do not build or run `gfrun` unless the user separately requests functional or accuracy validation.
- Read the selected model checkout's `modelSpec/pipeview.md` or `modelSpec/swimlane.md` before using version-specific options. Treat old trace flag behavior and L2 defaults as version-dependent.

## Choose L2 mode deliberately

Use an explicit `-s tlsu.fake_l2_enable=<true|false>` in every command. Prefer the mode the user requests or the project's validation policy.

If real L2 prevents the selected model/ELF from reaching a report, a fake-L2 trace is a diagnostic trace, not a hardware-faithful performance result. Preserve the real-L2 failure log and label the generated trace `fake-l2`.

## First run: bounded block-level trace

Start with a bounded trace and a dedicated output directory outside tracked source directories. For a 4PE ELF:

```bash
cd <SuperScalarModel-root>
mkdir -p <trace-dir>
timeout -k 10s <timeout-seconds> ./bin/gfsim -f <elf> \
  --conf fourpe --pto-v02 true \
  -s tlsu.fake_l2_enable=<true|false> \
  -p 2 --pipefile <trace-dir>/<case>-pipe
```

`-p 2` is block-level PipeView and should be the default for large kernels. Use `-p 1` only for a narrowly scoped instruction-level investigation with sufficient disk space; it can create very large files. Use `-p 0` to disable PipeView.

Confirm the log reached a normal report stop and the trace file exists and is non-empty before presenting it. A timeout, deadlock, assertion, or partial trace must be reported as such, not shown as a complete pipeline result.

Open the generated `<prefix>.out` in Konata. Do not upload it to a third-party service unless the user explicitly authorizes that action.

## Memory-bounded JSON generation

For 4PE SwimLane traces, prefer the [bounded generator](scripts/generate_swimlane_safe.py):

```bash
python3 scripts/generate_swimlane_safe.py \
  --model <SuperScalarModel-root> --elf <absolute-ELF> \
  --output-dir <new-trace-dir> --memory-gib 3 \
  --counter-interval 128 --fake-l2 false --soc-random true --seed 2
```

Choose the L2 and SoC settings to match the selected validation run; the example uses Real-L2 and random SoC seed 2. The helper copies the fourpe profile into the output directory, replacing its counter interval instead of adding a duplicate override. It caps only the child process's address space at the smaller of the requested budget and 60% of current available RAM, disables child core dumps, and records the command, binary/ELF hashes, model diff hash, exit status and peak RSS. It does not modify WSL memory/swap or global model configs. The destination must be new.

Counter sampling affects auxiliary cycle-sampled counters; block duration and dependency events stay complete. Record the interval. After a memory-limit failure, preserve the log and label the trace incomplete; do not automatically raise the limit or disable the cap.

On memory-constrained WSL, the model's JSON exporter should write one event at a time. The legacy exporter builds multiple full JSON arrays and a full output string and can exceed 4 GiB on a million-event trace. A memory cap prevents a legacy-export run from consuming all available RAM, but does not itself make that exporter complete.

When comparing a regenerated trace with an earlier one, use [streaming comparison](scripts/compare_trace_streaming.py) rather than loading both full documents with json.load:

```bash
python3 scripts/compare_trace_streaming.py <old-trace.json> <new-trace.json>
```

The comparator checks full event content/order and writes a compact semantic comparison report beside the new trace.

## SwimLane trace

Generate SwimLane separately, without `-p`, so its artifact and provenance are unambiguous:

```bash
cd <SuperScalarModel-root>
timeout -k 10s <timeout-seconds> ./bin/gfsim -f <elf> \
  --conf fourpe --pto-v02 true \
  -s tlsu.fake_l2_enable=<true|false> \
  --swimlane 1 --swimfile <trace-dir>/<case>-swim
```

Validate that `<prefix>.json` parses as JSON and contains non-empty events with meaningful timestamps. Inspect PE and engine tracks before claiming a utilization, dependency, or critical-path conclusion. Open the JSON locally in Perfetto (`https://ui.perfetto.dev/`) when the user asks to view it; its normal browser workflow does not require upload.

## Narrowing and filtering

Only after a normal trace establishes the broad behavior, use supported model flags to reduce trace volume. For example, if supported by the selected model revision, filter PipeView to an engine with:

```bash
-s dfx.pipeViewFilterEnable=true -s dfx.pipeViewFilterSet=CUBE
```

Record every filter. A filtered trace cannot establish whole-device utilization or a full critical path.

## Report

State separately:

- whether gfsim completed, its exit code, report-stop evidence, and total cycles;
- whether the trace is real-L2 or fake-L2, PE mode, and every filter;
- generated PipeView and SwimLane absolute paths, sizes, and validation result;
- observations backed by visible trace intervals or PMU/log evidence.

Do not call timing completion or a trace an accuracy pass. Do not convert aggregate PMU counts into an instruction timeline; use the trace for timeline claims.
