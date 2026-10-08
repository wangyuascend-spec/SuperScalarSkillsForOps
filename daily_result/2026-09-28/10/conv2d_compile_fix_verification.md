# conv2d 验证记录 — 2026-09-28

## 问题
验证 version-tracking-reports 报告（2026-09-25T0514）中 solution/conv2d 是否 gfrun 挂了。

## 结论
1. 报告中 conv2d **不是 gfrun 挂**，是 **COMPILE_FAIL**（编译期 backend 报错，无 ELF 产出，gfrun 从未执行）：
   `error in backend: cannot copy a Shared register: Shared handles have no MOVR/copy instruction`
   （kernel 树的 conv2d v300_conv2d_PE4 在报告中 gfrun=PASS。）
2. 报告链之后 ~19h，TileOP #234（b2b16fa，2026-09-25 23:53，"fix(shared): inline TIMG2COL_SPART handle path"）
   将 TIMG2COL_SPART 改为 PTO_SHARED_INLINE 强制内联，修复了该编译失败。
3. 最新链实测（2026-09-28）：conv2d_img2col / conv2d_img2col_dyn 编译 rc=0，
   **gfrun 双双 PASS（R2=0，4PE）**；gfsim 双双 FAIL 于 isa/Block.cpp:2314
   （"BSTART.TIMG2COL schema or parameter carrier is illegal"，时序模型缺口，非 ISA/功能问题）。

## 验证链（本次实测）
| 组件 | commit | 日期 |
|---|---|---|
| llvm-project (dev-llvm15_56) | af743c28be63 | 09-24（含 "Reject copies of open B.ASSEMBLE parents"） |
| Linx-TileOP-API (linx) | b2b16fa（#234） | 09-25 |
| SuperScalarModel (main) | 27200493（PR #798） | 09-28 |
| SuperNPUBench (main) | 5da6474 | 09-24（与报告一致） |

## A/B 归因
- 旧 TileOP 头 275d8e7（报告同款）+ llvm af743c28：复现逐字一致的报错，
  崩于 llvm::LinxV5InstrInfo::copyPhysReg（ExpandPostRA）→ 证实根因是
  TIMG2COL_SPART 未内联 → SharedTile 句柄经 C++ ABI 传递 → 生成 Shared 寄存器 copy
  → 后端（af743c28 的显式拒绝逻辑）正确拒绝。
- 新 TileOP 头 b2b16fa：编译通过，gfrun R2=0。
- 环境已恢复为新头，conv2d 重编译 rc=0。

## 判据
gfrun PASS = "Suaccelss to Reach the End of Benchmark! R2 = 0"，rc=0。
日志：本目录 logs/（gfrun_*.log、gfsim_*.log、build_conv2d*.log、ninja_llvm.log、build_ssm.log）
