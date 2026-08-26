# Skill 全量验证（build + gfrun + accuracy + gfsim）

- Generated: 2026-08-26T09:02:28+08:00
- Skill: `wangyuascend-spec/SuperScalarSkillsForOps` / `supernpu-gfrun-accuracy`
- gfrun: `timeout 90 gfrun -t 1 -f …`（QLI 按 README dump-memory，无 `-t 1`）
- gfsim: `timeout 180 gfsim -f … -t 1 --pto-v02 true`（norm/dmx 用无 res_check 的 clean ELF）

## 仓库分支

| 仓 | 分支 | HEAD |
|---|---|---|
| SuperNPUBench | `main` | `244d088 docs: stop tracking local multi-thread issue notes` |
| SuperScalarModel | `feat/gfrun-cooperative-tmatmul-fp16-bf16-rerun` | `a5dca25a docs(status): refresh current cross-model evidence` |
| Linx-TileOP-API | `linx` | `a795b97 [tileop-api] Adapt SizeCode 1..12 / PEMode to B.IOT/B.IOS (ADR 0069)` |
| llvm-project | `dev-llvm15_56` | `611105f2be11 [LinxV5] B.IOT/B.IOS SizeCode 4-bit + PEMode 3-bit (PTO-ISA ADR 0069)` |
| linx-toolchain-build | `main` | `e6a31ef macOS: install GNU tar for the package step` |
| pto-spec | `main` | `db89935b Refactor PTO specification management (#120)` |
| linx-model | `main` | `74dc99f ci: bind model authority to merged LinxISA (#12)` |

- gfrun: `/home/wangyu/Code/SuperScalar/SuperScalarModel/bin/gfrun` mtime 2026-08-24 10:43:46.417231
- gfsim: `/home/wangyu/Code/SuperScalar/SuperScalarModel/bin/gfsim` mtime 2026-08-24 10:55:17.993112

## 汇总

