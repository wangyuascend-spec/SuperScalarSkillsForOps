# SuperNPUBench solution 树单算子验证报告

> **日期**：2026-09-28 10:30–13:30 ｜ **执行**：Sisyphus（snb-solution-verify 流程）
> **范围**：`benchmark/one-level-arch/test/solution/` 全部单算子编译单元——**排除 `tileop-test/` 看护套件与 `common/`**，共 17 个 `compile.all` 单元、73 个 ELF，逐个跑 gfrun + gfsim，并补精度比对。
> **对照基准**：ziyang-cheng 版本跟踪报告 `2026-09-25T0514+0800__main__validation.md`

---

## 1. 结论摘要

| 维度 | 结果 | 相对 09-25 报告 |
|---|---|---|
| **编译** | **17/17 单元全部成功，73 ELF** | conv2d COMPILE_FAIL 已被 TileOP #234 修复 |
| **gfrun** | **67 PASS / 6 SELFFAIL**（R2=1），0 崩溃 / 0 超时 | 报告的"可用性"口径下 73/73 全部跑到终点（报告为 71 + 2 编译失败） |
| **gfsim** | **35 DONE / 24 ASSERT / 14 TIMEOUT** | +3 修复（moe mt 家族挂死）、**−2 回归（group_norm_grad 4PE）**、5 例 TIMEOUT→ASSERT（新断言）、conv2d 2 例转入 TIMG2COL 断言 |
| **精度** | dmxq **17/17 PASS**、norm **4/4 PASS**、gather_v2/view_copy **6/6 FAIL**（预存） | 与报告一致（gather/view 自 09-14 起失配）；dmxq/norm 全绿 |

**三条需要行动的发现**：
1. 🔴 **SSM 回归**：PR #798（4PE syscall lockstep，09-22~09-28 合入）使 `group_norm_grad` 4PE dynamic/static 从 gfsim PASS 变 ASSERT（`SyscallBarrier.cpp:1660`），建议报 issue；
2. 🟡 **gfsim 新断言面**：同批提交把 5 个原本 TIMEOUT 的用例变为快速 abort（`SyscallBarrier.cpp:1660`），conv2d 2 例挂在 TIMG2COL 契约（`Block.cpp:2314`）——均为时序模型缺口，非 ISA/功能问题（gfrun 全 PASS）；
3. 🟡 **上游 harness 漂移**：`res_check_all.py` 对当前树结构性失效（详见 §6.4），建议上游修复或归档。

---

## 2. 验证环境（全仓 latest）

| 组件 | 仓库 / 分支 | commit | 日期 | 备注 |
|---|---|---|---|---|
| llvm-project | LinxISA `dev-llvm15_56` | `af743c28` | 09-24 | 含 Shared 寄存器 copy 显式拒绝 |
| Linx-TileOP-API | LinxISA `linx` | `b2b16fa` | 09-25 | **#234 TIMG2COL_SPART 强制内联**（修 conv2d 编译） |
| SuperScalarModel | LinxISA `main` | `0688ed22` | 09-28 09:42 | **PR #798 4PE syscall lockstep**（本轮 gfsim 差异全部来源） |
| SuperNPUBench | PTO-ISA `main` | `5da6474` | 09-24 | 与 09-25 报告同版 |

构建：工具链增量 ninja + TileOP 头 rsync；gfrun/gfsim 为 Release 构建（`build.py build --target gfrun/gfsim -j16`）。
conv2d 修复归因（A/B 实证）：旧 TileOP 头（275d8e7）复现报告报错 `cannot copy a Shared register: Shared handles have no MOVR/copy instruction`（崩于 `LinxV5InstrInfo::copyPhysReg`）；#234 内联后消除。

---

## 3. 编译矩阵（17 单元）

