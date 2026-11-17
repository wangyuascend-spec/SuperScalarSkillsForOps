# MoonEP ca3b8f6 最新性能

- balanced: old 108.320 → new 90.317 μs; per-rank paired reduction 12.0–17.9%
- large-balanced: old 305.410 → new 288.136 μs; per-rank paired reduction 3.4–6.2%
- large-skewed: old 389.567 → new 376.626 μs; per-rank paired reduction 3.4–4.5%
- skewed: old 58.296 → new 40.853 μs; per-rank paired reduction 22.7–44.6%

完整融合、四卡32 AIV、seed42、trusted。736调用五输出精确通过。独立通信/计算及同批DSL未重测。全部长尾保留，观察范围不等于置信区间。
