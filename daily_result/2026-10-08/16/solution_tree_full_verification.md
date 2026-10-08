# SuperNPUBench solution 树全量验证报告 — 2026-10-08

> 范围：`test/solution/` 单算子树（排除 tileop-test），**16 单元 / 67 ELF**（归一化重构后清单有变），gfrun + gfsim 双扫描。
> 对照基线：2026-09-30 全量轮（17 单元 / 73 ELF）。

## 1. 验证链（全仓 latest，10-08 14:38 重建）

| 组件 | commit | 日期 | 8 天内新内容 |
|---|---|---|---|
| llvm dev-llvm15_56 | `62b878d6` | 09-30 17:13 | +7：element-if 修复、显式行 stride、**Reject invalid Shared tile copies**、TRegToOffset liveout（#60）、DTYPE_NONE TMOV（#64） |
| Linx-TileOP-API linx | `12bd048` | 09-30 | 无变化（tip 未动） |
| SuperScalarModel main | `96fdc684` | 10-06 | **+21**：#898 TLSU BIQ 每线程配额（修 4-PE 会合 TLOAD 队列垄断死锁）、#895 RAS restore hole（#874）、#829 gfrun 适配 PTO #339/#342 CUBE 契约、**#905 修 issue-866**（effective-D aux / RowMax-GroupMax 存储）、passlist 刷到 ops-20261004（816 ELF） |
| SuperNPUBench main | `3bdba36` | **10-08 09:39（今晨）** | +9：**#210 修 mega-moe/moe-dispatch/group-token 的 gfsim 仿真**、#209 GroupNorm FP16 oracle 修复、**#201/#204/#206/#208 归一化大重构**（gng_1d 并入 gng、rms 旧变体归档 V0）、fixp CUBE_N8 |

构建：llvm 增量 ninja（clean）+ TileOP 头 rsync；gfrun(14:36)/gfsim(14:38) Release。
编译：串行 16 单元全部 rc=0；`rms_norm/V0` 为刻意归档（compile.all 全注释，0 ELF 符合设计）。

## 2. 清单变化（73 → 67 ELF）

| 变化 | 说明 |
|---|---|
| −2 rms_norm_split_r ×2 | 归档进 V0（不再构建） |
| −4 rms_norm dynamic/static/m_R_simt/m_R_tree（非 32k） | 归档；保留并更名 simt_32k/tree_32k ×4 |
| −2 gng_1d 独立单元 | 并入 group_norm_grad（单元 2→4 ELF，1d 案例改名保留） |

## 3. gfrun 扫描（67 ELF，900s）

**61 PASS / 6 SELFFAIL / 0 CRASH / 0 TIMEOUT**

6 个 SELFFAIL 仍为 gather_v2 ×3 + view_copy ×3（R2=1，MGATHER/MSCATTER 通路 **09-14 回归，已挂 3.5 周未修**）。其余 61 例全部 R2=0（含重构后的归一化家族与 #210 修复的 MoE 家族）。

## 4. gfsim 扫描（67 ELF，900s，fourpe 判定）

**43 DONE / 13 ASSERT / 11 TIMEOUT / 0 CRASH**（09-30：41/19/12/1 on 73 例）

### 4.1 相对 09-30 的变化（同名 61 例精确 diff）

| 方向 | 用例 | 归因 |
|---|---|---|
| 🟢 CRASH→DONE | **moe_dispatch_mt_dyn**（上轮新发现的 BFU 断言，已修） | SNB #210 / SSM #898 |
| 🟢 ASSERT→DONE | group_token_old_mt、group_token_vec_mt | SNB #210 / SSM #898 |
| 🟢 TIMEOUT→DONE | mega_moe_sim_mt | SNB #210 / SSM #898 |

**零回归**（61 个同名用例中除上述 4 例外状态全部持平）。

### 4.2 残留 13 ASSERT（全部为已知开放问题，仅行号漂移）

| 类别 | 数量 | 断言（本轮 / 首报位置） |
|---|---|---|
| dmxq tail 家族 | 7 | TROWEXPAND broadcast（VecTop.cpp:4550 / 原 4432） |
| conv2d ×2 | 2 | TIMG2COL 契约（Block.cpp:2690 / 原 2314） |
| gng_1d ×2（并入 gng 后） | 2 | Tile register not enough（BIssue.cpp:4262 / 原 3994） |
| view_copy half ×2 | 2 | SyscallBarrier lockstep（SyscallBarrier.cpp:1889 / 原 1660）——kernel 未按 #196 模式适配 |

### 4.3 残留 11 TIMEOUT