| 单元 | rc | ELF 数 |
|---|---|---|
| conv2d | 0 | 2 |
| gather_v2 | 0 | 3 |
| group_token_old | 0 | 2 |
| group_token_vec | 0 | 3 |
| matmul_test | 0 | 9 |
| mega_moe | 0 | 3 |
| moe_combine | 0 | 3 |
| moe_dispatch | 0 | 3 |
| normalization/rms_norm | 0 | 8 |
| normalization/rms_norm_split_r | 0 | 2 |
| normalization/group_norm_grad | 0 | 2 |
| normalization/group_norm_grad_1d | 0 | 2 |
| qli | 0 | 4 |
| quant_batch_matmul_test | 0 | 2 |
| quant/dynamic_mx_quant | 0 | 17 |
| quant_sparse_flash_mla | 0 | 5 |
| view_copy | 0 | 3 |

历史怪癖核对：qsmla 已有自足 `compile.all`（5 模式 ×4PE + 现场 CPU golden，本轮全编过）；quant_batch 已不硬编码贡献者路径；matmul_test M100 配置与 qli 全部在最新 TileOP 下编译通过（09-17 时代的 Shared-B 契约阻塞已解除）。

> ⚠️ **编译基础设施坑（本轮新发现）**：各单测 Makefile 覆盖的 `clean` 目标执行 `find $(OBJ_ROOT) -name "*.o"` **删除整个 output/solution 树的所有 .o**（Makefile.common 的 `$(TARGET): clean ...` 使 clean 每次构建必跑）。**并行编译多个单元会互相删 .o**，表现为 `ld.lld: cannot open ....o: No such file or directory`（本轮 moe_dispatch_v2 / group_token_vec 首编被 race，单独重编立即成功）。**结论：跑 compile.all 必须串行。**（报告的 runner 串行编译，不受影响。）

---

## 4. gfrun 扫描（73 ELF）

判据：PASS = `R2 = 0`；SELFFAIL = `R2 = 1`（kernel 跑到底但自检数值失配）；4PE 按 ELF 名 `_mt`/`PE4`/`_4pe` 判定（`-s softcore.multiThreadNum=4`）。

**统计：67 PASS / 6 SELFFAIL / 0 CRASH / 0 TIMEOUT。**

6 个 SELFFAIL 全部为 09-14 起的已知预存数值失配（报告按"可用性 PASS、精度 ❌"口径计入 PASS）：

| 用例 | 失配 |
|---|---|
| gather_v2 ×3（half/float/int32 各 shape） | `FAIL: gather_v2 found 37 mismatches` 等 |
| view_copy ×3 | `FAIL: view_copy found 64 mismatches` 等 |

与报告对照的唯一 gfrun 变化：**conv2d ×2 COMPILE_FAIL → PASS**（TileOP #234）。

---

## 5. gfsim 扫描（73 ELF）

判据：DONE = 出现 `SuperScalar Report Stop`；ASSERT = 断言中止；TIMEOUT = 900s 超时。4PE 用 `--conf fourpe`（SSM 目录下运行）。

**统计：35 DONE / 24 ASSERT / 14 TIMEOUT**（报告：34 PASS / 15 FAIL / 22 TIMEOUT / 2 COMPILE_FAIL）

### 5.1 相对报告的变化（全部源于 SSM 88e25213→0688ed22 的 30 个提交，核心 PR #798）

| 方向 | 用例 | 断言/说明 |
|---|---|---|
| 🟢 TIMEOUT→DONE（+3） | moe_combine_mt、moe_dispatch_mt、moe_dispatch_mt_dyn | PR #798 syscall barrier 修复 mt 家族挂死 |
| 🔴 **回归** PASS→ASSERT（−2） | **group_norm_grad dynamic/static（4PE）** | `SyscallBarrier.cpp:1660`：`syscall_lockstep_and_timeout: a lockstep group's AND never completed (a participant did not arrive)` |
| 🔀 TIMEOUT→ASSERT（5） | group_token_old_mt、group_token_vec_mt、mega_moe_sim_mt、view_copy×2 | 同上断言（挂死变快速 abort，仍为 FAIL，但定位更快） |
| ➕ COMPILE_FAIL→ASSERT（2） | conv2d ×2 | `Block.cpp:2314`：`BSTART.TIMG2COL schema or parameter carrier is illegal`（gfrun PASS，纯时序模型契约缺口） |

