# 监控账号未关闭 Issue 报告

- 生成时间：2026-10-02T17:27:36+08:00
- 时区：Asia/Shanghai
- 监控账号：18
- 目标仓库：5
- 匹配的未关闭 Issue：38

## 汇总

| 类型 | 仓库 | 未关闭 Issue | 查询状态 |
| --- | --- | ---: | --- |
| spec | [PTO-ISA/pto-spec](https://github.com/PTO-ISA/pto-spec) | 0 | 成功 |
| benchmark | [PTO-ISA/SuperNPUBench](https://github.com/PTO-ISA/SuperNPUBench) | 7 | 成功 |
| compiler | [LinxISA/llvm-project](https://github.com/LinxISA/llvm-project) | 2 | 成功 |
| compiler | [LinxISA/Linx-TileOP-API](https://github.com/LinxISA/Linx-TileOP-API) | 2 | 成功 |
| model | [LinxISA/SuperScalarModel](https://github.com/LinxISA/SuperScalarModel) | 27 | 成功 |

## PTO-ISA/pto-spec

没有匹配监控账号的未关闭 Issue。

## PTO-ISA/SuperNPUBench

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#199](https://github.com/PTO-ISA/SuperNPUBench/issues/199) | 王宇 (`wangyuascend-spec`) | [quant_batch_matmul][mxfp4] 单 PE M8192 用例编译失败：Local MX ScaleA 需 CUBE_M32 layout，kernel 仍为 RowMajor | 2026-09-29 03:41:43 UTC | 2026-09-29 10:12:26 UTC | - |
| [#115](https://github.com/PTO-ISA/SuperNPUBench/issues/115) | 王宇 (`wangyuascend-spec`) | [matmul][gfrun] 全量验证 ops-20260904:shared 系 6 例 cooperative TMATMUL 输出全 NaN + FP4 packed 全错 + 13 例 CUBE 契约编译失败 | 2026-09-07 10:49:34 UTC | 2026-09-29 09:51:20 UTC | - |
| [#92](https://github.com/PTO-ISA/SuperNPUBench/issues/92) | 贾婷婷 (`Simona787`) | `HiF4_HiF4.cpp` 在新 TileOP API 下全部四条编译路径失败，内部实现其实是mxfp4，并非hif4, 文件名有误导性 | 2026-08-29 02:27:39 UTC | 2026-09-29 09:51:18 UTC | - |
| [#117](https://github.com/PTO-ISA/SuperNPUBench/issues/117) | 王宇 (`wangyuascend-spec`) | [CI][matmul] Dynamic MASK matmul fails to compile with current TMATMUL shape contract | 2026-09-08 08:10:49 UTC | 2026-09-29 09:51:17 UTC | - |
| [#132](https://github.com/PTO-ISA/SuperNPUBench/issues/132) | 王宇 (`wangyuascend-spec`) | [gfsim][normalization] group_norm_grad_static 4PE Real-L2 deadlock | 2026-09-13 09:13:03 UTC | 2026-09-28 13:23:51 UTC | - |
| [#66](https://github.com/PTO-ISA/SuperNPUBench/issues/66) | 王宇 (`wangyuascend-spec`) | [bb91c18e] rms_norm / rms_norm_static gfrun 秒级 FAIL：TCVT src/dst logical shape 断言 | 2026-08-18 06:25:39 UTC | 2026-08-18 06:25:39 UTC | - |
| [#48](https://github.com/PTO-ISA/SuperNPUBench/issues/48) | 程子杨 (`ziyang-cheng`) | （release_ver0812）：dynamic_mx_quant 3 处 toolchain/emulator 缺陷 | 2026-08-13 01:44:33 UTC | 2026-08-14 05:45:35 UTC | - |

## LinxISA/llvm-project

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#52](https://github.com/LinxISA/llvm-project/issues/52) | 程子杨 (`ziyang-cheng`) | dynamic_mx_quant 调试过程中触发问题：`B.IOT ... ->u<>` unknown operand、`-O0` 溢出/重载寄存器类不对称，`layout_type_to_str` 崩溃、tile 参数经 `TSTORE/TLOAD, S64` 栈传参，被 emulator `ValidateLocalTlsu` 拒绝 | 2026-08-15 02:46:34 UTC | 2026-09-30 03:39:29 UTC | - |
| [#116](https://github.com/LinxISA/llvm-project/issues/116) | 王宇 (`wangyuascend-spec`) | LinxV5: support Core4 barrier SYNCALL<core_scope> (FENCE.D.CORE4) for cross-PE GM read-after-write | 2026-09-29 10:55:10 UTC | 2026-09-30 01:55:59 UTC | - |

## LinxISA/Linx-TileOP-API

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#246](https://github.com/LinxISA/Linx-TileOP-API/issues/246) | 陈毅然 (`CYR-Firework`) | [Compiler][TMOV] Illegal Local TMOV keep-alive generated when tiles stay resident across a runtime block loop (blocks O/Q tile residency in flash-attention-style kernels) | 2026-09-29 08:05:54 UTC | 2026-09-30 09:27:57 UTC | - |
| [#166](https://github.com/LinxISA/Linx-TileOP-API/issues/166) | 王宇 (`wangyuascend-spec`) | [TROWSUM] Assemble parent valid shape 与后续 consumer B.DIM 不一致，缺 bounded source view/shape propagation | 2026-09-17 15:02:30 UTC | 2026-09-30 01:44:33 UTC | bug |

## LinxISA/SuperScalarModel

| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |
| ---: | --- | --- | --- | --- | --- |
| [#793](https://github.com/LinxISA/SuperScalarModel/issues/793) | 程子杨 (`ziyang-cheng`) | [gfsim][OEX] `C.BSTART.STD COND` 内存标志自旋等待块在 gfsim 上永不退出：BROB 无限 retire → 挂死/超时（gfrun 正常终止） | 2026-09-21 13:26:27 UTC | 2026-10-02 08:41:10 UTC | - |
| [#894](https://github.com/LinxISA/SuperScalarModel/issues/894) | 王宇 (`wangyuascend-spec`) | [gfrun][gfsim] 支持 ISA v0.2 Core4 屏障 SYNCALL<core_scope>（FENCE.D.CORE4）：解码 FenceMode=1 + 4PE 汇合，保证跨 PE GM 写后读 | 2026-09-29 10:55:12 UTC | 2026-10-02 07:02:16 UTC | invalid-title |
| [#890](https://github.com/LinxISA/SuperScalarModel/issues/890) | 王宇 (`wangyuascend-spec`) | [gfsim][PERF] SuperNPUBench solution 7 个大用例 gfsim 30 分钟跑不完（非挂死，4PE 约 600–1000 cycle/s），附进度/预计耗时清单 | 2026-09-29 06:17:41 UTC | 2026-10-02 07:02:15 UTC | 新增模块 |
| [#889](https://github.com/LinxISA/SuperScalarModel/issues/889) | 王宇 (`wangyuascend-spec`) | [gfsim][IFU] moe_combine_mt_dyn 在 main 47df5876 上 BFU 断言 GetLocalPipeID "Can't find occupied local pipe by globlal fbid"（0688ed22 不复现，疑似 d1baf3ef 回归） | 2026-09-29 06:16:26 UTC | 2026-10-02 07:02:12 UTC | - |
| [#888](https://github.com/LinxISA/SuperScalarModel/issues/888) | 王宇 (`wangyuascend-spec`) | [gfsim][GROUP] fourpe 下 worker 先到 _end exit_group 被 lockstep hold 后，其余线程停止退休 → syscall_lockstep_and_timeout（13 例，47df5876 仍复现） | 2026-09-29 06:16:05 UTC | 2026-10-02 07:02:10 UTC | - |
| [#886](https://github.com/LinxISA/SuperScalarModel/issues/886) | 王宇 (`wangyuascend-spec`) | [gfsim][IFU] conv2d TIMG2COL 块在 gfsim 断言：HandleUInstBIOR 未填 biorRecords；补上后 TLSU 又不支持 OIHW2NK layout | 2026-09-29 03:57:29 UTC | 2026-10-02 07:02:09 UTC | - |
| [#880](https://github.com/LinxISA/SuperScalarModel/issues/880) | 张新宇 (`Cell-Cell`) | [gfsim][TLSU] 首条 tile 请求被 L2 prior 绝对优先派发静默饿死（gtv_mt_dyn/mega_mt_dyn 冻结）+ SetACC 重放断言 | 2026-09-28 13:12:04 UTC | 2026-10-02 07:02:07 UTC | - |
| [#804](https://github.com/LinxISA/SuperScalarModel/issues/804) | 王宇 (`wangyuascend-spec`) | [gfsim][CELLREG] normalization 三类用例在 RenameSingleTileDst 因 Tile 寄存器不足终止 | 2026-09-22 03:41:31 UTC | 2026-10-02 07:02:05 UTC | - |
| [#776](https://github.com/LinxISA/SuperScalarModel/issues/776) | 王宇 (`wangyuascend-spec`) | [gfrun][NA] CUBE M-format TCVT CELL descriptor check rejects all CubeM32-migrated normalization kernels (10 solution-tree FAILs) | 2026-09-20 14:09:10 UTC | 2026-10-02 07:02:02 UTC | - |
| [#774](https://github.com/LinxISA/SuperScalarModel/issues/774) | 王宇 (`wangyuascend-spec`) | [gfsim][VECTOR] main + PR764 下 RMS Norm M32 Tree/SIMT 仍触发 scalar-numeric 描述符断言（跟进 #760） | 2026-09-20 11:04:36 UTC | 2026-10-02 07:02:01 UTC | - |
| [#740](https://github.com/LinxISA/SuperScalarModel/issues/740) | 王宇 (`wangyuascend-spec`) | [gfrun][NA] 合法动态 TCOLEXPAND [1,1]→[32,1] 被误判缺少 ValidCol/LB0 | 2026-09-18 16:32:15 UTC | 2026-10-02 07:01:59 UTC | - |
| [#714](https://github.com/LinxISA/SuperScalarModel/issues/714) | 王宇 (`wangyuascend-spec`) | [gfsim][OEX] dynamic RMS Norm R-tree 触发不支持的 B.PARAMETER | 2026-09-17 07:51:14 UTC | 2026-10-02 07:01:57 UTC | - |
| [#478](https://github.com/LinxISA/SuperScalarModel/issues/478) | 程子杨 (`ziyang-cheng`) | [gfrun][NA] 模型未实现/契约拒绝：TIMG2COL / TMRGSORT / TileArray region / range::Subview（看护 4 项） | 2026-09-02 02:57:12 UTC | 2026-10-02 07:01:55 UTC | - |
| [#433](https://github.com/LinxISA/SuperScalarModel/issues/433) | 张新宇 (`Cell-Cell`) | [gfsim][GROUP] SMT4 无法仿真 4-PE SPMD barrier 算子：跨 PE volatile 自旋标志不可见（纯 barrier 最小复现挂起）+ RAS spec_table 断言崩溃 + leader 退出/park 终止语义缺失 | 2026-08-31 05:13:24 UTC | 2026-10-02 07:01:53 UTC | - |
| [#323](https://github.com/LinxISA/SuperScalarModel/issues/323) | 程龙宇 (`luguo23187`) | [gfsim][SL2] L1D Prior Write 缺少 Data Slot 反压导致 gfsim 崩溃 | 2026-08-21 08:05:05 UTC | 2026-10-02 07:01:52 UTC | - |
| [#211](https://github.com/LinxISA/SuperScalarModel/issues/211) | 芦葳 (`luwei512`) | Coalesce::Row is not suppored for MGATHER | 2026-08-14 08:36:27 UTC | 2026-10-02 07:01:50 UTC | bug |
| [#149](https://github.com/LinxISA/SuperScalarModel/issues/149) | 程龙宇 (`luguo23187`) | 使用 HIFLOAT8 时编译器后端断言 | 2026-08-11 06:57:47 UTC | 2026-10-02 07:01:49 UTC | - |
| [#891](https://github.com/LinxISA/SuperScalarModel/issues/891) | 贾婷婷 (`Simona787`) | [gfsim][CUBE] gfsim tN=256 时 4-PE GMMA hif4 lockstep 失步死锁（SharedTReg rename FIFO 循环依赖） | 2026-09-29 07:17:59 UTC | 2026-09-29 07:17:59 UTC | - |
| [#605](https://github.com/LinxISA/SuperScalarModel/issues/605) | 程子杨 (`ziyang-cheng`) | [gfsim][VECTOR] TROWEXPAND 广播源被限制为「单个 128B CELL」，与 pto-spec 冲突 → 广播源 >128B 的 kernel 时序仿真 abort | 2026-09-09 06:40:13 UTC | 2026-09-29 06:19:00 UTC | - |
| [#876](https://github.com/LinxISA/SuperScalarModel/issues/876) | 陈毅然 (`CYR-Firework`) | [gfsim][TLSU] Cooperative tile-op completion fan-out covers only 1 of 4 stids: shared-instId MGATHER leaves three threads LIQ entries waiting forever (QSMLA csa_small 4-PE, full -t 1 trace) | 2026-09-28 04:46:25 UTC | 2026-09-28 07:22:28 UTC | - |
| [#769](https://github.com/LinxISA/SuperScalarModel/issues/769) | 贾婷婷 (`Simona787`) | [gfrun][NA] 单 PE (Local) MX scale tile 的 layout 在 ISA 编译期与 gfrun 运行期要求不一致 | 2026-09-20 09:15:52 UTC | 2026-09-23 09:59:22 UTC | - |
| [#801](https://github.com/LinxISA/SuperScalarModel/issues/801) | 陈毅然 (`CYR-Firework`) | [gfsim][TLSU] Split-store halves refused by a full STQ are dropped forever: STA/STD pipes are fire-and-forget, the twin STQ entry deadlocks the in-order drain (QSMLA 4-PE) | 2026-09-22 02:25:25 UTC | 2026-09-22 02:25:25 UTC | - |
| [#720](https://github.com/LinxISA/SuperScalarModel/issues/720) | 王宇 (`wangyuascend-spec`) | [gfrun][NA] TileOP #164 生成的 B.ASSEMBLE descriptor 被 gfrun 拒绝 | 2026-09-17 09:29:07 UTC | 2026-09-19 15:40:55 UTC | - |
| [#644](https://github.com/LinxISA/SuperScalarModel/issues/644) | 王宇 (`wangyuascend-spec`) | [gfrun][NA] Diagnose GroupNormGrad1D TLOAD descriptor preflight failure | 2026-09-12 09:53:12 UTC | 2026-09-14 01:36:20 UTC | - |
| [#622](https://github.com/LinxISA/SuperScalarModel/issues/622) | 王宇 (`wangyuascend-spec`) | [gfsim][VECTOR] rms_norm_binary 动态 4PE real L2 下 TROWSUM 输出不 ready 导致 deadlock | 2026-09-10 08:29:20 UTC | 2026-09-10 12:04:01 UTC | - |
| [#327](https://github.com/LinxISA/SuperScalarModel/issues/327) | 王宇 (`wangyuascend-spec`) | [gfsim][TLSU] four-PE rms_norm DATR-less TMOV deadlock | 2026-08-21 15:43:53 UTC | 2026-09-08 08:11:16 UTC | - |
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
