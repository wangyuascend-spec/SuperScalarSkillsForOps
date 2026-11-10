# 2026-11-10 FlashMLA Ascend 950 (dav-3510) 仿真结果

DeepSeek FlashMLA `csrc/ascend_kernels/prefill/sparse` 在 CANN 9.2.0 `cannsim`
(Ascend950PR_9599 camodel, cycle-accurate) 上的仿真产物。

## 目录约定

```
<spec>/
  logs/      npusim / report 日志、helper 日志
  traces/    trace_allchips.json、trace_chip0_kernel0.json、core_N/trace_coreN.json
  kernel/    该规格使用的 kernel .o（bisheng --npu-arch=dav-3510）及其 .disasm
disasm/      6 个 kernel 的设备码反汇编（去重）
```

流水图可直接拖入 `chrome://tracing` 或 `https://ui.perfetto.dev`。

## 反汇编

`.o` 中的 `.aicore_binary` 段是独立的 hiipu64 ELF，用编译器自带反汇编器导出：

```bash
llvm-objcopy --dump-section .aicore_binary=k.device.elf k.o
llvm-objdump -d --triple=hiipu64 k.device.elf > k.disasm
```

`disasm/*.disasm` 为去重后的 6 份（prefill/decode × sink/nosink × FP8/FP4-extra）。

## 规格与精度

| spec | 实例化 | 精度 (out max_abs / cos) |
|---|---|---|
| prefill_sq32_kv512_topk64 | prefill nosink | 4.08e-3 / 0.9999995 |
| prefill_sq8_kv512_topk128 | prefill nosink | 3.11e-3 / 0.9999980 |
| prefill_sq4_kv95_topk64_invalid | prefill nosink（含非法索引） | 3.55e-3 / 0.9999980 |
| prefill_sq8_kv256_topk64_sink | prefill sink | 3.92e-3 / 0.9999982 |
| prefill_sq4_kv256_topk64_topklen | prefill nosink（topk_length） | 6.95e-3 / 0.9999983 |
| decode_b4_fp8 | decode nosink（FP8 cache） | 3.83e-3 / 0.9999978 |
| decode_b4_fp8_sink | decode sink（FP8 cache） | 3.99e-3 / 0.9999981 |
| decode_b2_fp8_fp4extra | decode nosink（FP8 + FP4 extra） | 7.10e-3 / 0.9999979 |
| decode_b2_fp8_fp4extra_sink_tl | decode sink（FP8 + FP4 extra） | 4.01e-3 / 0.9999978 |

9/9 PASS（参考值为同一量化 KV 的 CPU float32 反量化注意力计算）。

## 环境/适配备注

- CANN 9.2.0（`/home/developer/Ascend92/cann-9.2.0`），`bisheng 15.0.5`
- 源码适配：`asc_float2bfloat16_rn_v2_impl` → `_v2`（公开 9.2 删除了内部符号）；
  另需 `bits/stl_pair.h` concepts shim（`.asc` 前端对 libstdc++13 约束版 `std::pair` 误判）
- cannsim 9.2 `report` 修复 3 处 helper DB 列名大小写问题（否则只出 log、不出流水图）
- 采集命令：`cannsim record <bin> -u <case> -s Ascend950 -o simout`
  + `cannsim report -e <record> -o <report> -n all -m`
