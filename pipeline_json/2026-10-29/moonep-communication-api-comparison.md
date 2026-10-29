# MoonEP：cannbot-dsl 通信接口与当前 PyPTO 实现对照

日期：2026-10-29（Asia/Shanghai）。范围：最初分析的 cannbot-dsl PR 238 七 kernel 版本中的 Exchange 通信流程，与已提交 pypto-gym PR #1 的实现候选。

## 版本与结论

- cannbot-dsl 基准：eb25c890295aa83cb35f7aed4d344f2b84a7ff04。后续 master 已有融合 kernel，不能把原七 kernel 的结构当作最新 master 结构。
- 当前移植：wangyu_ai/pypto-gym，feat/moonep-plan-pypto 分支；实现模块 op_kernel/moonep_plan.py 的计算与通信逻辑对应提交 1db6992，后续 60a9507 仅补充验证说明。
- PyPTO 接口核查：官方源码提交 4a9f18d77b0959299c92f233fe5777e596b31bb3。下文“未找到”限于该源码的接口、解析器和所检查示例，不是对未来版本或所有后端的否定。
- 当前并非逐接口移植 Exchange：用一条 PyTorch distributed collective 收集全部 tpe，在 NPU/HCCL 环境下由 HCCL 承担通信；六阶段规划计算采用原生 PyPTO-Pro SIMT。
- PyPTO Tensor 层已有 SHMEM 通信；当前候选没有采用它。不能把“Tensor 层有接口”写成“当前 Pro kernel 已实现或已验证”。

## 接口对照表

| cannbot-dsl 接口/机制 | 原实现功能 | 当前候选实际采用什么 | PyPTO 已找到的相关能力 | 替代程度与限制 |
| --- | --- | --- | --- | --- |
| get_comm_context(CommContext, group_name, op_name=...) | 在 context 创建时取得设备通信上下文 | 仍使用外部 moonep_context；计数交换使用 context.group 对应的 PyTorch ProcessGroup | Tensor 的 create_shmem_tensor 等按 group_name 接入；Pro 未找到对应 CommContext 桥接入口 | 未完成基础设施迁移。原 context 仍依赖 cannbotdsl；不是完全摆脱原框架 |
| ctx: StructRef[CommContext] | 将设备通信上下文传入 Exchange | 新 Pro JIT 不接收 ctx_tensor；host wrapper 调用 distributed collective | Pro 有普通 Tensor/Ptr 类型，但未确认它们能直接承载并消费原通信 context | 通过通信外置绕开，不是同类型替换 |
| SymBuffer(ctx, shape=(MAX_R,MAX_E), base_offset=DEM_ALL_OFF) | 描述对称堆内计数交换区 | 普通 torch.empty((R,E),int32,device=NPU) 输出缓冲；HCCL 管理实际传输 | Tensor: create_shmem_tensor | 当前不创建自己的计数对称窗口；原 context 本身仍可能申请其原有通信区域 |
| SymBuffer(...,shape=(MAX_R,),base_offset=READY_OFF) | 保存各来源发布的 epoch/ready 标记 | 不再创建 plan 的 ready 数组，由 collective 完成机制衔接后续消费 | Tensor: create_shmem_signal、shmem_signal | 删除手写协议，没有保留可直接观察的 ready[r] |
| tile_slice(sym,...).peer(p) | 指定目标卡 p 的对称内存子区域 | 无逐 peer 寻址；collective 接收缓冲按组内 rank 顺序组织 | Tensor: shmem_view 加 shmem_put 的 dst_pe/offsets | 不保留低层 peer 访问控制；Pro 未找到对应入口 |
| create_transfer_context(ctx,ub_xfer,role=TransferRole.VEC) | 建立设备侧传输操作上下文 | 不创建 transfer context；由 HCCL 后端管理 | Tensor SHMEM 算子由图/运行时组织；Pro 未找到同类公开 transfer context | 管理权转移到 collective 库 |
| Buffer(UB,(512,),uint8) | 为传输上下文提供辅助 UB 缓冲 | 无此缓冲声明 | Pro 支持 Vec/UB Tile，但普通本地 Tile 不是跨卡传输上下文 | 该辅助资源随手写传输流程取消；HCCL 内部资源不据此归零 |
| xfer.put(p,remote_dem_row,gm_tpe) | 将本 rank 的 E 个计数写入其他卡的来源行 | dist.all_gather_into_tensor(dem.view(-1),tokens_per_expert,group=group) | Tensor: shmem_put；另有 shmem_get | 收集计数的数据目的相同，协议、算法、流和资源行为不保证相同 |
| xfer.put(p,remote_ready_slot,gm_flag) | 数据发送后发布本轮 epoch | 当前没有显式 signal 发送，随 collective 一并交给 HCCL | Tensor: shmem_signal(...,pred=[put_out]) | 未保留原 epoch 握手；不能说当前代码在用 Tensor shmem_signal |
| xfer.flush(p) | 发送侧逐 peer flush，配合数据/标记协议 | 没有同名调用；依赖 collective 的完成和流衔接机制 | Tensor 通信用返回的依赖张量及 pred 连接；未找到同形式公开 per-peer flush | 不声称 pred 与 flush 完全等价；远端可见性需真实环境核验 |
| busy_wait_flag(ready[r],gm_flag,event_id) | 在本卡轮询，等待来源 r 的标记达到本轮 epoch | 不执行自定义轮询，由 HCCL collective 管理通信完成 | Tensor: shmem_wait_until | 不是同样的设备自旋实现，延迟/同步行为不同 |
| received_flag >= expected_epoch | 防止把上一次 ready 值当成本轮通知 | 无显式 epoch 比较 | Tensor shmem_wait_until 文档目前只声明 EQ；clear_signal 可用于信号消费协议 | EQ 与 GE 不等价，原 epoch 协议不可原样套用；是否可扩展需编译/运行证据 |
| vec_sync_notify / vec_sync_wait，PIPE.S 与 PIPE.MTE2 | 在轮询中协调标量流水与搬运流水，等待 flag 拷入 UB 再比较 | 计数交换不手写流水事件；后续 Pro 启动消费 collective 结果 | Pro: pl.system.sync_src / sync_dst；本地流水同步 | 有本地同步能力，但它不负责跨卡数据到达，不能拿来代替远端 signal |
| mem_copy(ub_tpe,gm_tpe) 后写本地 dem_all[me] | 补齐自己的计数行，避免给自己做远端 put | collective 自然包含本 rank 输入 | Pro: pl.load/store 与 SIMT 本地 GM 访问 | 当前不需要独立自拷贝步骤；内部复制实现由 collective 决定 |
| mem_copy(ub_dem,dem_all) → gm_dem_by_rank | 收齐后从通信区搬到普通计算工作表 | collective 直接写 dem[R,E]，该张量传入 plan_from_dem | Tensor: SHMEM 取数接口；Pro 本地搬运能力 | 当前省去显式 dem_all→UB→dem 工作表的两步，但不能据此推导物理流量或性能提升 |
| _EPOCH += 1、每轮 gm_flag 张量 | 进程内单调调用序号，收发方按相同调用序列配合 | 新 plan 不使用该 epoch；仍要求各 rank collective 调用顺序一致 | Tensor signal/wait 支持另一套图依赖和信号流程 | 不能将删除显式 epoch 理解为支持乱序或任意并发 |
| sync_transport_stream(context) | context 跨流时用事件衔接调用顺序 | 当前仍直接调用外部原实现 | PyTorch NPU stream/event 可承载该 host 机制 | 保留外部依赖，未重写为 Pro；还需验证 HCCL 内部通信流与调用流的交互 |
| check_no_shared_elastic_buffer(group_name) | 检查 context 与 ElasticBuffer 通信域分离约束 | 当前仍直接调用外部原实现 | 不属于单个设备指令，而是集成期通信器隔离检查 | 未移除原对称堆约束；HCCL collective 与原窗口共存仍待验收 |

