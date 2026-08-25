# Selected operator inventory

Check GitHub PR state and changed files at execution time; the states below were observed on 2026-08-25 and are not permanent.

| Operator | Source | Expected test area |
|---|---|---|
| Matmul | PR #82, `https://github.com/PTO-ISA/SuperNPUBench/pull/82` | `benchmark/one-level-arch/test/kernel/matmul` |
| QuantMatmul | PR #73, `https://github.com/PTO-ISA/SuperNPUBench/pull/73` | `benchmark/one-level-arch/test/kernel/matmul` |
| RmsNorm | PR #84, https://github.com/PTO-ISA/SuperNPUBench/pull/84 | `benchmark/one-level-arch/test/kernel/normalization/rms_norm` and related RMSNorm directories |
| GatherV2 | PR #79, `https://github.com/PTO-ISA/SuperNPUBench/pull/79` | `benchmark/one-level-arch/test/kernel/gather_v2` |
| ViewCopy | PR #79, `https://github.com/PTO-ISA/SuperNPUBench/pull/79` | `benchmark/one-level-arch/test/kernel/view_copy` |
| GroupNormGrad | PR #84, https://github.com/PTO-ISA/SuperNPUBench/pull/84 | `benchmark/one-level-arch/test/kernel/normalization/group_norm_grad` and `group_norm_grad_1d` |
| DynamicMxQuant | PR #83, `https://github.com/PTO-ISA/SuperNPUBench/pull/83` | `benchmark/one-level-arch/test/kernel/quant/dynamic_mx_quant` |
| QSMLA | PR #39, `https://github.com/PTO-ISA/SuperNPUBench/pull/39` | `benchmark/one-level-arch/test/kernel/fa` |
| QLI | PR #78, `https://github.com/PTO-ISA/SuperNPUBench/pull/78` | `benchmark/one-level-arch/test/kernel/qli` |
| MegaMoe | PR #74, `https://github.com/PTO-ISA/SuperNPUBench/pull/74` | `benchmark/one-level-arch/test/kernel/mega_moe` |
| DispatchCombine | PR #74, `https://github.com/PTO-ISA/SuperNPUBench/pull/74` | `benchmark/one-level-arch/test/kernel/moe_dispatch` and `moe_combine` |
| Conv2dV2 | PR #75, `https://github.com/PTO-ISA/SuperNPUBench/pull/75` | `benchmark/one-level-arch/test/kernel/conv2d` and `conv2d_rm` |

PR fetch pattern:

```bash
git fetch origin refs/pull/<N>/head:refs/codex/pr-<N>
git worktree add <temporary-path> refs/codex/pr-<N>
```

Before using this inventory, query the PR state and head SHA with `gh pr view`. If a PR has merged, prefer the selected base implementation and retain the PR number only as provenance. If it is closed without merge, report that fact and ask whether its last head should still be tested when the user's intent is ambiguous.

`DispatchCombine` is a reporting group, not necessarily one binary: validate dispatch and combine cases separately, then provide a grouped summary.
