# Exchange 两卡计数交换示例

日期：2026-10-29。对应 cannbot-dsl PR 238、提交 eb25c890 的原七 kernel 版本中的 Exchange。

## 完整交换过程

```text
rank 0                              rank 1
tpe=[4,3,1,0]                       tpe=[4,2,1,1]

把自己的 tpe 写给 rank1 第0行 ──────→ dem_all[0,:]
dem_all[1,:] ←────────────────────── 把自己的 tpe 写给 rank0 第1行

把 epoch 写给 rank1 ready[0] ───────→ ready[0]
ready[1] ←────────────────────────── 把 epoch 写给 rank0 ready[1]

本地填第0行                          本地填第1行
等待 ready[1]                        等待 ready[0]

收齐后，各自复制出：
[
  [4,3,1,0],
  [4,2,1,1]
]
```

## 如何读这张图

两张卡各自拥有一份 dem_all 和 ready，并不是共享同一个普通内存数组。箭头表示发送方主动将数据写入另一张卡的对称内存。

- rank0 的 tpe 表示它的输入分别产生了专家0的4次、专家1的3次、专家2的1次、专家3的0次处理任务。
- rank1 的 tpe 表示它的输入分别产生了专家0的4次、专家1的2次、专家2的1次、专家3的1次处理任务。
- 每个来源 rank 固定写自己的行：rank0 写第0行，rank1 写第1行。来源不同，所以写入区域不冲突。
- 自己的数据不做远端 put：rank0 本地填第0行，rank1 本地填第1行。
- dem_all 的行表示输入来源，不表示任务最终在哪张卡处理。后续 Greedy 才决定专家实例的处理份额。

## ready 和 epoch

ready 的下标表示来源 rank，保存的值表示该来源发布的轮次。epoch 是 Python 外层每次 plan 调用递增的序号。

假设本次为第7轮：

```text
rank0 → rank1：先写 dem_all[0,:]，再写 ready[0]=7
rank1 → rank0：先写 dem_all[1,:]，再写 ready[1]=7

rank0 用自己的本轮序号7，等待本卡 ready[1]>=7
rank1 用自己的本轮序号7，等待本卡 ready[0]>=7
```

这里的7不是目标卡号、专家号或token数。它用于区分本轮通知与上轮残留值，例如第6轮留下的ready=6不能使第7轮等待提前通过。

接收方轮询的是自己卡上的ready，由其他卡远程写入；不是反复读取另一张卡的ready。

## 顺序保证

原实现按“put计数 → put标记 → 对各peer flush”提交发送流程，然后本地填自己的行并等待其他来源标记。数据与标记的可靠顺序依赖通信库的保序和远端可见性保证，不能只凭普通程序书写顺序推断任意异步通信都安全。

看到对应标记后才读取计数，是接收协议的关键。各rank还必须按一致顺序调用plan、推进epoch；该机制不证明任意并发安全。

## Exchange 最终做了什么

每张卡独立获得同一张需求表：

```text
dem_by_rank = [
  [4,3,1,0],   # 来源rank0
  [4,2,1,1]    # 来源rank1
]
```

这一步不做专家放置、不搬hidden或权重，也不在Exchange内求全局需求列和。后续初始化阶段才按列汇总，得到专家需求 [8,5,2,1]。

## 相关文件

- [完整 HTML 分析报告](moonep_plan_analysis.html)：下载后用浏览器打开。
- [算子功能与实现分析](moonep-plan-functional-analysis.md)
- [通信接口对照表](moonep-communication-api-comparison.md)