### 5.2 与报告相同的已知断言（行号随新提交漂移 +37~54，同源）

| 类别 | 用例数 | 断言（本轮位置 / 报告位置） |
|---|---|---|
| Tile 寄存器容量 | 6：gng_1d ×2、rms_norm dynamic/static、split_r ×2 | `Tile register is not enough`（BIssue.cpp:4031 / 3994） |
| TROWEXPAND 广播源 | 7：dmxq tail 家族 | `VecTop.cpp:4486` / 4432 |
| STQ 准入窗口 | 2：qsmla hca/swa | `TlsuFrontend.cpp:1362` / 1354 |

### 5.3 不变的 TIMEOUT（14）

gather_v2 ×3、group_token_vec_mt_dyn、matmul_test M512 + mt ×2、mega_moe sim/sim_mt_dyn、moe_combine_mt_dyn、qli Skv8192、quant_batch ×2、view_copy int32。

---

## 6. 精度

### 6.1 dmxq 官方入口 `run_precision_check.py`（gen → res_check 编译 → gfrun → 逐字节比对）

**17/17 PASS**（output + scale，MSE=0.000000）——tail/nontail × fp8/fp4 × static/dyn/splitN/bench 全绿。

### 6.2 normalization（官方 runner + 手工补齐）

| 用例 | 入口 | 结果 |
|---|---|---|
| rms_norm dynamic gA128/gR8192 | 官方 `run_precision_check.py` | **PASS**（max_abs=0.001953, mse=7.4e-11） |
| rms_norm_split_r dynamic gA16/gR16384 | 手工（gen 默认形状） | **PASS** |
| group_norm_grad dynamic N2/C32/G8/HxW2048 | 手工 | **PASS** |
| group_norm_grad_1d dynamic N256/C4096/G8 | 手工 | **PASS** |

### 6.3 gather_v2 / view_copy（`check_gfrun.py`，独立 host golden）

**6/6 FAIL** —— 与 gfrun R2=1 自洽，09-14 起已知预存精度缺口。

### 6.4 旧 harness `res_check_all.py` 结构性失效（上游漂移，建议报 issue）

1. **dmxq 注入被骗过**：`compile_units` 的注入条件 `if "res_check=on" not in script` 被 dmxq compile.all **注释里的** "res_check=on" 字样（第 4/61/63 行）骗过 → 不注入 → 编出 plain ELF（无 I/O 桩）→ kernel 自检 R2=0 但不写 output.bin → 误报 `output=missing files` FAIL。dmxq 实际已迁移到自带 `run_precision_check.py`（注释明示），harness 未跟上。
2. **_NORM CASES 表形状过期**：期望 gA512/N32C16HxW8192/N512C64 等形状，而当前 compile.all 与 gen 默认均为 gA128/N2C32HxW2048/N256C4096；且 Makefile 只支持 `_dynamic/_static` TESTCASE（CASES 表里的无后缀名已不存在）→ 全部 SKIP。

---

## 7. 逐用例结果（73 例）

判据列：gfrun PASS=R2=0、SELFFAIL=R2=1；gfsim DONE=正常到 Report Stop、ASSERT=断言中止、TIMEOUT=900s。

#### conv2d（2 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `conv2d_img2col_PE4` | PASS | ASSERT | 报告 COMPILE_FAIL → 编译已修复；gfsim 新断言 TIMG2COL（Block.cpp:2314） |
| `conv2d_img2col_dyn_PE4` | PASS | ASSERT | 报告 COMPILE_FAIL → 编译已修复；gfsim 新断言 TIMG2COL（Block.cpp:2314） |

#### gather_v2（3 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `gather_v2_DType__half_ITypeuint32_t_RANK2_DIM0_IN11_17_OUT8_17_TILE64` | SELFFAIL | TIMEOUT | （R2=1 预存，精度 ❌） |
| `gather_v2_DTypefloat_ITypeuint32_t_RANK1_DIM0_IN19_OUT37_TILE32` | SELFFAIL | TIMEOUT | （R2=1 预存，精度 ❌） |
| `gather_v2_DTypeint32_t_ITypeint32_t_RANK2_DIM1_IN5_11_OUT5_7_TILE32` | SELFFAIL | TIMEOUT | （R2=1 预存，精度 ❌） |

