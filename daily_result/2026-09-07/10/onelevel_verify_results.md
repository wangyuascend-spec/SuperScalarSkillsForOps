# Skill 全量验证（最新 tag baseline 刷新 + build + gfrun + accuracy）

- Generated: 2026-09-07T10:59:04+08:00
- Skill: `wangyuascend-spec/SuperScalarSkillsForOps` / `supernpu-gfrun-accuracy`
- Baseline: SuperNPUBench 最新远程 release tag `ops-20260904` @ `a0ddcc36`（= 当日 origin/main HEAD，tag/分支清单经 `git ls-remote` 实时解析）
- gfrun: `timeout 90 gfrun -t 1 -f …`；大指令量 case（topk 1.03e8 instr）`-t 1` trace 致超时，复跑改无 `-t` 并记录
- normalization 全部 qualifying case 按 skill 规则仅取 dynamic-shape + 4PE 变体，`-s softcore.multiThreadNum=4`，kernel 内部 `get_thread_idx()` 分区、main 单次调用
- 本轮未跑 gfsim（范围：baseline tag 更新 + category smoke + PR/kernel gfrun accuracy）

## 仓库分支

| 仓 | 分支/tag | HEAD |
|---|---|---|
| SuperNPUBench | tag `ops-20260904` | `a0ddcc36 docs: update verification env to llvm 1ae4ee39 + fa re-test note` |
| SuperScalarModel | `codex/consolidate-post-main-fixes-20260903` | `49547742 test: update TLSU layout types` |
| Linx-TileOP-API | `linx`（detached） | `804eb035`（= README 09-04 pin `804eb03`） |
| llvm-project | `dev-llvm15_56`（detached） | `1ae4ee39e096399cea63793a5f40e0d42017e144` |
| linx-toolchain-build | `main` | `e6a31ef macOS: install GNU tar for the package step` |
| linx-musl | `linx` | `af0dfc20` |
| jemalloc | `linx` | `4495309c`（+1 untracked `configure~`，autotools 临时文件） |
| linux-linxisa | `main` | `1055a743` |

- 工具链/模型全部 **REUSED**：clang 15.0.4（`linx64v5-unknown-linux-musl`，built from `1ae4ee39`）与 README 09-04 基线 pin 一致；gfrun 增量重建 no-op（`build.py build --target gfrun`，二进制不变）作为身份证据
- 与 README 09-04 验证环境的两处不可复现偏差（已记录）：
  1. README 记录的 gfrun commit `bc7fae00` 已被分支 rebase 丢弃（不可达），使用 pinned 分支当前 HEAD `49547742`
  2. README 记录 09-04 工作树 TileOP `804eb03` 含**未提交** `template_asm.hpp`（cooperative matmul LB0，ADR-0100 group_M）；干净 `804eb03` 无此修改 → multi_thread matmul_shared 输出全 inf（见下）

## Phase 1 — baseline `ops-20260904` 一级 category smoke（16 类各 1 代表 case，`res_check=on`）

