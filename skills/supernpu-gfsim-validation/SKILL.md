---
name: supernpu-gfsim-validation
description: Freeze current main baselines, incrementally build affected artifacts, and validate SuperNPUBench solution ELFs with true multi-PE gfsim. Use for real-L2 timing, performance, deadlock, regression, or reproducibility checks; use a numerical-oracle workflow such as supernpu-gfrun-accuracy when the request is about precision.
---

# SuperNPUBench gfsim validation

Validate timing-model execution with an immutable source tuple and reproducible logs. Never report numerical accuracy from gfsim alone: a completed gfsim run proves model execution, not output correctness.

## Establish the validation tuple

At the start of every run:

1. Fetch SuperNPUBench `origin/main` and tags immediately before resolving the source. Test a clean worktree at the fetched `origin/main` commit.
2. Resolve the newest published SuperNPUBench tag, read that tag's README, and lock LLVM/compiler and TileOP to the exact revisions it specifies. Do not select those dependencies from their own main branches. Stop as `BASELINE_BLOCKED` if the pins are missing or ambiguous.
3. Fetch SuperScalarModel `origin/main` immediately before building and test a clean worktree at that fetched commit.
4. Record the full SuperNPUBench main commit, dependency-source tag, LLVM/compiler and TileOP commits, full model main commit, host/compiler versions, build flags, gfsim MD5, and every ELF SHA256.
5. Treat `SuperNPUBench commit + LLVM commit + TileOP commit + model commit + build flags + gfsim MD5 + ELF SHA256 + PE config + L2 mode` as the immutable tuple.
6. Check both remote main refs after a long build. If either moved, report both tips; do not call the older tuple current latest.

Do not overlay unmerged SuperNPUBench PRs unless the user explicitly requests one. Record its base, PR head, and integration commit separately.
Use a clean, separate worktree when a requested ref differs from an existing checkout. Preserve user working trees and prior patched environments.
Do not repeat repository updates and dependency checks for every operator; freeze the tuple once for the complete batch.

When validating a model PR, state whether the tested commit is the exact PR head, an integration commit, or a newer main that contains the PR. Use `git merge-base --is-ancestor` instead of assuming ancestry from a commit message.

## Reuse only valid artifacts

- A SuperScalarModel-only change invalidates gfsim but normally does not invalidate an already matching SuperNPUBench ELF.
- A SuperNPUBench, TileOP header, compiler, target sysroot, shape, dtype, PE-count, or build-flag change invalidates affected ELFs.
- Reuse an ELF only when its recorded SHA256 and complete build inputs match the requested tuple. File existence or timestamp is not sufficient.
- Record each artifact as `REUSED`, `REBUILT`, `NEW`, or `BLOCKED`, together with the invalidating input.

## Build preflight on WSL

Before compiling, inspect `free -h`, swap, `nproc`, and active `ninja`, `make`, `cc1plus`, or gfsim processes. Do not overlap a full model build with simulations.

## Standard solution batch profile

Rescan the frozen SuperNPUBench main worktree on every batch. Enumerate `test/solution/**/compile.all` and relevant Makefile-only cases. Determine PE count from kernel behavior and launch contract: an `_mt`/`_4pe` suffix helps, but `get_thread_idx()` or equivalent partitioning plus explicit four-PE launch is the deciding evidence.

Default selection:

- exclude single-PE cases;
- run real L2 only;
- keep only MatmulTest 4PE `M=256,N=256,K=256`, tile `128x64x64`;
- prefer DynamicMxQuant `tail_ocp_fp8_dyn` over equivalent static `tail_ocp_fp8`, retain other distinct 4PE variants, and exclude single-PE BigBS;
- keep QuantSparseFlashMLA `swa_tadd_4pe`, `csa_tadd_4pe`, and `ori_cmp_sparse_tadd_4pe`; do not claim omitted modes were tested;
- keep distinct 4PE GatherV2, ViewCopy, GroupToken, MoE, and dynamic normalization cases unless the user narrows them.

If main changes names, shapes, semantics, or PE behavior, regenerate and present the inventory rather than forcing an old list.

Compile shared dependencies once. Reuse an ELF only when a fingerprint covering source/dependency commits, source/header hashes, shape, dtype, tile, PE count, build flags, and compiler identity matches. Finish builds before simulation.

On an approximately 8 GiB WSL host, use at most two gfsim workers after checking free memory and stale processes; fall back to one under pressure. Apply a 900-second timeout to each case, continue the queue after a per-case failure, and disable SwimLane/PipeView for the ordinary batch.

Print start, completion, and aggregate progress, for example:

```text
[RUN 03/24][worker=2] rms_norm_binary real-L2
[DONE 03/24][TIMEOUT][900.0s] rms_norm_binary
[SUMMARY] completed=3 running=1 queued=20 pass=2 timeout=1 fail=0

On an approximately 8–10 GiB WSL host:
```

## Build the model safely on WSL

- use `python3 build.py all -j2` when available memory is below 6 GiB or other heavy processes are active;
- `-j3` may be used when at least 6 GiB is available and measured compiler RSS supports it;
- never default to `-j8`;
- after an OOM, retry with `-j1` rather than repeatedly restarting the same parallel build.

Capture the full command with `/usr/bin/time -v`, build log, wall time, and peak RSS. A configure or compile error is `BUILD_FAIL`, not a gfsim failure.

