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

## 5. 三周趋势（gfsim 900s 判据）

| 轮次 | SSM | DONE | 备注 |
|---|---|---|---|
| 09-28 | 0688ed22 | 35/73 | SyscallBarrier 回归出现 |
| 09-30 | 57378d2c | 41/73 | gng 回归修复；moe_dispatch_mt_dyn 新 CRASH |
| **10-08** | 96fdc684 | **43/67（64%）** | CRASH 清零、MoE/token 家族全修复；分母随归一化重构 -6 |

## 6. 行动建议

1. **gather_v2/view_copy 的 MGATHER 通路回归**（gfrun R2=1，09-14 起 6 例）——最高优先级，唯一"真算错"类问题，建议催 SSM；
2. mega_moe_sim_mt_dyn：#210 未覆盖，建议反馈；
3. view_copy half ×2 的 SyscallBarrier 适配、conv2d TIMG2COL 契约、gng_1d Tile 容量：既有开放项；
4. 长负载（matmul mt/quant_batch）建议报告 runner 分级超时。

## 7. 产物

- 本目录：REPORT.md、logs/（逐 ELF 双仿真日志、sweep 汇总、编译日志）、bin/（compile_all_serial.sh、sweep.sh）
- 同步副本：`/mnt/workspace/CANNBOT/CODE/OUTPUT/sol_verify_20261008_full/`