#### group_token_old（2 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `group_token_old` | PASS | DONE |  |
| `group_token_old_mt` | PASS | ASSERT | 🔀 报告 TIMEOUT → ASSERT（SyscallBarrier.cpp:1660，挂死变快速 abort） |

#### group_token_vec（3 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `group_token_vec` | PASS | DONE |  |
| `group_token_vec_mt` | PASS | ASSERT | 🔀 报告 TIMEOUT → ASSERT（SyscallBarrier.cpp:1660，挂死变快速 abort） |
| `group_token_vec_mt_dyn` | PASS | TIMEOUT |  |

#### matmul_test（9 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `matmul_test_B1_M100_N100_K100_tM16_tN16_tK16` | PASS | DONE |  |
| `matmul_test_B1_M101_N99_K110_tM16_tN16_tK16` | PASS | DONE |  |
| `matmul_test_B1_M105_N99_K103_tM32_tN32_tK32` | PASS | DONE |  |
| `matmul_test_B1_M200_N96_K128_tM16_tN16_tK16` | PASS | DONE |  |
| `matmul_test_B1_M203_N99_K101_tM16_tN16_tK16` | PASS | DONE |  |
| `matmul_test_B1_M256_N256_K256_tM16_tN16_tK16` | PASS | DONE |  |
| `matmul_test_B1_M512_N256_K512_tM32_tN32_tK32` | PASS | TIMEOUT |  |
| `matmul_test_mt_B1_M120_N256_K1536_tM128_tN256_tK128` | PASS | TIMEOUT |  |
| `matmul_test_mt_B1_M160_N320_K1536_tM64_tN512_tK128` | PASS | TIMEOUT |  |

#### mega_moe（3 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `mega_moe_sim_BS16_H32_HD64` | PASS | TIMEOUT |  |
| `mega_moe_sim_mt_BS16_H32_HD64` | PASS | ASSERT | 🔀 报告 TIMEOUT → ASSERT（SyscallBarrier.cpp:1660，挂死变快速 abort） |
| `mega_moe_sim_mt_dyn` | PASS | TIMEOUT |  |

#### moe_combine（3 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `moe_combine_mt` | PASS | DONE | 🟢 报告 TIMEOUT → DONE（PR #798 修 mt 挂死） |
| `moe_combine_mt_dyn` | PASS | TIMEOUT |  |
| `moe_combine_v2` | PASS | DONE |  |

#### moe_dispatch（3 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `moe_dispatch_mt` | PASS | DONE | 🟢 报告 TIMEOUT → DONE（PR #798 修 mt 挂死） |
| `moe_dispatch_mt_dyn` | PASS | DONE | 🟢 报告 TIMEOUT → DONE（PR #798 修 mt 挂死） |
| `moe_dispatch_v2` | PASS | DONE |  |

#### normalization/rms_norm（8 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `rms_norm_rms_norm_dynamic_DType__half_gA128_gR8192_PE4` | PASS | ASSERT |  |
| `rms_norm_rms_norm_dynamic_m_R_simt_32k_DType__half_gA128_gR16384_PE4` | PASS | DONE |  |
| `rms_norm_rms_norm_dynamic_m_R_simt_32k_DType__half_gA128_gR8192_PE4` | PASS | DONE |  |
| `rms_norm_rms_norm_dynamic_m_R_simt_DType__half_gA128_gR8192_PE4` | PASS | DONE |  |
| `rms_norm_rms_norm_dynamic_m_R_tree_32k_DType__half_gA128_gR16384_PE4` | PASS | DONE |  |
| `rms_norm_rms_norm_dynamic_m_R_tree_32k_DType__half_gA128_gR8192_PE4` | PASS | DONE |  |
| `rms_norm_rms_norm_dynamic_m_R_tree_DType__half_gA128_gR8192_PE4` | PASS | DONE |  |
| `rms_norm_rms_norm_static_DType__half_gA128_gR8192_PE4` | PASS | ASSERT |  |

