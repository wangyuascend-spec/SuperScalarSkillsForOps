---
name: supernpu-gfrun-accuracy
description: Update SuperNPUBench from the latest or requested tag/branch, smoke-test one case per one-level category, and validate gfrun numerical accuracy for selected kernels and PRs combined with that baseline. Use for version refreshes or precision checks involving Matmul, QuantMatmul, RmsNorm, GatherV2, ViewCopy, GroupNormGrad, DynamicMxQuant, QSMLA, QLI, MegaMoe, DispatchCombine, or Conv2dV2.
---

# SuperNPUBench gfrun accuracy

Prepare and smoke-test the requested SuperNPUBench version, then optionally validate the selected operators without modifying the user's working tree.

This workflow has a required version boundary and a conditional approval boundary:

1. Resolve the latest remote release tag or the user's requested SuperNPUBench tag/branch, then update the README-pinned dependencies and binaries. Read [references/baseline-update.md](references/baseline-update.md).
2. Select and run one representative gfrun case from every discovered one-level category.
3. Report the updated commits, build results, and category smoke results. Then ask whether to continue with the selected PR and kernel accuracy validation.
4. Stop until the user confirms. After confirmation, read [references/operators.md](references/operators.md) and run the detailed accuracy workflow below.

If the user explicitly requests only one phase, perform that phase and preserve the same version and accuracy rules. A targeted single-operator request may skip category smoke, but must never skip remote version preflight. Updating the baseline does not itself authorize testing open PR code. A request explicitly naming both baseline update and PR/kernel validation authorizes both phases; do not ask again between them.

## Establish the tested source

- Run version preflight at the start of every invocation, including a single-operator run or failure rerun. Fetch remote tags and branches; never infer "latest" from a local checkout or cached tags.
- Record the SuperNPUBench baseline ref/full commit, compiler/TileOP, and SuperScalarModel branch plus full commit before building.
- Fetch the current base branch and `refs/pull/<N>/head` for open PR implementations. Never check out a PR over a dirty working tree; use a separate git worktree under a temporary directory.
- By default, "validate the current PR" means the selected/latest release baseline plus the current PR head, not the PR head in isolation. Run `git merge-base --is-ancestor <baseline-sha> <pr-head-sha>` before building. If true, test the PR head and record that it contains the baseline. If false, create a disposable integration worktree from the PR head, merge the selected baseline locally, and test the resulting integration commit. Never push or rewrite the PR branch unless explicitly asked.
- If that merge conflicts, preserve the conflict list and stop as `SOURCE_INTEGRATION_BLOCKED` unless conflict resolution was explicitly requested. Never fall back to silently testing the stale PR head.
- Test the exact PR head without the selected baseline only when explicitly requested as a diagnostic. Label it `PR_HEAD_ONLY`; it does not establish compatibility with the current release.
- For implementations already present in the selected base, test the selected base commit. If the user asks to include local uncommitted changes, copy or patch only the relevant files into a disposable worktree and identify them in the report.
- Group operators from the same PR in one worktree, but report each operator separately.
- Define one immutable source tuple per run: `baseline ref/SHA + PR number/head SHA (if any) + integration SHA + dependency/model commits`. Every build, ELF, log, result row, and issue must use that tuple. Never combine evidence from older runs or different tuples.

## Discover the authoritative cases

For each operator, inspect its test directory's `Makefile`, `compile.all`, README, generators, and comparison scripts. Treat those files as authoritative; do not invent shapes or replace an operator-specific precision workflow with a generic smoke case.

Classify every declared case as one of:

- `accuracy`: generates or embeds a reference and compares the device result.
- `execution-only`: reaches the benchmark end but has no numerical comparison.
- `unsupported`: cannot be built or run with the pinned toolchain/model.

Include all authoritative accuracy cases unless the user explicitly requests a smoke subset. If no precision case exists, report `NO_ACCURACY_ORACLE`; never call it PASS merely because gfrun exits successfully.

For normalization validation, do not treat the directory as one sampled category. Inventory and report every present canonical case separately: `rms_norm`, `rms_norm_binary`, `group_norm_grad`, and `group_norm_grad_1d`. For each canonical case, validate only variants that are both dynamic-shape and 4PE; exclude static-shape and single-PE variants from this skill's normalization result. Derive the qualifying variants from `compile.all`, the generator, Makefile, and test source rather than from names alone. If a canonical case has no dynamic 4PE variant, report `MISSING_DYNAMIC_4PE_CASE`; never substitute a static or single-PE result. In particular, `rms_norm_binary` has its own generator and external precision checker, so a passing `rms_norm` result does not cover it.

## Build without exhausting WSL memory

- Before a build, check `free -h` and ensure no other `ninja`, `make`, `cc1plus`, or compiler build is active.
- This environment has about 10 GiB RAM and 2 GiB swap. Use at most two compile jobs; use one job for LLVM/Clang Sema or when one compiler process approaches 3 GiB.
- Keep the LLVM Ninja compile pool capped at 2 and link pool at 1. Do not start overlapping builds.
- Build test binaries with the repository's precision switch, normally `res_check=on`. Preserve any operator-specific generator or comparison target.
- Capture the full build command and log. A compile failure is `BUILD_FAIL`, not a gfrun failure.
- Reuse an ELF only when a machine-readable manifest proves its complete input fingerprint matches the current source tuple and build inputs. A missing, incomplete, or mismatched manifest requires rebuilding; existence and timestamps are not proof.

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

For every qualifying normalization case, run with `-s softcore.multiThreadNum=4` and verify the test invokes the kernel once while the kernel partitions work internally with `get_thread_idx()` or its current equivalent. For non-normalization operators, add the setting only when the authoritative case is genuinely multi-PE; never call a kernel once per PE merely to represent four PEs.

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

- operator and source (`base@commit`, `PR #N@commit`, or `integration@commit`);
- case/shape/dtype and PE configuration;
- build result;
- oracle and tolerance;
- gfrun result;
- accuracy status and error metric;
- elapsed time;
- concise failure cause and log path.

End with totals by status and explicitly list operators that have no real accuracy oracle. Keep raw logs outside tracked source directories unless the user requests otherwise.

At the start of the report, print the immutable source tuple, ancestry result, and artifact-manifest path. A report or issue based on stale or mixed logs is invalid and must be regenerated from the current run.
