# gfrun、gfsim 与故障诊断

## 输入与黄金结果

- 从该 case 自带 generator/test/checker 确认实际 layout、shape、seed、dtype 和 tiling，而不是复制旧目录的 bins。
- shape 改动须同时检查 Makefile、compile.all、动态/静态 C++、静态模板有效维度、generator、checker 默认路径与 ELF 的 CHK_DIR。
- 每次运行隔离输出目录；如 test 硬编码路径则显式编译对应路径。保留输入和 golden，不得混用两个模型并发写同一输出目录。
- 已有 dx/dgamma/dbeta 等结果移至该轮的 old-output 子目录或备份，不让旧文件被当作本次输出。不要删除输入或 golden。
- 若复用数据，必须有生成输入指纹匹配证据；shape 相同但 seed/oracle 变化也应重新生成。
- 多输出算子全部检查，记录长度、dtype、NaN/Inf 处理、atol/rtol/相对MSE等真实规则；缺 checker 记 NO_ACCURACY_ORACLE。

## gfrun 精度流程

先检查 runner 使用方法。当前4PE示例：
```bash
timeout -k 5s 120s "$model/bin/gfrun" -f "$elf" \
  -s softcore.multiThreadNum=4 > "$run_dir/gfrun.log" 2>&1
```
120秒是初始上限，可按用户/历史时长调整并在启动前说明；超时不是死锁证据。
普通运行不要默认 -t 1/-t 2；失败再对同一 ELF 运行 -t 1 捕获首个失败指令，-t 2 数据输出可能很大，按需限量。
检查 exit=0、Reach the End of Benchmark、R2=0，以及实际 oracle 是否执行。

外部 checker 必须在成功执行并生成本次输出后运行，例如：
```bash
python3 "$checker" --cmp-dir "$cmp_dir"
```
参数由源码核对，不假定每个算子都相同。记录 checker 退出码和每个输出指标。
runner PASS 但未比较仅为 EXECUTION_PASS，不是 ACCURACY_PASS。
任何编译失败或 runner 中途退出，不运行旧输出精度检查，也不标成“精度不通过”。

## gfsim 性能流程

默认只测 real L2；fake L2 仅在用户要求或经确认用于诊断时追加。
所有 gfsim 一律使用 random SoC，seed 固定为 2（`-s core.soc_random=true -s core.soc_lat_random_seed=2`），
其余 random SoC 参数保持 `configs/core.toml` 默认值；默认（固定延迟）SoC 不跑，除非用户明确要求。
一例最大900秒（15分钟）；超时终止自己启动的进程组并继续剩余队列，不无限重试。
默认单 worker。若确需并行，最多2个、先测 RSS，确保输入输出隔离且不与 LLVM/模型重建重叠。

当前真实4PE入口：
```bash
cd "$model"
timeout -k 10s 900s ./bin/gfsim -f "$elf" --conf fourpe --pto-v02 true \
  -s tlsu.fake_l2_enable=false -s core.soc_random=true -s core.soc_lat_random_seed=2 \
  > "$run_dir/gfsim-real-randsoc-seed2.log" 2>&1
```
必须从模型根目录执行（配置可能相对解析），核对当前版本支持参数。
gfrun 的 softcore.multiThreadNum=4 不能代替 gfsim fourpe 配置。
检查生效日志：core.threadCount=4、fourpe.pe_cluster_enable=true、
pe_cluster_count=4、pe_cluster_frontend_thread_count=4、core.soc_random=true、
core.soc_lat_random_seed=2；必要时核对 PE0–PE3 PMU 活动。
日志未显示 L2 生效时查配置解析，不凭默认值猜 real L2。
fake L2 对照只能改变该开关，保持 binary/ELF/数据/其他配置不变。

gfsim PASS 要求 exit=0、正确PE/L2配置、正常报告结束（如 SuperScalar Report Stop）、
有效 Total Cycles，且无 assertion/deadlock/fatal/timeout。
同时统计并报告 `scb_waw_violation` 条数（`invariants:` 行的 `scb_waw_tile`）；非零不改变 PASS，但必须如实报告。
gfsim 只证明性能模型执行完成；不能替代 gfrun 精度验证。
已知精度错误的 kernel 可按用户要求跑性能诊断，但明确标 INVALID_ACCURACY，不作为正确算子性能结论。

## 流水图与性能报告

用户要求性能流水图时，阅读**所测模型版本**的：
- modelSpec/performance_analysis_guide.md
- modelSpec/swimlane.md
- 需要指令级分析时再读 modelSpec/pipeview.md

采用该版本真实 SwimLane 开关生成 Perfetto/Chrome Trace JSON；
不要拿汇总 PMU 数字伪造成指令时间线，也不要把普通统计 JSON 称为流水图。
先普通 PMU 跑通，再按请求生成有范围约束的 trace，防止8GiB环境内存/磁盘膨胀。
核验 JSON 可解析、包含非空事件、时间单位正确且 PE/engine 轨道有数据。
报告 ELF/model hash、Total Cycles、主要瓶颈证据、trace 与原始日志绝对路径。
未跑完的 trace 标记 partial，不能当完整性能结果。
汇总多 PE 工作量计数不能直接当 wall cycles；TSTORE 等待可能由上游未完成引起。

## 失败分层与归属

分别记 SOURCE_INTEGRATION_BLOCKED、BUILD_FAIL、TEST_INFRA_FAIL、MODEL_FAIL、
ACCURACY_FAIL、CONFIG_FAIL、TIMEOUT、DEADLOCK、PASS；不要把不同层级混写。

1. 确认实际运行的是新 ELF、新 runner，以及输入/golden匹配。
2. 保存首条因果错误、BPC、TEPL、线程、源码行、完整命令和 stderr。
3. Tile 错误分别核对类型、layout、valid row/col、physical row/col、运行时描述、LB0/LB1/LB2、生产者与消费者。
4. 联合断言只表明至少一项失败；没有 dump 时，把代码推导标成推断，不把所有字段都说成已观测。
5. 不通过取消模型检查、改 golden/容差、硬编码绕过输入限制或恢复 scalar 数值计算路径制造 PASS。
6. 修改 kernel 只在用户授权修复时进行；诊断变量一次改一个并保留对照，最终代码恢复用户要求的优化，不把临时回退遗漏在交付版本。
7. kernel 违反已明确接口契约归算子；生成指令与合法源码契约不一致归编译器/TileOP 候选；合法指令被错误执行/检查归模型候选。不能仅凭报错文件名确定责任仓。
8. 同一源 tuple 复现并明确缩小范围后再建议 issue 归属。未授权不要自动创建 issue。
9. 用户授权发 issue 时标题只选一个：[gfrun][模块]、[gfsim][模块] 或 [CI][模块]。两种 runner 独立问题分开。
10. 复现包包括完整测试场景而非仅最小触发点：源码/patch、ELF、输入输出/golden/tiling bins、参数、日志、工具链/模型版本、可迁移的构建和运行脚本及 SHA256。
    ELF 可能嵌入绝对输入路径；给出重编参数或受控路径映射步骤，不能说“复制 ELF 即可”。
    获准上传后用 tar.gz 附件或可访问 release 链接，并验证他人可下载；本地路径不是附件。去除凭据和无关数据。