#### normalization/rms_norm_split_r（2 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `rms_norm_split_r_rms_norm_split_r_dynamic_DType__half_gA16_gR16384_PE4` | PASS | ASSERT |  |
| `rms_norm_split_r_rms_norm_split_r_static_DType__half_gA16_gR16384_PE4` | PASS | ASSERT |  |

#### normalization/group_norm_grad（2 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `group_norm_grad_group_norm_grad_dynamic_DType__half_N2_C32_G8_HxW2048_PE4` | PASS | ASSERT | 🔴 **回归**：报告 PASS → ASSERT（SyscallBarrier.cpp:1660） |
| `group_norm_grad_group_norm_grad_static_DType__half_N2_C32_G8_HxW2048_PE4` | PASS | ASSERT | 🔴 **回归**：报告 PASS → ASSERT（SyscallBarrier.cpp:1660） |

#### normalization/group_norm_grad_1d（2 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `group_norm_grad_1d_group_norm_grad_1d_dynamic_DType__half_N256_C4096_G8_PE4` | PASS | ASSERT |  |
| `group_norm_grad_1d_group_norm_grad_1d_static_DType__half_N256_C4096_G8_PE4` | PASS | ASSERT |  |

#### qli（4 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `check_opt_fp8_B1_Sq4_Skv2048_g64_Tm16_Tk32` | PASS | DONE |  |
| `check_opt_fp8_B1_Sq4_Skv2080_g64_Tm16_Tk32` | PASS | DONE |  |
| `check_opt_fp8_B1_Sq4_Skv8192_g64_Tm16_Tk32` | PASS | TIMEOUT |  |
| `check_opt_fp8_B1_Sq64_Skv128_g64_Tm16_Tk32` | PASS | DONE |  |

#### quant_batch_matmul_test（2 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `quant_batch_matmul_test_hif4_B1_M256_N256_K256_tM64_tN32_tK64` | PASS | TIMEOUT |  |
| `quant_batch_matmul_test_mxfp4_mt_B1_M256_N256_K256_tM64_tN32_tK64` | PASS | TIMEOUT |  |

#### quant/dynamic_mx_quant（17 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `nontail_cublas_fp8` | PASS | DONE |  |
| `nontail_cublas_fp8_dyn` | PASS | DONE |  |
| `nontail_cublas_fp8_splitN_dyn` | PASS | DONE |  |
| `nontail_ocp_fp4` | PASS | DONE |  |
| `nontail_ocp_fp4_dyn` | PASS | DONE |  |
| `nontail_ocp_fp4_splitN_dyn` | PASS | DONE |  |
| `tail_cublas_fp8` | PASS | ASSERT |  |
| `tail_cublas_fp8_dyn` | PASS | ASSERT |  |
| `tail_ocp_fp4` | PASS | ASSERT |  |
| `tail_ocp_fp4_bench_small` | PASS | ASSERT |  |
| `tail_ocp_fp4_dyn` | PASS | ASSERT |  |
| `tail_ocp_fp8` | PASS | ASSERT |  |
| `tail_ocp_fp8_bench_small_V1_dyn` | PASS | DONE |  |
| `tail_ocp_fp8_bench_small_V1_static` | PASS | DONE |  |
| `tail_ocp_fp8_bench_small_V2_dyn` | PASS | DONE |  |
| `tail_ocp_fp8_bench_small_V2_static` | PASS | DONE |  |
| `tail_ocp_fp8_dyn` | PASS | ASSERT |  |