If current main requires `libelf-dev`, request authorization before installing it. When sudo is unavailable, a locally downloaded and extracted package may be supplied through `CMAKE_INCLUDE_PATH` and `CMAKE_LIBRARY_PATH`; do not patch repository source or fabricate system-wide headers merely to pass configure.

## Prove the intended PE mode

For gfsim, true 4PE execution uses:

```bash
cd <SuperScalarModel-root>
./bin/gfsim -f <ELF> --conf fourpe --pto-v02 true ...
```

Run from the SuperScalarModel root because `--conf fourpe` resolves repository-relative configuration files.

Do not use either of these as proof of 4PE:

- gfsim default/auto-detect for a clean ELF;
- `-s softcore.multiThreadNum=4`, which is a gfrun setting and does not establish gfsim fourpe timing mode.

A 4PE result is valid only when the log confirms all of:

```text
[gfsim] explicit PE config present; skipping ELF auto-detection
core.threadCount=4
fourpe.pe_cluster_enable=true
fourpe.pe_cluster_count=4
fourpe.pe_cluster_frontend_thread_count=4
```

For performance claims, also confirm PE0–PE3 have activity in the relevant engine PMU. Directory names such as `single_thread`, `multi_thread`, or `solution` do not determine PE count.

## Make L2 mode explicit

Use the same gfsim binary and ELF for both runs, changing only `tlsu.fake_l2_enable`:

```bash
# real L2
./bin/gfsim -f <ELF> --conf fourpe --pto-v02 true \
  -s tlsu.fake_l2_enable=false

# fake L2
./bin/gfsim -f <ELF> --conf fourpe --pto-v02 true \
  -s tlsu.fake_l2_enable=true
```

Never infer real L2 merely from an omitted flag. Explicit values make logs self-describing and protect against future default changes. Confirm the effective override near the beginning of each log.

Use [scripts/run_gfsim_matrix.sh](scripts/run_gfsim_matrix.sh) for repeatable single-case real/fake runs. It preserves commands, logs, exit codes, total cycles, and a TSV summary while continuing to the second L2 mode if the first fails.

## Run a bounded, single-variable matrix

- Run cases serially on memory-constrained WSL. A gfsim process may use around 1 GiB RSS, and large SwimLane traces add substantial memory and disk pressure.
- Use a timeout based on known runtime. `600s` is a safe initial bound for large normalization cases; do not reuse a short gfrun timeout blindly.
- Start without SwimLane or PipeView. Enable them only after the ordinary run identifies a failure or performance question.
- For a deadlock or suspected nondeterminism, rerun the exact failing tuple three times. Record whether the cycle, thread, block, and first causal instruction are identical.
- Preserve the first causal assertion or stalled instruction. Repeated scoreboard warnings that also occur in passing runs are secondary evidence, not automatically the cause.

The basic matrix for each ELF is:

1. explicit 4PE + real L2;
2. explicit 4PE + fake L2.

Add single-PE or another PE count only when requested or when needed to isolate a multi-PE defect. Label such runs separately; they do not replace the 4PE matrix.

## Classify results

A gfsim run is `PASS` only when all are true:

- process exit code is zero;
- the explicit intended PE configuration is present;
- `SuperScalar Report Stop` is present;
- no deadlock, fatal signal, assertion, or timeout occurred;
- `Total Cycles` is present.

Use these other statuses:

- `DEADLOCK`: model's deadlock detector fires;
- `TIMEOUT`: external timeout expires without a model deadlock report;
- `MODEL_FAIL`: assertion, signal, illegal instruction, unsupported operation, or other nonzero model exit;
- `CONFIG_FAIL`: requested PE/L2 configuration was not effective;
- `BUILD_FAIL`: model or ELF did not build;
- `TEST_INFRA_FAIL`: missing inputs, permissions, disk space, or runner infrastructure prevented the run.

Do not call a gfsim `PASS` an accuracy pass. If accuracy is requested, run the matching gfrun oracle workflow and report the two results independently.

## Diagnose real/fake differences

Interpret the pair before assigning ownership:

- real fails and fake passes: real-L2 latency/backpressure is a trigger; inspect TLSU/L2 interaction and downstream engine completion, but do not assume L2 is the root cause. A waiting TSTORE may be a symptom of an upstream Vector/CUBE Tile never becoming ready.
- real passes and fake fails: inspect fake-L2 bypass semantics and mode-specific configuration.
- both fail at the same first instruction: focus on the shared engine, decode, allocation, or kernel contract.
- both pass with different cycles: expected; report the ratio but do not treat fake-L2 cycles as hardware truth.

For deeper timing analysis, read [references/performance-analysis.md](references/performance-analysis.md). For a reproducible GitHub report, read [references/reproducible-issues.md](references/reproducible-issues.md).

## Report

Start with the immutable tuple and whether the remote ref was still current at completion. For each case and L2 mode report:

- operator, shape, dtype, ELF SHA256, and PE configuration;
- effective real/fake L2 value;
- exit code, status, `Total Cycles`, wall time, and peak RSS;
- first causal error for failures;
- exact log path.

Compare against an older result only when the older tuple is explicitly stated. End with totals by status and clearly separate timing-model execution from numerical accuracy.

Keep raw logs and generated traces outside tracked source directories, normally under `.validation/<tuple-name>/`. Do not create or update GitHub issues, close issues, push branches, or upload artifacts unless the user explicitly requests that external action.
