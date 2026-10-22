# 四仓 NDDMA 统计结果（排除 experimental）

日期：2026-10-22（Asia/Shanghai）。统计下载时 master 提交，按算子工程去重，排除 experimental、公共辅助目录、示例、测试和内嵌 3rd 副本。

**共 1,360 个算子工程，220 个涉及 NDDMA，占 16.18%。显式 87，隐式 133。**

- **ops-nn**：总数 648；NDDMA 105；显式 58；broadcast 25；reduce 9；共享 kernel 13。
- **ops-math**：总数 398；NDDMA 106；显式 25；broadcast 47；reduce 18；共享 kernel 16。
- **ops-transformer**：总数 220；NDDMA 7；显式 2；broadcast 0；reduce 2；共享 kernel 3。
- **ops-cv**：总数 94；NDDMA 2；显式 2；broadcast 0；reduce 0；共享 kernel 0。

隐式分类合计：atvoss broadcast 72、reduce 29、共享 kernel 32。以上为静态源码存在相关路径的统计，不表示所有芯片、shape、tiling 分支都会执行 NDDMA，未进行动态指令采样。

## 文件说明

- main_only_operators.csv：正式目录全部 1,360 个工程及分类标记。
- nddma_operators.csv：涉及 NDDMA 的 220 个工程及源码证据位置。
- main_only_summary.json：各仓汇总。
- audit_main_only.json：正式目录证据、共享 include 链、固定版本和场景说明。

## 隐式使用场景

### atvoss broadcast：连续广播
BroadcastSch 的 schMode=1/2 分别选择不带/带外层循环的 BroadcastNddmaSch；内部调用 BroadcastNddmaWithoutLoop/WithLoop，再用 NdDmaParams + DataCopy 搬运。超过硬件单次维度范围时由外层循环分段。schMode=101–104/109 为 UB broadcast，201/202 为一维调度，不能把这些执行分支称为 NDDMA。
证据：opbase/pkg_inc/op_common/atvoss/broadcast/broadcast_sch.h:44

### atvoss broadcast：非连续与转置
schMode=301 是非尾轴转置 NDDMA，303 是尾轴转置调度（内部配置 NdDmaParams）；304/305 是非连续 NDDMA。302 为 UB broadcast 分支。模板中 KirinX90/Kirin9030 的说明明确不支持 NDDMA 模板。
证据：opbase/pkg_inc/op_common/atvoss/broadcast/broadcast_sch.h:98

### atvoss reduce：连续但需要重排
ReduceSch::CopyInAux 在 view.isBlockAligned==0 时选择 CopyInWithNddma。IsUseNddma 由尾轴长度、cacheline 切分维度、A/R 轴乘积等决定；尾轴 >= 一个 UB block 元素数时返回 0。即使进入 CopyInWithNddma，outer==1 时仍会退化为普通 DataCopyPad；不能宣称每个 reduce 输入都会执行 NDDMA。
证据：opbase/src/op_common/atvoss/reduce/reduce_tiling.cpp:1148

### atvoss reduce：非连续输入
尾轴 stride!=1 时 IsUseNddma 返回 1；CopyInAux 根据 isContiguous 选择 CopyInWithNddmaNonContiguous，实际用五维 NdDmaLoopInfo/Params + DataCopy。若 ReduceOp 自定义了 CopyIn，则优先执行其自定义实现。
证据：opbase/pkg_inc/op_common/atvoss/reduce/reduce_sch.h:517

### 广播辅助接口和新旧 API 名称
除 NdDmaParams/NdDmaLoopInfo，也扫描 MultiCopyParams/MultiCopyLoopInfo；Vec::CopyInBrc 的多维重载在 __DAV_C310__ 条件下调用 DataCopy。普通 CopyIn、CopyInBrc(count)、Reg::DataCopy 或 DataCopyPad 本身不能证明 NDDMA。
证据：opbase/pkg_inc/op_common/atvoss/util/vec.h:735

### 跨算子复用 kernel
包括 Slice/StridedSlice 的 Pad、PadV2/V3、MirrorPad 和 StridedSliceV2/V3；Transpose 的 ConfusionTranspose/DepthToSpace/SpaceToDepth；BroadcastTo 的 Expand/Tile；ArgMaxWithValue 的 ArgMaxV2/ArgMin/ArgMinWithValue；ReduceVar 的 ReduceStdV2；LayerNormV3 的 LayerNorm；AddRmsNorm 的 InplaceAddRmsNorm；pool_3d_common 的 AvgPool3D/MaxPool3D；Quantize 的 AscendQuantV2；以及卷积公共实现。共 32 个正式工程归入共享 kernel 分类。
证据：ops-math/conversion/strided_slice_v2/op_kernel/strided_slice_v2_apt.cpp:57

### Matmul 和 MC2 的公共搬运
BatchMatMulV3 的迭代 batch epilogue 将 tiling.needNdDma 传入 FusionAdd/Mul，再到 CopyFusionX3NdDma；三个 MC2 工程复用 mc2/3rd 的量化 per-block kernel，用多维 DMA 搬运 scale。3rd 副本不另计独立算子。
证据：ops-nn/matmul/common/cmct/kernel/kernel_matmul_iterbatch.h:299

## 固定版本

- ops-nn：master / `a998da60cced87f74339cbbed15178020fd2630c`。
- ops-math：master / `d42ee965cc810672ab7c3121d9d09c3e0bc45425`。
- ops-transformer：master / `7be990e05c319cdc1d2f80aef38d01d914b4bc97`。
- ops-cv：master / `f691c06aa5c69577cfa5f65633b0d7c5cd6963f8`。
- opbase：master / `e7bdd3e10277bc75312ca92961e8ee394c602e06`。

opbase 仅用于核实公共模板，不纳入四仓总量。原始仓库位于 C:\Users\wangy\Desktop\CODEX。

## 完整命中名单

### ops-nn

#### 显式 NDDMA（58）