#### quant_sparse_flash_mla（5 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `B1_s11_oriS2128_cmpS264_N164_N21_D512_oriK40_cmpK40_ratio4_Tm64_Tk32_Td64_IMPLcsa_tadd_4pe_DTYPEHIF8_INPUTembedded` | PASS | DONE |  |
| `B1_s11_oriS2128_cmpS264_N164_N21_D512_oriK40_cmpK40_ratio4_Tm64_Tk32_Td64_IMPLhca_tadd_4pe_DTYPEHIF8_INPUTembedded` | PASS | ASSERT |  |
| `B1_s11_oriS2128_cmpS264_N164_N21_D512_oriK40_cmpK40_ratio4_Tm64_Tk32_Td64_IMPLori_cmp_sparse_tadd_4pe_DTYPEHIF8_INPUTembedded` | PASS | DONE |  |
| `B1_s11_oriS2128_cmpS264_N164_N21_D512_oriK40_cmpK40_ratio4_Tm64_Tk32_Td64_IMPLori_sparse_tadd_4pe_DTYPEHIF8_INPUTembedded` | PASS | DONE |  |
| `B1_s11_oriS2128_cmpS264_N164_N21_D512_oriK40_cmpK40_ratio4_Tm64_Tk32_Td64_IMPLswa_tadd_4pe_DTYPEHIF8_INPUTembedded` | PASS | ASSERT |  |

#### view_copy（3 例）

| 用例 | gfrun | gfsim | 相对 09-25 报告 |
|---|---|---|---|
| `view_copy_DType__half_SHAPE4_4_6_TILE64_IN_STRIDE24_1_4_OUT_STRIDE24_6_1` | SELFFAIL | ASSERT | 🔀 报告 TIMEOUT → ASSERT（SyscallBarrier.cpp:1660，挂死变快速 abort） |
| `view_copy_DType__half_SHAPE4_4_8_TILE64_IN_STRIDE32_8_1_OUT_STRIDE32_1_4` | SELFFAIL | ASSERT | （R2=1 预存，精度 ❌） |
| `view_copy_DTypeint32_t_SHAPE2_4_8_TILE32_IN_STRIDE32_1_4_OUT_STRIDE32_8_1` | SELFFAIL | TIMEOUT | （R2=1 预存，精度 ❌） |

---

## 8. 与 09-25 报告的总结论对比

| 维度 | 09-25 报告 | 本轮（2026-09-28 最新链） |
|---|---|---|
| solution 编译 | 71 单元可用 + conv2d ×2 COMPILE_FAIL | **73/73 编译成功** |
| gfrun | 71 可用性 PASS（含 6 个 R2=1 计 PASS） | **73/73 可用性 PASS**（67 个 R2=0 + 6 个 R2=1 预存） |
| gfsim | 34 PASS / 15 FAIL / 22 TIMEOUT / 2 CF | 35 DONE / 24 ASSERT / 14 TIMEOUT（+3 moe 修复，−2 gng 回归，+2 conv2d 转 TIMG2COL 断言，5 例 TIMEOUT→ASSERT） |
| 精度 | gather/view ❌（6）、dmxq tail 3 PASS | gather/view ❌（6，预存）；**dmxq 17/17 PASS、norm 4/4 PASS** |

## 9. 建议行动

1. **SSM issue**：PR #798 syscall lockstep 使 group_norm_grad（4PE）gfsim 回归（SyscallBarrier.cpp:1660）；同一断言把 5 个原 TIMEOUT 用例转为快速 abort，建议一并排查。
2. **SSM issue（低优先）**：gfsim TIMG2COL Shared-ND 出口操作数契约（Block.cpp:2314）阻塞 conv2d ×2。
3. **SNB issue**：`res_check_all.py` CASES 表/注入逻辑过期（§6.4）；单测 Makefile `clean` 的全树删 .o 行为在并行编译下互相破坏（建议 `find` 限定本单元目录）。
4. **预存不回归项**（与报告一致，无需本轮行动）：gather_v2/view_copy R2=1（09-14 起）、Tile-not-enough ×6、dmxq tail gfsim ×7、qsmla hca/swa ×2、14 TIMEOUT。

## 10. 产物索引与复现