| category | case | compile | gfrun | accuracy | root cause |
|---|---|:---:|:---:|:---:|---|
| matmul | MASK_FP32 M256 N256 K256 tM32 tN32 tK32 | OK | OK | PASS | gfrun_matmul.py：mse=2.45e-15 max_abs=4.17e-07 |
| fa | fa_2d_unroll Sq256 Skv512 Tm16 Tk32 X1 Y2 | OK | OK | PASS | numpy attention golden：max_abs=7.15e-03（atol/rtol 2e-2；输入按 repo 惯例 uniform(-0.1,0.1)；±0.5 宽动态范围时 3.8e-02 超 2e-2，fp16 中间量精度边界） |
| flashMLA | Sq64 QHeadPerHK1 NumBlocks2 Dk512 Dv512 | OK | OK | PASS | out max_abs=5.38e-04；lse max_abs=2.02（值域 ~125，rel 1.6% < rtol 5e-2） |
| normalization | rms_norm __half dynamic（run_precision_check.py 一键） | OK | OK | PASS | max_abs=1.95e-03 mse=4.75e-10 |
| gather | fp32 gKs200000 gMs202 gNs97 tMs128 tNs128 | OK | OK | FAIL | 19594/19594 mismatch；实测语义 `res[0][j]=inp_flat[off[j]]`（offset 表逐元素取数），与 repo golden 行收集语义错位；kernel 源注释记录"当前编译器 MGATHER 按字节偏移取数，非行索引"；行号/字节两种 offset 均不匹配；09-04 基线该 case PASS（其工作树状态不可复现） |
| multi_thread | matmul_shared float B1 M256 N256 K256 tM128 tN256 tK128（4PE） | OK | OK | FAIL | res 65536/65536 inf（golden 值域正常）；高置信根因 = TileOP `804eb03` 缺 README 记录的未提交 cooperative LB0 修改；单线程 matmul（非 cooperative）同环境 PASS 可作对照 |
| sort | topk（embedded 131072 uint16 → top 2048） | OK | OK | FAIL | R2=1（match != kTopK）；09-04 已知不变；无 `-t` 193s 跑完（1.03e8 instr），`-t 1` trace 下 90s 看门狗超时 |
| broadcast | broadcast_vec_07 __half 1443x1→1443x129 | OK | MODEL_FAIL | SKIP | `PTO v0.58 COPY expansion requires one broadcast source`；09-04 已知不变 |
| control | hashtable_lookup_simd kNum6144 num_col256 debug_on | OK | MODEL_FAIL | SKIP | TCVT tile-carrier 契约断言；09-04 已知不变 |
| norm | rms_norm M16 N256 tM8 tN128（PE_NUM=4） | OK | MODEL_FAIL | SKIP | `binary TEPL source dtype/shape/stride is incompatible`（ValidateBasicBinaryTepl，AccumulateBlockInfo.cpp:744）；09-04 基线未覆盖该目录 |
| concat | concat_gather int32 64x2→64x2000 | OK | OK | EXECUTION_ONLY | 测试 I/O 全被注释 → NO_ACCURACY_ORACLE |
| deepseek | fused_weight | OK | OK | EXECUTION_ONLY | 源码无 RES_CHECK → NO_ACCURACY_ORACLE |
| element_wise | gelu __bf16 24x8x1024 | OK | OK | EXECUTION_ONLY | RES_CHECK 块被注释 → NO_ACCURACY_ORACLE |
| reduction | reducemax_col int32 2048x64 | OK | OK | EXECUTION_ONLY | 源码无 RES_CHECK → NO_ACCURACY_ORACLE |
| transpose | __half 1476x32→32x1476 | OK | OK | EXECUTION_ONLY | 源码无 RES_CHECK → NO_ACCURACY_ORACLE |
| conv2d | - | - | - | UNSUPPORTED | 单线程 conv2d 未接入 compile_all.sh、无 compile.all；目录为已知 ColMajor TLOAD/TSTORE 布局丢失 bug 复现文档 |

### Phase 1 计数

- 16 一级 category：PASS 4 / ACCURACY_FAIL 3 / MODEL_FAIL 3 / EXECUTION_ONLY 5 / UNSUPPORTED 1

## Phase 2 — PR + kernel accuracy（baseline `ops-20260904` 组合）

PR head 于 2026-09-07 经 `git ls-remote refs/pull/*/head` 实时解析。**仅 PR #84 包含 baseline**（直接测 head）；其余 8 个本地 merge 集成，4 个冲突 → `SOURCE_INTEGRATION_BLOCKED`（保留冲突清单，未授权不解决、不静默测 stale head）。

