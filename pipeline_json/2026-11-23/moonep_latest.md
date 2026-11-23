MoonEP 四卡实测 · 2026-11-23

PyPTO PR 518bd5c 对照 cannbot DSL 主线 e776e13（算子最后修改 55e8df5）。DSL 0.8.2 在四卡通信初始化时找不到 cannbotdsl._comm_native，检查的 cp310 x86_64 0.8.2/0.8.3/0.8.4 wheel 均缺该扩展。预填需求矩阵的纯计算诊断在 0.8.2、0.8.4 均未获得样本，0.8.4 在 _run_cannbotir_passes 出现段错误。最新 DSL 耗时和相对倍率均待验证。

小网络每卡 S=1024、K=4、总 E=16。大网络每卡 S=8192、K=16、总 E=112。balanced 从全部专家抽样，skewed 从 max(K,E/4) 个热门专家中抽样，extreme 固定选择前 K 个专家。

full 为融合任务的设备耗时，compute 使用预填需求矩阵，comm 为独立通信测量。两列分别是同一 PR 的 early_count=False 和 True。单位 μs，full/compute 每个 rank 取 20 个样本中位数，再取四个 rank 的中位数。原始长尾样本见 JSON。

小网络 balanced 计算受 Count 与 Greedy 的串行执行影响，提前 Count 后从 35.74 降至 27.97 μs。两种热点路由在默认模式下跳过 Count，开启后多做了一次计数。大网络 E=112 超出提前 Count 的特化范围，两列差异不能归因于提前 Count。

大网络 skewed 默认纯计算 346.20 μs，端到端 367.34 μs；balanced 分别为 271.42 和 285.49 μs。纯计算随路由变慢约 75 μs，是大网络 skewed 最明确的瓶颈。当前没有各个计算子阶段的独立计时。本轮已完成的采样范围内，端到端与分段分别取样，不能用两个中位数的差值估算通信占比。

| 规模/批次 | 测试项 | 默认 μs | 提前 Count μs |
| --- | --- | --- | --- |
| large | compute-balanced | 271.42 | 271.32 |
| large | compute-extreme | 102.33 | 102.66 |
| large | compute-skewed | 346.20 | 346.35 |
| large | full-balanced | 285.49 | 285.24 |
| large | full-extreme | 126.47 | 127.28 |
| large | full-skewed | 367.34 | 363.57 |
| small | comm-balanced | 22.63 | 25.21 |
| small | comm-extreme | 14.42 | 12.63 |
| small | comm-skewed | 36.03 | 41.64 |
| small | compute-balanced | 35.74 | 27.97 |
| small | compute-extreme | 13.67 | 16.25 |
| small | compute-skewed | 13.52 | 16.32 |
| small | full-balanced | 58.07 | 47.54 |
| small | full-extreme | 32.78 | 29.78 |
| small | full-skewed | 29.37 | 29.86 |
| large | comm-balanced | 30.06 | 29.41 |
| large | comm-extreme | 30.64 | 31.37 |
| large | comm-skewed | 17.12 | 21.01 |