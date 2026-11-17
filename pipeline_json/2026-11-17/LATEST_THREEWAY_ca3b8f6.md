# MoonEP 最新三方性能 · ca3b8f6

2026-11-17 同一 qrun 锁内两组配对实验，四卡、32 AIV、seed42、默认 trusted。

小 S1024/K4/E16，大 S8192/K16/E112，balanced/skewed。DSL 为 scalar Count 诊断版，规划核数上限32并实测核对。每侧3 warmup +20正式样本。

小 balanced 最新／DSL 完整融合配对比2.023，计算约2.533，仍是主要劣化项。大 balanced 完整融合约0.879，大 skewed约0.603。完整原始样本、各 rank 数据、配对范围与胜率见同目录HTML/JSON。

旧／新 PyPTO 和 DSL／最新 PyPTO 是不同同进程配对组，均在同一排队执行锁内。不得跨组构造旧 PyPTO／DSL 比值或共用最新中位数。通信长尾大，配对比与汇总时长比均保留。

12 scope共2208调用，旧新4 full共736调用，额外240 smoke。数值、80 Pro SO及48 DSL SO、完整ABI、PID/device/任务数及实际32 AIV验证通过。原推荐八卡未测。
