# SuperNPUBench solution 树全量验证报告 — 2026-09-30

> 范围：`test/solution/` 单算子树（排除 tileop-test），17 单元 / 73 ELF，gfrun + gfsim 双扫描。
> 对照基线：2026-09-28 全量轮（同环境同判据）。

## 1. 验证链（全仓 latest，09-30 11:30 重建）

| 组件 | commit | 日期 | 本轮新内容 |
|---|---|---|---|
| llvm dev-llvm15_56 | `61d4f98b` | 09-30 09:47 | Refresh element-if model artifact |
| Linx-TileOP-API linx | `12bd048` | 09-30 09:39 | #248 region reductions 保留 assembled parent geometry |
| SuperScalarModel main | `57378d2c` | 09-30 10:50 | **PR #893**：#885 subview_vec、**#887 issue-881 lockstep-mem-stall**、MX Shared binding 0-4 switch、sharetreg 回退 256KiB/64ssb、Werror 修复 |
| SuperNPUBench main | `a283194` | 09-30 10:39 | **#198 tile-maximize MoE 算子 + fourpe gfsim 修复**、#200 group_token_vec_mt_dyn volatile 修复 |

构建：llvm 增量 ninja + TileOP 头 rsync；gfrun(11:27)/gfsim(11:30) Release 重编。
编译：**串行**执行 17 个 compile.all（避开单测 Makefile clean 的全树删 .o 竞态）——**17/17 全部 rc=0，73 ELF，本轮零竞态**。

## 2. gfrun 扫描（73 ELF，900s）

**67 PASS / 6 SELFFAIL / 0 CRASH / 0 TIMEOUT** —— 与 09-28 完全一致。

6 个 SELFFAIL 仍为 gather_v2 ×3 + view_copy ×3（R2=1，MGATHER/MSCATTER 通路 09-14 回归，
上游未修，独立 golden 比对确认真实失配）。其余全部 R2=0。

## 3. gfsim 扫描（73 ELF，900s，fourpe 判定）

**41 DONE / 19 ASSERT / 12 TIMEOUT / 1 CRASH**
（09-28 基线：35 DONE / 24 ASSERT / 14 TIMEOUT → **净 +6**）

### 3.1 相对 09-28 基线的变化

| 方向 | 用例 | 归因 |
|---|---|---|
| 🟢 ASSERT→DONE | **group_norm_grad dynamic/static**（09-28 发现的 SyscallBarrier 回归，**已修复**） | SSM #887（issue-881 lockstep-mem-stall）或 #885 |
| 🟢 TIMEOUT→DONE | mega_moe_sim、moe_combine_mt_dyn、group_token_vec_mt_dyn | SSM #887 + SNB #198/#200 |
| 🟢 ASSERT→DONE | qsmla hca / swa | SSM PR #875（09-28 下午已确认） |
| 🔴 DONE→**CRASH** | **moe_dispatch_mt_dyn**（9s，`BFU::GetLocalPipeID` bfu.cpp:4169 "Can't find occupied local pipe by global fbid"） | **A/B 实证：旧内核(208acfe)+新 gfsim=DONE** → SNB #198 新 tile-maximize 内核踩 gfsim BFU 缺口（kernel 领先模型，非 SSM 回归） |
| 🔀 ASSERT→TIMEOUT | mega_moe_sim_mt（194s 快败 → 900s 慢/挂） | 待查，仍不通过 |

### 3.2 与基线相同的已知项

- **ASSERT**：dmxq tail ×7（VecTop broadcast）、conv2d ×2（TIMG2COL 契约）、gng_1d ×2 + rms_norm ×2 + split_r ×2（Tile not enough）、group_token_old_mt / group_token_vec_mt / view_copy half ×2（SyscallBarrier.cpp:1660 家族）
- **TIMEOUT**（900s 判据下的长负载，前轮已证明多数能过只是慢）：matmul M512（需 ~1578s）、matmul mt ×2（需 ~3h）、quant_batch ×2（需 ~1100-2000s）、gather_v2 ×3、qli Skv8192、view_copy int32
- 若放宽到 2400s：预计 41 + 3（M512、quant_batch ×2）= **44 DONE / 73 = 60%**

## 4. 结论与行动建议

1. **gfrun 面**：唯一真伤仍是 gather_v2/view_copy 的 MGATHER/MSCATHER 通路回归（09-14 起，6 例）——继续推动 SSM 修复；
2. **gfsim 面**：09-28 报的 group_norm_grad SyscallBarrier 回归**已被上游修复**；新出现 moe_dispatch_mt_dyn BFU 断言（SNB #198 新内核 × gfsim BFU 缺口），建议报 SSM issue（附 A/B 证据：旧内核同 gfsim 可过）；
3. mega_moe_sim_mt 从快败转慢挂，建议下轮单独跟进；
4. 长负载（matmul mt/quant_batch）建议报告 runner 放宽超时或单列。

## 5. 产物

- 本目录：REPORT.md、logs/（逐 ELF gfrun_*/gfsim_* 日志、sweep_*.txt、编译日志、A/B 日志 gfsim_moe_mt_dyn_OLDkernel.log）、bin/（compile_all_serial.sh、sweep.sh）
- 同步副本：`/mnt/workspace/CANNBOT/CODE/OUTPUT/sol_verify_20260930_full/`
