# 监控账号未关闭 Issue 报告

- 生成时间：2026-10-09T08:13:17+08:00
- 时区：Asia/Shanghai
- 监控账号：18
- 目标仓库：5
- 匹配的未关闭 Issue：23

## 汇总

| 类型 | 仓库 | 未关闭 Issue | 查询状态 |
| --- | --- | ---: | --- |
| spec | [PTO-ISA/pto-spec](https://github.com/PTO-ISA/pto-spec) | 0 | 成功 |
| benchmark | [PTO-ISA/SuperNPUBench](https://github.com/PTO-ISA/SuperNPUBench) | 3 | 成功 |
| compiler | [LinxISA/llvm-project](https://github.com/LinxISA/llvm-project) | 1 | 成功 |
| compiler | [LinxISA/Linx-TileOP-API](https://github.com/LinxISA/Linx-TileOP-API) | 3 | 成功 |
| model | [LinxISA/SuperScalarModel](https://github.com/LinxISA/SuperScalarModel) | 16 | 成功 |

## PTO-ISA/pto-spec

没有匹配监控账号的未关闭 Issue。

## PTO-ISA/SuperNPUBench

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#132](https://github.com/PTO-ISA/SuperNPUBench/issues/132) | 王宇 (`wangyuascend-spec`) | [gfsim][normalization] group_norm_grad_static 4PE Real-L2 deadlock | 2026-09-13 09:13:03 UTC | 2026-10-08 13:31:40 UTC | - |
| [#199](https://github.com/PTO-ISA/SuperNPUBench/issues/199) | 王宇 (`wangyuascend-spec`) | [quant_batch_matmul][mxfp4] 单 PE M8192 用例编译失败：Local MX ScaleA 需 CUBE_M32 layout，kernel 仍为 RowMajor | 2026-09-29 03:41:43 UTC | 2026-09-29 10:12:26 UTC | - |
| [#115](https://github.com/PTO-ISA/SuperNPUBench/issues/115) | 王宇 (`wangyuascend-spec`) | [matmul][gfrun] 全量验证 ops-20260904:shared 系 6 例 cooperative TMATMUL 输出全 NaN + FP4 packed 全错 + 13 例 CUBE 契约编译失败 | 2026-09-07 10:49:34 UTC | 2026-09-29 09:51:20 UTC | - |

## LinxISA/llvm-project

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#116](https://github.com/LinxISA/llvm-project/issues/116) | 王宇 (`wangyuascend-spec`) | LinxV5: support Core4 barrier SYNCALL<core_scope> (FENCE.D.CORE4) for cross-PE GM read-after-write | 2026-09-29 10:55:10 UTC | 2026-09-30 01:55:59 UTC | - |

## LinxISA/Linx-TileOP-API

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#246](https://github.com/LinxISA/Linx-TileOP-API/issues/246) | 陈毅然 (`CYR-Firework`) | [Compiler][TMOV] Illegal Local TMOV keep-alive generated when tiles stay resident across a runtime block loop (blocks O/Q tile residency in flash-attention-style kernels) | 2026-09-29 08:05:54 UTC | 2026-10-08 12:26:38 UTC | - |
| [#250](https://github.com/LinxISA/Linx-TileOP-API/issues/250) | 陈毅然 (`CYR-Firework`) | [Compiler][Correctness] Tile declared outside an if/else whose both arms write it is silently corrupted - run completes R2=0 but the dump mismatches | 2026-10-08 03:14:26 UTC | 2026-10-08 08:41:58 UTC | - |
| [#166](https://github.com/LinxISA/Linx-TileOP-API/issues/166) | 王宇 (`wangyuascend-spec`) | [TROWSUM] Assemble parent valid shape 与后续 consumer B.DIM 不一致，缺 bounded source view/shape propagation | 2026-09-17 15:02:30 UTC | 2026-09-30 01:44:33 UTC | bug |

## LinxISA/SuperScalarModel

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#888](https://github.com/LinxISA/SuperScalarModel/issues/888) | 王宇 (`wangyuascend-spec`) | [gfsim][GROUP] fourpe 下 worker 先到 _end exit_group 被 lockstep hold 后，其余线程停止退休 → syscall_lockstep_and_timeout（13 例，47df5876 仍复现） | 2026-09-29 06:16:05 UTC | 2026-10-08 13:02:20 UTC | - |
| [#793](https://github.com/LinxISA/SuperScalarModel/issues/793) | 程子杨 (`ziyang-cheng`) | [gfsim][OEX] `C.BSTART.STD COND` 内存标志自旋等待块在 gfsim 上永不退出：BROB 无限 retire → 挂死/超时（gfrun 正常终止） | 2026-09-21 13:26:27 UTC | 2026-10-08 13:02:03 UTC | - |
| [#891](https://github.com/LinxISA/SuperScalarModel/issues/891) | 贾婷婷 (`Simona787`) | [gfsim][CUBE] gfsim tN=256 时 4-PE GMMA hif4 lockstep 失步死锁（SharedTReg rename FIFO 循环依赖） | 2026-09-29 07:17:59 UTC | 2026-10-08 09:30:24 UTC | - |
| [#327](https://github.com/LinxISA/SuperScalarModel/issues/327) | 王宇 (`wangyuascend-spec`) | [gfsim][TLSU] four-PE rms_norm DATR-less TMOV deadlock | 2026-08-21 15:43:53 UTC | 2026-10-08 03:36:40 UTC | - |
| [#644](https://github.com/LinxISA/SuperScalarModel/issues/644) | 王宇 (`wangyuascend-spec`) | [gfrun][NA] Diagnose GroupNormGrad1D TLOAD descriptor preflight failure | 2026-09-12 09:53:12 UTC | 2026-10-08 03:36:39 UTC | - |
| [#801](https://github.com/LinxISA/SuperScalarModel/issues/801) | 陈毅然 (`CYR-Firework`) | [gfsim][TLSU] Split-store halves refused by a full STQ are dropped forever: STA/STD pipes are fire-and-forget, the twin STQ entry deadlocks the in-order drain (QSMLA 4-PE) | 2026-09-22 02:25:25 UTC | 2026-10-08 03:36:38 UTC | - |
| [#605](https://github.com/LinxISA/SuperScalarModel/issues/605) | 程子杨 (`ziyang-cheng`) | [gfsim][VECTOR] TROWEXPAND 广播源被限制为「单个 128B CELL」，与 pto-spec 冲突 → 广播源 >128B 的 kernel 时序仿真 abort | 2026-09-09 06:40:13 UTC | 2026-10-08 03:36:38 UTC | - |
| [#433](https://github.com/LinxISA/SuperScalarModel/issues/433) | 张新宇 (`Cell-Cell`) | [gfsim][GROUP] SMT4 无法仿真 4-PE SPMD barrier 算子：跨 PE volatile 自旋标志不可见（纯 barrier 最小复现挂起）+ RAS spec_table 断言崩溃 + leader 退出/park 终止语义缺失 | 2026-08-31 05:13:24 UTC | 2026-10-08 03:36:36 UTC | - |
| [#876](https://github.com/LinxISA/SuperScalarModel/issues/876) | 陈毅然 (`CYR-Firework`) | [gfsim][TLSU] Cooperative tile-op completion fan-out covers only 1 of 4 stids: shared-instId MGATHER leaves three threads LIQ entries waiting forever (QSMLA csa_small 4-PE, full -t 1 trace) | 2026-09-28 04:46:25 UTC | 2026-10-08 02:31:46 UTC | - |
| [#915](https://github.com/LinxISA/SuperScalarModel/issues/915) | 张旭波 (`KeepTryingTo`) | [gfsim][GROUP] lockstep 早退、TLSU 内存不可见、nuke flush 状态丢失、掩码 tile store 泄漏及跨 PE 并发数据缺口，解决 gmov 挂死、单引擎停摆与输出全零等问题。 | 2026-10-08 02:21:01 UTC | 2026-10-08 02:21:01 UTC | - |
| [#880](https://github.com/LinxISA/SuperScalarModel/issues/880) | 张新宇 (`Cell-Cell`) | [gfsim][TLSU] 首条 tile 请求被 L2 prior 绝对优先派发静默饿死（gtv_mt_dyn/mega_mt_dyn 冻结）+ SetACC 重放断言 | 2026-09-28 13:12:04 UTC | 2026-10-06 07:17:22 UTC | - |
| [#894](https://github.com/LinxISA/SuperScalarModel/issues/894) | 王宇 (`wangyuascend-spec`) | [gfrun][gfsim] 支持 ISA v0.2 Core4 屏障 SYNCALL<core_scope>（FENCE.D.CORE4）：解码 FenceMode=1 + 4PE 汇合，保证跨 PE GM 写后读 | 2026-09-29 10:55:12 UTC | 2026-10-02 07:02:16 UTC | invalid-title |
| [#890](https://github.com/LinxISA/SuperScalarModel/issues/890) | 王宇 (`wangyuascend-spec`) | [gfsim][PERF] SuperNPUBench solution 7 个大用例 gfsim 30 分钟跑不完（非挂死，4PE 约 600–1000 cycle/s），附进度/预计耗时清单 | 2026-09-29 06:17:41 UTC | 2026-10-02 07:02:15 UTC | 新增模块 |
| [#886](https://github.com/LinxISA/SuperScalarModel/issues/886) | 王宇 (`wangyuascend-spec`) | [gfsim][IFU] conv2d TIMG2COL 块在 gfsim 断言：HandleUInstBIOR 未填 biorRecords；补上后 TLSU 又不支持 OIHW2NK layout | 2026-09-29 03:57:29 UTC | 2026-10-02 07:02:09 UTC | - |
| [#804](https://github.com/LinxISA/SuperScalarModel/issues/804) | 王宇 (`wangyuascend-spec`) | [gfsim][CELLREG] normalization 三类用例在 RenameSingleTileDst 因 Tile 寄存器不足终止 | 2026-09-22 03:41:31 UTC | 2026-10-02 07:02:05 UTC | - |
| [#311](https://github.com/LinxISA/SuperScalarModel/issues/311) | 王宇 (`wangyuascend-spec`) | [rms_norm_binary] dyn 场景：Local tile cache 在 gfsim Deadlock；关联 ctzll/SWAR 与精度坑 | 2026-08-21 00:58:12 UTC | 2026-08-21 07:00:38 UTC | - |

## 监控账号

- 杨继伟 — [`joey-jwyang`](https://github.com/joey-jwyang)
- 常磊 — [`gagahamburger`](https://github.com/gagahamburger)
- 程龙宇 — [`luguo23187`](https://github.com/luguo23187)
- 程子杨 — [`ziyang-cheng`](https://github.com/ziyang-cheng)
- 蒋礼锐 — [`JiangLirui`](https://github.com/JiangLirui)
- 林鹏翔 — [`ordinarylpx`](https://github.com/ordinarylpx)
- 刘志涵 — [`robot-inteligence`](https://github.com/robot-inteligence)
- 芦葳 — [`luwei512`](https://github.com/luwei512)
- 唐浩 — [`HaoTang99`](https://github.com/HaoTang99)
- 王宇 — [`wangyuascend-spec`](https://github.com/wangyuascend-spec)
- 王哲 — [`ZWANG987`](https://github.com/ZWANG987)
- 杨彬榕 — [`yangbinrong`](https://github.com/yangbinrong)
- 张耀辉 — [`zzzyh222`](https://github.com/zzzyh222)
- 赵颖超 — [`zhaoyingchao88`](https://github.com/zhaoyingchao88)
- 张新宇 — [`Cell-Cell`](https://github.com/Cell-Cell)
- 张旭波 — [`KeepTryingTo`](https://github.com/KeepTryingTo)
- 陈毅然 — [`CYR-Firework`](https://github.com/CYR-Firework)
- 贾婷婷 — [`Simona787`](https://github.com/Simona787)