- 长负载（前轮已证明给足时间能过）：matmul M512（~1578s）、matmul mt ×2（~3h）、quant_batch ×2（~1100–2000s）
- 未解：mega_moe_sim_mt_dyn（#210 修了 sim_mt 但 mt_dyn 仍超时）、gather_v2 ×3、qli Skv8192、view_copy int32
- 2400s 判据下预计 46/67 = 69%

## 5. 逐 ELF 验证明细（67 例）

判据：gfrun PASS = `R2 = 0`、SELFFAIL = `R2 = 1`；gfsim DONE = 出现 `SuperScalar Report Stop`、ASSERT = 断言中止、TIMEOUT = 900s 超时。失败原因列为 gfsim 断言位置及消息（或超时/崩溃说明），gfrun 失配单独标注。

#### conv2d（2 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `conv2d_img2col_PE4` | PASS | 0s | ASSERT | 1s | `Block.cpp:2690` dataTypeLegal && dimensionsLegal && dataAttributesLegal && iorLegal && |
| `conv2d_img2col_dyn_PE4` | PASS | 0s | ASSERT | 1s | `Block.cpp:2690` dataTypeLegal && dimensionsLegal && dataAttributesLegal && iorLegal && |

#### gather_v2（3 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `gather_v2_DType__half_ITypeuint32_t_RANK2_DIM0_IN11_17_OUT8_17_TILE64` | SELFFAIL | 1s | TIMEOUT | 900s | 900s 超时（长负载/未解）；gfrun R2=1 数值失配 |
| `gather_v2_DTypefloat_ITypeuint32_t_RANK1_DIM0_IN19_OUT37_TILE32` | SELFFAIL | 0s | TIMEOUT | 900s | 900s 超时（长负载/未解）；gfrun R2=1 数值失配 |
| `gather_v2_DTypeint32_t_ITypeint32_t_RANK2_DIM1_IN5_11_OUT5_7_TILE32` | SELFFAIL | 0s | TIMEOUT | 900s | 900s 超时（长负载/未解）；gfrun R2=1 数值失配 |

#### group_token_old（2 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `group_token_old` | PASS | 5s | DONE | 372s |  |
| `group_token_old_mt` | PASS | 3s | DONE | 399s |  |

#### group_token_vec（3 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `group_token_vec` | PASS | 10s | DONE | 101s |  |
| `group_token_vec_mt` | PASS | 25s | DONE | 400s |  |
| `group_token_vec_mt_dyn` | PASS | 26s | DONE | 758s |  |

#### matmul_test（9 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `matmul_test_B1_M100_N100_K100_tM16_tN16_tK16` | PASS | 4s | DONE | 88s |  |
| `matmul_test_B1_M101_N99_K110_tM16_tN16_tK16` | PASS | 4s | DONE | 97s |  |
| `matmul_test_B1_M105_N99_K103_tM32_tN32_tK32` | PASS | 4s | DONE | 92s |  |
| `matmul_test_B1_M200_N96_K128_tM16_tN16_tK16` | PASS | 8s | DONE | 169s |  |
| `matmul_test_B1_M203_N99_K101_tM16_tN16_tK16` | PASS | 7s | DONE | 136s |  |
| `matmul_test_B1_M256_N256_K256_tM16_tN16_tK16` | PASS | 31s | DONE | 595s |  |
| `matmul_test_B1_M512_N256_K512_tM32_tN32_tK32` | PASS | 82s | TIMEOUT | 900s | 900s 超时（长负载/未解） |
| `matmul_test_mt_B1_M120_N256_K1536_tM128_tN256_tK128` | PASS | 90s | TIMEOUT | 900s | 900s 超时（长负载/未解） |
| `matmul_test_mt_B1_M160_N320_K1536_tM64_tN512_tK128` | PASS | 115s | TIMEOUT | 900s | 900s 超时（长负载/未解） |

#### mega_moe（3 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `mega_moe_sim_BS16_H32_HD64` | PASS | 12s | DONE | 263s |  |
| `mega_moe_sim_mt_BS16_H32_HD64` | PASS | 5s | DONE | 837s |  |
| `mega_moe_sim_mt_dyn` | PASS | 11s | TIMEOUT | 900s | 900s 超时（长负载/未解） |

#### moe_combine（3 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `moe_combine_mt` | PASS | 1s | DONE | 32s |  |
| `moe_combine_mt_dyn` | PASS | 2s | DONE | 51s |  |
| `moe_combine_v2` | PASS | 0s | DONE | 2s |  |

#### moe_dispatch（3 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `moe_dispatch_mt` | PASS | 1s | DONE | 11s |  |
| `moe_dispatch_mt_dyn` | PASS | 2s | DONE | 22s |  |
| `moe_dispatch_v2` | PASS | 1s | DONE | 3s |  |