| operator | compile | gfrun | accuracy | gfsim | root cause |
|---|:---:|:---:|:---:|:---:|---|
| GatherV2 | rank1_float | FAIL | SKIP | SKIP | SKIP | missing pto::Coalesce |
| GatherV2 | rank2_int32 | FAIL | SKIP | SKIP | SKIP | missing pto::Coalesce |
| GatherV2 | coalesce_half | FAIL | SKIP | SKIP | SKIP | missing pto::Coalesce |
| ViewCopy | int32_2x4x8 | FAIL | SKIP | SKIP | SKIP | -DDType clashes with TileOP %c[DType] |
| ViewCopy | half_4x4x8 | FAIL | SKIP | SKIP | SKIP | -DDType clashes with TileOP %c[DType] |
| ViewCopy | half_tail | FAIL | SKIP | SKIP | SKIP | -DDType clashes with TileOP %c[DType] |
| Matmul | self_verify_tM16 | OK | OK | FAIL | OK | R2=1 |
| Matmul | self_verify_tM32 | OK | OK | FAIL | OK | R2=1 |
| QuantMatmul | MULTI_BLOCK | SKIP | SKIP | NO_ORACLE | SKIP | PR adds MULTI_BLOCK only; no compile.all accuracy case |
| DynamicMxQuant | TAIL_CUBLAS_FP8 | OK | MODEL_FAIL | SKIP | FAIL | ASSERTION FAILED: IsCompareSelectTeplDataType(block->tileOp, block->dataType) && "compare/select TEPL tuple is not defined by PTO ISA v0.2" |
| DynamicMxQuant | TAIL_OCP_FP4 | OK | MODEL_FAIL | SKIP | FAIL | ASSERTION FAILED: source && OperandTypeIsTile(source->type) && source->tileInfo && source->tileInfo->dataType == block->dataType && source->tileInfo->validRow == validRow && sourc… |
| DynamicMxQuant | NONTAIL_CUBLAS_FP8 | OK | MODEL_FAIL | SKIP | FAIL | ASSERTION FAILED: IsCompareSelectTeplDataType(block->tileOp, block->dataType) && "compare/select TEPL tuple is not defined by PTO ISA v0.2" |
| Conv2dV2 | fp32_tmul | OK | OK | PASS | OK |  |
| Conv2dV2 | fp16_14x14 | OK | OK | PASS | OK |  |
| MegaMoe | mega_moe_sim_BS64 | FAIL | SKIP | SKIP | SKIP | Cannot select: t74: v2i64 = BUILD_VECTOR Constant:i64<0>, Constant:i64<0> |
| MoeDispatch | moe_dispatch_v2 | OK | OK | PASS | FAIL | 6_64-linux-gnu/libc.so.6(+0x2a1ca)[0x7a190182a1ca] /lib/x86_64-linux-gnu/libc.so.6(__libc_start_main+0x8b)[0x7a190182a28b] /home/wangyu/Code/SuperScalar/SuperScalarModel/bin/gfsim… |
| MoeCombine | moe_combine_v2 | OK | OK | PASS | OK |  |
| RmsNorm | rms_norm __half res_check | OK | OK | FAIL | OK | usage: rms_norm_data_compare.py [-h] [--cmp-dir CMP_DIR] [--output OUTPUT] [--golden GOLDEN] [--atol ATOL] [--rtol RTOL] [--mse-tol MSE_TOL] rms_norm_data_compare.py: error: unrec… |
| GroupNormGrad | group_norm_grad | OK | OK | PASS | OK | Report Stop |
| GroupNormGrad | group_norm_grad_1d | OK | OK | PASS | OK | Report Stop |
| QLI | Sq64_Skv128_topk128 | FAIL | SKIP | SKIP | SKIP | golden gen failed |
| QLI | Sq4_Skv2048_topk512 | FAIL | SKIP | SKIP | SKIP | golden gen failed |
| QLI | Sq4_Skv8192_topk512 | FAIL | SKIP | SKIP | SKIP | golden gen failed |
| QLI | Sq4_Skv2080_topk512 | FAIL | SKIP | SKIP | SKIP | golden gen failed |
| QSMLA | baseline_swa | OK | MODEL_FAIL | SKIP | FAIL | ]: Rename for BPC:0x11372 TPC:0x113a4 P0-L0-(B213+)-G0-T0-I27-ST0 TR41-UR17 sid:0 lsid:0 src0:[t#1.sw]-P(168)-not_rdy,->dst0:[t.fs]-P(169),|scvtf [t#1.sw] -> [t.fs] last: false [C… |

### 计数

- compile: {'FAIL': 11, 'OK': 13, 'SKIP': 1}
- gfrun (ran): {'OK': 9, 'MODEL_FAIL': 4}
- accuracy (ran): {'FAIL': 3, 'PASS': 6}
- gfsim (ran): {'OK': 8, 'FAIL': 5}

## 明细

| operator | source | case | compile | gfrun | accuracy | gfsim | gfrun_s | gfsim_s | log |
|---|---|---|:---:|:---:|:---:|:---:|---:|---:|---|
| GatherV2 | PR#79@6359467 | `rank1_float` | FAIL | SKIP | SKIP | SKIP |  |  | logs/build_gather_rank1_float.log |
| GatherV2 | PR#79@6359467 | `rank2_int32` | FAIL | SKIP | SKIP | SKIP |  |  | logs/build_gather_rank2_int32.log |
| GatherV2 | PR#79@6359467 | `coalesce_half` | FAIL | SKIP | SKIP | SKIP |  |  | logs/build_gather_coalesce_half.log |
| ViewCopy | PR#79@6359467 | `int32_2x4x8` | FAIL | SKIP | SKIP | SKIP |  |  | logs/build_view_int32_2x4x8.log |
| ViewCopy | PR#79@6359467 | `half_4x4x8` | FAIL | SKIP | SKIP | SKIP |  |  | logs/build_view_half_4x4x8.log |
| ViewCopy | PR#79@6359467 | `half_tail` | FAIL | SKIP | SKIP | SKIP |  |  | logs/build_view_half_tail.log |
| Matmul | PR#82@dec7e3e | `self_verify_tM16` | OK | OK | FAIL | OK | 1.18 | 1.14 | logs/gfrun_matmul_self_verify_tM16.log |
| Matmul | PR#82@dec7e3e | `self_verify_tM32` | OK | OK | FAIL | OK | 1.13 | 1.12 | logs/gfrun_matmul_self_verify_tM32.log |
| QuantMatmul | PR#73@52f6c29 | `MULTI_BLOCK` | SKIP | SKIP | NO_ORACLE | SKIP |  |  |  |
| DynamicMxQuant | PR#83@88f68b0 | `TAIL_CUBLAS_FP8` | OK | MODEL_FAIL | SKIP | FAIL | 0.83 | 6.79 | logs/gfrun_dmx_TAIL_CUBLAS_FP8.log |
| DynamicMxQuant | PR#83@88f68b0 | `TAIL_OCP_FP4` | OK | MODEL_FAIL | SKIP | FAIL | 0.82 | 5.28 | logs/gfrun_dmx_TAIL_OCP_FP4.log |
| DynamicMxQuant | PR#83@88f68b0 | `NONTAIL_CUBLAS_FP8` | OK | MODEL_FAIL | SKIP | FAIL | 0.78 | 4.96 | logs/gfrun_dmx_NONTAIL_CUBLAS_FP8.log |
| Conv2dV2 | PR#75@68f4ccd | `fp32_tmul` | OK | OK | PASS | OK | 0.85 | 2.79 | logs/gfrun_conv_fp32_tmul.log |
| Conv2dV2 | PR#75@68f4ccd | `fp16_14x14` | OK | OK | PASS | OK | 3.38 | 39.55 | logs/gfrun_conv_fp16_14x14.log |
| MegaMoe | PR#74@92c2efb | `mega_moe_sim_BS64` | FAIL | SKIP | SKIP | SKIP |  |  | logs/build_mega_moe.log |
| MoeDispatch | PR#74@92c2efb | `moe_dispatch_v2` | OK | OK | PASS | FAIL | 4.27 | 18.0 | logs/gfrun_moe_dispatch.log |
| MoeCombine | PR#74@92c2efb | `moe_combine_v2` | OK | OK | PASS | OK | 5.3 | 73.61 | logs/gfrun_moe_combine.log |
| RmsNorm | main+DATA_TYPE | `rms_norm __half res_check` | OK | OK | FAIL | OK | 1.33 | 6.29 | logs/gfrun_rms_res.log |
| GroupNormGrad | main+DATA_TYPE | `group_norm_grad` | OK | OK | PASS | OK | 2.72 | 10.27 | logs/gfrun_gng_res.log |
| GroupNormGrad | main+DATA_TYPE | `group_norm_grad_1d` | OK | OK | PASS | OK | 3.06 | 18.7 | logs/gfrun_gng1d_res.log |
| QLI | PR#78@631a36c | `Sq64_Skv128_topk128` | FAIL | SKIP | SKIP | SKIP |  |  | logs/qli_gen_Sq64_Skv128_topk128.log |
| QLI | PR#78@631a36c | `Sq4_Skv2048_topk512` | FAIL | SKIP | SKIP | SKIP |  |  | logs/qli_gen_Sq4_Skv2048_topk512.log |
| QLI | PR#78@631a36c | `Sq4_Skv8192_topk512` | FAIL | SKIP | SKIP | SKIP |  |  | logs/qli_gen_Sq4_Skv8192_topk512.log |
| QLI | PR#78@631a36c | `Sq4_Skv2080_topk512` | FAIL | SKIP | SKIP | SKIP |  |  | logs/qli_gen_Sq4_Skv2080_topk512.log |
| QSMLA | PR#39@0402abd | `baseline_swa` | OK | MODEL_FAIL | SKIP | FAIL | 52.53 | 195.27 | logs/gfrun_qsmla.log |