- **confusion_softmax_grad** — [ops-nn/activation/confusion_softmax_grad/op_kernel/arch35/confusion_softmax_grad_ar_small_r.h:308](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/confusion_softmax_grad/op_kernel/arch35/confusion_softmax_grad_ar_small_r.h#L308)
- **fused_bias_leaky_relu_grad** — [ops-nn/activation/fused_bias_leaky_relu_grad/op_kernel/arch35/fused_bias_leaky_relu_grad_kernel.h:151](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/fused_bias_leaky_relu_grad/op_kernel/arch35/fused_bias_leaky_relu_grad_kernel.h#L151)
- **log_softmax_grad** — [ops-nn/activation/log_softmax_grad/op_kernel/arch35/log_softmax_grad_ar_small_r.h:283](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/log_softmax_grad/op_kernel/arch35/log_softmax_grad_ar_small_r.h#L283)
- **log_softmax_v2** — [ops-nn/activation/log_softmax_v2/op_kernel/arch35/log_softmax_v2_ar_small_r.h:280](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/log_softmax_v2/op_kernel/arch35/log_softmax_v2_ar_small_r.h#L280)
- **silu_grad** — [ops-nn/activation/silu_grad/op_kernel/arch35/silu_grad_bf16_nddma_with_loops.h:89](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/silu_grad/op_kernel/arch35/silu_grad_bf16_nddma_with_loops.h#L89)
- **softmax_cross_entropy_with_logits** — [ops-nn/activation/softmax_cross_entropy_with_logits/op_kernel/arch35/softmax_cross_entropy_with_logits_full_load.h:286](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/softmax_cross_entropy_with_logits/op_kernel/arch35/softmax_cross_entropy_with_logits_full_load.h#L286)
- **softmax_grad** — [ops-nn/activation/softmax_grad/op_kernel/arch35/softmax_grad_ar_small_r.h:283](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/softmax_grad/op_kernel/arch35/softmax_grad_ar_small_r.h#L283)
- **softmax_grad_ext** — [ops-nn/activation/softmax_grad_ext/op_kernel/arch35/softmax_grad_ext_ar_small_r.h:401](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/softmax_grad_ext/op_kernel/arch35/softmax_grad_ext_ar_small_r.h#L401)
- **softmax_v2** — [ops-nn/activation/softmax_v2/op_kernel/arch35/softmax_v2_ar_small_r.h:274](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/softmax_v2/op_kernel/arch35/softmax_v2_ar_small_r.h#L274)
- **softplus_v2_grad** — [ops-nn/activation/softplus_v2_grad/op_kernel/arch35/softplus_v2_grad_kernel.h:143](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/softplus_v2_grad/op_kernel/arch35/softplus_v2_grad_kernel.h#L143)
- **conv2d_v2** — [ops-nn/conv/conv2d_v2/op_kernel/arch35/conv2d_v2_depthwise_simplify.h:410](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/conv/conv2d_v2/op_kernel/arch35/conv2d_v2_depthwise_simplify.h#L410)
- **conv3d_backprop_input_v2** — [ops-nn/conv/conv3d_backprop_input_v2/op_kernel/arch35/convolution_3d_backprop/conv3d_bp_impl_base.h:162](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/conv/conv3d_backprop_input_v2/op_kernel/arch35/convolution_3d_backprop/conv3d_bp_impl_base.h#L162)
- **scatter_elements** — [ops-nn/index/scatter_elements/op_kernel/arch35/scatter_elements_deterministic.h:443](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/index/scatter_elements/op_kernel/arch35/scatter_elements_deterministic.h#L443)
- **scatter_elements_v2** — [ops-nn/index/scatter_elements_v2/op_kernel/arch35/scatter_elements_v2_deterministic.h:414](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/index/scatter_elements_v2/op_kernel/arch35/scatter_elements_v2_deterministic.h#L414)
- **sparse_slice** — [ops-nn/index/sparse_slice/op_kernel/arch35/sparse_slice_dimension_base.h:393](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/index/sparse_slice/op_kernel/arch35/sparse_slice_dimension_base.h#L393)
- **unique_with_counts_and_sorting** — [ops-nn/index/unique_with_counts_and_sorting/op_kernel/arch35/sort/unique_sort_small_axis_two_stage.h:192](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/index/unique_with_counts_and_sorting/op_kernel/arch35/sort/unique_sort_small_axis_two_stage.h#L192)
- **mse_loss_grad_v2** — [ops-nn/loss/mse_loss_grad_v2/op_kernel/arch35/mse_loss_grad_v2_kernel.h:177](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/mse_loss_grad_v2/op_kernel/arch35/mse_loss_grad_v2_kernel.h#L177)
- **soft_margin_loss_grad** — [ops-nn/loss/soft_margin_loss_grad/op_kernel/arch35/soft_margin_loss_grad.h:105](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/soft_margin_loss_grad/op_kernel/arch35/soft_margin_loss_grad.h#L105)
- **add_rms_norm** — [ops-nn/norm/add_rms_norm/op_kernel/arch35/add_rms_norm_regbase.h:312](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/add_rms_norm/op_kernel/arch35/add_rms_norm_regbase.h#L312)
- **add_rms_norm_cast** — [ops-nn/norm/add_rms_norm_cast/op_kernel/arch35/add_rms_norm_cast_regbase.h:114](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/add_rms_norm_cast/op_kernel/arch35/add_rms_norm_cast_regbase.h#L114)
- **batch_norm** — [ops-nn/norm/batch_norm/op_kernel/arch35/batch_norm_full_reduce.h:196](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/batch_norm/op_kernel/arch35/batch_norm_full_reduce.h#L196)
- **batch_norm3_d** — [ops-nn/norm/batch_norm3_d/op_kernel/arch35/batch_norm3d_full_reduce.h:196](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/batch_norm3_d/op_kernel/arch35/batch_norm3d_full_reduce.h#L196)
- **batch_norm_ext2** — [ops-nn/norm/batch_norm_ext2/op_kernel/arch35/batch_norm_ext2_full_reduce.h:196](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/batch_norm_ext2/op_kernel/arch35/batch_norm_ext2_full_reduce.h#L196)
- **batch_norm_grad_v3** — [ops-nn/norm/batch_norm_grad_v3/op_kernel/arch35/batch_norm_grad_v3_common.h:269](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/batch_norm_grad_v3/op_kernel/arch35/batch_norm_grad_v3_common.h#L269)
- **batch_norm_v3** — [ops-nn/norm/batch_norm_v3/op_kernel/arch35/batch_norm_v3.h:236](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/batch_norm_v3/op_kernel/arch35/batch_norm_v3.h#L236)
- **bn3_d_training_reduce_grad** — [ops-nn/norm/bn3_d_training_reduce_grad/op_kernel/arch35/bn3d_training_reduce_grad_kernel.h:742](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/bn3_d_training_reduce_grad/op_kernel/arch35/bn3d_training_reduce_grad_kernel.h#L742)
- **bn3d_training_update_grad** — [ops-nn/norm/bn3d_training_update_grad/op_kernel/arch35/bn3d_training_update_grad_base_kernel.h:639](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/bn3d_training_update_grad/op_kernel/arch35/bn3d_training_update_grad_base_kernel.h#L639)
- **bn_infer_grad** — [ops-nn/norm/bn_infer_grad/op_kernel/arch35/bn_infer_grad.h:114](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/bn_infer_grad/op_kernel/arch35/bn_infer_grad.h#L114)
- **bn_training_reduce** — [ops-nn/norm/bn_training_reduce/op_kernel/arch35/bn_training_reduce_small_r.h:154](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/bn_training_reduce/op_kernel/arch35/bn_training_reduce_small_r.h#L154)
- **bn_training_update** — [ops-nn/norm/bn_training_update/op_kernel/arch35/bn_training_update.h:297](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/bn_training_update/op_kernel/arch35/bn_training_update.h#L297)
- **dua_quantize_add_layer_norm** — [ops-nn/norm/dua_quantize_add_layer_norm/op_kernel/arch35/dua_quantize_add_layer_norm_base.h:1109](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/dua_quantize_add_layer_norm/op_kernel/arch35/dua_quantize_add_layer_norm_base.h#L1109)
- **gn_training_update** — [ops-nn/norm/gn_training_update/op_kernel/arch35/gn_training_update_kernel.h:192](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/gn_training_update/op_kernel/arch35/gn_training_update_kernel.h#L192)
- **group_norm_silu** — [ops-nn/norm/group_norm_silu/op_kernel/arch35/group_norm_silu_regbase_base.h:1583](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/group_norm_silu/op_kernel/arch35/group_norm_silu_regbase_base.h#L1583)
- **group_norm_silu_quant** — [ops-nn/norm/group_norm_silu_quant/op_kernel/arch35/group_norm_silu_quant_regbase_base.h:1754](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/group_norm_silu_quant/op_kernel/arch35/group_norm_silu_quant_regbase_base.h#L1754)
- **in_training_reduce_grad** — [ops-nn/norm/in_training_reduce_grad/op_kernel/arch35/in_training_reduce_grad.h:140](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/in_training_reduce_grad/op_kernel/arch35/in_training_reduce_grad.h#L140)
- **layer_norm_grad** — [ops-nn/norm/layer_norm_grad/op_kernel/arch35/layer_norm_grad_base.h:1011](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/layer_norm_grad/op_kernel/arch35/layer_norm_grad_base.h#L1011)
- **layer_norm_grad_v3** — [ops-nn/norm/layer_norm_grad_v3/op_kernel/arch35/layer_norm_grad_v3_base.h:1376](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/layer_norm_grad_v3/op_kernel/arch35/layer_norm_grad_v3_base.h#L1376)
- **layer_norm_v3** — [ops-nn/norm/layer_norm_v3/op_kernel/arch35/layer_norm_v3_norm_not_equal_params.h:169](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/layer_norm_v3/op_kernel/arch35/layer_norm_v3_norm_not_equal_params.h#L169)
- **rms_norm** — [ops-nn/norm/rms_norm/op_kernel/arch35/rms_norm_regbase.h:188](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/rms_norm/op_kernel/arch35/rms_norm_regbase.h#L188)
- **adam_apply_one_assign** — [ops-nn/optim/adam_apply_one_assign/op_kernel/arch35/adam_apply_one_assign_kernel.h:105](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/adam_apply_one_assign/op_kernel/arch35/adam_apply_one_assign_kernel.h#L105)
- **apply_adam_v2** — [ops-nn/optim/apply_adam_v2/op_kernel/arch35/apply_adam_v2_kernel.h:290](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/apply_adam_v2/op_kernel/arch35/apply_adam_v2_kernel.h#L290)
- **fused_mul_apply_keras_momentum** — [ops-nn/optim/fused_mul_apply_keras_momentum/op_kernel/arch35/fused_mul_apply_keras_momentum_kernel.h:121](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/fused_mul_apply_keras_momentum/op_kernel/arch35/fused_mul_apply_keras_momentum_kernel.h#L121)
- **fused_mul_apply_momentum** — [ops-nn/optim/fused_mul_apply_momentum/op_kernel/arch35/fused_mul_apply_momentum_kernel.h:86](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/fused_mul_apply_momentum/op_kernel/arch35/fused_mul_apply_momentum_kernel.h#L86)
- **inplace_apply_ada_max** — [ops-nn/optim/inplace_apply_ada_max/op_kernel/arch35/inplace_apply_ada_max.h:158](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/inplace_apply_ada_max/op_kernel/arch35/inplace_apply_ada_max.h#L158)
- **adaptive_avg_pool2d** — [ops-nn/pooling/adaptive_avg_pool2d/op_kernel/arch35/adaptive_pool2d_big_kernel.h:144](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/pooling/adaptive_avg_pool2d/op_kernel/arch35/adaptive_pool2d_big_kernel.h#L144)
- **adaptive_avg_pool2d_grad** — [ops-nn/pooling/adaptive_avg_pool2d_grad/op_kernel/arch35/adaptive_avg_pool2d_grad_big_kernel.h:249](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/pooling/adaptive_avg_pool2d_grad/op_kernel/arch35/adaptive_avg_pool2d_grad_big_kernel.h#L249)
- **adaptive_avg_pool3d_grad** — [ops-nn/pooling/adaptive_avg_pool3d_grad/op_kernel/arch35/adaptive_avg_pool3d_grad_ncdhw_big_kernel.h:317](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/pooling/adaptive_avg_pool3d_grad/op_kernel/arch35/adaptive_avg_pool3d_grad_ncdhw_big_kernel.h#L317)
- **avg_pool3_d_grad** — [ops-nn/pooling/avg_pool3_d_grad/op_kernel/arch35/avg_pool3_d_grad_ndhwc_kernel.h:527](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/pooling/avg_pool3_d_grad/op_kernel/arch35/avg_pool3_d_grad_ndhwc_kernel.h#L527)
- **max_pool3d_grad** — [ops-nn/pooling/max_pool3d_grad/op_kernel/arch35/max_pool3d_grad_ndhwc_impl_gather.h:681](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/pooling/max_pool3d_grad/op_kernel/arch35/max_pool3d_grad_ndhwc_impl_gather.h#L681)
- **acts_ulq** — [ops-nn/quant/acts_ulq/op_kernel/arch35/acts_ulq_kernel.h:162](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/quant/acts_ulq/op_kernel/arch35/acts_ulq_kernel.h#L162)
- **ascend_anti_quant_v2** — [ops-nn/quant/ascend_anti_quant_v2/op_kernel/arch35/ascend_anti_quant_v2_per_channel_nddma_regbase.h:173](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/quant/ascend_anti_quant_v2/op_kernel/arch35/ascend_anti_quant_v2_per_channel_nddma_regbase.h#L173)
- **ascend_requant** — [ops-nn/quant/ascend_requant/op_kernel/arch35/ascend_requant_kernel.h:97](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/quant/ascend_requant/op_kernel/arch35/ascend_requant_kernel.h#L97)
- **dequant_bias** — [ops-nn/quant/dequant_bias/op_kernel/arch35/dequant_bias_kernel.h:169](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/quant/dequant_bias/op_kernel/arch35/dequant_bias_kernel.h#L169)
- **dequantize** — [ops-nn/quant/dequantize/op_kernel/arch35/dequantize_min_combined_kernel.h:124](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/quant/dequantize/op_kernel/arch35/dequantize_min_combined_kernel.h#L124)
- **dynamic_mx_quant** — [ops-nn/quant/dynamic_mx_quant/op_kernel/arch35/dynamic_mx_quant_post.h:378](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/quant/dynamic_mx_quant/op_kernel/arch35/dynamic_mx_quant_post.h#L378)
- **quantize** — [ops-nn/quant/quantize/op_kernel/arch35/quantize_per_channel_nddma_no_offset_regbase.h:118](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/quant/quantize/op_kernel/arch35/quantize_per_channel_nddma_no_offset_regbase.h#L118)
- **wts_arq** — [ops-nn/quant/wts_arq/op_kernel/arch35/wts_arq_kernel.h:447](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/quant/wts_arq/op_kernel/arch35/wts_arq_kernel.h#L447)
- **thnn_fused_gru_cell** — [ops-nn/rnn/thnn_fused_gru_cell/op_kernel/arch35/thnn_fused_gru_cell_kernel.h:132](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/rnn/thnn_fused_gru_cell/op_kernel/arch35/thnn_fused_gru_cell_kernel.h#L132)

#### atvoss broadcast（25）

- **gelu_grad** — [ops-nn/activation/gelu_grad/op_kernel/gelu_grad_apt.cpp:29](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/gelu_grad/op_kernel/gelu_grad_apt.cpp#L29)
- **gelu_grad_v2** — [ops-nn/activation/gelu_grad_v2/op_kernel/gelu_grad_v2_apt.cpp:31](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/gelu_grad_v2/op_kernel/gelu_grad_v2_apt.cpp#L31)
- **leaky_relu_grad** — [ops-nn/activation/leaky_relu_grad/op_kernel/leaky_relu_grad_apt.cpp:30](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/leaky_relu_grad/op_kernel/leaky_relu_grad_apt.cpp#L30)
- **logsigmoid_grad** — [ops-nn/activation/logsigmoid_grad/op_kernel/logsigmoid_grad.cpp:31](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/logsigmoid_grad/op_kernel/logsigmoid_grad.cpp#L31)
- **p_relu** — [ops-nn/activation/p_relu/op_kernel/p_relu_apt.cpp:26](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/p_relu/op_kernel/p_relu_apt.cpp#L26)
- **p_relu_grad_update** — [ops-nn/activation/p_relu_grad_update/op_kernel/p_relu_grad_update_apt.cpp:33](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/p_relu_grad_update/op_kernel/p_relu_grad_update_apt.cpp#L33)
- **relu6_grad** — [ops-nn/activation/relu6_grad/op_kernel/relu6_grad_apt.cpp:32](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/relu6_grad/op_kernel/relu6_grad_apt.cpp#L32)
- **relu_grad** — [ops-nn/activation/relu_grad/op_kernel/relu_grad_apt.cpp:34](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/relu_grad/op_kernel/relu_grad_apt.cpp#L34)
- **softplus_grad** — [ops-nn/activation/softplus_grad/op_kernel/softplus_grad.cpp:40](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/softplus_grad/op_kernel/softplus_grad.cpp#L40)
- **threshold_grad_v2_d** — [ops-nn/activation/threshold_grad_v2_d/op_kernel/threshold_grad_v2_d.cpp:30](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/threshold_grad_v2_d/op_kernel/threshold_grad_v2_d.cpp#L30)
- **binary_cross_entropy_grad** — [ops-nn/loss/binary_cross_entropy_grad/op_kernel/binary_cross_entropy_grad.cpp:31](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/binary_cross_entropy_grad/op_kernel/binary_cross_entropy_grad.cpp#L31)
- **kl_div_loss_grad** — [ops-nn/loss/kl_div_loss_grad/op_kernel/kl_div_loss_grad.cpp:30](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/kl_div_loss_grad/op_kernel/kl_div_loss_grad.cpp#L30)
- **kl_div_target_loss_grad** — [ops-nn/loss/kl_div_target_loss_grad/op_kernel/kl_div_target_loss_grad_apt.cpp:30](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/kl_div_target_loss_grad/op_kernel/kl_div_target_loss_grad_apt.cpp#L30)
- **l1_loss_grad** — [ops-nn/loss/l1_loss_grad/op_kernel/l1_loss_grad.cpp:38](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/l1_loss_grad/op_kernel/l1_loss_grad.cpp#L38)
- **mse_loss_grad** — [ops-nn/loss/mse_loss_grad/op_kernel/mse_loss_grad.cpp:29](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/mse_loss_grad/op_kernel/mse_loss_grad.cpp#L29)
- **sigmoid_cross_entropy_with_logits_grad_v2** — [ops-nn/loss/sigmoid_cross_entropy_with_logits_grad_v2/op_kernel/sigmoid_cross_entropy_with_logits_grad_v2_apt.cpp:34](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/sigmoid_cross_entropy_with_logits_grad_v2/op_kernel/sigmoid_cross_entropy_with_logits_grad_v2_apt.cpp#L34)
- **sigmoid_cross_entropy_with_logits_v2** — [ops-nn/loss/sigmoid_cross_entropy_with_logits_v2/op_kernel/sigmoid_cross_entropy_with_logits_v2.cpp:32](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/sigmoid_cross_entropy_with_logits_v2/op_kernel/sigmoid_cross_entropy_with_logits_v2.cpp#L32)
- **smooth_l1_loss_grad_v2** — [ops-nn/loss/smooth_l1_loss_grad_v2/op_kernel/smooth_l1_loss_grad_v2.cpp:28](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/smooth_l1_loss_grad_v2/op_kernel/smooth_l1_loss_grad_v2.cpp#L28)
- **adam_apply_one** — [ops-nn/optim/adam_apply_one/op_kernel/arch35/adam_apply_one.cpp:33](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/adam_apply_one/op_kernel/arch35/adam_apply_one.cpp#L33)
- **adam_apply_one_with_decay** — [ops-nn/optim/adam_apply_one_with_decay/op_kernel/arch35/adam_apply_one_with_decay.cpp:33](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/adam_apply_one_with_decay/op_kernel/arch35/adam_apply_one_with_decay.cpp#L33)
- **adam_apply_one_with_decay_assign** — [ops-nn/optim/adam_apply_one_with_decay_assign/op_kernel/arch35/adam_apply_one_with_decay_assign.cpp:34](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/adam_apply_one_with_decay_assign/op_kernel/arch35/adam_apply_one_with_decay_assign.cpp#L34)
- **lamb_apply_weight_assign** — [ops-nn/optim/lamb_apply_weight_assign/op_kernel/lamb_apply_weight_assign.cpp:33](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/lamb_apply_weight_assign/op_kernel/lamb_apply_weight_assign.cpp#L33)
- **lamb_next_right** — [ops-nn/optim/lamb_next_right/op_kernel/lamb_next_right.cpp:32](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/lamb_next_right/op_kernel/lamb_next_right.cpp#L32)
- **lamb_update_with_lr** — [ops-nn/optim/lamb_update_with_lr/op_kernel/lamb_update_with_lr.cpp:33](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/lamb_update_with_lr/op_kernel/lamb_update_with_lr.cpp#L33)
- **lamb_update_with_lr_v2** — [ops-nn/optim/lamb_update_with_lr_v2/op_kernel/lamb_update_with_lr_v2.cpp:32](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/optim/lamb_update_with_lr_v2/op_kernel/lamb_update_with_lr_v2.cpp#L32)

#### atvoss reduce（9）

- **p_relu_grad_reduce** — [ops-nn/activation/p_relu_grad_reduce/op_kernel/p_relu_grad_reduce_apt.cpp:42](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/activation/p_relu_grad_reduce/op_kernel/p_relu_grad_reduce_apt.cpp#L42)
- **repeat_interleave_grad** — [ops-nn/index/repeat_interleave_grad/op_kernel/repeat_interleave_grad_apt.cpp:54](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/index/repeat_interleave_grad/op_kernel/repeat_interleave_grad_apt.cpp#L54)
- **binary_cross_entropy** — [ops-nn/loss/binary_cross_entropy/op_kernel/binary_cross_entropy.cpp:48](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/binary_cross_entropy/op_kernel/binary_cross_entropy.cpp#L48)
- **l2_loss** — [ops-nn/loss/l2_loss/op_kernel/l2_loss.cpp:42](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/l2_loss/op_kernel/l2_loss.cpp#L42)
- **lp_loss** — [ops-nn/loss/lp_loss/op_kernel/lp_loss.cpp:43](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/lp_loss/op_kernel/lp_loss.cpp#L43)
- **mse_loss** — [ops-nn/loss/mse_loss/op_kernel/mse_loss.cpp:43](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/mse_loss/op_kernel/mse_loss.cpp#L43)
- **smooth_l1_loss_v2** — [ops-nn/loss/smooth_l1_loss_v2/op_kernel/smooth_l1_loss_v2.cpp:46](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/smooth_l1_loss_v2/op_kernel/smooth_l1_loss_v2.cpp#L46)
- **soft_margin_loss** — [ops-nn/loss/soft_margin_loss/op_kernel/soft_margin_loss.cpp:41](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/loss/soft_margin_loss/op_kernel/soft_margin_loss.cpp#L41)
- **lp_norm_v2** — [ops-nn/norm/lp_norm_v2/op_kernel/lp_norm_v2_apt.cpp:52](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/lp_norm_v2/op_kernel/lp_norm_v2_apt.cpp#L52)

#### 共享 kernel（13）

- **conv3d_transpose_v2** — [ops-nn/conv/conv3d_backprop_input_v2/op_kernel/arch35/convolution_3d_backprop/conv3d_bp_impl_base.h:162](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/conv/conv3d_backprop_input_v2/op_kernel/arch35/convolution_3d_backprop/conv3d_bp_impl_base.h#L162)
- **conv3d_v2** — [ops-nn/conv/common/op_kernel/arch35/conv_instr_opt_group_impl.h:120](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/conv/common/op_kernel/arch35/conv_instr_opt_group_impl.h#L120)
- **extend_conv2d** — [ops-nn/conv/common/op_kernel/arch35/conv_instr_opt_group_impl.h:120](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/conv/common/op_kernel/arch35/conv_instr_opt_group_impl.h#L120)
- **extend_conv_transpose** — [ops-nn/conv/conv3d_backprop_input_v2/op_kernel/arch35/convolution_3d_backprop/conv3d_bp_impl_base.h:162](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/conv/conv3d_backprop_input_v2/op_kernel/arch35/convolution_3d_backprop/conv3d_bp_impl_base.h#L162)
- **extend_conv_transpose_v2** — [ops-nn/conv/conv3d_backprop_input_v2/op_kernel/arch35/convolution_3d_backprop/conv3d_bp_impl_base.h:162](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/conv/conv3d_backprop_input_v2/op_kernel/arch35/convolution_3d_backprop/conv3d_bp_impl_base.h#L162)
- **quant_conv2d** — [ops-nn/conv/common/op_kernel/arch35/conv_instr_opt_group_impl.h:120](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/conv/common/op_kernel/arch35/conv_instr_opt_group_impl.h#L120)
- **quant_conv3d** — [ops-nn/conv/common/op_kernel/arch35/conv_instr_opt_group_impl.h:120](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/conv/common/op_kernel/arch35/conv_instr_opt_group_impl.h#L120)
- **batch_mat_mul_v3** — [ops-nn/matmul/common/cmct/tile/x3_copy_utils.h:35](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/matmul/common/cmct/tile/x3_copy_utils.h#L35)
- **inplace_add_rms_norm** — [ops-nn/norm/add_rms_norm/op_kernel/arch35/add_rms_norm_regbase.h:312](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/add_rms_norm/op_kernel/arch35/add_rms_norm_regbase.h#L312)
- **layer_norm** — [ops-nn/norm/layer_norm_v3/op_kernel/arch35/layer_norm_v3_norm_not_equal_params.h:169](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/norm/layer_norm_v3/op_kernel/arch35/layer_norm_v3_norm_not_equal_params.h#L169)
- **avg_pool3_d** — [ops-nn/pooling/pool_3d_common/op_kernel/arch35/pool_3d_ncdhw_small_kernel.h:63](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/pooling/pool_3d_common/op_kernel/arch35/pool_3d_ncdhw_small_kernel.h#L63)
- **max_pool3_d** — [ops-nn/pooling/pool_3d_common/op_kernel/arch35/pool_3d_ncdhw_small_kernel.h:63](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/pooling/pool_3d_common/op_kernel/arch35/pool_3d_ncdhw_small_kernel.h#L63)
- **ascend_quant_v2** — [ops-nn/quant/quantize/op_kernel/arch35/quantize_per_head_regbase.h:241](https://gitcode.com/cann/ops-nn/blob/a998da60cced87f74339cbbed15178020fd2630c/quant/quantize/op_kernel/arch35/quantize_per_head_regbase.h#L241)

### ops-math

#### 显式 NDDMA（25）

- **as_strided** — [ops-math/conversion/as_strided/op_kernel/arch35/as_strided.h:261](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/as_strided/op_kernel/arch35/as_strided.h#L261)
- **broadcast_to** — [ops-math/conversion/broadcast_to/op_kernel/arch35/broadcast_to_with_dma.h:56](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/broadcast_to/op_kernel/arch35/broadcast_to_with_dma.h#L56)
- **clip_by_norm_no_div_sum** — [ops-math/conversion/clip_by_norm_no_div_sum/op_kernel/arch35/clip_by_norm_no_div_sum_kernel.h:145](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/clip_by_norm_no_div_sum/op_kernel/arch35/clip_by_norm_no_div_sum_kernel.h#L145)
- **dynamic_partition** — [ops-math/conversion/dynamic_partition/op_kernel/arch35/dynamic_partition_with_h_mc_small_w.h:129](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/dynamic_partition/op_kernel/arch35/dynamic_partition_with_h_mc_small_w.h#L129)
- **slice** — [ops-math/conversion/slice/op_kernel/arch35/slice_nddma.h:34](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/slice/op_kernel/arch35/slice_nddma.h#L34)
- **slice_last_dim** — [ops-math/conversion/slice_last_dim/op_kernel/arch35/slice_last_dim.h:131](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/slice_last_dim/op_kernel/arch35/slice_last_dim.h#L131)
- **strided_slice** — [ops-math/conversion/strided_slice/op_kernel/arch35/strided_slice_nddma.h:32](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/strided_slice/op_kernel/arch35/strided_slice_nddma.h#L32)
- **strided_slice_grad** — [ops-math/conversion/strided_slice_grad/op_kernel/arch35/split_all_axis_nddma.h:42](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/strided_slice_grad/op_kernel/arch35/split_all_axis_nddma.h#L42)
- **tile_with_axis** — [ops-math/conversion/tile_with_axis/op_kernel/arch35/tile_with_axis.h:127](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/tile_with_axis/op_kernel/arch35/tile_with_axis.h#L127)
- **transpose** — [ops-math/conversion/transpose/op_kernel/arch35/transpose_big_dim.h:51](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/transpose/op_kernel/arch35/transpose_big_dim.h#L51)
- **view_copy** — [ops-math/conversion/view_copy/op_kernel/arch35/view_copy_base.h:110](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/view_copy/op_kernel/arch35/view_copy_base.h#L110)
- **add_mat_mat_elements** — [ops-math/math/add_mat_mat_elements/op_kernel/arch35/add_mat_mat_elements.h:85](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/add_mat_mat_elements/op_kernel/arch35/add_mat_mat_elements.h#L85)
- **arg_max_with_value** — [ops-math/math/arg_max_with_value/op_kernel/arch35/arg_max_with_value_ara.h:613](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/arg_max_with_value/op_kernel/arch35/arg_max_with_value_ara.h#L613)
- **bias** — [ops-math/math/bias/op_kernel/arch35/bias_kernel.h:79](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/bias/op_kernel/arch35/bias_kernel.h#L79)
- **cdist** — [ops-math/math/cdist/op_kernel/broadcast_common.h:213](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/cdist/op_kernel/broadcast_common.h#L213)
- **cumsum** — [ops-math/math/cumsum/op_kernel/arch35/cumsum_base/cumsum_core_sklansky.h:246](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/cumsum/op_kernel/arch35/cumsum_base/cumsum_core_sklansky.h#L246)
- **lerp** — [ops-math/math/lerp/op_kernel/arch35/lerp_bf16_nddma_with_loops.h:83](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/lerp/op_kernel/arch35/lerp_bf16_nddma_with_loops.h#L83)
- **pow** — [ops-math/math/pow/op_kernel/arch35/pow_bf16_nddma_with_loops.h:79](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/pow/op_kernel/arch35/pow_bf16_nddma_with_loops.h#L79)
- **reduce_var** — [ops-math/math/reduce_var/op_kernel/arch35/reduce_var_sch.h:1489](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_var/op_kernel/arch35/reduce_var_sch.h#L1489)
- **scale** — [ops-math/math/scale/op_kernel/arch35/scale_kernel.h:102](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/scale/op_kernel/arch35/scale_kernel.h#L102)
- **sort** — [ops-math/math/sort/op_kernel/arch35/common/non_last_small_axis_base.h:169](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/sort/op_kernel/arch35/common/non_last_small_axis_base.h#L169)
- **tanh_grad** — [ops-math/math/tanh_grad/op_kernel/arch35/tanh_grad_bf16_nddma_with_loops.h:80](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/tanh_grad/op_kernel/arch35/tanh_grad_bf16_nddma_with_loops.h#L80)
- **xdivy** — [ops-math/math/xdivy/op_kernel/arch35/xdivy_kernel.h:110](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/xdivy/op_kernel/arch35/xdivy_kernel.h#L110)
- **xlog1py** — [ops-math/math/xlog1py/op_kernel/arch35/xlog1py_kernel.h:105](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/xlog1py/op_kernel/arch35/xlog1py_kernel.h#L105)
- **xlogy** — [ops-math/math/xlogy/op_kernel/arch35/xlogy_kernel.h:117](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/xlogy/op_kernel/arch35/xlogy_kernel.h#L117)

#### atvoss broadcast（47）

- **clip_by_value** — [ops-math/conversion/clip_by_value/op_kernel/arch35/clip_by_value.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/clip_by_value/op_kernel/arch35/clip_by_value.cpp#L29)
- **clip_by_value_v2** — [ops-math/conversion/clip_by_value_v2/op_kernel/arch35/clip_by_value_v2.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/clip_by_value_v2/op_kernel/arch35/clip_by_value_v2.cpp#L29)
- **masked_fill** — [ops-math/conversion/masked_fill/op_kernel/masked_fill_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/masked_fill/op_kernel/masked_fill_apt.cpp#L29)
- **add** — [ops-math/math/add/op_kernel/arch35/add.cpp:37](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/add/op_kernel/arch35/add.cpp#L37)
- **add_v2** — [ops-math/math/add_v2/op_kernel/arch35/add_v2.cpp:42](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/add_v2/op_kernel/arch35/add_v2.cpp#L42)
- **addcdiv** — [ops-math/math/addcdiv/op_kernel/addcdiv_apt.cpp:28](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/addcdiv/op_kernel/addcdiv_apt.cpp#L28)
- **addcmul** — [ops-math/math/addcmul/op_kernel/addcmul_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/addcmul/op_kernel/addcmul_apt.cpp#L29)
- **addr** — [ops-math/math/addr/op_kernel/addr.cpp:30](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/addr/op_kernel/addr.cpp#L30)
- **atan2** — [ops-math/math/atan2/op_kernel/atan2_apt.cpp:34](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/atan2/op_kernel/atan2_apt.cpp#L34)
- **axpy** — [ops-math/math/axpy/op_kernel/axpy_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/axpy/op_kernel/axpy_apt.cpp#L29)
- **axpy_v2** — [ops-math/math/axpy_v2/op_kernel/axpy_v2_apt.cpp:33](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/axpy_v2/op_kernel/axpy_v2_apt.cpp#L33)
- **bias_add** — [ops-math/math/bias_add/op_kernel/bias_add_apt.cpp:28](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/bias_add/op_kernel/bias_add_apt.cpp#L28)
- **bitwise_and** — [ops-math/math/bitwise_and/op_kernel/bitwise_and_apt.cpp:27](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/bitwise_and/op_kernel/bitwise_and_apt.cpp#L27)
- **bitwise_or** — [ops-math/math/bitwise_or/op_kernel/bitwise_or_apt.cpp:27](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/bitwise_or/op_kernel/bitwise_or_apt.cpp#L27)
- **bitwise_xor** — [ops-math/math/bitwise_xor/op_kernel/bitwise_xor_apt.cpp:27](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/bitwise_xor/op_kernel/bitwise_xor_apt.cpp#L27)
- **complex** — [ops-math/math/complex/op_kernel/arch35/complex.h:38](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/complex/op_kernel/arch35/complex.h#L38)
- **div** — [ops-math/math/div/op_kernel/div_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/div/op_kernel/div_apt.cpp#L29)
- **div_no_nan** — [ops-math/math/div_no_nan/op_kernel/div_no_nan_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/div_no_nan/op_kernel/div_no_nan_apt.cpp#L29)
- **equal** — [ops-math/math/equal/op_kernel/equal_apt.cpp:28](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/equal/op_kernel/equal_apt.cpp#L28)
- **floor_div** — [ops-math/math/floor_div/op_kernel/floor_div_apt.cpp:28](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/floor_div/op_kernel/floor_div_apt.cpp#L28)
- **floor_mod** — [ops-math/math/floor_mod/op_kernel/floor_mod_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/floor_mod/op_kernel/floor_mod_apt.cpp#L29)
- **fused_mul_add** — [ops-math/math/fused_mul_add/op_kernel/fused_mul_add_apt.cpp:31](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/fused_mul_add/op_kernel/fused_mul_add_apt.cpp#L31)
- **fused_mul_add_add** — [ops-math/math/fused_mul_add_add/op_kernel/fused_mul_add_add_apt.cpp:31](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/fused_mul_add_add/op_kernel/fused_mul_add_add_apt.cpp#L31)
- **gcd** — [ops-math/math/gcd/op_kernel/gcd_apt.cpp:28](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/gcd/op_kernel/gcd_apt.cpp#L28)
- **ger** — [ops-math/math/ger/op_kernel/ger_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/ger/op_kernel/ger_apt.cpp#L29)
- **greater** — [ops-math/math/greater/op_kernel/greater_apt.cpp:24](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/greater/op_kernel/greater_apt.cpp#L24)
- **greater_equal** — [ops-math/math/greater_equal/op_kernel/greater_equal_apt.cpp:24](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/greater_equal/op_kernel/greater_equal_apt.cpp#L24)
- **is_close** — [ops-math/math/is_close/op_kernel/is_close_apt.cpp:30](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/is_close/op_kernel/is_close_apt.cpp#L30)
- **less** — [ops-math/math/less/op_kernel/less_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/less/op_kernel/less_apt.cpp#L29)
- **less_equal** — [ops-math/math/less_equal/op_kernel/less_equal_apt.cpp:28](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/less_equal/op_kernel/less_equal_apt.cpp#L28)
- **log_add_exp** — [ops-math/math/log_add_exp/op_kernel/log_add_exp_apt.cpp:33](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/log_add_exp/op_kernel/log_add_exp_apt.cpp#L33)
- **logical_and** — [ops-math/math/logical_and/op_kernel/logical_and_apt.cpp:27](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/logical_and/op_kernel/logical_and_apt.cpp#L27)
- **logical_or** — [ops-math/math/logical_or/op_kernel/logical_or_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/logical_or/op_kernel/logical_or_apt.cpp#L29)
- **maximum** — [ops-math/math/maximum/op_kernel/maximum_apt.cpp:28](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/maximum/op_kernel/maximum_apt.cpp#L28)
- **minimum** — [ops-math/math/minimum/op_kernel/minimum_apt.cpp:28](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/minimum/op_kernel/minimum_apt.cpp#L28)
- **mod** — [ops-math/math/mod/op_kernel/mod_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/mod/op_kernel/mod_apt.cpp#L29)
- **mul** — [ops-math/math/mul/op_kernel/mul_apt.cpp:30](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/mul/op_kernel/mul_apt.cpp#L30)
- **mul_no_nan** — [ops-math/math/mul_no_nan/op_kernel/mul_no_nan_apt.cpp:31](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/mul_no_nan/op_kernel/mul_no_nan_apt.cpp#L31)
- **not_equal** — [ops-math/math/not_equal/op_kernel/not_equal_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/not_equal/op_kernel/not_equal_apt.cpp#L29)
- **real_div** — [ops-math/math/real_div/op_kernel/real_div_apt.cpp:28](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/real_div/op_kernel/real_div_apt.cpp#L28)
- **right_shift** — [ops-math/math/right_shift/op_kernel/right_shift_apt.cpp:30](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/right_shift/op_kernel/right_shift_apt.cpp#L30)
- **select** — [ops-math/math/select/op_kernel/select_apt.cpp:37](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/select/op_kernel/select_apt.cpp#L37)
- **select_v2** — [ops-math/math/select_v2/op_kernel/select_v2_apt.cpp:28](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/select_v2/op_kernel/select_v2_apt.cpp#L28)
- **squared_difference** — [ops-math/math/squared_difference/op_kernel/squared_difference_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/squared_difference/op_kernel/squared_difference_apt.cpp#L29)
- **sub** — [ops-math/math/sub/op_kernel/sub_apt.cpp:32](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/sub/op_kernel/sub_apt.cpp#L32)
- **truncate_div** — [ops-math/math/truncate_div/op_kernel/truncate_div_apt.cpp:25](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/truncate_div/op_kernel/truncate_div_apt.cpp#L25)
- **truncate_mod** — [ops-math/math/truncate_mod/op_kernel/truncate_mod_apt.cpp:24](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/truncate_mod/op_kernel/truncate_mod_apt.cpp#L24)

#### atvoss reduce（18）

- **bias_add_grad** — [ops-math/math/bias_add_grad/op_kernel/bias_add_grad_apt.cpp:42](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/bias_add_grad/op_kernel/bias_add_grad_apt.cpp#L42)
- **cdist_grad** — [ops-math/math/cdist_grad/op_kernel/cdist_grad_apt.cpp:29](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/cdist_grad/op_kernel/cdist_grad_apt.cpp#L29)
- **dot** — [ops-math/math/dot/op_kernel/dot_apt.cpp:41](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/dot/op_kernel/dot_apt.cpp#L41)
- **grouped_bias_add_grad** — [ops-math/math/grouped_bias_add_grad/op_kernel/grouped_bias_add_grad_apt.cpp:50](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/grouped_bias_add_grad/op_kernel/grouped_bias_add_grad_apt.cpp#L50)
- **kl_div** — [ops-math/math/kl_div/op_kernel/kl_div_apt.cpp:44](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/kl_div/op_kernel/kl_div_apt.cpp#L44)
- **kl_div_v2** — [ops-math/math/kl_div_v2/op_kernel/kl_div_v2_apt.cpp:48](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/kl_div_v2/op_kernel/kl_div_v2_apt.cpp#L48)
- **reduce_all** — [ops-math/math/reduce_all/op_kernel/reduce_all_apt.cpp:41](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_all/op_kernel/reduce_all_apt.cpp#L41)
- **reduce_any** — [ops-math/math/reduce_any/op_kernel/reduce_any_apt.cpp:41](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_any/op_kernel/reduce_any_apt.cpp#L41)
- **reduce_log_sum** — [ops-math/math/reduce_log_sum/op_kernel/reduce_log_sum_apt.cpp:41](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_log_sum/op_kernel/reduce_log_sum_apt.cpp#L41)
- **reduce_log_sum_exp** — [ops-math/math/reduce_log_sum_exp/op_kernel/reduce_log_sum_exp_apt.cpp:64](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_log_sum_exp/op_kernel/reduce_log_sum_exp_apt.cpp#L64)
- **reduce_max** — [ops-math/math/reduce_max/op_kernel/reduce_max_apt.cpp:61](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_max/op_kernel/reduce_max_apt.cpp#L61)
- **reduce_mean** — [ops-math/math/reduce_mean/op_kernel/reduce_mean_apt.cpp:41](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_mean/op_kernel/reduce_mean_apt.cpp#L41)
- **reduce_mean_with_count** — [ops-math/math/reduce_mean_with_count/op_kernel/reduce_mean_with_count_apt.cpp:52](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_mean_with_count/op_kernel/reduce_mean_with_count_apt.cpp#L52)
- **reduce_min** — [ops-math/math/reduce_min/op_kernel/reduce_min_apt.cpp:60](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_min/op_kernel/reduce_min_apt.cpp#L60)
- **reduce_nansum** — [ops-math/math/reduce_nansum/op_kernel/reduce_nansum_apt.cpp:55](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_nansum/op_kernel/reduce_nansum_apt.cpp#L55)
- **reduce_prod** — [ops-math/math/reduce_prod/op_kernel/reduce_prod_apt.cpp:42](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_prod/op_kernel/reduce_prod_apt.cpp#L42)
- **reduce_sum** — [ops-math/math/reduce_sum/op_kernel/reduce_sum_apt.cpp:43](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_sum/op_kernel/reduce_sum_apt.cpp#L43)
- **square_sum_v1** — [ops-math/math/square_sum_v1/op_kernel/square_sum_v1_apt.cpp:49](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/square_sum_v1/op_kernel/square_sum_v1_apt.cpp#L49)

#### 共享 kernel（16）

- **confusion_transpose_d** — [ops-math/conversion/transpose/op_kernel/arch35/transpose_cut_one_axis.h:66](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/transpose/op_kernel/arch35/transpose_cut_one_axis.h#L66)
- **depth_to_space** — [ops-math/conversion/transpose/op_kernel/arch35/transpose_cut_one_axis.h:66](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/transpose/op_kernel/arch35/transpose_cut_one_axis.h#L66)
- **mirror_pad** — [ops-math/conversion/slice/op_kernel/arch35/slice_nddma.h:34](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/slice/op_kernel/arch35/slice_nddma.h#L34)
- **pad** — [ops-math/conversion/slice/op_kernel/arch35/slice_nddma.h:34](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/slice/op_kernel/arch35/slice_nddma.h#L34)
- **pad_v2** — [ops-math/conversion/slice/op_kernel/arch35/slice_nddma.h:34](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/slice/op_kernel/arch35/slice_nddma.h#L34)
- **pad_v3** — [ops-math/conversion/slice/op_kernel/arch35/slice_nddma.h:34](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/slice/op_kernel/arch35/slice_nddma.h#L34)
- **space_to_depth** — [ops-math/conversion/transpose/op_kernel/arch35/transpose_cut_one_axis.h:66](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/transpose/op_kernel/arch35/transpose_cut_one_axis.h#L66)
- **strided_slice_v2** — [ops-math/conversion/strided_slice/op_kernel/arch35/strided_slice_nddma.h:32](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/strided_slice/op_kernel/arch35/strided_slice_nddma.h#L32)
- **strided_slice_v3** — [ops-math/conversion/strided_slice/op_kernel/arch35/strided_slice_nddma.h:32](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/strided_slice/op_kernel/arch35/strided_slice_nddma.h#L32)
- **arg_max_v2** — [ops-math/math/arg_max_with_value/op_kernel/arch35/arg_max_with_value_ara.h:613](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/arg_max_with_value/op_kernel/arch35/arg_max_with_value_ara.h#L613)
- **arg_min** — [ops-math/math/arg_max_with_value/op_kernel/arch35/arg_max_with_value_ara.h:613](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/arg_max_with_value/op_kernel/arch35/arg_max_with_value_ara.h#L613)
- **arg_min_with_value** — [ops-math/math/arg_max_with_value/op_kernel/arch35/arg_max_with_value_ara.h:613](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/arg_max_with_value/op_kernel/arch35/arg_max_with_value_ara.h#L613)
- **expand** — [ops-math/conversion/broadcast_to/op_kernel/arch35/broadcast_to_with_dma.h:56](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/broadcast_to/op_kernel/arch35/broadcast_to_with_dma.h#L56)
- **reduce_std_v2** — [ops-math/math/reduce_var/op_kernel/arch35/reduce_var_sch.h:1489](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/reduce_var/op_kernel/arch35/reduce_var_sch.h#L1489)
- **tile** — [ops-math/conversion/broadcast_to/op_kernel/arch35/broadcast_to_with_dma.h:56](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/conversion/broadcast_to/op_kernel/arch35/broadcast_to_with_dma.h#L56)
- **top_k_v2** — [ops-math/math/sort/op_kernel/arch35/common/non_last_small_axis_base.h:169](https://gitcode.com/cann/ops-math/blob/d42ee965cc810672ab7c3121d9d09c3e0bc45425/math/sort/op_kernel/arch35/common/non_last_small_axis_base.h#L169)

### ops-transformer

#### 显式 NDDMA（2）

- **gather_pa_kv_cache** — [ops-transformer/attention/gather_pa_kv_cache/op_kernel/arch35/gather_pa_kv_cache_nz.h:344](https://gitcode.com/cann/ops-transformer/blob/7be990e05c319cdc1d2f80aef38d01d914b4bc97/attention/gather_pa_kv_cache/op_kernel/arch35/gather_pa_kv_cache_nz.h#L344)
- **kv_rms_norm_rope_cache** — [ops-transformer/posembedding/kv_rms_norm_rope_cache/op_kernel/arch35/kv_rms_norm_rope_cache_regbase_base.h:319](https://gitcode.com/cann/ops-transformer/blob/7be990e05c319cdc1d2f80aef38d01d914b4bc97/posembedding/kv_rms_norm_rope_cache/op_kernel/arch35/kv_rms_norm_rope_cache_regbase_base.h#L319)

#### atvoss reduce（2）

- **apply_rotary_pos_emb_grad** — [ops-transformer/posembedding/apply_rotary_pos_emb_grad/op_kernel/apply_rotary_pos_emb_grad_apt.cpp:145](https://gitcode.com/cann/ops-transformer/blob/7be990e05c319cdc1d2f80aef38d01d914b4bc97/posembedding/apply_rotary_pos_emb_grad/op_kernel/apply_rotary_pos_emb_grad_apt.cpp#L145)
- **rotary_position_embedding_grad** — [ops-transformer/posembedding/rotary_position_embedding_grad/op_kernel/rotary_position_embedding_grad_apt.cpp:126](https://gitcode.com/cann/ops-transformer/blob/7be990e05c319cdc1d2f80aef38d01d914b4bc97/posembedding/rotary_position_embedding_grad/op_kernel/rotary_position_embedding_grad_apt.cpp#L126)

#### 共享 kernel（3）

- **all_gather_matmul_v2** — [ops-transformer/mc2/3rd/quant_batch_matmul_v3/op_kernel/arch35/qbmm_perblock_api_utils.h:123](https://gitcode.com/cann/ops-transformer/blob/7be990e05c319cdc1d2f80aef38d01d914b4bc97/mc2/3rd/quant_batch_matmul_v3/op_kernel/arch35/qbmm_perblock_api_utils.h#L123)
- **matmul_all_reduce** — [ops-transformer/mc2/3rd/quant_batch_matmul_v3/op_kernel/arch35/qbmm_perblock_api_utils.h:123](https://gitcode.com/cann/ops-transformer/blob/7be990e05c319cdc1d2f80aef38d01d914b4bc97/mc2/3rd/quant_batch_matmul_v3/op_kernel/arch35/qbmm_perblock_api_utils.h#L123)
- **matmul_reduce_scatter_v2** — [ops-transformer/mc2/3rd/quant_batch_matmul_v3/op_kernel/arch35/qbmm_perblock_api_utils.h:123](https://gitcode.com/cann/ops-transformer/blob/7be990e05c319cdc1d2f80aef38d01d914b4bc97/mc2/3rd/quant_batch_matmul_v3/op_kernel/arch35/qbmm_perblock_api_utils.h#L123)

### ops-cv

#### 显式 NDDMA（2）

- **nms_with_mask** — [ops-cv/image/nms_with_mask/op_kernel/arch35/nms_with_mask_regbase_multiprocess.h:169](https://gitcode.com/cann/ops-cv/blob/f691c06aa5c69577cfa5f65633b0d7c5cd6963f8/image/nms_with_mask/op_kernel/arch35/nms_with_mask_regbase_multiprocess.h#L169)
- **points_in_polygons** — [ops-cv/image/points_in_polygons/op_kernel/arch35/points_in_polygons.h:364](https://gitcode.com/cann/ops-cv/blob/f691c06aa5c69577cfa5f65633b0d7c5cd6963f8/image/points_in_polygons/op_kernel/arch35/points_in_polygons.h#L364)
