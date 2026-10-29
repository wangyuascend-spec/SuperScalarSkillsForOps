# moonep_plan 算子功能与实现分析

整理日期：2026-10-29。本文对应 cannbot-dsl PR 238 固定提交 eb25c890295aa83cb35f7aed4d344f2b84a7ff04 的七 kernel 版本。后续 master 已有融合实现，本文不代表最新 master 的 kernel 数量。

## 1. 功能：决定哪些专家任务在哪张卡上处理

MoE router 为每个 token 选择 K 个专家。传统专家并行把每个专家固定放在一张卡上，热门专家可能让这张卡过载。MoonEP 允许在其他 rank 创建专家副本，以分担计算。

moonep_plan 读取路由计数和 top-k，决定：每个专家在各 rank 上处理多少任务、哪些 rank 需要预取远程专家权重、每个本地 token 的每个专家任务发往哪个实例。

它不计算 FFN，也不搬 hidden 或专家权重。token 分发由 ElasticBuffer.dispatch 完成；权重搬运由 prefetch_weight 完成；反向副本权重梯度由 reduce_grad 归并。

```text
router → plan → dispatch → prefetch_weight → 专家计算 → combine
          ├─ vtopk：虚拟专家路由
          ├─ cu_seqlens：专家计算分组边界
          └─ experts_to_copy：副本权重预取清单
```

## 2. 记号和计数含义

- rank：EP 组内进程编号，通常一进程对应一张 NPU，组内编号不一定等于物理卡号。
- R：组内 rank 数；E：专家总数；epn=E/R：每 rank 原本拥有的专家数。
- S：每 rank 的输入 token 数；K：每 token 选择的专家数；N=S*K：每 rank 产生的专家处理任务数。
- 当前实现要求所有 rank 的 S、K 一致，但各 rank 的专家选择可以不同。
- 一次“路由任务”是一个 token 交给一个专家处理一次。例如 token A 选择专家0和专家2，就产生两次专家任务；不是两个独立输入 token。
- home(e)=e//epn：专家原本所在 rank；src 是 token 来源；dst 是该专家任务实际处理目的地。

## 3. 输入输出契约

输入均为连续 NPU int32 张量：

| 参数 | 形状 | 功能 |
| --- | --- | --- |
| tokens_per_expert | [E] | 当前 rank 各专家的任务计数，应与 top-k 直方图一致 |
| topk_experts_sk | [S,K] | 每 token 选择的真实专家 ID，同行 K 个专家互不重复 |
| context | 通信上下文 | 提供组内 rank、rank_size 和对称通信基础设施 |

输出：

| 返回值 | 形状 | 当前七 kernel 版本的语义 |
| --- | --- | --- |
| dst_n | [N] | 全零只读占位，不是实际接收行号 |
| cu_seqlens | [2epn] | 当前接收 rank 各真实专家及副本槽的累计结束位置，没有开头的零 |
| experts_to_copy | [R,epn] | 各 rank 的远程专家清单，按专家 ID 升序，空槽为 -1 |
| src_n | [N] | 全零只读占位，与 dst_n 使用同一缓存张量 |
| vtopk | [N] | 展平顺序不变的虚拟专家编号，交给 dispatch 前 view(S,K) |

有效规划下每 rank 计划处理 N 次专家任务，cu 最后一个元素为 N。固定副本槽是否足够是额外条件，不能只看 token 总量是否可均衡。

## 4. 七个 kernel 的输入、输出与配合

下表形状中 nc 为本地 chunk 数，bdp 为按专家分块的 block 数。