#### normalization/rms_norm（4 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `rms_norm_rms_norm_dynamic_simt_32k_DType__half_gA128_gR16384_PE4` | PASS | 17s | DONE | 79s |  |
| `rms_norm_rms_norm_dynamic_simt_32k_DType__half_gA128_gR8192_PE4` | PASS | 8s | DONE | 50s |  |
| `rms_norm_rms_norm_dynamic_tree_32k_DType__half_gA128_gR16384_PE4` | PASS | 16s | DONE | 86s |  |
| `rms_norm_rms_norm_dynamic_tree_32k_DType__half_gA128_gR8192_PE4` | PASS | 7s | DONE | 35s |  |

#### normalization/group_norm_grad（4 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `group_norm_grad_group_norm_grad_1d_dynamic_DType__half_N256_C4096_G8_PE4` | PASS | 47s | ASSERT | 2s | `BIssue.cpp:4262` 0 && "Tile register is not enough for the simulator!" , func RenameSin |
| `group_norm_grad_group_norm_grad_1d_static_DType__half_N256_C4096_G8_PE4` | PASS | 45s | ASSERT | 1s | `BIssue.cpp:4262` 0 && "Tile register is not enough for the simulator!" , func RenameSin |
| `group_norm_grad_group_norm_grad_dynamic_DType__half_N2_C32_G8_HxW2048_PE4` | PASS | 4s | DONE | 94s |  |
| `group_norm_grad_group_norm_grad_static_DType__half_N2_C32_G8_HxW2048_PE4` | PASS | 4s | DONE | 89s |  |

#### qli（4 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `check_opt_fp8_B1_Sq4_Skv2048_g64_Tm16_Tk32` | PASS | 129s | DONE | 496s |  |
| `check_opt_fp8_B1_Sq4_Skv2080_g64_Tm16_Tk32` | PASS | 128s | DONE | 502s |  |
| `check_opt_fp8_B1_Sq4_Skv8192_g64_Tm16_Tk32` | PASS | 255s | TIMEOUT | 900s | 900s 超时（长负载/未解） |
| `check_opt_fp8_B1_Sq64_Skv128_g64_Tm16_Tk32` | PASS | 63s | DONE | 147s |  |

#### quant_batch_matmul_test（2 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `quant_batch_matmul_test_hif4_B1_M256_N256_K256_tM64_tN32_tK64` | PASS | 11s | TIMEOUT | 900s | 900s 超时（长负载/未解） |
| `quant_batch_matmul_test_mxfp4_mt_B1_M256_N256_K256_tM64_tN32_tK64` | PASS | 11s | TIMEOUT | 900s | 900s 超时（长负载/未解） |

#### quant/dynamic_mx_quant（17 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `nontail_cublas_fp8` | PASS | 1s | DONE | 2s |  |
| `nontail_cublas_fp8_dyn` | PASS | 2s | DONE | 2s |  |
| `nontail_cublas_fp8_splitN_dyn` | PASS | 1s | DONE | 2s |  |
| `nontail_ocp_fp4` | PASS | 1s | DONE | 1s |  |
| `nontail_ocp_fp4_dyn` | PASS | 1s | DONE | 1s |  |
| `nontail_ocp_fp4_splitN_dyn` | PASS | 1s | DONE | 2s |  |
| `tail_cublas_fp8` | PASS | 1s | ASSERT | 1s | `VecTop.cpp:4550` broadcastBytes > 0U && broadcastBytes <= VEC_CELL_GRANULARITY && "TROW |
| `tail_cublas_fp8_dyn` | PASS | 1s | ASSERT | 1s | `VecTop.cpp:4550` broadcastBytes > 0U && broadcastBytes <= VEC_CELL_GRANULARITY && "TROW |
| `tail_ocp_fp4` | PASS | 1s | ASSERT | 1s | `VecTop.cpp:4550` broadcastBytes > 0U && broadcastBytes <= VEC_CELL_GRANULARITY && "TROW |
| `tail_ocp_fp4_bench_small` | PASS | 3s | ASSERT | 0s | `VecTop.cpp:4550` broadcastBytes > 0U && broadcastBytes <= VEC_CELL_GRANULARITY && "TROW |
| `tail_ocp_fp4_dyn` | PASS | 1s | ASSERT | 1s | `VecTop.cpp:4550` broadcastBytes > 0U && broadcastBytes <= VEC_CELL_GRANULARITY && "TROW |
| `tail_ocp_fp8` | PASS | 1s | ASSERT | 1s | `VecTop.cpp:4550` broadcastBytes > 0U && broadcastBytes <= VEC_CELL_GRANULARITY && "TROW |
| `tail_ocp_fp8_bench_small_V1_dyn` | PASS | 18s | DONE | 33s |  |
| `tail_ocp_fp8_bench_small_V1_static` | PASS | 17s | DONE | 31s |  |
| `tail_ocp_fp8_bench_small_V2_dyn` | PASS | 6s | DONE | 16s |  |
| `tail_ocp_fp8_bench_small_V2_static` | PASS | 5s | DONE | 14s |  |
| `tail_ocp_fp8_dyn` | PASS | 1s | ASSERT | 1s | `VecTop.cpp:4550` broadcastBytes > 0U && broadcastBytes <= VEC_CELL_GRANULARITY && "TROW |

