# 依赖下载与增量构建

## 仓库来源与初次准备

以下是已知仓库入口，实际 ref、构建开关以所选 SuperNPUBench README 为准：
- https://github.com/PTO-ISA/SuperNPUBench
- https://github.com/LinxISA/linx-toolchain-build
- https://github.com/LinxISA/llvm-project （主线验证分支 dev-llvm15_56）
- https://github.com/LinxISA/Linx-TileOP-API （linx）
- https://github.com/LinxISA/SuperScalarModel （main）
- toolchain 的其余组件按 init-src.sh/README：linx-musl（linx）、jemalloc（linx）、linux（main）等，不能遗漏 runtime/sysroot。

先检查 clone 是否存在且 remote 正确。缺失仓库才 clone；不要在已有目录嵌套 clone。
使用现有 gh/git 身份；不要把 token 放到 URL、脚本、日志或 manifest。
私有仓无权限时报告 AUTH_BLOCKED，不硬编码历史 token。

示例（替换为已解析路径/ref，只对不存在的目标执行 clone）：
```bash
git clone https://github.com/PTO-ISA/SuperNPUBench.git "$bench"
git clone https://github.com/LinxISA/linx-toolchain-build.git "$toolchain"
git clone https://github.com/LinxISA/SuperScalarModel.git "$model"
git -C "$bench" fetch origin --tags
```

审阅 init-src.sh 后，仅在初始空组件树运行 `make init-src`；已有组件树先检查其行为，避免脚本 pull 切换用户修改。
逐仓记录并解析 ref，使用精确 SHA checkout。submodule 按文档初始化。
不要 lexicographic 排序臆测最新 tag；检查发布信息、命名约定和远端 refs。缺依赖包时报告具体包，安装须获授权。

## 预检和资源约束

执行 `free -h`、`nproc`、`df -h`，检查 swap、活动构建/仿真和最近 OOM 证据。
不要自动修改 .wslconfig、swap、内存限制或 kill 无关进程。
默认编译2、链接1；顶层步骤串行。统计峰值后才提高并发，不用裸 `-j$(nproc)`。
有效设置必须进入内部 Ninja/Make；只给顶层 -j2 或 THREADS=2 不一定限制 LLVM。

## 编译器：默认永远不 clean

日常更新禁止 `make clean`、`ninja clean`、`--clean-first`、删除 build/stamps/output 和 wrapper 内隐藏 clean。
先检查真实 Makefile/脚本，特别是默认目标、clean 依赖、stamp、内部 rm 和并行参数。
不要直接运行包含隐式 clean 的 compile.all。

初次完整构建（只在当前 wrapper 支持这些变量时）：
```bash
make -C "$toolchain" -j1 WITH_TARGET=linx64v5-linux-musl \
  THREADS=2 LLVM_MAKE="ninja -j2 -l2"
```
可用且已安装 ccache 时使用支持的开关；不私自安装或修改全局配置。

已有 LLVM 构建：
1. 读取 CMakeCache：CMAKE_HOME_DIRECTORY、generator、host compiler、target triple、install prefix 必须对应本次选择。
2. 保留原 CMake 选项；若 supported，配置 LLVM_PARALLEL_COMPILE_JOBS=2、LLVM_PARALLEL_LINK_JOBS=1。
3. 原目录增量构建并安装，不丢弃对象缓存：
```bash
cmake --build "$llvm_build" --parallel 2
cmake --build "$llvm_build" --target install --parallel 1
```
使用当前 generator 支持的等效 Ninja 命令也可以，不能更换 source/cache 配对。
4. stamp 可能只依赖目录或 .git 路径；新 commit 不保证 make 认为过期。核对实际 Ninja 工作和安装哈希，禁止仅看“Nothing to be done”。
5. 依据 compiler/ABI/runtime 输入变化重建目标运行库闭包。增量不代表跳过不兼容旧对象；对于构建系统追踪不到的 compiler 外部输入，显式使精确受影响组件失效，或用单独新 build/install 目录，保留旧环境。
6. 不伪造完成 stamp、不随便 touch stamp 跳过构建、不从其他工具链拷二进制拼装环境。
7. 检查 musl、compiler-rt、libc++、libc++abi、libunwind、jemalloc 和最终头文件安装的一致性。
8. 仅 TileOP 头文件变化时执行文档支持的头文件 install 目标；比较安装头文件与选定源码指纹，避免实际编译仍使用旧 include。

跨 LLVM 分支/major、host compiler、generator/ABI 不兼容时，先报告原因并询问全量重建；
优先独立新构建目录，不自动清理既有目录。用户明确要求 clean 时才按授权精确执行并保留旧 manifest。

## 模型：gfrun 和 gfsim 分开确认

先读该版本 README、AGENTS.md、build.py 参数，确认命令不包含 clean。
当前常见入口：
```bash
cd "$model"
python3 build.py all -j2                       # 初次 configure+build，不能加 --clean
python3 build.py build --target gfrun -j2      # 已配置环境
python3 build.py build --target gfsim -j2
```
命令随版本变化，先核对 help/source。仅测一个 runner 可以只构建一个；请求两者就分别验证两个产物。
CMake 配置改变需重新 configure，保留 build dir。依赖缺失记 BUILD_BLOCKED。
源码 HEAD、二进制 build-source SHA、产物 SHA256 分别记录；不要因 gfsim 重建了就声称 gfrun 也是最新。
编译器是目标算子的编译器，模型通常用主机 C++ 编译器；两者不要混淆。

## 算子 ELF：防止假增量

- 先 make -n 检查目标是否含 clean、是否会真正编译目标 .cpp。
- 当前部分 Makefile 只追踪 .cpp，不追踪 .hpp，也不追踪 shape 宏。kernel-only、参数和工具链变化时必须使对应对象重新编译。
- 经检查确认安全后，可用以下模式强制测试翻译单元重编，而不清理全部输出：
```bash
make -C "$case_dir" -o clean -W "$case_cpp" \
  TESTCASE="$case_name" COMPILER_DIR="$compiler_bin" \
  DType=__half PE_NUM=4 res_check=on diss
```
这是条件性用法：-o clean 只屏蔽名为 clean 的目标，不能阻止 recipe 内嵌 rm/clean；
-W 的路径必须匹配实际 prerequisite。公共头文件/runtime 也变化时，单独强制重建对应 common 对象。
- 不同 shape/dtype 的 Makefile 可能共用 .o 路径；因此顺序编译、立即冻结 ELF/hash。不能因 ELF 文件名不同就并行构建。
- 保持相同 flags 的 ELF 可用于 gfrun/gfsim；若 timing 构建契约不同则另建 ELF，明确报告两个 hash。
- 用真实退出码判断成功。shell 管道必须启用 pipefail；wrapper 内部 tee 若吞掉状态，需核对其子构建日志和新产物，不能运行残留旧 ELF。
- 记录反汇编和可用调试信息，便于从 BPC/TEPL 映射到 kernel 行号。

## 构建计时

每段独立记录 fetch、configure、LLVM compile、install/runtime、model、ELF、data、gfrun、checker、gfsim、trace。
可用 `/usr/bin/time -v -o <unique-time-log> <command>`，分别保存 stdout/stderr 和退出码。
报告时间占比时区分串行 wall time 与并行 CPU/阶段总和，不将并行阶段耗时直接相加作为总时长。