| kernel | 主要输入 | 主要输出 | 实现与作用 |
| --- | --- | --- | --- |
| Exchange | tpe[E]、epoch[1]、ctx | dem_by_rank[R,E] | 单 block；向其他卡 put 自己的计数和标记，轮询收齐后复制完整需求表 |
| GreedyInit | dem_by_rank[R,E] | rem[E,R]、order[E,R]、loads_part[bdp,R] | 各 block 负责不同专家，求全局需求并先全部放到 home，独立局部负载行免原子 |
| Greedy | rem、order、loads_part | 更新后的 rem/order、cu[2epn] | 单 block 标量贪心，转移最忙 rank 的专家任务到最闲 rank，构造本 rank 分组边界 |
| Tables | order[E,R] | jrep[R,E]、etc[R,epn] | 每 block 一个目标 rank，按专家 ID 扫描安排副本槽 |
| Count | topk_all[R,N] 的当前 rank 行 | counts[nc,E] | 各 chunk 统计专家任务数，chunk 输出行互不冲突 |
| Pfx | dem、counts、rem、order | pcnt[E,nc]、dpre[E]、vid[E]、ord_rank/ord_end[E,R+1] | 按专家构造输入序号前缀、实例处理区间和固定路由快路径 |
| Assign | 本地 top-k、Pfx 输出、jrep | vtopk[N] | 按专家内全局序号命中实例区间，映射虚拟专家编号；跨区间时才重新查表 |

```text
tpe → Exchange → dem → GreedyInit → Greedy → cu
                  │                   ├→ Tables → etc
                  │                   │     └→ jrep ─────────┐
                  └───────────────────┼→ Pfx ────────────────┤
本地 topk → Count → counts ────────────┘                     ▼
本地 topk ───────────────────────────────────────────────→ Assign → vtopk
```

当前七阶段按 host 程序顺序执行。Count 在逻辑上独立于贪心，但原版本未因此自动并发这两个分支。只有 Exchange 涉及跨卡通信，其余计算读取本卡工作表。

## 5. Greedy 的数学含义

rem[e,r] 是专家 e 分给 rank r 的任务数。order[e,r] 为 0 表示不承载，1 是 home，2+ 是该专家的副本创建顺序。每个专家初始需求为对 dem 的来源 rank 维求和。

```text
cap = 全组需求总数 / R = N（计数正确且每 rank N 相同时）
src = 当前负载最高的 rank
dst = 当前负载最低的 rank
e = src 上份额最大的专家
move = min(load[src]-cap, cap-load[dst], rem[e,src])
```

转移 move 份额，必要时登记新副本。原实现最多运行 E 轮，并在已无超载时跳过实际移动。

注意 order 与 jrep 不同：order 是“一个专家的不同实例”的顺序；jrep 是“一个 rank 上不同副本专家”的槽位。前者划分输入任务区间，后者定位权重视图。

## 6. 虚拟专家空间与 token 归属

每 rank 有 2epn 个逻辑槽：前 epn 为本地专家，后 epn 为副本槽。全组虚拟专家数为 2E。

```text
home 实例：vid = home_rank*(2epn) + e%epn
远程实例：vid = dst_rank*(2epn) + epn + jrep[dst_rank,e]
实际目的 rank = vid//(2epn)
```

同一专家的输入按来源 rank、token 下标、k 下标排序。当前任务的专家内序号为：

```text
pos = dpre[e] + pcnt[e,chunk] + 当前 chunk 内该专家此前出现次数
```

用 pos 查询 ord_end 的首个严格大于 pos 的边界，即确定该任务交给哪个实例。无远程正份额的专家直接查固定 vid；有副本的专家缓存当前区间，避免逐任务反复扫描全部实例。

## 7. K=2 完整示例

R=2，E=4，epn=2，S=4，K=2，N=8。每 rank 有 4 个输入 token、8 次专家任务。专家0/1在rank0，专家2/3在rank1。

| token | rank0 topk | rank1 topk |
| --- | --- | --- |
| t0 | [0,1] | [0,1] |
| t1 | [0,1] | [0,1] |
| t2 | [0,1] | [0,2] |
| t3 | [0,2] | [0,3] |

1. Exchange：dem=[[4,3,1,0],[4,2,1,1]]，列和为全局需求[8,5,2,1]。
2. GreedyInit：rem=[[8,0],[5,0],[0,2],[0,1]]，loads=[13,3]。
3. Greedy：专家0从rank0转移5次任务给rank1；rem变为[[3,5],[5,0],[0,2],[0,1]]，loads=[8,8]。
4. Tables：etc=[[-1,-1],[0,-1]]。rank1的副本槽0放专家0，对应虚拟编号6；原本专家2/3的虚拟编号为4/5。
5. Count：真实分块对N=8只有一个chunk，两卡counts分别为[[4,3,1,0]]和[[4,2,1,1]]。
6. Pfx：pcnt全零；rank0的dpre=[0,0,0,0]，rank1的dpre=[4,3,1,0]。专家0的区间[0,3)给home，[3,8)给rank1副本。
7. Assign：专家0按来源顺序的前3次来自r0:t0/t1/t2，给home；其余r0:t3和r1的4个token给副本。

