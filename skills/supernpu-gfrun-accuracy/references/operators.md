# Selected operator inventory

Check GitHub PR state and changed files at execution time; the states below were observed on 2026-08-25 and are not permanent.

| Operator | Source | Expected test area |
|---|---|---|
| Matmul | PR #82, `https://github.com/PTO-ISA/SuperNPUBench/pull/82` | `benchmark/one-level-arch/test/kernel/matmul` |
| QuantMatmul | PR #73, `https://github.com/PTO-ISA/SuperNPUBench/pull/73` | `benchmark/one-level-arch/test/kernel/matmul` |
| RmsNorm | PR #84, https://github.com/PTO-ISA/SuperNPUBench/pull/84 | Both `benchmark/one-level-arch/test/kernel/normalization/rms_norm` and `rms_norm_binary`; preserve their existing paths and validate only dynamic-shape 4PE variants from each `compile.all` |
| GatherV2 | PR #79, `https://github.com/PTO-ISA/SuperNPUBench/pull/79` | `benchmark/one-level-arch/test/kernel/gather_v2` |
| ViewCopy | PR #79, `https://github.com/PTO-ISA/SuperNPUBench/pull/79` | `benchmark/one-level-arch/test/kernel/view_copy` |
| GroupNormGrad | PR #84, https://github.com/PTO-ISA/SuperNPUBench/pull/84 | `benchmark/one-level-arch/test/kernel/normalization/group_norm_grad` and `group_norm_grad_1d`; validate only dynamic-shape 4PE variants |
| DynamicMxQuant | PR #83, `https://github.com/PTO-ISA/SuperNPUBench/pull/83` | `benchmark/one-level-arch/test/kernel/quant/dynamic_mx_quant` |
| QSMLA | PR #39, `https://github.com/PTO-ISA/SuperNPUBench/pull/39` | `benchmark/one-level-arch/test/kernel/fa` |
| QLI | PR #78, `https://github.com/PTO-ISA/SuperNPUBench/pull/78` | `benchmark/one-level-arch/test/kernel/qli` |
| MegaMoe | PR #74, `https://github.com/PTO-ISA/SuperNPUBench/pull/74` | `benchmark/one-level-arch/test/kernel/mega_moe` |
| DispatchCombine | PR #74, `https://github.com/PTO-ISA/SuperNPUBench/pull/74` | `benchmark/one-level-arch/test/kernel/moe_dispatch` and `moe_combine` |
| Conv2dV2 | PR #75, `https://github.com/PTO-ISA/SuperNPUBench/pull/75` | `benchmark/one-level-arch/test/kernel/conv2d` and `conv2d_rm` |

## Plan shared work once

Resolve all live PR heads first, then group requested operators by identical source tuple. Use one integration worktree, dependency decision, compiler/model identity check, and manifest namespace per tuple.

- Operators from the same PR share one integration worktree. In particular, validate RmsNorm and GroupNormGrad together for PR #84; GatherV2 and ViewCopy together for PR #79; MegaMoe and DispatchCombine together for PR #74.
- Run dependency invalidation once per tuple. Do not repeat toolchain or model checks for every operator in the group.
- Cache data and ELFs per case fingerprint, not per invocation. Rebuild only cases affected by source, generator, shape, dtype, compiler, TileOP, linker, or embedded-path changes.
- A model-only change reruns matching ELFs without recompiling them. A PR-only change does not rebuild the toolchain.
- Run the smallest representative case first as an environment gate. If it fails due to a shared compiler/model/test-infrastructure cause, classify the remaining cases as blocked by that cause instead of repeating identical expensive failures.
- Retry only failed or invalidated cases. Do not rerun already proven PASS cases from the same immutable tuple unless the user requests repetition.

Directory placement does not define PE count. Determine 4PE from the test startup, compile definitions, gfrun configuration, and kernel-owned partitioning such as `get_thread_idx()`. During baseline integration, preserve an operator's existing paths unless an actual interface or build dependency requires a move; a new `single_thread/` or `multi_thread/` convention alone is not a reason to relocate PR code.

PR fetch and integration pattern:

```bash
git fetch origin refs/pull/<N>/head:refs/codex/pr-<N>
git merge-base --is-ancestor <baseline-sha> refs/codex/pr-<N>
# When the ancestry check fails:
git worktree add --detach <temporary-path> refs/codex/pr-<N>
git -C <temporary-path> merge --no-ff <baseline-sha>
```

Before using this inventory, query the PR state and head SHA with `gh pr view`. For an open PR, follow the baseline-composition rules in the main skill; direct exact-head testing is diagnostic-only unless the PR already contains the selected baseline. If a PR has merged, prefer the selected base implementation and retain the PR number only as provenance. If it is closed without merge, report that fact and ask whether its last head should still be tested when the user's intent is ambiguous.

`DispatchCombine` is a reporting group, not necessarily one binary: validate dispatch and combine cases separately, then provide a grouped summary.
