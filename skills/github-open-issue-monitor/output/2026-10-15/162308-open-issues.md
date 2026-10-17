# 监控账号未关闭 Issue 报告

- 生成时间：2026-10-15T16:23:08+08:00
- 时区：Asia/Shanghai
- 监控账号：18
- 目标仓库：5
- 匹配的未关闭 Issue：29

## 汇总

| 类型 | 仓库 | 未关闭 Issue | 查询状态 |
| --- | --- | ---: | --- |
| spec | [PTO-ISA/pto-spec](https://github.com/PTO-ISA/pto-spec) | 0 | 成功 |
| benchmark | [PTO-ISA/SuperNPUBench](https://github.com/PTO-ISA/SuperNPUBench) | 5 | 成功 |
| compiler | [LinxISA/llvm-project](https://github.com/LinxISA/llvm-project) | 1 | 成功 |
| compiler | [LinxISA/Linx-TileOP-API](https://github.com/LinxISA/Linx-TileOP-API) | 2 | 成功 |
| model | [LinxISA/SuperScalarModel](https://github.com/LinxISA/SuperScalarModel) | 21 | 成功 |

## PTO-ISA/pto-spec

没有匹配监控账号的未关闭 Issue。

## PTO-ISA/SuperNPUBench

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#238](https://github.com/PTO-ISA/SuperNPUBench/issues/238) | 林鹏翔 (`ordinarylpx`) | matmul_test M120 Cube 气泡——TLSU 搬运带宽不足 + tN=256 受 internal_acc 条目数限制 | 2026-10-13 13:56:59 UTC | 2026-10-15 06:37:27 UTC | - |
| [#240](https://github.com/PTO-ISA/SuperNPUBench/issues/240) | 林鹏翔 (`ordinarylpx`) | Matmul BF16场景基本块设置(128, 256)会出现模型报错 | 2026-10-14 02:09:39 UTC | 2026-10-14 02:09:39 UTC | - |
| [#132](https://github.com/PTO-ISA/SuperNPUBench/issues/132) | 王宇 (`wangyuascend-spec`) | [gfsim][normalization] group_norm_grad_static 4PE Real-L2 deadlock | 2026-09-13 09:13:03 UTC | 2026-10-09 00:54:30 UTC | - |
| [#199](https://github.com/PTO-ISA/SuperNPUBench/issues/199) | 王宇 (`wangyuascend-spec`) | [quant_batch_matmul][mxfp4] 单 PE M8192 用例编译失败：Local MX ScaleA 需 CUBE_M32 layout，kernel 仍为 RowMajor | 2026-09-29 03:41:43 UTC | 2026-09-29 10:12:26 UTC | - |
| [#115](https://github.com/PTO-ISA/SuperNPUBench/issues/115) | 王宇 (`wangyuascend-spec`) | [matmul][gfrun] 全量验证 ops-20260904:shared 系 6 例 cooperative TMATMUL 输出全 NaN + FP4 packed 全错 + 13 例 CUBE 契约编译失败 | 2026-09-07 10:49:34 UTC | 2026-09-29 09:51:20 UTC | - |

## LinxISA/llvm-project

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#116](https://github.com/LinxISA/llvm-project/issues/116) | 王宇 (`wangyuascend-spec`) | LinxV5: support Core4 barrier SYNCALL<core_scope> (FENCE.D.CORE4) for cross-PE GM read-after-write | 2026-09-29 10:55:10 UTC | 2026-09-30 01:55:59 UTC | - |

## LinxISA/Linx-TileOP-API

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#262](https://github.com/LinxISA/Linx-TileOP-API/issues/262) | 程子杨 (`ziyang-cheng`) | [Linx-TileOP-API] PR #248 起 pto_region_unary 引用 Tile 类不存在的 PhysicalCol 成员（实际定义在 SubTileView 上），自带测试 TileRegionCubeSubview（compile.all 默认清单内）编译失败，TPARTVIEW 切片 + TROWMAX/TROWSUM/TEXP/TROWMIN 全部堵死 | 2026-10-13 07:17:27 UTC | 2026-10-13 07:17:27 UTC | - |
| [#166](https://github.com/LinxISA/Linx-TileOP-API/issues/166) | 王宇 (`wangyuascend-spec`) | [TROWSUM] Assemble parent valid shape 与后续 consumer B.DIM 不一致，缺 bounded source view/shape propagation | 2026-09-17 15:02:30 UTC | 2026-09-30 01:44:33 UTC | bug |

## LinxISA/SuperScalarModel

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#979](https://github.com/LinxISA/SuperScalarModel/issues/979) | 程子杨 (`ziyang-cheng`) | [gfrun][NA] TROWEXPAND 族不解码 B.DATR.RMode 的 BroadcastByteOffset（规范 normative 字段）——CUBE 打包 CELL 广播恒读列 0，奇数槽拿错系数，静默错值无断言 | 2026-10-14 09:32:23 UTC | 2026-10-14 09:34:33 UTC | - |
| [#971](https://github.com/LinxISA/SuperScalarModel/issues/971) | 程子杨 (`ziyang-cheng`) | [gfsim][CELLREG] tile size-class 分配器路径 FreeSingleFreeEntry producerCnt 下溢断言：TileN=128 宽 tile kernel gfsim abort（tile_size_class_enable=false 即跑通，80,923 cycles） | 2026-10-13 09:17:14 UTC | 2026-10-14 08:54:12 UTC | - |
| [#968](https://github.com/LinxISA/SuperScalarModel/issues/968) | 程子杨 (`ziyang-cheng`) | [gfsim][TLSU] TASSEMBLE 组装 parent 的消费路径未闭合：TSTORE 组装 parent 默认配置崩 l2_agu.cpp:251 entry.col >= entry.validCol；开 assemble_enable 改崩 GetProducerTag mapQ 断言 | 2026-10-13 08:12:43 UTC | 2026-10-14 08:54:10 UTC | - |
| [#644](https://github.com/LinxISA/SuperScalarModel/issues/644) | 王宇 (`wangyuascend-spec`) | [gfrun][NA] Diagnose GroupNormGrad1D TLOAD descriptor preflight failure | 2026-09-12 09:53:12 UTC | 2026-10-13 16:56:24 UTC | - |
| [#894](https://github.com/LinxISA/SuperScalarModel/issues/894) | 王宇 (`wangyuascend-spec`) | [gfrun][gfsim] 支持 ISA v0.2 Core4 屏障 SYNCALL<core_scope>（FENCE.D.CORE4）：解码 FenceMode=1 + 4PE 汇合，保证跨 PE GM 写后读 | 2026-09-29 10:55:12 UTC | 2026-10-13 16:55:14 UTC | invalid-title |
| [#963](https://github.com/LinxISA/SuperScalarModel/issues/963) | 王宇 (`wangyuascend-spec`) | [gfrun][SSR] THREAD_ID 0x0026 is unimplemented: four-PE threads read zero; gfsim has the same handling gap | 2026-10-13 01:51:58 UTC | 2026-10-13 16:54:55 UTC | invalid-title |
| [#945](https://github.com/LinxISA/SuperScalarModel/issues/945) | 陈毅然 (`CYR-Firework`) | [gfsim][TLSU] Tile-store data half never lands (dataRdy=0) with hazard-sleeping loads: csa deadlock stable across main versions, now also hits the Td=256 residency form | 2026-10-12 01:43:00 UTC | 2026-10-12 14:17:39 UTC | - |
| [#929](https://github.com/LinxISA/SuperScalarModel/issues/929) | 陈毅然 (`CYR-Firework`) | [gfsim][GROUP] 4-PE Shared TLOAD (GMMA_LD) collective-completion deadlock: one thread allocated, three completed-but-not-committed in circular wait (repro: QSMLA v3 CSA / fa_gmma_dynamic) | 2026-10-10 02:55:06 UTC | 2026-10-12 09:03:04 UTC | - |
| [#930](https://github.com/LinxISA/SuperScalarModel/issues/930) | 陈毅然 (`CYR-Firework`) | [gfsim][TLSU] Local TMOV keep-alive for cross-back-edge tiles is emitted illegal: Shared-binder TMOV and generation size-mismatch (srcSize != dstSize) both trip 'Local TMOV requires one matching source and destination Tile' | 2026-10-10 03:26:34 UTC | 2026-10-12 08:57:03 UTC | - |
| [#876](https://github.com/LinxISA/SuperScalarModel/issues/876) | 陈毅然 (`CYR-Firework`) | [gfsim][TLSU] Cooperative tile-op completion fan-out covers only 1 of 4 stids: shared-instId MGATHER leaves three threads LIQ entries waiting forever (QSMLA csa_small 4-PE, full -t 1 trace) | 2026-09-28 04:46:25 UTC | 2026-10-10 03:45:14 UTC | - |
| [#801](https://github.com/LinxISA/SuperScalarModel/issues/801) | 陈毅然 (`CYR-Firework`) | [gfsim][TLSU] Split-store halves refused by a full STQ are dropped forever: STA/STD pipes are fire-and-forget, the twin STQ entry deadlocks the in-order drain (QSMLA 4-PE) | 2026-09-22 02:25:25 UTC | 2026-10-10 03:45:13 UTC | - |
| [#793](https://github.com/LinxISA/SuperScalarModel/issues/793) | 程子杨 (`ziyang-cheng`) | [gfsim][OEX] `C.BSTART.STD COND` 内存标志自旋等待块在 gfsim 上永不退出：BROB 无限 retire → 挂死/超时（gfrun 正常终止） | 2026-09-21 13:26:27 UTC | 2026-10-08 13:02:03 UTC | - |
| [#891](https://github.com/LinxISA/SuperScalarModel/issues/891) | 贾婷婷 (`Simona787`) | [gfsim][CUBE] gfsim tN=256 时 4-PE GMMA hif4 lockstep 失步死锁（SharedTReg rename FIFO 循环依赖） | 2026-09-29 07:17:59 UTC | 2026-10-08 09:30:24 UTC | - |
| [#327](https://github.com/LinxISA/SuperScalarModel/issues/327) | 王宇 (`wangyuascend-spec`) | [gfsim][TLSU] four-PE rms_norm DATR-less TMOV deadlock | 2026-08-21 15:43:53 UTC | 2026-10-08 03:36:40 UTC | - |
| [#433](https://github.com/LinxISA/SuperScalarModel/issues/433) | 张新宇 (`Cell-Cell`) | [gfsim][GROUP] SMT4 无法仿真 4-PE SPMD barrier 算子：跨 PE volatile 自旋标志不可见（纯 barrier 最小复现挂起）+ RAS spec_table 断言崩溃 + leader 退出/park 终止语义缺失 | 2026-08-31 05:13:24 UTC | 2026-10-08 03:36:36 UTC | - |
| [#915](https://github.com/LinxISA/SuperScalarModel/issues/915) | 张旭波 (`KeepTryingTo`) | [gfsim][GROUP] lockstep 早退、TLSU 内存不可见、nuke flush 状态丢失、掩码 tile store 泄漏及跨 PE 并发数据缺口，解决 gmov 挂死、单引擎停摆与输出全零等问题。 | 2026-10-08 02:21:01 UTC | 2026-10-08 02:21:01 UTC | - |
| [#880](https://github.com/LinxISA/SuperScalarModel/issues/880) | 张新宇 (`Cell-Cell`) | [gfsim][TLSU] 首条 tile 请求被 L2 prior 绝对优先派发静默饿死（gtv_mt_dyn/mega_mt_dyn 冻结）+ SetACC 重放断言 | 2026-09-28 13:12:04 UTC | 2026-10-06 07:17:22 UTC | - |
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