| 来源 token | 原 topk | 输出虚拟 topk | 两个专家任务的去向 |
| --- | --- | --- | --- |
| r0:t0 | [0,1] | [0,1] | rank0专家0、rank0专家1 |
| r0:t1 | [0,1] | [0,1] | rank0专家0、rank0专家1 |
| r0:t2 | [0,1] | [0,1] | rank0专家0、rank0专家1 |
| r0:t3 | [0,2] | [6,4] | rank1专家0副本、rank1专家2 |
| r1:t0 | [0,1] | [6,1] | rank1专家0副本、rank0专家1 |
| r1:t1 | [0,1] | [6,1] | rank1专家0副本、rank0专家1 |
| r1:t2 | [0,2] | [6,4] | rank1专家0副本、rank1专家2 |
| r1:t3 | [0,3] | [6,5] | rank1专家0副本、rank1专家3 |

rank0各槽任务数=[3,5,0,0]，cu=[3,8,8,8]；rank1各槽任务数=[2,1,5,0]，cu=[2,3,8,8]。每卡都是8次专家任务。

同一 token 的两次专家处理可以落到不同卡，例如 r1:t0 的 [6,1]。任务数不能简单等同于网络物理传输次数或去重后的 hidden 缓冲行数。

## 8. Exchange 的 ready/epoch 如何工作

发送方 rank me 向每个目标 p 写两样东西：先把tpe写入peer的dem_all[me,:]，再把本轮epoch写入peer的ready[me]。本卡自己的计数行通过本地拷贝填入。

例如第7轮，rank0向rank1写ready[0]=7；rank1使用自己的本轮标量7，轮询本卡ready[0]>=7。ready下标表示来源卡，值表示该来源发布到哪轮。这样第6轮遗留标记不会被当作第7轮就绪。

这个协议依赖通信库的数据/标记顺序和可见性保证，并要求各rank的调用顺序一致。原代码在Python外层维护递增_EPOCH并创建本轮gm_flag，kernel不会自行协商轮次；不支持据此推导任意并发安全性。

## 9. 实现边界

- 贪心不约束副本槽数；均衡成功不代表epn个副本槽一定够。R=3、E=3、需求[43,21,41]可让rank1需要两个副本但只有一个槽。
- 原cu/etc有写前保护，vtopk编码缺少对应超槽保护；报警延迟到后续prefetch/reduce。当前PyPTO候选改为Assign前检查全目标槽溢出。
- 原分块依靠2的幂因子整除N；N=65537会降为chunk=1，nc=65537、block_dim=1，前缀表显著膨胀。当前候选采用固定256和尾部边界。
- E和R独立上限不代表所有组合都符合UB预算；原Greedy在E=1024、R=64时仅rem/order两表就占512KiB。
- 原pending_overflow只保存最新一次plan；连续plan调用可能覆盖前一次检查载荷。
- 原样例的host缓存、epoch和跨流护栏依赖调用纪律，不能视为任意并发安全。

## 附件与相关资料

- [完整 HTML 分析报告](moonep_plan_analysis.html)：下载后用浏览器打开；GitHub通常展示源码，不直接渲染HTML。
- [通信接口及当前替代方案对照表](moonep-communication-api-comparison.md)
- [原 DSL PR 238](https://gitcode.com/cann/cannbot-dsl/pull/238)
- [PyPTO 实验性候选 PR #1](https://gitcode.com/wangyu_ai/pypto-gym/merge_requests/1)

本功能分析的算法示例经CPU模拟核对。当前PyPTO候选已做CPU语义与参考测试，但仍未通过原生编译、官方设备仿真或多卡E2E验收。
