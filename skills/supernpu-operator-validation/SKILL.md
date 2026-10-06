---
name: supernpu-operator-validation
description: Prepare SuperNPUBench and its compiler, TileOP and model dependencies, perform memory-bounded incremental builds, and validate selected one-level operators with gfrun numerical checks and real-L2 gfsim. Use for end-to-end environment refresh, PR or local-kernel validation, and reproducible simulation results.
---

# SuperNPUBench 算子端到端验证

目的：得到可复现的“版本 → 依赖与二进制 → ELF → 输入/参考输出 → 精度/性能”结果。
不要把编译通过、gfrun 执行结束、精度通过、gfsim 性能完成混为一谈。

## 1. 确定任务与版本策略

先输出工作目录、算子/变体/shape/dtype/PE、是否更新代码、所用版本策略。
用户当前指令优先于本 skill 默认值；不重复询问已明确的选择。

- **本地修改复测**：使用指定工作区当前文件，保存 HEAD、diff 及内容哈希；不自动拉取或覆盖源码/依赖。
- **指定 tag**：解析该 tag 的完整 SHA，读取该版本 README 和构建文档，按其依赖约束准备环境。
- **最新环境**（未另指定）：SuperNPUBench 最新 main；依赖约束来自最新发布 tag 的 README；SuperScalarModel 最新 main。LLVM/TileOP 使用该 README 指定版本。
- **显式主线依赖更新**：LLVM 默认分支是 `dev-llvm15_56`，不是 `main`；TileOP 是 `linx`；模型是 `main`。以用户明确指定的分支/commit 覆盖默认值。
- README 只列分支、不列 commit 时，记录这一事实，解析对应远端分支当次 SHA；不得称其为“tag 锁定 commit”。文档互相冲突或缺失关键版本时先询问。
- PR：记录 PR 状态、base/head SHA。用户要求“基线+PR”时检查 ancestry，不包含基线则在隔离工作区集成；冲突未获授权解决时停止。用户要求“PR原样”则测试 exact head，不擅自合并其他版本。
- 一批算子只解析一次版本并冻结。长构建结束可检查远端是否移动，但不在中途更换 tuple；报告“截至抓取时间”的版本。

在任何依赖下载、更新或编译前，完整阅读 [依赖与增量构建](references/build.md)。

## 2. 清点与保护工作区

默认本机工作根目录可用 `/home/wangyu/Code/PtoNpu`，它不是固定要求。
目录后缀 main/main-latest 不能证明实际分支、commit 或二进制版本。

- 检查目标仓及祖先 AGENTS.md、git status、remote、branch/HEAD、submodules。
- 保护用户未提交修改、未跟踪文件、已打补丁的工具链。不要自动 reset/clean/stash。
- 用户要求更新指定目录时，干净工作区可快进/切换；有冲突则使用隔离 worktree 或询问。不得悄悄改在别处又声称原目录已同步。
- 必须记录构建目录 CMakeCache 指向的真正源码路径，防止更新 A 仓而从 B 仓编译。
- 验证本身不授权提交、推送、创建/关闭 issue、上传附件或修改系统设置。

## 3. 制定复用与执行计划

先比较上一次成功 manifest，逐项标记 REUSED / REBUILT / NEW / BLOCKED 和原因：

- 模型源码变化：重建请求的 runner；通常复用 ELF。
- kernel/test/shape/dtype/PE/flags 变化：重建受影响 ELF；生成器/oracle 输入变化才重建数据。
- TileOP 变化：安装对应头文件，重建受影响 ELF；不无故重编 LLVM。
- LLVM、链接器、ABI、sysroot 变化：重建受影响编译器及目标运行库闭包，再重建 ELF；不能只更新 clang 却混用不兼容 runtime。
- fetch 本身不导致重建。文件存在、mtime、clang --version 均不足以证明匹配。
- 缺少可靠产物指纹时重建一次并记录；失败/中断的构建不能标记可复用。

在 8–10GiB WSL 上默认重构建串行、编译 -j2、链接 -j1。
只有实测可用内存至少 6GiB、无竞争且历史峰值支持时才考虑 -j3；OOM 后降到 -j1。
不要同时编 LLVM、模型和跑多个仿真。只读版本查询可并行；共享输出目录的算子构建不能并行。

## 4. 枚举真正的测试

读取当前源码的 Makefile、compile.all、test C++、数据生成器、checker；
按“算子 + 变体 + shape + dtype + PE + tiling”枚举，去除重复入口，不凭文件名推测覆盖。

- 请求动态/静态都测时分别列出，不能沿用旧 skill 的“只测动态”筛选。
- normalization 常见项：rms_norm、rms_norm_split_r、group_norm_grad、group_norm_grad_1d，以及目录中存在且本次要求的 tree/simt 变体。旧名称 rms_norm_binary 仅用于发现历史路径，不漏掉 split_r。
- 4PE 由 launch/runtime 与 kernel 内部 get_thread_idx 等分工共同证明，不能在 host/test 中人为重复调用四次 kernel。
- 多 kernel 任务保留独立 launch 和完成顺序；不要为绕过失败插入未授权同步或修改算法。
- 默认只测指定范围。全 one-level 烟测才选每分类代表；全 solution 则重新枚举、排除单 PE 并确认筛选，不把历史 46 个用例当固定列表。
- 不擅自缩小 shape、删除尾块、调整容差或改变布局来制造 PASS。诊断变体需另列结果。

运行前完整阅读 [执行、精度与性能](references/run.md)。

## 5. 证据、进度与交付

每轮建唯一目录，例如 `<workspace>/validation_logs/<UTC-run-id>/`；
数据目录应隔离，ELF 中 CHK_DIR 的绝对路径也属于编译输入。不要复用旧日志目录覆盖证据。

每个阶段记录真实退出码、起止时间、wall time、可取得的峰值 RSS。每个 case 开始/结束打印：
`[case 2/4][gfrun][running] ...`，并汇总 completed/running/queued/pass/fail/timeout。
重建时报告 compile/link/install 阶段和已完成目标；不知道百分比就不编造。
持续运行时简短更新进度，遵守用户要求的反馈间隔；暂停请求要真正停止或暂停自己启动的任务，不能只停止发消息。

manifest 至少记录：
- run_id、时间、workspace、版本策略；各仓 URL/ref/full SHA、dirty diff hash、submodule SHA；
- baseline tag/SHA、PR head/integration SHA（若有）；
- toolchain wrapper、LLVM、TileOP、runtime、模型源码和构建配置；
- **分别**记录 clang/linker、已安装 TileOP、sysroot、gfrun、gfsim 的构建来源及 SHA256；
- 每个 ELF 的 SHA256、源码/include/flags 指纹、命令、shape、tiling、dtype、PE；
- generator/seed/input/golden/checker hash、容差、输出文件、两个 runner 的独立结果；
- config、有效 L2 模式、SoC 模式（gfsim 一律 random SoC seed=2，默认 SoC 不跑）、日志/trace/perf 路径、失败首条指令。

只在成功构建后发布新的产物 manifest；源码更新但 runner 未重建时不得把源码 HEAD 标成 runner 版本。
结果依次说明版本、各 case 精度与 gfsim 状态（random SoC seed=2 的 Total Cycles 与 scb_waw_violation 条数）、错误位置、未覆盖项、绝对日志路径。
用户要求 issue 时提供完整用例、源码 patch、ELF、输入/golden/tiling、重现脚本和编译环境；上传或发布先取得相应授权。
