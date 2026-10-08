# solution 树手工验证轮（snb-solution-verify）

人工触发的 `test/solution` 单算子树全量验证（排除 tileop-test）：三仓 latest → 串行编译 → gfrun + gfsim 双扫描（900s，4PE 按文件名判定）→ 与上一轮/官方日报告 diff。最新在最上。

| 时间 | 验证链（llvm/TileOP/SSM/SNB） | gfrun | gfsim | 报告 |
|---|---|---|---|---|
| 2026-10-08 | `62b878d6` / `12bd048` / `96fdc684` / `3bdba36` | 61 PASS / 6 SELFFAIL（67 ELF） | 43 DONE / 13 ASSERT / 11 TIMEOUT（64%，0 CRASH） | [报告](2026-10-08T1600+0800__solution-tree-full-verification.md) |
| 2026-09-30 | `61d4f98b` / `12bd048` / `57378d2c` / `a283194` | 67 PASS / 6 SELFFAIL（73 ELF） | 41 DONE / 19 ASSERT / 12 TIMEOUT / 1 CRASH | [报告](2026-09-30T1300+0800__solution-tree-full-verification.md) |
| 2026-09-28 | `af743c28` / `b2b16fa` / `0688ed22` / `5da6474`（+PTO 0.58.7 刷新附录） | 67 PASS / 6 SELFFAIL（73 ELF） | 35→39 DONE（2400s 判据） | [报告](2026-09-28T1500+0800__solution-tree-full-verification.md) |
| 2026-09-28 | conv2d 专项：COMPILE_FAIL 归因 TileOP #234 + A/B 实证 + 修复确认 | conv2d ×2 PASS | ×2 TIMG2COL 断言（已知） | [报告](2026-09-28T1030+0800__conv2d-compile-fix-verification.md) |

## 跨轮未解问题（截至 2026-10-08）

1. **gather_v2 ×3 + view_copy ×3：gfrun R2=1**——MGATHER/MSCATHER 通路 09-14 被 gfrun Shared-TMATMUL-layout 分支切换破坏（SNB README 记录在案），已挂 3.5 周，唯一"真算错"类问题；
2. conv2d ×2：gfsim TIMG2COL 操作数契约（Block.cpp，随版本行号漂移）；
3. gng_1d ×2：gfsim Tile 寄存器容量；
4. dmxq tail ×7：gfsim TROWEXPAND 广播源断言；
5. 长负载超时（900s 装不下，给足时间能过）：matmul M512（~1578s）/mt ×2（~3h）、quant_batch ×2（~20–35min）。

> 判据：gfrun PASS = `R2 = 0`；gfsim DONE = 出现 `SuperScalar Report Stop`；4PE = 文件名 `_mt`/`PE4`/`_4pe`（gfrun `multiThreadNum=4`、gfsim `--conf fourpe`）。
> 完整逐 ELF 日志与驱动脚本保存在验证机 `artifacts/sol_verify_*/`（未入库，体积 ~6MB/轮）。
