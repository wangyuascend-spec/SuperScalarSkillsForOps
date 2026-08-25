---
name: supernpu-gfrun-accuracy
description: Update a SuperNPUBench validation environment from a requested tag or branch, smoke-test one case per one-level category, and optionally validate numerical accuracy with gfrun for selected kernels and open PRs. Use for version refreshes or precision checks involving Matmul, QuantMatmul, RmsNorm, GatherV2, ViewCopy, GroupNormGrad, DynamicMxQuant, QSMLA, QLI, MegaMoe, DispatchCombine, or Conv2dV2.
---

# SuperNPUBench gfrun accuracy

Prepare and smoke-test the requested SuperNPUBench version, then optionally validate the selected operators without modifying the user's working tree.

This workflow has a required approval boundary:

1. Update the baseline from a user-specified SuperNPUBench tag or branch and rebuild the README-pinned dependencies and binaries. Read [references/baseline-update.md](references/baseline-update.md).
2. Select and run one representative gfrun case from every discovered one-level category.
3. Report the updated commits, build results, and category smoke results. Then ask whether to continue with the selected PR and kernel accuracy validation.
4. Stop until the user confirms. After confirmation, read [references/operators.md](references/operators.md) and run the detailed accuracy workflow below.

If the user explicitly requests only one phase, perform that phase and preserve the same version and accuracy rules. Updating the baseline does not itself authorize testing open PR code.

## Establish the tested source

- Record SuperNPUBench, compiler/TileOP, and SuperScalarModel branch plus full commit before building.
- Fetch the current base branch and `refs/pull/<N>/head` for open PR implementations. Never check out a PR over a dirty working tree; use a separate git worktree under a temporary directory.
- Test an open PR at its exact head commit by default. Report its base commit and whether it is behind the current base. Do not silently merge or rebase it. If compatibility with the latest base is requested, create a second disposable worktree and report that result separately.
- For implementations already present in the selected base, test the selected base commit. If the user asks to include local uncommitted changes, copy or patch only the relevant files into a disposable worktree and identify them in the report.
- Group operators from the same PR in one worktree, but report each operator separately.

## Discover the authoritative cases

For each operator, inspect its test directory's `Makefile`, `compile.all`, README, generators, and comparison scripts. Treat those files as authoritative; do not invent shapes or replace an operator-specific precision workflow with a generic smoke case.

Classify every declared case as one of:

- `accuracy`: generates or embeds a reference and compares the device result.
- `execution-only`: reaches the benchmark end but has no numerical comparison.
- `unsupported`: cannot be built or run with the pinned toolchain/model.

Include all authoritative accuracy cases unless the user explicitly requests a smoke subset. If no precision case exists, report `NO_ACCURACY_ORACLE`; never call it PASS merely because gfrun exits successfully.

## Build without exhausting WSL memory

- Before a build, check `free -h` and ensure no other `ninja`, `make`, `cc1plus`, or compiler build is active.
- This environment has about 10 GiB RAM and 2 GiB swap. Use at most two compile jobs; use one job for LLVM/Clang Sema or when one compiler process approaches 3 GiB.
- Keep the LLVM Ninja compile pool capped at 2 and link pool at 1. Do not start overlapping builds.
- Build test binaries with the repository's precision switch, normally `res_check=on`. Preserve any operator-specific generator or comparison target.
- Capture the full build command and log. A compile failure is `BUILD_FAIL`, not a gfrun failure.

## Prove that precision is checked

Before accepting a result, trace the test's oracle path:

1. Identify how inputs and golden outputs are produced.
2. Identify where the kernel result is read and compared.
3. Identify tolerance or exact-match rules, including dtype-specific thresholds.
4. Confirm comparison failure propagates to the benchmark status register (`R2 != 0`) or to a documented post-run checker.

Run gfrun with a bounded timeout. The ordinary invocation is:

```bash
timeout 90 <SuperScalarModel>/bin/gfrun -t 1 -f <case.elf>
```

Add `-s softcore.multiThreadNum=4` only when the test or kernel is genuinely multi-PE/multi-thread; do not call a kernel once per PE merely to represent four PEs.

A gfrun-integrated accuracy case is `PASS` only when all are true:

- process exit code is zero;
- output contains `Reach the End of Benchmark`;
- output contains `R2 = 0`;
- the inspected binary/test path actually enabled and executed its numerical oracle.

For an external comparison script, require successful gfrun plus successful checker output and preserve its reported error metrics. Record timeout, signal, assertion, illegal instruction, missing end marker, and nonzero R2 distinctly.

## Diagnose failures

Rerun only the failing case with its exact command and retain the first causal error. Separate failures into `BUILD_FAIL`, `MODEL_FAIL`, `ACCURACY_FAIL`, `TIMEOUT`, and `TEST_INFRA_FAIL`. For accuracy failures, report actual tolerance and available maximum absolute/relative error; for model failures, identify the first unsupported instruction or assertion. Do not change tolerances or golden data to make a case pass.

## Report

Give one row per operator and case with:

- operator and source (`base@commit` or `PR #N@commit`);
- case/shape/dtype and PE configuration;
- build result;
- oracle and tolerance;
- gfrun result;
- accuracy status and error metric;
- elapsed time;
- concise failure cause and log path.

End with totals by status and explicitly list operators that have no real accuracy oracle. Keep raw logs outside tracked source directories unless the user requests otherwise.