| operator | source | case | compile | gfrun | accuracy | root cause |
|---|---|---|:---:|:---:|:---:|---|
| RmsNorm | PR#84@88bace01 | rms_norm __half gA512 gR8192 PE4 dynamic | OK | OK | PASS | max_abs=1.95e-03 mse=1.02e-09（run_precision_check.py，atol/rtol 2e-2） |
| RmsNorm | PR#84@88bace01 | rms_norm_binary __half gA16 gR16384 PE4 dynamic | OK | OK | PASS | max_abs=1.95e-03 mse=6.14e-10 |
| GroupNormGrad | PR#84@88bace01 | group_norm_grad N32 C16 G8 HxW8192 PE4 dynamic | OK | OK | FAIL | dgamma mse=7.81e-03 > mse_tol 1e-3（max_abs=0.25、max_rel=8.9e-04、within_atol_or_rtol=true——大数值 fp16 累加的绝对 mse 判据触发；dx PASS 1.95e-03 / dbeta PASS 0） |
| GroupNormGrad | PR#84@88bace01 | group_norm_grad_1d N512 C64 G8 PE4 dynamic | OK | OK | PASS | dx=9.77e-04 dgamma=0 dbeta=0 |
| GatherV2 | PR#79@12c16c1c | rank1_float IN19 OUT37 TILE32（embedded ABS/REL_TOL 1e-3） | OK | OK | FAIL | R2=1，5 mismatches（guest printf 格式化缺陷致指标不可提取） |
| GatherV2 | PR#79@12c16c1c | rank2_int32 IN5_11 OUT5_7 TILE32 | OK | OK | FAIL | R2=1，3 mismatches |
| GatherV2 | PR#79@12c16c1c | rank2_half IN11_17 OUT8_17 TILE64 | OK | OK | FAIL | R2=1，8 mismatches |
| ViewCopy | PR#79@12c16c1c | int32_2x4x8 / half_4x4x8 / half_tail | FAIL | SKIP | SKIP | `fatal error: 'view_copy/view_copy_pto.hpp' file not found`——PR 提供 `kernels/view_copy/view_copy.hpp`，include 文件名不匹配（PR head 自身缺陷，非 merge 造成） |
| QuantMatmul | PR#73@3b76bb37 | MULTI_BLOCK M8192 N4096 K1600 tM/tN/tK=32 NBLOCKS=32（权威 shape=源码默认，PR 无 compile.all 条目） | FAIL | SKIP | SKIP | template_asm.hpp `IsCubeLayout` 静态断言：CUBE D/A 需 CUBE_M16/M32 CELL layout、B 需 CUBE_N8（与 README 09-04 记录的 matmul CUBE layout 编译回归同类） |
| DynamicMxQuant | PR#83@184fc11f | TAIL_CUBLAS_FP8 M8 K32 | OK | MODEL_FAIL | SKIP | `TCMPS requires one compatible Tile source`（ValidateCompareSelectTepl，AccumulateBlockInfo.cpp:566） |
| DynamicMxQuant | PR#83@184fc11f | TAIL_OCP_FP4 M8 K64 | OK | MODEL_FAIL | SKIP | 同上 TCMPS 断言 |
| DynamicMxQuant | PR#83@184fc11f | NONTAIL_CUBLAS_FP8 M32 K32 | OK | MODEL_FAIL | SKIP | 同上 TCMPS 断言 |
| DynamicMxQuant | PR#83@184fc11f | PROBE_OCP_FP8_NEWCALC M8 K32（fp16-in） | OK | MODEL_FAIL | SKIP | `PTO row expansion requires a one-column broadcast source`（ValidateReduceAndExpandTepl，AccumulateBlockInfo.cpp:1012） |
| MegaMoe | PR#74@d27da072 | mega_moe_sim BS16 H32 HD64（单线程，内嵌全 MoE golden） | OK | OK | PASS | R2=0（golden Y + token counts 一致）；无 `-t` 31s（`-t 1` trace 致超时） |
| MegaMoe | PR#74@d27da072 | mega_moe_sim_mt BS16 H32 HD64 4PE | OK* | OK | PASS | R2=0（PE0 独占校验）；*compile.all 原样构建缺 `__linx_group_worker_start` → 4PE 挂起（无 PE1..PE3 启动行），需 `res_check=on` hosted 重建——PR 编排缺陷 |
| MoeDispatch | PR#74@d27da072 | moe_dispatch_v2（单线程） | OK | OK | EXECUTION_ONLY | 源码无 oracle → NO_ACCURACY_ORACLE |
| MoeDispatch | PR#74@d27da072 | moe_dispatch_mt 4PE（res_check=on hosted 重建） | OK | OK | EXECUTION_ONLY | 同上；4PE hosted-link 要求同 mega_moe_sim_mt |
| MoeCombine | PR#74@d27da072 | moe_combine_v2（单线程） | OK | OK | EXECUTION_ONLY | 源码无 oracle → NO_ACCURACY_ORACLE |
| MoeCombine | PR#74@d27da072 | moe_combine_mt 4PE（res_check=on hosted 重建） | OK | OK | EXECUTION_ONLY | 同上 |
| Matmul | PR#82@dec7e3e | - | BLOCKED | - | - | merge 冲突：`kernels/single_thread/matmul/matmul_test.hpp`（behind baseline 40 commits） |
| QSMLA | PR#39@0214897 | - | BLOCKED | - | - | merge 冲突：6 个 fa kernel 头（qsmla_config/mode/quant_sparse_flash_mla*；behind 27） |
| QLI | PR#78@3ee5a75 | - | BLOCKED | - | - | merge 冲突：`kernels/README.md` + `microbenchmark/vector/src/thistogram_{i16,i32}_16x16.cpp`（behind 40） |
| Conv2dV2 | PR#75@5c49b7e | - | BLOCKED | - | - | merge 冲突：`test/kernel/conv2d/Makefile`（behind 40） |