## 当前候选的真实执行路径

```text
外部 cannbot-dsl MoonepContext
    │ context.group + rank/rank_size
    ▼
PyTorch dist.all_gather_into_tensor（NPU 环境采用 HCCL）
    │ 普通设备张量 dem[R,E]
    ▼
plan_from_dem：输入验证与分配
    ▼
PyPTO-Pro 六阶段 SIMT：Init → Greedy → Tables/cu → Count → Prefix → Assign
    ▼
(dst_n零占位, cu, experts_to_copy, src_n零占位, vtopk)
```

表格描述的替换只覆盖 plan。prefetch_weight/reduce_grad 仍用原 cannbot-dsl 通信实现；dispatch/combine 仍由 ElasticBuffer 承担。

## Tensor SHMEM 路线与 Pro 缺口

Tensor 层源码包含 create_shmem_tensor、create_shmem_signal、shmem_view、shmem_put、shmem_get、shmem_signal、shmem_wait_until、shmem_barrier_all、shmem_clear_data 和 shmem_clear_signal。官方 test_allgather_matmul 示例通过 put_out → signal(pred=[put_out]) 连接数据发送与通知，再使用 EQ+clear_signal 等待、消费通知。

若要在 Pro 内复刻原 Exchange，仍需确认/补齐：通信组与设备 context 接入、对称内存类型和 peer 地址映射、设备远端传输、完成/发布顺序、远端信号等待与重复调用协议，以及相关对象在 Pro JIT/SIMT 的解析和运行时支持。

pl.system.sync_all、跨核事件和 pl.simt.threadfence 都不能直接作为跨卡 barrier/flush 的证明：它们的设备内同步或可见性范围与远端传输不同。

## 验证状态

- 已完成：原仓库 CPU golden 28 passed；迁移后同源 SIMT CPU 语义测试 8 组通过；静态检查无违规。
- 尚未完成：Pro 原生编译、NPU 数值、HCCL 多 rank 集成和原仓库完整多卡 E2E；官方 CAModel/cannsim 仿真也未执行。
- CPU 语义测试不执行 HCCL，不证明本表中 collective、流衔接或跨卡内存模型正确。
- 当前候选含数据校验与状态回读，不保留原 plan 返回路径零同步特性；未做性能结论。

## 源码与提交

- [原 DSL PR 238](https://gitcode.com/cann/cannbot-dsl/pull/238)
- [当前 PyPTO 候选 PR #1](https://gitcode.com/wangyu_ai/pypto-gym/merge_requests/1)
- [当前候选源文件](https://gitcode.com/wangyu_ai/pypto-gym/blob/60a9507/ops/pypto_pro/experimental/moonep_plan/op_kernel/moonep_plan.py)
- [PyPTO Tensor 通信源码](https://gitcode.com/cann/pypto/blob/4a9f18d77b0959299c92f233fe5777e596b31bb3/python/pypto/op/distributed.py)
- [官方 all-gather 示例](https://gitcode.com/cann/pypto/blob/4a9f18d77b0959299c92f233fe5777e596b31bb3/python/tests/st/operator/distributed/test_allgather_matmul.py)
- [Pro 流水与核内同步 API](https://gitcode.com/cann/pypto/blob/4a9f18d77b0959299c92f233fe5777e596b31bb3/python/pypto_pro/language/_system_api.py)
- [Pro SIMT 内存 fence API](https://gitcode.com/cann/pypto/blob/4a9f18d77b0959299c92f233fe5777e596b31bb3/python/pypto_pro/language/_simt_api.py)
