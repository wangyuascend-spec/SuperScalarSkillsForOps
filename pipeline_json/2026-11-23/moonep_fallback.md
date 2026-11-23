MoonEP 同机对比 · 用户包 DSL 参考 · 2026-11-23

四卡、32 AIV。小网络 S1024 K4 E16，大网络 S8192 K16 E112。balanced 从全部专家抽样，skewed 从热点专家抽样，extreme 固定选择前 K 个专家。

PyPTO 提交 518bd5c。18 组主矩阵采用用户包源文件的 scalar Count 诊断副本及 early_count=False。独立补测使用用户包原版和 early_count=True。原文件 SHA256 为 05e60dd2cbae41c50ecd61a2155cf0fac6266df6299e8ffaedc68a7967c1b68e。最新 DSL 主线的采集阻塞见同目录 moonep_latest.html。

每卡取 20 次设备 Task Duration 的中位数，再取四卡中位数。倍率按同卡配对计算后汇总，小于 1 表示 PyPTO 更快。通信/融合含跨卡等待，长尾可能使配对倍率与表内两个中位数的商出现方向差异。

小网络 balanced 默认计算比诊断 DSL 慢约 31%，是最明确的相对短板。大网络 skewed 的计算绝对耗时最高，PyPTO 约 346 μs，但相对 DSL 的 719 μs 已明显更快。不同批次和不同 DSL 版本分别列示，不能拼接计算倍率。

| 参考与 PyPTO 设置 | 规格 / 路由 / 测试项 | DSL μs | PyPTO μs | PyPTO / DSL 配对倍率 |
| --- | --- | --- | --- | --- |
| scalar Count · 默认 False | s1024-k4-epn4-balanced-comm | 60.36 | 27.32 | 0.941 |
| scalar Count · 默认 False | s1024-k4-epn4-balanced-compute | 27.31 | 35.84 | 1.312 |
| scalar Count · 默认 False | s1024-k4-epn4-balanced-full | 38.97 | 53.38 | 1.253 |
| scalar Count · 默认 False | s1024-k4-epn4-extreme-comm | 18.17 | 24.54 | 1.139 |
| scalar Count · 默认 False | s1024-k4-epn4-extreme-compute | 36.08 | 13.71 | 0.378 |
| scalar Count · 默认 False | s1024-k4-epn4-extreme-full | 52.10 | 32.61 | 0.611 |
| scalar Count · 默认 False | s1024-k4-epn4-skewed-comm | 26.48 | 26.02 | 1.146 |
| scalar Count · 默认 False | s1024-k4-epn4-skewed-compute | 36.06 | 13.59 | 0.376 |
| scalar Count · 默认 False | s1024-k4-epn4-skewed-full | 164.67 | 287.02 | 0.972 |
| scalar Count · 默认 False | s8192-k16-epn28-balanced-comm | 16.70 | 20.10 | 0.961 |
| scalar Count · 默认 False | s8192-k16-epn28-balanced-compute | 313.67 | 271.19 | 0.865 |
| scalar Count · 默认 False | s8192-k16-epn28-balanced-full | 331.42 | 289.36 | 0.867 |
| scalar Count · 默认 False | s8192-k16-epn28-extreme-comm | 15.53 | 13.83 | 0.810 |
| scalar Count · 默认 False | s8192-k16-epn28-extreme-compute | 689.83 | 102.37 | 0.148 |
| scalar Count · 默认 False | s8192-k16-epn28-extreme-full | 717.00 | 127.75 | 0.177 |
| scalar Count · 默认 False | s8192-k16-epn28-skewed-comm | 25.02 | 21.96 | 1.008 |
| scalar Count · 默认 False | s8192-k16-epn28-skewed-compute | 718.64 | 346.02 | 0.481 |
| scalar Count · 默认 False | s8192-k16-epn28-skewed-full | 744.97 | 367.82 | 0.488 |
| 用户包原版 · 显式 True | s1024-k4-epn4-balanced-full | 42.05 | 45.40 | 1.040 |
| 用户包原版 · 显式 True | s1024-k4-epn4-extreme-full | 48.91 | 34.48 | 0.599 |
| 用户包原版 · 显式 True | s1024-k4-epn4-skewed-full | 50.52 | 28.04 | 0.542 |