- 本报告与全部日志/脚本：`/mnt/workspace/CANNBOT/artifacts/sol_verify_20260928_full/`
  - `logs/sweep_gfrun.txt`、`sweep_gfsim.txt`（状态+耗时）；`logs/gfrun_*.log`、`gfsim_*.log`（逐 ELF 完整输出）
  - `logs/build_*.log`（编译）、`dmxq_precision.log`、`rms_norm_precision.log`、`prec_cmp_*.log`（精度）
  - `bin/compile_all.sh`、`sweep.sh`、`norm_precision.sh`（驱动脚本，可复跑）
- 复现要点：
  1. 三仓 latest（§2 版本表）；`COMPILER_DIR=/tmp/opencode/linx-toolchain-build/output/linx_blockisa_llvm_musl/bin`，`baremetal=off`；
  2. 编译**串行**执行 17 个 compile.all（避免 clean 竞态）；
  3. gfrun 从 `output/solution` 目录用相对路径；gfsim 从 SSM 目录用绝对路径 + `--conf fourpe`（4PE）；
  4. ⚠️ 当前输出树为 res_check 污染态（精度轮重编覆盖了 dmxq/norm/gather/view 的 plain ELF），再跑 plain 扫描须先清空重编。

---

## 附录 A：PTO 0.58.7 链刷新复验（2026-09-28 16:00–17:30）

正文验证基于 14:00 前的链。当日 14:11–14:54 四仓协同发版 **PTO 0.58.7**，已跟进更新并重建复验：

| 组件 | 新 commit | 内容 |
|---|---|---|
| llvm | `6574dfe6` | TileOp 宏更新至 PTO 0.58.7 |
| TileOP | `771669f` | #240 对齐 PTO 0.58.7 + #239 TEXPDIF |
| SSM | `1051ded6` | **PR #875 修 QSMLA 4PE STQ/BIQ/STA 竞态**（仅改 gfsim 侧，gfrun 二进制无变化） |
| SNB | `208acfe` | **#196 GFSIM=on 构建挡板**（4PE 全员 file I/O 适配 SyscallBarrier lockstep）+ #195 quant_batch CSV 测试基建 |

### 复验结果（新 gfsim，gfrun 无变化）

| 用例 | 正文时状态 | 刷新后 | 归因 |
|---|---|---|---|
| qsmla hca / swa | ASSERT（TlsuFrontend.cpp:1362） | **DONE ✅** | SSM PR #875 |
| qsmla csa / ori ×2 | DONE | DONE（无回归） | — |
| quant_batch hif4 / mxfp4_mt | TIMEOUT(900s) | **DONE ✅**（2400s 预算下完成；900s 时已推进至 81%/71%，本非死锁，纯长负载） | 充足时间 + #196 GFSIM 挡板 |
| quant_batch plain 版 gfrun（#195/#196 改源后重编） | PASS | **PASS（R2=0）** | 无回归 |
| gng dynamic/static | ASSERT 1660 | **仍 ASSERT**（dynamic 现挂 SyscallBarrier.cpp:1933、static 仍 1660） | kernel 未按 #196 方式适配 4PE I/O |
| gt_old_mt / gt_vec_mt / mega_moe_sim_mt / view_copy ×3 | ASSERT 1660 | 仍 ASSERT 1660（view_copy int32 从 TIMEOUT 转 ASSERT） | 同上 |
| mega_moe_sim_mt_dyn / moe_combine_mt_dyn | TIMEOUT | 仍 TIMEOUT | — |
| moe_combine_mt / moe_dispatch_mt / moe_dispatch_mt_dyn | DONE | **DONE（无回归）** | — |

### 刷新后 gfsim solution 树更新计数

- 900s 判据：**37 DONE** / 22 ASSERT / 14 TIMEOUT
- 2400s 判据（quant_batch 放行）：**39 DONE / 73 = 53%**

### 待办更新

1. SyscallBarrier.cpp:1660/1933 的 9 例（gng ×2、gt ×2、mega_moe ×1、view_copy ×3）：需 SNB 侧按 #196 模式给这些 kernel 加 GFSIM=on 适配，或 SSM 侧放宽 fail-fast——建议两边报 issue 时互相引用；
2. quant_batch 属长负载，建议报告 runner 对该单元放宽超时（≥2400s）。