#### quant_sparse_flash_mla（5 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `B1_s11_oriS2128_cmpS264_N164_N21_D512_oriK40_cmpK40_ratio4_Tm64_Tk32_Td64_IMPLcsa_tadd_4pe_DTYPEHIF8_INPUTembedded` | PASS | 4s | DONE | 235s |  |
| `B1_s11_oriS2128_cmpS264_N164_N21_D512_oriK40_cmpK40_ratio4_Tm64_Tk32_Td64_IMPLhca_tadd_4pe_DTYPEHIF8_INPUTembedded` | PASS | 3s | DONE | 238s |  |
| `B1_s11_oriS2128_cmpS264_N164_N21_D512_oriK40_cmpK40_ratio4_Tm64_Tk32_Td64_IMPLori_cmp_sparse_tadd_4pe_DTYPEHIF8_INPUTembedded` | PASS | 4s | DONE | 331s |  |
| `B1_s11_oriS2128_cmpS264_N164_N21_D512_oriK40_cmpK40_ratio4_Tm64_Tk32_Td64_IMPLori_sparse_tadd_4pe_DTYPEHIF8_INPUTembedded` | PASS | 2s | DONE | 169s |  |
| `B1_s11_oriS2128_cmpS264_N164_N21_D512_oriK40_cmpK40_ratio4_Tm64_Tk32_Td64_IMPLswa_tadd_4pe_DTYPEHIF8_INPUTembedded` | PASS | 2s | DONE | 51s |  |

#### view_copy（3 例）

| 用例 | gfrun | 耗时 | gfsim | 耗时 | 失败原因 |
|---|---|---|---|---|---|
| `view_copy_DType__half_SHAPE4_4_6_TILE64_IN_STRIDE24_1_4_OUT_STRIDE24_6_1` | SELFFAIL | 1s | ASSERT | 10s | `SyscallBarrier.cpp:1889` false && "syscall_lockstep_and_timeout: a lockstep group's AND " "neve；gfrun R2=1 数值失配 |
| `view_copy_DType__half_SHAPE4_4_8_TILE64_IN_STRIDE32_8_1_OUT_STRIDE32_1_4` | SELFFAIL | 0s | ASSERT | 12s | `SyscallBarrier.cpp:1889` false && "syscall_lockstep_and_timeout: a lockstep group's AND " "neve；gfrun R2=1 数值失配 |
| `view_copy_DTypeint32_t_SHAPE2_4_8_TILE32_IN_STRIDE32_1_4_OUT_STRIDE32_8_1` | SELFFAIL | 0s | TIMEOUT | 901s | 900s 超时（长负载/未解）；gfrun R2=1 数值失配 |

## 6. 三周趋势（gfsim 900s 判据）

| 轮次 | SSM | DONE | 备注 |
|---|---|---|---|
| 09-28 | 0688ed22 | 35/73 | SyscallBarrier 回归出现 |
| 09-30 | 57378d2c | 41/73 | gng 回归修复；moe_dispatch_mt_dyn 新 CRASH |
| **10-08** | 96fdc684 | **43/67（64%）** | CRASH 清零、MoE/token 家族全修复；分母随归一化重构 -6 |

## 7. 行动建议

1. **gather_v2/view_copy 的 MGATHER 通路回归**（gfrun R2=1，09-14 起 6 例）——最高优先级，唯一"真算错"类问题，建议催 SSM；
2. mega_moe_sim_mt_dyn：#210 未覆盖，建议反馈；
3. view_copy half ×2 的 SyscallBarrier 适配、conv2d TIMG2COL 契约、gng_1d Tile 容量：既有开放项；
4. 长负载（matmul mt/quant_batch）建议报告 runner 分级超时。

## 8. 产物

- 本目录：REPORT.md、logs/（逐 ELF 双仿真日志、sweep 汇总、编译日志）、bin/（compile_all_serial.sh、sweep.sh）
- 同步副本：`/mnt/workspace/CANNBOT/CODE/OUTPUT/sol_verify_20261008_full/`