### Phase 2 计数

- accuracy case（ran）：PASS 5 / FAIL 4（group_norm_grad dgamma-mse 1 + gather_v2 3）
- compile：BUILD_FAIL 4（view_copy ×3、matmul_multi_block ×1）/ OK 15
- gfrun（ran）：OK 15 / MODEL_FAIL 4（DynamicMxQuant 全族）
- EXECUTION_ONLY 4（moe dispatch/combine 单+mt，均无 oracle）
- SOURCE_INTEGRATION_BLOCKED 4 PR（Matmul、QSMLA、QLI、Conv2dV2）
- 无真实 accuracy oracle 的算子：DispatchCombine（全 4 case）+ Phase 1 的 concat/deepseek/gelu/reduction/transpose

## 与 2026-08-26 daily 结果对比（同 PR 清单）

| operator | 08-26 | 09-07（本轮） | 变化 |
|---|---|---|---|
| GatherV2 | compile FAIL（missing pto::Coalesce） | compile OK / accuracy FAIL ×3（R2=1 部分元素错） | 编译修复后暴露数值层失败 |
| ViewCopy | compile FAIL（-DDType clashes） | BUILD_FAIL（include 文件名不匹配） | 编译失败原因变化 |
| Matmul PR#82 | OK / gfrun OK / accuracy FAIL（self_verify R2=1） | SOURCE_INTEGRATION_BLOCKED（matmul_test.hpp 冲突） | 本轮 baseline 前进 40 commits 产生冲突 |
| QuantMatmul PR#73 | SKIP（无 compile.all accuracy case） | BUILD_FAIL（CUBE cell-layout，权威 shape=源码默认） | 按 skill 以源码默认 shape 落地编译 |
| DynamicMxQuant PR#83 | MODEL_FAIL ×3（compare/select TEPL tuple） | MODEL_FAIL ×4（TCMPS / row expansion；新增 probe config） | 同族模型侧断言，具体契约不同 |
| Conv2dV2 PR#75 | OK / PASS ×2 | SOURCE_INTEGRATION_BLOCKED（conv2d/Makefile 冲突） | - |
| MegaMoe PR#74 | compile FAIL（v2i64 BUILD_VECTOR，BS64） | PASS ×2（BS16 per compile.all，内嵌 golden） | 编译修复 + 内嵌 golden 全过 |
| MoeDispatch/MoeCombine | accuracy PASS（R2=0 口径） | EXECUTION_ONLY（源码无 oracle，按 skill 不得记 PASS） | 判据口径收紧：仅执行、无金标准 |
| RmsNorm | FAIL（compare 脚本调用用法错误） | PASS ×2（gen+compare 正确链路） | 脚本链路修复 |
| GroupNormGrad | PASS ×2 | group_norm_grad FAIL（dgamma mse）/ group_norm_grad_1d PASS | PR#84 head 前进（uneven 4PE row partitions），dgamma 绝对 mse 超限 |
| QLI PR#78 | golden gen failed ×4 | SOURCE_INTEGRATION_BLOCKED | - |
| QSMLA PR#39 | MODEL_FAIL | SOURCE_INTEGRATION_BLOCKED | - |

## 环境与工件

- SuperNPUBench worktree：`/mnt/workspace/CANNBOT/wt/ops-20260904`（bare clone `supernpubench.git`）；PR worktrees：`wt/pr-84`（head）、`wt/pr-{73,79,83,74}-int`（integration）、`wt/pr-{82,39,78,75}-int`（冲突态保留）
- 日志：`/mnt/workspace/CANNBOT/artifacts/logs/`（Phase 1：`build_*.log`/`run_*.log`；Phase 2：`p84_*`/`p79_*`/`p74_*`/`p73_*`/`p83_*`）
- Manifest：`/mnt/workspace/CANNBOT/artifacts/manifest_ops-20260904.md`（immutable source tuple、ancestry、逐 case 结果、失效分析）
- 比对数据（输入/golden/res）：各 worktree `benchmark/one-level-arch/compare/<elf-stem>/`（未跟踪）
- 依赖失效决策：工具链/sysroot REUSED（组件 commit 匹配 README pin + clang --version 证据）、gfrun REUSED（增量重建 no-op）、全部 smoke/PR ELF NEW（fresh worktree）
