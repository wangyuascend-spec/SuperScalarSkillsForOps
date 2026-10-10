---
name: supernpu-pipeline-visualization
description: Generate a Perfetto SwimLane JSON plus a PE-union preview (preview.html, overview.png, row_zoom.png) from an existing SuperNPUBench ELF. gfsim runs from the SuperScalarModel root with explicit fourpe, real L2, and random SoC seed 2. Use when the user asks for a pipeline diagram, swimlane, pipeview, 流水图, 泳道, 流水线视图, gfsim trace, perfetto trace, or an execution timeline. Do not use for numerical accuracy.
---

# SuperNPU pipeline visualization

Generate the timeline from an existing ELF. Do not compile the kernel and do not treat the trace as an accuracy result.

## Generate the JSON

```bash
python3 <this-skill>/scripts/generate_swimlane_safe.py \
  --model <SuperScalarModel-root> \
  --elf <absolute-ELF> \
  --output-dir <new-directory>
```

The destination must not already exist. gfsim runs with its working directory at the model root. The script writes `pipeline.json` straight into the output directory, caps the child address space at the smaller of `--memory-gib` (default 6) and 60% of `MemAvailable`, and refuses to start below 2 GiB. It records the command, hashes, exit status, `Total Cycles`, and `scb_waw_tile` in `manifest.json`. On `PASS` it also renders the preview.

The JSON dump keeps the whole trace in memory. A 4PE run around 60k cycles aborts under a 3 GiB cap after `SuperScalar Report Stop` (`DUMP_FAIL`, signal 6, no `pipeline.json`) and completes with the default 6 GiB cap (observed peak about 3.9 GiB, JSON about 110 MB). The cap still stops at 60% of `MemAvailable`. Do not raise it again after a `DUMP_FAIL` at that ceiling; record the log and say the trace is incomplete.

PE mode comes from the ELF name. A `*_PE4.elf` uses `--conf fourpe --pto-v02 true`. Anything else stays single-PE unless `--pe 4` is passed. `--pe 1` forces single-PE. A timing ELF often does not end in `_PE4.elf`; pass `--pe 4` when the launch contract is four-PE.

Default SoC is real L2 and random latency seed 2:

- `-s tlsu.fake_l2_enable=false`
- `-s core.soc_random=true -s core.soc_lat_random_seed=2`
- bandwidth, latency, and credit stay at `configs/core.toml`

Pass `--fake-l2 true` only when the user asks, or after a real-L2 run fails and the log is kept. Label that JSON as a diagnostic trace.

`--counter-interval` defaults to 8, the value already in `configs/fourpe.conf`. Sampled counters change with the interval; block slices and dependency events stay complete. A different interval is written into a copied profile because a second `-s` of the same key is not a reliable override. On a single-PE run the interval is passed with `-s`, since `DFX.toml` samples every cycle.

Optional flags:

- `--pipeview block` adds Konata block PipeView (`-p 2`). `--pipeview full` is per-instruction (`-p 1`) and can be very large.
- `--pipe-filter-group` keeps group-level PipeView rows.
- `--set key=value` forwards one extra `-s`. Repeat it only for a value the user named.
- `--timeout` defaults to 900 seconds. `timeout` exit 124 is `TIMEOUT`.

## Do not import these flags

Some external trace wrappers set them. They change the run or do not select the PE mode:

- `-s softcore.multiThreadNum=4` is a gfrun option. The script rejects it. 4PE is `--conf fourpe`.
- `core.soc_bw_limit` and `core.soc_lat_mean` (including 113 and 330) replace the `core.toml` random-SoC defaults. Add them only when the user gives those numbers, and name them in the report.
- A fixed Mac `SSM_DIR` or `GFSIM`. Use the checkout the user named, or the model root already used for the matching timing run.

## Show the preview

After `PASS`, the same output directory contains:

| File | What it shows |
|------|----------------|
| `preview.html` | Labeled view. Open this for the user. |
| `overview.png` | Full run, no labels. |
| `row_zoom.png` | A 3000-cycle window starting at one third of the trace. |
| `preview_summary.json` | Merged slice count and busy cycles per lane. |

Blue is Vector, green is TLOAD, orange is TSTORE. Each row is the union of that PE. Vector is `VECTOR_0..3` (pids 70000, 70036, 70072, 70108). TLOAD and TSTORE come from TLSU thread names `*_PE0N_LOAD_*` and `*_PE0N_STORE_*`. Other tracks stay in `pipeline.json`.

Re-render an existing JSON with:

```bash
python3 <this-skill>/scripts/render_swimlane_preview.py <pipeline.json> \
  --output-dir <directory> --title "<case>" --zoom-start <cycle>
```

Serve `preview.html` from its directory when a browser cannot open `file://`. Open `pipeline.json` locally at <https://ui.perfetto.dev> only when the user wants the full track list. Open `<elf>.pipeview.log.out` in Konata when PipeView was requested. Do not upload these files unless the user asks.

## Read the result

`PASS` requires exit code 0, `SuperScalar Report Stop`, a `Total Cycles` line, the requested PE lines (`explicit PE config present`, `core.threadCount=4`, `fourpe.pe_cluster_enable=true`, `fourpe.pe_cluster_count=4` for 4PE), and `core.soc_random=true` with seed 2. A timeout, assertion, deadlock, or empty JSON is not a timeline.

Report `scb_waw_tile` whenever it is nonzero. That count stays visible next to `PASS`.

Compare two JSON traces with [streaming comparison](scripts/compare_trace_streaming.py). Do not `json.load` both documents:

```bash
python3 <this-skill>/scripts/compare_trace_streaming.py <old.json> <new.json>
```

## Report

State the model commit, `gfsim` and ELF hashes, the command, PE mode, real or fake L2, seed 2, and any `--set` override. Then status, exit code, `Total Cycles`, `scb_waw_tile`, peak RSS, the absolute JSON path and size, and the `preview.html` path. Quote per-PE busy cycles from `preview_summary.json` when describing the picture. Timeline claims come from these slice intervals, not from aggregate PMU counts.
