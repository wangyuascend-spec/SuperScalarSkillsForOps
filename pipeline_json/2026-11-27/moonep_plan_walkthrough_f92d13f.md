# MoonEP Plan 算子实现详解：从四卡需求交换到每一条路由的 VID

## 01　跟踪目标与版本

主仓 !1118，固定提交 f92d13f。四卡，每卡 S=1024、K=4，总 E=16，32 AIV，early_count=True、validate_inputs=False。跟踪实际 balanced 输入（seed 42）：rank 3 的 token 879 选了 [6,4,0,1]，规划后得到 [10,4,0,1]。输入的 4 是专家号，输出的 4 是目的地址，二者含义不同。

每卡一次融合 kernel：交换需求 → Greedy 分配份额（其他核同时 Count）→ 发布和同步 → 按 mode 建表或直接映射 → 返回 VID。Plan 只交换规划元数据，不搬 token 特征、不执行专家网络。所有内核文件均位于 ops/pypto_pro/experimental/moonep_plan/op_kernel/。每块直接附固定版本源码及原文件行号。

## 02　先分清来源、目的、槽位和块

| 变量 | 形状或单位 | 含义 |
| --- | --- | --- |
| topk / flat | [1024,4] / [4096] | 本来源卡的选择。i=token×4+K槽，值为专家号。 |
| tpe / dem | [16] / [4,16] | 本卡次数 / 四张来源卡的直方图。dem[src,e] 是谁选了专家。 |
| rem / order | 各 [16,4] | rem[e,dst] 是计划由谁承担多少条；order 是服务段顺序，home=1。 |
| ub_loads / loads | 逻辑长度 4 | ub_loads[0,dst] 是该目的卡所有专家份额的总和。 |
| counts / pcnt | 逻辑 [16块,16专家] / [16专家,16块] | 块内次数 / 此来源以前完整块的累计次数。counts 物理行宽 128。 |
| dpre / ord_rank / ord_end | [16] / [16,5] / [16,5] | 本来源在专家序列中的起点 / 服务段目的卡 / 右开区间终点。 |
| fixed / jrep | [16] / [4,16] | 专家固定地址或慢路径标记 / 专家在目的卡迁入区的槽序号。 |
| etc / cu | [4,4] / [8] | 各目的卡迁入槽对应专家 / 本目的卡八个槽的累计终点。 |
| vtopk | [4096] | 本来源每条路由的目的地址。VID=dst×8+slot；0～3 原属，4～7 迁入。 |

## 03　Host 入口、内存与一次启动

所有 rank 按相同顺序创建和调用实例。构造检查 R/E、S/K 和 int32 范围，分配 GM 缓冲和 Window。N=S×K=4096，chunk 数 ceil(N/256)=16。counts 的 128 个 int32 物理行宽使每块独占 512 B；只有前 16 桶是有效专家。每次调用核对设备、流、形状和连续性，递增 epoch 后启动 kernel[None,workers]。结果别名指向复用的工作区。

moonep_plan_latest_pro.py · 第 374–419 行

```python
    def __init__(self, group, experts, tokens, topk, workers=None, validate_inputs=False, *, early_count=True):
        r, e, s, k = group.size(), experts, tokens, topk
        if not (1 <= r <= 64 and r <= e <= 1024 and e % r == 0):
            raise ValueError('invalid R/E')
        if not (s >= 1 and 1 <= k <= e and r*s*k < 2**31):
            raise ValueError('S/K invalid or int32 overflow')
        if not isinstance(validate_inputs,bool):
            raise ValueError('validate_inputs must be bool')
        if type(early_count) is not bool and early_count != 'auto':
            raise ValueError('early_count must be bool or auto')
        self._early_count = 2 if early_count == 'auto' else int(early_count)
        self._strict_mode=int(validate_inputs)
        from pypto_pro.runtime.platform import get_platform_info
        try:
            resident=int(get_platform_info().vector_core_num)
        except Exception:
            resident=8
        resident=min(resident if resident>0 else 8,64)
        default_workers=min(r,8) if validate_inputs else min(resident,32,max(r,(s*k+127)//128))
        self.workers=default_workers if workers is None else workers
        if not isinstance(self.workers,int) or not 1<=self.workers<=min(resident,56):
            raise ValueError('workers exceed resident AIV cores or current acceptance-domain limit (experimental strict/trusted: 56)')
        self.r,self.e,self.s,self.k=r,e,s,k
        self.device=torch.device('npu',torch.npu.current_device())
        self.stream=torch.npu.current_stream().npu_stream
        self._epoch=0; self.closed=False; self.lock=threading.Lock()
        n,epn,nc=s*k,e//r,(s*k+255)//256
        count_stride=128 if e==16 and 256<n<=4096 else e
        shapes=[(r,e),(e,r),(e,r),(r,),(r,e),(r,epn),(2*epn,),
                (r,),(nc,count_stride),(e,nc),(e,),(e,),(e,r+1),(e,r+1),
                (nc,e,3),(n,),(n,),(1,)]
        self.buffers=[torch.empty(shape,dtype=torch.int32,device=self.device) for shape in shapes]
        # Partition ownership is expressed in conservative 512-byte cache lines.
        if any(t.data_ptr()%512 for t in self.buffers):
            raise RuntimeError('workspace allocator must provide 512-byte alignment')
        # Trusted zero placeholders are initialized by the first Pro launch,
        # then reused read-only. Construction launches no torch zero kernel.
        self.dem=self.buffers[0]
        aligned=(e+7)//8*8
        self.padded_tpe=torch.empty((1,aligned),dtype=torch.int32,device=self.device)
        self.padded_dem=torch.empty((r,aligned),dtype=torch.int32,device=self.device)
        self.validation=torch.empty((s if validate_inputs else 1,),dtype=torch.int32,device=self.device)
        self.hist_error=torch.empty((1,),dtype=torch.int32,device=self.device)
        self.win=None if r==1 else pld.create_window(group,size=r*aligned*4,num_signals=r)
        if self.win is not None and (self.win.nrank()!=r or self.win.num_signals()<r or self.win.size()<r*aligned*4):
            raise RuntimeError('Window metadata mismatch')
```

moonep_plan_latest_pro.py · 第 425–455 行

```python
    def __call__(self,tpe,topk):
        if not self.lock.acquire(blocking=False):
            raise RuntimeError('concurrent use of DistributedPlan')
        try:
            if self.closed: raise RuntimeError('Window closed')
            if torch.npu.current_device()!=self.device.index or torch.npu.current_stream().npu_stream!=self.stream:
                raise RuntimeError('use the creating stream')
            for value,shape in ((tpe,(self.e,)),(topk,(self.s,self.k))):
                if value.shape!=shape or value.dtype!=torch.int32 or value.device!=self.device or not value.is_contiguous():
                    raise ValueError('input shape/dtype/device/contiguity mismatch')
            if self._epoch>=2**63-1: raise OverflowError('recreate Window before epoch wraps')
            self._epoch+=1
            b=self.buffers
            kernel=moonep_local_latest_kernel if self.r==1 else moonep_latest_kernel
            endpoint=0 if self.r==1 else self.win
            policy_args = () if self.r == 1 else (self._early_count,)
            kernel[None,self.workers](endpoint,b[0],tpe,topk,*b[1:],self.padded_tpe,self.padded_dem,self.hist_error,self.validation,self.workers,self._epoch,self._strict_mode,*policy_args)
            return b[16],b[6],b[5],b[16],b[15],b[17]
        finally:
            self.lock.release()

    def close(self):
        if not self.lock.acquire(blocking=False):
            raise RuntimeError('concurrent close')
        try:
            if not self.closed:
                torch.npu.synchronize(self.device)
                if self.win is not None: self.win.close()
                self.closed=True
        finally:
            self.lock.release()
```

## 04　Exchange：本地 tpe 怎样成为四行 dem

首轮用 128 线程 helper 清零占位；全体 AIV 在入口参加 Window barrier。AIV 0 把本卡 tpe 装入 UB，本例按 8 对齐且总矩阵 256 B，走紧凑路径。给三个远端 peer 各 put 本行 64 B 并 notify(epoch)，本地行也 put；等待三个来源 ready≥本轮 epoch 后，整矩阵 get 到 UB 再 store 到本卡 GM。每卡远端有效数据共 192 B，另有控制信号。源码另一分支逐行收取，必要时去掉 padding。

| 来源 | 专家 0～7 | 专家 8～15 | 行和 |
| --- | --- | --- | --- |
| 0 | [253, 262, 245, 238, 271, 255, 264, 255] | [272, 254, 257, 254, 228, 270, 269, 249] | 4096 |
| 1 | [257, 274, 234, 280, 239, 256, 252, 269] | [248, 253, 258, 268, 243, 255, 240, 270] | 4096 |
| 2 | [228, 237, 252, 278, 277, 252, 256, 254] | [269, 245, 260, 238, 299, 254, 248, 249] | 4096 |
| 3 | [255, 245, 274, 246, 272, 283, 236, 262] | [248, 256, 261, 230, 244, 272, 246, 266] | 4096 |

moonep_plan_latest_pro.py · 第 57–100 行

```python
        bi = pl.get_block_idx()
        me = win.rank()
        flat = pl.make_tensor(pl.make_ptr(topk),[topk.shape[0]*topk.shape[1]],dtype=pl.DT_INT32)
        if strict_mode == 0:
            if epoch == 1:
                _zero_partition[128](zero,bi,workers)
        # All AIVs participate; this isolates payload reuse across ranks/rounds.
        pld.barrier(win)
        if bi == 0:
            tile=pl.make_tile(pl.TileType(shape=[1,padded_tpe.shape[1]],dtype=pl.DT_INT32,target_memory=pl.MemorySpace.Vec),addr=0)
            if padded_tpe.shape[1] == tpe.shape[0]:
                tpe_view=pl.make_tensor(pl.make_ptr(tpe),[1,tpe.shape[0]],dtype=pl.DT_INT32)
                pl.load(tile,tpe_view,[0,0])
            else:
                _pad_tpe[1](tpe,padded_tpe)
                pl.system.sync_src(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=4)
                pl.system.sync_dst(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=4)
                pl.system.dsb(scope=pl.MemDsb.DDR)
                pl.load(tile,padded_tpe,[0,0])
            pl.system.sync_src(set_pipe=pl.PipeType.MTE2,wait_pipe=pl.PipeType.MTE3,event_id=2)
            pl.system.sync_dst(set_pipe=pl.PipeType.MTE2,wait_pipe=pl.PipeType.MTE3,event_id=2)
            data=pld.make_dtensor(win,0,[padded_dem.shape[0],padded_dem.shape[1]],pl.DT_INT32)
            if padded_dem.shape[1] == dem.shape[1] and padded_dem.shape[0]*padded_dem.shape[1]*4 <= 32768:
                ready=pld.signal(win,me)
                for peer in pl.range(dem.shape[0]):
                    if peer != me:
                        pld.put(data,tile,[me,0],peer)
                        pld.notify(ready,peer,epoch)
                # Local copy fills the same symmetric-buffer row as the DSL.
                pld.put(data,tile,[me,0],me)
                pl.system.sync_src(set_pipe=pl.PipeType.MTE3,wait_pipe=pl.PipeType.MTE2,event_id=3)
                pl.system.sync_dst(set_pipe=pl.PipeType.MTE3,wait_pipe=pl.PipeType.MTE2,event_id=3)
                for source in pl.range(dem.shape[0]):
                    if source != me:
                        received=pld.signal(win,source)
                        pld.wait(received,epoch,cmp=pld.Cmp.GE)
                matrix=pl.make_tile(pl.TileType(shape=[padded_dem.shape[0],padded_dem.shape[1]],dtype=pl.DT_INT32,target_memory=pl.MemorySpace.Vec),addr=0)
                pld.get(matrix,data,[0,0],me)
                pl.system.sync_src(set_pipe=pl.PipeType.MTE2,wait_pipe=pl.PipeType.MTE3,event_id=2)
                pl.system.sync_dst(set_pipe=pl.PipeType.MTE2,wait_pipe=pl.PipeType.MTE3,event_id=2)
                pl.store(dem,matrix,[0,0])
                pl.system.sync_src(set_pipe=pl.PipeType.MTE3,wait_pipe=pl.PipeType.S,event_id=1)
                pl.system.sync_dst(set_pipe=pl.PipeType.MTE3,wait_pipe=pl.PipeType.S,event_id=1)
                pl.system.dsb(scope=pl.MemDsb.DDR)
```

moonep_plan_latest_pro.py · 第 101–123 行

```python
            else:
                ready=pld.signal(win,me)
                for peer in pl.range(dem.shape[0]):
                    pld.put(data,tile,[me,0],peer)
                    pld.notify(ready,peer,epoch)
                for source in pl.range(dem.shape[0]):
                    received=pld.signal(win,source)
                    pld.wait(received,epoch,cmp=pld.Cmp.GE)
                for row in pl.range(dem.shape[0]):
                    pld.get(tile,data,[row,0],me)
                    pl.system.sync_src(set_pipe=pl.PipeType.MTE2,wait_pipe=pl.PipeType.MTE3,event_id=2)
                    pl.system.sync_dst(set_pipe=pl.PipeType.MTE2,wait_pipe=pl.PipeType.MTE3,event_id=2)
                    if padded_dem.shape[1] == dem.shape[1]:
                        pl.store(dem,tile,[row,0])
                    else:
                        pl.store(padded_dem,tile,[row,0])
                    pl.system.sync_src(set_pipe=pl.PipeType.MTE3,wait_pipe=pl.PipeType.MTE2,event_id=3)
                    pl.system.sync_dst(set_pipe=pl.PipeType.MTE3,wait_pipe=pl.PipeType.MTE2,event_id=3)
                pl.system.sync_src(set_pipe=pl.PipeType.MTE3,wait_pipe=pl.PipeType.S,event_id=1)
                pl.system.sync_dst(set_pipe=pl.PipeType.MTE3,wait_pipe=pl.PipeType.S,event_id=1)
                pl.system.dsb(scope=pl.MemDsb.DDR)
                if padded_dem.shape[1] != dem.shape[1]:
                    _unpad_dem[1](padded_dem,dem)
```

## 05　Count：一块路由对应一行直方图

只读本卡 flat，因此不依赖 Exchange 结果。提前时 AIV 1～16 各领一个 256 项块，AIV 17～31 没有块可领。每核 64 个 SIMT 线程，tid 处理块内 tid、tid+64、tid+128、tid+192。核内清零 hist 后同步，多线程用 UB atomic_add 更新同一专家桶，再同步、写 GM；第三次核内同步保证复用下一块之前已读完。

| 来源 | 块 | 路由下标 | 实际有效 counts 行 |
| --- | --- | --- | --- |
| 0 | 0 | 0～255 | [16, 16, 18, 15, 20, 12, 17, 18, 11, 24, 11, 22, 11, 10, 19, 16] |
| 3 | 13 | 3328～3583 | [20, 15, 15, 20, 9, 18, 14, 19, 19, 21, 14, 15, 13, 14, 14, 16] |

True 的适用条件是默认可信多卡路径、E=16、256<N≤4096、多 AIV。False 在 mode 1 决策后再数；auto 在相同形状下根据本卡 tpe 判断，最热专家超过两倍平均需求便不提前。按列跨块汇总应还原 tpe；块内统计保留了分块并行 Assign 所需的顺序信息。

moonep_plan_latest_pro.py · 第 124–134 行

```python
        overlap_count = early_count != 0 and strict_mode == 0 and dem.shape[1] == 16 and flat.shape[0] > 256 and flat.shape[0] <= 4096 and workers > 1
        if early_count == 2 and overlap_count:
            pl.system.dcci(tpe)
            for expert in pl.range(dem.shape[1]):
                if tpe[expert] * dem.shape[1] > 2 * flat.shape[0]:
                    overlap_count = False
        if overlap_count:
            if bi > 0:
                hist = pl.make_tile(pl.TileType(shape=[1, ((counts.shape[1]+7)//8)*8], dtype=pl.DT_INT32, target_memory=pl.MemorySpace.Vec), addr=131072)
                _count_partition_trusted[64](flat,counts,hist,bi-1,workers-1,dem.shape[1])
        # Bounded UB working set; large R/E falls back to the existing GM path.
```

moonep_plan_stages_pro.py · 第 355–388 行

```python
@pl.vector_function(mode="simt", max_threads=64)
def _count_partition_trusted(topk, counts, hist, worker, workers, logical_e):
    tid = pl.simt.linear_thread_idx()
    threads = pl.simt.block_dim().x
    n = topk.shape[0]
    e_count = logical_e
    row_stride = counts.shape[1]
    chunks = counts.shape[0]
    group_width = 1
    for alignment_step in pl.range(7):
        if row_stride * group_width % 128 != 0:
            group_width = group_width * 2
    for group_start in pl.range(worker * group_width, chunks, workers * group_width):
        group_end = group_start + group_width
        if chunks < group_end:
            group_end = chunks
        for c in pl.range(group_start, group_end):
            for e in pl.range(tid, row_stride, threads):
                hist[0,e] = 0
            pl.simt.syncthreads()
            end = (c + 1) * 256
            if n < end:
                end = n
            for i in pl.range(c * 256 + tid,end,threads):
                e = pl.simt.cast(topk[i],pl.DT_INT64)
                if e >= 0 and e < e_count:
                    pl.simt.atomic_add(hist[0,e],pl.simt.cast(1,pl.DT_INT32))
            pl.simt.syncthreads()
            for e in pl.range(tid, row_stride, threads):
                counts[c,e] = hist[0,e]
            # All lanes finish reading this row before reusing the tile.
            pl.simt.syncthreads()
    pl.simt.threadfence()

```

## 06　Greedy 初始化：只让专家的原属卡承担需求

同一 dem 在每卡 AIV 0 产生相同决策。本例命中精确的小网络 scalar 分支。epn=E/R=4；UB 中每个专家物理预留八列。对专家 e 把四张来源卡的 dem 求和，将总数放在 ub_rem[e,home]，并设 ub_order[e,home]=1。然后对每个目的卡按专家求和得到 ub_loads。

| 原属目的卡 | 专家 | 各专家初始份额 | ub_loads |
| --- | --- | --- | --- |
| 0 | e0～e3 | [993, 1018, 1005, 1042] | 4058 |
| 1 | e4～e7 | [1059, 1046, 1008, 1040] | 4153 |
| 2 | e8～e11 | [1037, 1008, 1036, 990] | 4071 |
| 3 | e12～e15 | [1014, 1051, 1003, 1034] | 4102 |

e5 的四个来源分别有 255、256、252、283 条。ub_rem[5,:]=[0,1046,0,0]，表示初始全给 rank 1。ub_loads[0,1]=4153 是整个目的卡的任务量，不是专家 5 自己的量。rank 1 作为来源只发出 4096 条。全局总数 16384，目标 cap=4096。

moonep_plan_latest_pro.py · 第 135–182 行

```python
        padded_ranks = ((dem.shape[0]+7)//8)*8
        greedy_bytes = dem.shape[1]*padded_ranks*8 + padded_ranks*4
        ub_cols = padded_ranks if greedy_bytes <= 98304 else 8
        ub_rows = dem.shape[1] if greedy_bytes <= 98304 else 1
        if greedy_bytes <= 98304:
            ub_rem=pl.make_tile(pl.TileType(shape=[ub_rows,ub_cols],dtype=pl.DT_INT32,target_memory=pl.MemorySpace.Vec),addr=0)
            ub_order=pl.make_tile(pl.TileType(shape=[ub_rows,ub_cols],dtype=pl.DT_INT32,target_memory=pl.MemorySpace.Vec),addr=ub_rows*ub_cols*4)
            ub_loads=pl.make_tile(pl.TileType(shape=[1,ub_cols],dtype=pl.DT_INT32,target_memory=pl.MemorySpace.Vec),addr=ub_rows*ub_cols*8)
            if bi == 0:
                # Four-rank small-network scalar Greedy, validated with 32 AIVs.
                if dem.shape[0] == 4 and dem.shape[1] == 16 and topk.shape[0] == 1024 and topk.shape[1] == 4 and workers == 32 and strict_mode == 0:
                    ranks = dem.shape[0]
                    experts = dem.shape[1]
                    epn = experts // ranks
                    bad = 0
                    if strict_mode != 0:
                        for r in pl.range(ranks):
                            total = 0
                            for e in pl.range(experts):
                                value = dem[r, e]
                                if value < 0:
                                    bad = 1
                                total = total + value
                            if total != flat.shape[0]:
                                bad = 4
                    errors[0] = bad
                    hist_error[0] = 0
                    overflow[0] = 0
                    for e in pl.range(experts):
                        total = 0
                        for r in pl.range(ranks):
                            total = total + dem[r, e]
                        for r in pl.range(ranks):
                            ub_rem[e, r] = 0
                            ub_order[e, r] = 0
                        home = e // epn
                        ub_rem[e, home] = total
                        ub_order[e, home] = 1
                    for r in pl.range(ranks):
                        ub_loads[0, r] = 0
                    if bad == 0:
                        experts = dem.shape[1]
                        ranks = dem.shape[0]
                        epn = experts // ranks
                        total = 0
                        for r in pl.range(ranks):
                            amount = 0
                            for e in pl.range(experts):
```

## 07　Greedy 四轮：为什么 e5 的结果是 1021 + 25

每轮选负载最高 src、最低 dst，从 src 原属专家中挑当前 ub_rem[e,src] 最大者。take=min(该专家剩余量,cap−dst负载)。一个专家不够时仍在同一 src 内选。并列时严格比较、升序扫描，先遇到的小编号胜出。新服务位置记下一顺序号；从源份额扣除 take，加到目的份额。

| 扫描 | src→dst | 调整 | 各目的卡负载 |
| --- | --- | --- | --- |
| 初始 | — | — | 4058,4153,4071,4102 |
| 1 | 1→0 | e4 给 38 | 4096,4115,4071,4102 |
| 2 | 1→2 | e5 给 25 | 4096,4090,4096,4102 |
| 3 | 3→1 | e13 给 6 | 4096,4096,4096,4096 |
| 4 | — | high==cap，不调整 | 4096,4096,4096,4096 |

e4 原有 1059，第一次调整后剩 1021；第二轮 e5 的 1046 成为最大。rank 1 此时仅超目标 19，但 rank 2 缺 25，代码优先填满目的卡，所以给出 25。e5 最终 rem=[0,1021,25,0]、order=[0,1,2,0]。这里只分数额，尚未为具体 token 选目的卡。

moonep_plan_latest_pro.py · 第 183–231 行

```python
                                amount = amount + ub_rem[e, r]
                            ub_loads[0, r] = amount
                            total = total + amount
                        cap = total // ranks
                        for iteration in pl.range(ranks):
                            src = 0
                            dst = 0
                            high = -1
                            low = 2147483647
                            for r in pl.range(ranks):
                                amount = ub_loads[0, r]
                                if amount > high:
                                    high = amount
                                    src = r
                                if amount < low:
                                    low = amount
                                    dst = r
                            if high > cap:
                                remaining = cap - low
                                moved = 0
                                for slot in pl.range(epn):
                                    if remaining > 0:
                                        best = -1
                                        largest = 0
                                        for j in pl.range(epn):
                                            e = src * epn + j
                                            amount = ub_rem[e, src]
                                            if amount > largest:
                                                largest = amount
                                                best = e
                                        if largest > 0:
                                            take = largest
                                            if remaining < take:
                                                take = remaining
                                            if ub_order[best, dst] == 0:
                                                copies = 0
                                                for r in pl.range(ranks):
                                                    if ub_order[best, r] > 0:
                                                        copies = copies + 1
                                                ub_order[best, dst] = copies + 1
                                            ub_rem[best, src] = ub_rem[best, src] - take
                                            ub_rem[best, dst] = ub_rem[best, dst] + take
                                            remaining = remaining - take
                                            moved = moved + take
                                ub_loads[0, src] = high - moved
                                ub_loads[0, dst] = cap
                    if strict_mode == 0:
                        remote = 0
                        split = 0
```

## 08　mode 与 Publish：让其他 AIV 看见规划

根据正份额判断：全在 home 为 mode 0；存在远端但每个有需求的专家只在一处为 mode 2；任一专家分在两处或更多，覆盖为 mode 1。本例 e4、e5、e13 均拆分。可信路径用 overflow[0] 携带 mode。

决策由 AIV 0 的 scalar 单元串行执行。_publish_greedy[64] 用 AIV 0 的线程把 rem/order/loads 发布至本卡 GM；本例线程 0～15 有专家行。mode 0 还写 etc/cu；mode 2 写 fixed。所有 32 个 AIV 在第 263 行第一次显式卡内全核同步。

moonep_plan_latest_pro.py · 第 231–264 行

```python
                        split = 0
                        for e in pl.range(experts):
                            active = 0
                            for r in pl.range(ranks):
                                if ub_rem[e, r] > 0:
                                    active = active + 1
                                    if r != e // epn:
                                        remote = 1
                            if active > 1:
                                split = 1
                        mode = 0
                        if remote != 0:
                            mode = 2
                        if split != 0:
                            mode = 1
                        overflow[0] = mode
                    pl.system.dsb(scope=pl.MemDsb.ALL)
                    pl.system.dcci(overflow)
                else:
                    _stage_zero_ub[1](dem,ub_rem,ub_order,ub_loads,errors,hist_error,overflow,flat.shape[0],strict_mode)
            _publish_greedy[64](ub_rem,ub_order,ub_loads,rem,order,loads,etc,cu,fixed,overflow,me,bi,strict_mode)
        else:
            if bi == 0:
                _stage_zero_legacy_mode[1](dem,flat,rem,order,loads,errors,hist_error,overflow,etc,cu,fixed,me,topk.shape[1],strict_mode)
        if strict_mode != 0:
            _validate_tokens[64](flat,validation,topk.shape[1],dem.shape[1],bi,workers)
            _count_partition[64](flat,counts,out,zero,bi,workers,dem.shape[1])
        pl.system.sync_src(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=5)
        pl.system.sync_dst(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=5)
        pl.system.dsb(scope=pl.MemDsb.DDR)
        # SYNCALL orders cores; explicit clean/invalidate handles scalar cache.
        pl.system.dcci(errors)
        pl.system.sync_all(core_type=pl.SyncCoreType.AIV_ONLY)
        pl.system.dcci(errors)
```

moonep_plan_stages_pro.py · 第 501–546 行

```python
@pl.vector_function(mode="simt", max_threads=64)
def _publish_greedy(ub_rem, ub_order, ub_loads, rem, order, loads, etc, cu, fixed, flag, me, worker, strict_mode):
    tid = pl.simt.linear_thread_idx()
    threads = pl.simt.block_dim().x
    experts = rem.shape[0]
    ranks = rem.shape[1]
    epn = experts // ranks
    if worker == 0:
        for e in pl.range(tid, experts, threads):
            for r in pl.range(ranks):
                rem[e, r] = ub_rem[e, r]
                order[e, r] = ub_order[e, r]
        for r in pl.range(tid, ranks, threads):
            loads[r] = ub_loads[0, r]
    # Lane 0 has consumed load[0]; this UB slot has no later loads reader.
    if worker == 0 and strict_mode == 0 and (tid == 0):
        ub_loads[0, 0] = pl.simt.atomic_add(flag[0], pl.simt.cast(0, pl.DT_INT32))
    # Keep the barrier uniform for strict mode and otherwise idle AIVs too.
    pl.simt.syncthreads()
    if worker == 0 and strict_mode == 0:
        remote = ub_loads[0, 0]
        if remote == 0:
            for i in pl.range(tid, experts, threads):
                etc[i // epn, i % epn] = -1
            if tid == 0:
                acc = 0
                for j in pl.range(epn):
                    acc = acc + pl.simt.cast(ub_rem[me * epn + j, me], pl.DT_INT64)
                    cu[j] = pl.simt.cast(acc, pl.DT_INT32)
                for j in pl.range(epn):
                    cu[epn + j] = pl.simt.cast(acc, pl.DT_INT32)
        if remote == 2:
            for e in pl.range(tid, experts, threads):
                home = e // epn
                dst = home
                for r in pl.range(ranks):
                    if ub_rem[e, r] > 0:
                        dst = r
                slot = e % epn
                if dst != home:
                    slot = epn
                    for other in pl.range(e):
                        if ub_order[other, dst] >= 2:
                            slot = slot + 1
                fixed[e] = pl.simt.cast(dst * (2 * epn) + slot, pl.DT_INT32)
    pl.simt.threadfence()
```

## 09　Tables：从目的卡观察各槽接多少条

mode 1 调用 _tables_partition[4]。每行 epn=4，按 512 B 对齐组合的 group_width=32，四行都落到第一个组，故 AIV 0 的 4 个线程各处理一行。先累计 home 槽，再按专家编号升序登记迁入槽。jrep 在 replicas 递增前记录，首个额外槽的相对下标为 0。etc 含全部目的卡，cu 仅对应当前目的卡。

| 目的卡 | etc 迁入区 → 专家 | 本目的卡的 cu |
| --- | --- | --- |
| 0 | [4, -1, -1, -1] | [993, 2011, 3016, 4058, 4096, 4096, 4096, 4096] |
| 1 | [13, -1, -1, -1] | [1021, 2042, 3050, 4090, 4096, 4096, 4096, 4096] |
| 2 | [5, -1, -1, -1] | [1037, 2045, 3081, 4071, 4096, 4096, 4096, 4096] |
| 3 | [-1, -1, -1, -1] | [1014, 2059, 3062, 4096, 4096, 4096, 4096, 4096] |

rank 0 的 home 槽累计到 4058，迁入 e4 后累计到 4096，差值 38 就是额外槽 4 的工作量。cu 后续保持 4096，表示剩余槽均为空。

moonep_plan_stages_pro.py · 第 49–90 行

```python
@pl.vector_function(mode="simt", max_threads=4)
def _tables_partition(rem, order, jrep, etc, cu, status, me, worker, workers):
    tid = pl.simt.linear_thread_idx()
    threads = pl.simt.block_dim().x
    e_count = rem.shape[0]
    ranks = rem.shape[1]
    epn = e_count // ranks
    if worker == 0 and tid == 0:
        for rr in pl.range(ranks):
            status[rr] = 0
    start = worker
    stride = workers
    group_width = 1
    for alignment_step in pl.range(7):
        if epn * group_width % 128 != 0:
            group_width = group_width * 2
    for group_start in pl.range(worker * group_width, ranks, workers * group_width):
        group_end = group_start + group_width
        if ranks < group_end:
            group_end = ranks
        for r in pl.range(group_start + tid, group_end, threads):
            for j in pl.range(epn):
                etc[r, j] = -1
            replicas = 0
            acc = 0
            if r == me:
                for j in pl.range(epn):
                    acc = acc + pl.simt.cast(rem[r * epn + j, r], pl.DT_INT64)
                    cu[j] = pl.simt.cast(acc, pl.DT_INT32)
            for e in pl.range(e_count):
                jrep[r, e] = pl.simt.cast(replicas, pl.DT_INT32)
                if order[e, r] >= 2:
                    if replicas < epn:
                        etc[r, replicas] = pl.simt.cast(e, pl.DT_INT32)
                        if r == me:
                            acc = acc + pl.simt.cast(rem[e, r], pl.DT_INT64)
                            cu[epn + replicas] = pl.simt.cast(acc, pl.DT_INT32)
                    replicas = replicas + 1
            if r == me:
                for j in pl.range(replicas, epn):
                    cu[epn + j] = pl.simt.cast(acc, pl.DT_INT32)
    pl.simt.threadfence()
```

## 10　Prefix：从块内次数推导专家的全局序号

_prefix_partition[64] 按 128 专家一组，E=16 时只有 AIV 0 领取有效组，线程 0～15 各处理一个专家。纯 home 专家可写直接 VID；有远端份额的专家设 fixed=-1。pcnt[e,c] 先记录 acc 才加 counts[c,e]，所以不含本块。

dpre 的来源排序先列出服务该专家的卡，再按编号补齐其他来源。ord_rank 是各服务段目的卡，ord_end 是累计右端点。e4 的来源需求 [271,239,277,272]，来源顺序 [1,0,2,3]；rank 3 的 dpre=239+271+277=787。目的段是 rank 1 的 [0,1021) 和 rank 0 的 [1021,1059)。Tables/Prefix 完成后各核在第 308 行同步。

moonep_plan_stages_pro.py · 第 92–151 行

```python
@pl.vector_function(mode="simt", max_threads=64)
def _prefix_partition(dem, counts, rem, order, pcnt, dpre, fixed, ord_rank, ord_end, me, worker, workers):
    tid = pl.simt.linear_thread_idx()
    threads = pl.simt.block_dim().x
    e_count = rem.shape[0]
    ranks = rem.shape[1]
    epn = e_count // ranks
    chunks = counts.shape[0]
    start = worker
    stride = workers
    group_width = 128
    for group_start in pl.range(worker * group_width, e_count, workers * group_width):
        group_end = group_start + group_width
        if e_count < group_end:
            group_end = e_count
        for e in pl.range(group_start + tid, group_end, threads):
            home = e // epn
            fixed[e] = pl.simt.cast(home * (2 * epn) + e % epn, pl.DT_INT32)
            for r in pl.range(ranks):
                if r != home:
                    if rem[e, r] > 0:
                        fixed[e] = -1
            # Fixed-home experts never consume these prefix/state tables.
            if fixed[e] < 0:
                acc = 0
                for c in pl.range(chunks):
                    pcnt[e, c] = pl.simt.cast(acc, pl.DT_INT32)
                    acc = acc + pl.simt.cast(counts[c, e], pl.DT_INT64)
                for o in pl.range(ranks + 1):
                    ord_rank[e, o] = -1
                for r in pl.range(ranks):
                    o = pl.simt.cast(order[e, r], pl.DT_INT64)
                    if o > 0:
                        ord_rank[e, o - 1] = pl.simt.cast(r, pl.DT_INT32)
                # Source preference matches bundled DSL: serving ranks in segment
                # order, followed by non-serving ranks in ascending rank order.
                acc_p = 0
                seen_me = 0
                for o in pl.range(ranks):
                    r = pl.simt.cast(ord_rank[e, o], pl.DT_INT64)
                    if r >= 0 and seen_me == 0:
                        if r == me:
                            seen_me = 1
                        else:
                            acc_p = acc_p + pl.simt.cast(dem[r, e], pl.DT_INT64)
                for r in pl.range(ranks):
                    if seen_me == 0:
                        if r == me:
                            seen_me = 1
                        else:
                            if order[e, r] == 0:
                                acc_p = acc_p + pl.simt.cast(dem[r, e], pl.DT_INT64)
                dpre[e] = pl.simt.cast(acc_p, pl.DT_INT32)
                acc = 0
                for o in pl.range(ranks + 1):
                    r = pl.simt.cast(ord_rank[e, o], pl.DT_INT64)
                    if r >= 0:
                        acc = acc + pl.simt.cast(rem[e, r], pl.DT_INT64)
                    ord_end[e, o] = pl.simt.cast(acc, pl.DT_INT32)
    pl.simt.threadfence()
```

moonep_plan_latest_pro.py · 第 292–309 行

```python
                else:
                    if not overlap_count:
                        hist = pl.make_tile(pl.TileType(shape=[1, ((counts.shape[1]+7)//8)*8], dtype=pl.DT_INT32, target_memory=pl.MemorySpace.Vec), addr=131072)
                        _count_partition_trusted[64](flat,counts,hist,bi,workers,dem.shape[1])
                        pl.system.sync_src(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=6)
                        pl.system.sync_dst(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=6)
                        pl.system.dsb(scope=pl.MemDsb.DDR)
                        pl.system.dcci(errors)
                        pl.system.sync_all(core_type=pl.SyncCoreType.AIV_ONLY)
                        pl.system.dcci(errors)
                    _tables_partition[4](rem,order,jrep,etc,cu,overflow,me,bi,workers)
                    _prefix_partition[64](dem,counts,rem,order,pcnt,dpre,fixed,ord_rank,ord_end,me,bi,workers)
                    pl.system.sync_src(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=6)
                    pl.system.sync_dst(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=6)
                    pl.system.dsb(scope=pl.MemDsb.DDR)
                    pl.system.dcci(errors)
                    pl.system.sync_all(core_type=pl.SyncCoreType.AIV_ONLY)
                    pl.system.dcci(errors)
```

## 11　Assign：SIMD 快项与压紧慢项

chunk=wave×workers+bi。16 个有效块由 AIV 0～15 处理；其余核的 valid_count=0。工作核将本块 256 个 topk 和 fixed 表加载到 UB，_assign_projection 分四组 64 项用 gather 查地址，并将 fixed<0 的慢项在本块的原始位置按顺序写到 slow。以下摘录展示第一组；其余三组偏移 64、128、192。

_assign_compacted_chunk[1] 每有效块用一个 SIMT 线程处理慢项。scratch[e,0]=dpre[e]+pcnt[e,chunk] 是下一个序号；scratch[e,1] 是当前段终点；scratch[e,2] 是缓存的 VID。序号跨段时才重新查 ord_end/ord_rank。home 段用 e%epn，迁入段用 epn+jrep[dst,e]。写回 values[原位置] 后序号加一，最后整个块写到 GM 的 out。

moonep_plan_latest_pro.py · 第 310–352 行

```python
                    if dem.shape[1] == 16 and flat.shape[0] > 256 and (flat.shape[0] <= 4096):
                        fixed_matrix = pl.make_tensor(pl.make_ptr(fixed), [1, dem.shape[1]], dtype=pl.DT_INT32)
                        top_matrix = pl.make_tensor(pl.make_ptr(flat), [1, flat.shape[0]], dtype=pl.DT_INT32)
                        out_matrix = pl.make_tensor(pl.make_ptr(out), [1, flat.shape[0]], dtype=pl.DT_INT32)
                        fixed_tile = pl.make_tile(pl.TileType(shape=[1, 16], dtype=pl.DT_INT32, target_memory=pl.MemorySpace.Vec), addr=512)
                        top_tile = pl.make_tile(pl.TileType(shape=[1, 256], dtype=pl.DT_INT32, target_memory=pl.MemorySpace.Vec, valid_shape=[-1, -1]), addr=576)
                        values_tile = pl.make_tile(pl.TileType(shape=[1, 256], dtype=pl.DT_INT32, target_memory=pl.MemorySpace.Vec, valid_shape=[-1, -1]), addr=1600)
                        slow_tile = pl.make_tile(pl.TileType(shape=[1, 256], dtype=pl.DT_INT32, target_memory=pl.MemorySpace.Vec), addr=2624)
                        count_tile = pl.make_tile(pl.TileType(shape=[1, 8], dtype=pl.DT_INT32, target_memory=pl.MemorySpace.Vec), addr=3648)
                        pl.set_validshape(top_tile, [1, 256])
                        pl.set_validshape(values_tile, [1, 256])
                        pl.load(fixed_tile, fixed_matrix, [0, 0])
                        pl.system.sync_src(set_pipe=pl.PipeType.MTE2, wait_pipe=pl.PipeType.V, event_id=1)
                        pl.system.sync_dst(set_pipe=pl.PipeType.MTE2, wait_pipe=pl.PipeType.V, event_id=1)
                        for wave in pl.range((pcnt.shape[1] + workers - 1) // workers):
                            chunk = wave * workers + bi
                            valid_count = flat.shape[0] - chunk * 256
                            if valid_count > 256:
                                valid_count = pl.const(256, pl.DT_INT64)
                            if valid_count < 0:
                                valid_count = pl.const(0, pl.DT_INT64)
                            if valid_count > 0:
                                pl.set_validshape(top_tile, [1, valid_count])
                                pl.set_validshape(values_tile, [1, valid_count])
                                pl.load(top_tile, top_matrix, [0, chunk * 256])
                            pl.system.sync_src(set_pipe=pl.PipeType.MTE2, wait_pipe=pl.PipeType.V, event_id=1)
                            pl.system.sync_dst(set_pipe=pl.PipeType.MTE2, wait_pipe=pl.PipeType.V, event_id=1)
                            _assign_projection(top_tile, fixed_tile, values_tile, slow_tile, count_tile, valid_count)
                            pl.system.sync_src(set_pipe=pl.PipeType.V, wait_pipe=pl.PipeType.S, event_id=4)
                            pl.system.sync_dst(set_pipe=pl.PipeType.V, wait_pipe=pl.PipeType.S, event_id=4)
                            _assign_compacted_chunk[1](top_tile, values_tile, slow_tile, count_tile, fixed_tile, pcnt, dpre, ord_rank, ord_end, jrep, scratch, chunk, valid_count)
                            pl.system.sync_src(set_pipe=pl.PipeType.V, wait_pipe=pl.PipeType.MTE3, event_id=2)
                            pl.system.sync_dst(set_pipe=pl.PipeType.V, wait_pipe=pl.PipeType.MTE3, event_id=2)
                            if valid_count > 0:
                                pl.store(out_matrix, values_tile, [0, chunk * 256])
                            # Protect top UB from the next wave's MTE2 load.
                            pl.system.sync_src(set_pipe=pl.PipeType.MTE3, wait_pipe=pl.PipeType.MTE2, event_id=3)
                            pl.system.sync_dst(set_pipe=pl.PipeType.MTE3, wait_pipe=pl.PipeType.MTE2, event_id=3)
                    else:
                        _assign_partition[assign_threads](flat, pcnt, dpre, fixed, ord_rank, ord_end, jrep, scratch, state, out, bi, workers)
        pl.system.sync_src(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=7)
        pl.system.sync_dst(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=7)
        pl.system.dsb(scope=pl.MemDsb.DDR)
```

moonep_plan_assign_simd.py · 第 10–37 行

```python
@pl.vector_function
def _assign_projection(top,fixed,out,slow,count,valid_count):
    full_i=vf.create_mask(pattern=pl.MaskPattern.ALL,dtype=I32)
    full_f=vf.create_mask(pattern=pl.MaskPattern.ALL,dtype=F32)
    ones=vf.full(pl.const(1.0,F32),dtype=F32)
    zeros=vf.full(pl.const(0.0,F32),dtype=F32)
    accum=vf.full(pl.const(0.0,F32),dtype=F32)
    zero_values=vf.full(pl.const(0,I32),dtype=I32)
    areg=vf.unalign_reg_for_store()
    vf.clear_spr()
    remaining=valid_count-0
    if remaining > 64:
        remaining=pl.const(64,pl.DT_INT64)
    if remaining < 0:
        remaining=pl.const(0,pl.DT_INT64)
    active=vf.update_mask(remaining,dtype=I32)
    indices=vf.load_align(top,[0,0])
    gather_indices=vf.astype(indices,active,dtype=U32)
    values=vf.gather(fixed,gather_indices,active)
    vf.store_align(out,values,active,[0,0])
    safe_values=vf.select(values,zero_values,active)
    is_slow=vf.lt(safe_values,pl.const(0,I32),full_i)
    positions=vf.arange(0,dtype=I32)
    packed=vf.squeeze(positions,is_slow,gather_mode=pl.SqueezeMode.STORE_REG)
    vf.squeeze_store_unalign(slow,packed,areg)
    selected=vf.select(ones,zeros,is_slow)
    accum=vf.add(accum,selected,full_f)
    remaining=valid_count-64
```

moonep_plan_assign_simd.py · 第 86–126 行

```python
    selected=vf.select(ones,zeros,is_slow)
    accum=vf.add(accum,selected,full_f)
    vf.squeeze_store_unalign_post(slow,areg)
    total=vf.reduce_sum(accum,full_f)
    total_i=vf.astype(total,full_f,dtype=I32)
    count_mask=vf.update_mask(8,dtype=I32)
    vf.store_align(count,total_i,count_mask,[0,0])

@pl.vector_function(mode="simt",max_threads=1)
def _assign_compacted_chunk(top,values,slow,count,fixed,pcnt,dpre,ord_rank,ord_end,jrep,scratch,chunk,valid_count):
    if valid_count > 0:
        e_count=pcnt.shape[0]
        ranks=jrep.shape[0]
        epn=e_count//ranks
        for e in pl.range(e_count):
            if fixed[0,e] < 0:
                a=pl.simt.cast(dpre[e],pl.DT_INT64)
                b=pl.simt.cast(pcnt[e,chunk],pl.DT_INT64)
                scratch[e,0]=pl.simt.cast(a+b,pl.DT_INT32)
                scratch[e,1]=0
                scratch[e,2]=-1
        for j in pl.range(pl.simt.cast(count[0,0],pl.DT_INT64)):
            i=pl.simt.cast(slow[0,j],pl.DT_INT64)
            e=pl.simt.cast(top[0,i],pl.DT_INT64)
            pos=pl.simt.cast(scratch[e,0],pl.DT_INT64)
            if pos >= scratch[e,1]:
                dst=-1
                seg=0
                for o in pl.range(ranks+1):
                    if dst < 0:
                        if pos < ord_end[e,o]:
                            dst=pl.simt.cast(ord_rank[e,o],pl.DT_INT64)
                            seg=o
                slot=e%epn
                if seg > 0:
                    slot=epn+pl.simt.cast(jrep[dst,e],pl.DT_INT64)
                scratch[e,1]=ord_end[e,seg]
                scratch[e,2]=pl.simt.cast(dst*(2*epn)+slot,pl.DT_INT32)
            values[0,i]=scratch[e,2]
            scratch[e,0]=pl.simt.cast(pos+1,pl.DT_INT32)
    pl.simt.threadfence()
```

## 12　逐 token 对账：同一块里的两个 e4 为何去了不同卡

| 来源 | token | K槽 | 块 | dpre | pcnt | 块内此前 e4 数 | pos | VID |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 1 | 0 | 0 | 239 | 0 | 0 | 239 | 8 |
| 3 | 875 | 1 | 13 | 787 | 227 | 6 | 1020 | 8 |
| 3 | 879 | 1 | 13 | 787 | 227 | 7 | 1021 | 4 |

rank 3 的 token 875 和 879 对应 e4 序列中相邻的两项。前者 pos=1020，去 rank 1 原属槽 0，得到 8；后者 pos=1021，去 rank 0 迁入槽 4，得到 4。反向解码：4//8=0、4%8=4，etc[0,4−4]=4，恢复出原专家。

| 来源与 token | 输入 topk | 最终 VID |
| --- | --- | --- |
| rank 0 · token 0 | [6, 3, 0, 7] | [10, 3, 0, 11] |
| rank 0 · token 1 | [4, 6, 15, 5] | [8, 10, 27, 9] |
| rank 3 · token 875 | [2, 4, 12, 1] | [2, 8, 24, 1] |
| rank 3 · token 879 | [6, 4, 0, 1] | [10, 4, 0, 1] |

返回元组含六项：位置 0、3 是同一个全零占位缓冲；位置 1 是 cu，2 是 etc，4 是本来源扁平 vtopk，5 是内部 errors。历史 DSL 对照用前五项逐元素比较。

moonep_plan_latest_pro.py · 第 435–444 行

```python
            if self._epoch>=2**63-1: raise OverflowError('recreate Window before epoch wraps')
            self._epoch+=1
            b=self.buffers
            kernel=moonep_local_latest_kernel if self.r==1 else moonep_latest_kernel
            endpoint=0 if self.r==1 else self.win
            policy_args = () if self.r == 1 else (self._early_count,)
            kernel[None,self.workers](endpoint,b[0],tpe,topk,*b[1:],self.padded_tpe,self.padded_dem,self.hist_error,self.validation,self.workers,self._epoch,self._strict_mode,*policy_args)
            return b[16],b[6],b[5],b[16],b[15],b[17]
        finally:
            self.lock.release()
```

## 13　mode 0 / mode 2：两个可复现的对照输入

mode 0：每个来源循环选择 [0,1,2,3]、[4,5,6,7]、[8,9,10,11]、[12,13,14,15] 共 1024 个 token。每卡初始负载恰为 4096，etc 全 −1，_assign_home_partition[128] 用 (e//4)×8+e%4 直接算。专家 5 得到 9。32 核各 128 个线程，本例每线程一条。

mode 2：所有 token 均选择 [0,1,2,3]。初始负载 [16384,0,0,0]。按较小编号优先，e0、e1、e2 各整份迁至 rank 1、2、3，e3 留 rank 0，于是每个 token 得到 [12,20,28,3]。_tables_partition_stable[4] 建接收表；_assign_fixed_partition[128] 只查已发布的 fixed，无需等其他核完成 etc/cu。这两个模式可能已提前 Count，但不消费 counts。

moonep_plan_latest_pro.py · 第 285–295 行

```python
        else:
            if overflow[0] == 0:
                _assign_home_partition[128](flat,out,dem.shape[1]//dem.shape[0],bi,workers)
            else:
                if overflow[0] == 2:
                    _tables_partition_stable[4](rem,order,jrep,etc,cu,overflow,me,bi,workers)
                    _assign_fixed_partition[128](flat,fixed,out,bi,workers)
                else:
                    if not overlap_count:
                        hist = pl.make_tile(pl.TileType(shape=[1, ((counts.shape[1]+7)//8)*8], dtype=pl.DT_INT32, target_memory=pl.MemorySpace.Vec), addr=131072)
                        _count_partition_trusted[64](flat,counts,hist,bi,workers,dem.shape[1])
```

moonep_plan_stages_pro.py · 第 603–661 行

```python
@pl.vector_function(mode="simt", max_threads=128)
def _assign_home_partition(topk, out, epn, worker, workers):
    tid = pl.simt.linear_thread_idx()
    threads = pl.simt.block_dim().x
    # Each AIV owns complete 512-byte output groups; no shared state is needed.
    for i in pl.range(worker*threads+tid,topk.shape[0],workers*threads):
        e = pl.simt.cast(topk[i],pl.DT_INT64)
        out[i] = pl.simt.cast((e//epn)*(2*epn)+e%epn,pl.DT_INT32)
    pl.simt.threadfence()

@pl.vector_function(mode="simt", max_threads=4)
def _tables_partition_stable(rem, order, jrep, etc, cu, status, me, worker, workers):
    tid = pl.simt.linear_thread_idx()
    threads = pl.simt.block_dim().x
    e_count = rem.shape[0]
    ranks = rem.shape[1]
    epn = e_count // ranks
    start = worker
    stride = workers
    group_width = 1
    for alignment_step in pl.range(7):
        if epn * group_width % 128 != 0:
            group_width = group_width * 2
    for group_start in pl.range(worker * group_width, ranks, workers * group_width):
        group_end = group_start + group_width
        if ranks < group_end:
            group_end = ranks
        for r in pl.range(group_start + tid, group_end, threads):
            for j in pl.range(epn):
                etc[r, j] = -1
            replicas = 0
            acc = 0
            if r == me:
                for j in pl.range(epn):
                    acc = acc + pl.simt.cast(rem[r * epn + j, r], pl.DT_INT64)
                    cu[j] = pl.simt.cast(acc, pl.DT_INT32)
            for e in pl.range(e_count):
                jrep[r, e] = pl.simt.cast(replicas, pl.DT_INT32)
                if order[e, r] >= 2:
                    if replicas < epn:
                        etc[r, replicas] = pl.simt.cast(e, pl.DT_INT32)
                        if r == me:
                            acc = acc + pl.simt.cast(rem[e, r], pl.DT_INT64)
                            cu[epn + replicas] = pl.simt.cast(acc, pl.DT_INT32)
                    replicas = replicas + 1
            if r == me:
                for j in pl.range(replicas, epn):
                    cu[epn + j] = pl.simt.cast(acc, pl.DT_INT32)
    pl.simt.threadfence()


@pl.vector_function(mode="simt", max_threads=128)
def _assign_fixed_partition(topk, fixed, out, worker, workers):
    tid = pl.simt.linear_thread_idx()
    threads = pl.simt.block_dim().x
    for i in pl.range(worker*threads+tid,topk.shape[0],workers*threads):
        e = pl.simt.cast(topk[i],pl.DT_INT64)
        out[i] = fixed[e]
    pl.simt.threadfence()
```

## 14　同步与回退：哪些结论只适用于这个例子

| 路径 | 显式卡内 AIV sync_all | 实际分工 |
| --- | --- | --- |
| mode 0 | 1 次，263 行 | AIV 0 发布；Assign 全 32 核。 |
| mode 2 | 1 次，263 行 | AIV 0 承担表行；Assign 全 32 核。 |
| mode 1 提前 Count | 2 次，263、308 行 | Count 1～16；Greedy、Tables、Prefix 为 0；Assign 有效块为 0～15。 |
| mode 1 延后 Count | 3 次，263、300、308 行 | 确认 mode 后才由 0～15 数块，增加一次同步。 |
| 严格校验 | 2 次，263、276 行 | 检查范围、重复和直方图；通过状态决定能否继续规划。 |

Window barrier 隔离窗口轮次；ready/wait 按来源确认到达；sync_all 做卡内全核交接；syncthreads 只作用于一个核内；MTE 事件约束流水，DSB 和 DCCI 分别涉及内存顺序与缓存维护。上表只统计显式 sync_all。

单 rank 不创建跨卡 Window；local kernel 用自己的 tpe 填 dem。未命中小网络 scalar 专化时，工作集≤98304 B 走原 UB 单线程 SIMT Greedy，超过该值有 GM 后备路径。其他规格的 Assign 可能走通用 _assign_partition。

moonep_plan_latest_pro.py · 第 249–282 行

```python
                else:
                    _stage_zero_ub[1](dem,ub_rem,ub_order,ub_loads,errors,hist_error,overflow,flat.shape[0],strict_mode)
            _publish_greedy[64](ub_rem,ub_order,ub_loads,rem,order,loads,etc,cu,fixed,overflow,me,bi,strict_mode)
        else:
            if bi == 0:
                _stage_zero_legacy_mode[1](dem,flat,rem,order,loads,errors,hist_error,overflow,etc,cu,fixed,me,topk.shape[1],strict_mode)
        if strict_mode != 0:
            _validate_tokens[64](flat,validation,topk.shape[1],dem.shape[1],bi,workers)
            _count_partition[64](flat,counts,out,zero,bi,workers,dem.shape[1])
        pl.system.sync_src(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=5)
        pl.system.sync_dst(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=5)
        pl.system.dsb(scope=pl.MemDsb.DDR)
        # SYNCALL orders cores; explicit clean/invalidate handles scalar cache.
        pl.system.dcci(errors)
        pl.system.sync_all(core_type=pl.SyncCoreType.AIV_ONLY)
        pl.system.dcci(errors)
        assign_threads = 1 if dem.shape[1] == 16 and flat.shape[0] <= 4096 else 16 if dem.shape[1] == 112 else (32 if dem.shape[1] <= 128 else (16 if dem.shape[1] <= 256 else (8 if dem.shape[1] <= 512 else 4)))
        scratch=pl.make_tile(pl.TileType(shape=[assign_threads*dem.shape[1],8],dtype=pl.DT_INT32,target_memory=pl.MemorySpace.Vec),addr=0)
        if strict_mode != 0:
            _check_counts[64](dem,counts,hist_error,me,bi,validation,errors)
            if errors[0] == 0:
                _tables_partition[4](rem,order,jrep,etc,cu,overflow,me,bi,workers)
                _prefix_partition[64](dem,counts,rem,order,pcnt,dpre,fixed,ord_rank,ord_end,me,bi,workers)
            pl.system.sync_src(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=6)
            pl.system.sync_dst(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=6)
            pl.system.dsb(scope=pl.MemDsb.DDR)
            pl.system.dcci(errors)
            pl.system.sync_all(core_type=pl.SyncCoreType.AIV_ONLY)
            pl.system.dcci(errors)
            if hist_error[0] == 0:
                if errors[0] == 0:
                    _assign_partition[assign_threads](flat,pcnt,dpre,fixed,ord_rank,ord_end,jrep,scratch,state,out,bi,workers)
            else:
                if bi == 0:
```

moonep_plan_stages_pro.py · 第 279–339 行

```python
def _validate_tokens(topk, validation, k, experts, worker, workers):
    tid = pl.simt.linear_thread_idx()
    threads = pl.simt.block_dim().x
    tokens = topk.shape[0] // k
    # AIVs own whole 512-byte lines; lanes validate independent tokens.
    for group in pl.range(worker * 128, tokens, workers * 128):
        for offset in pl.range(tid, 128, threads):
            token = group + offset
            if token < tokens:
                bad = 0
                for a in pl.range(k):
                    expert = pl.simt.cast(topk[token*k+a], pl.DT_INT64)
                    if expert < 0 or expert >= experts:
                        bad = 2
                for a in pl.range(k):
                    for b in pl.range(a+1,k):
                        if topk[token*k+a] == topk[token*k+b]:
                            bad = 3
                validation[token] = pl.simt.cast(bad, pl.DT_INT32)
    pl.simt.threadfence()

@pl.vector_function(mode="simt", max_threads=64)
def _check_counts(dem, counts, hist_error, me, worker, validation, errors):
    tid = pl.simt.linear_thread_idx()
    threads = pl.simt.block_dim().x
    if worker == 0:
        if tid == 0:
            hist_error[0] = 0
        pl.simt.threadfence()
        pl.simt.syncthreads()
        # Each lane checks a disjoint strided portion. Valid inputs issue no
        # error atomic; invalid flags are combined coherently across lanes.
        invalid = 0
        for token in pl.range(tid,validation.shape[0],threads):
            flag = pl.simt.cast(validation[token], pl.DT_INT64)
            if flag > invalid:
                invalid = flag
        if invalid > 0:
            pl.simt.atomic_max(hist_error[0],pl.simt.cast(invalid,pl.DT_INT32))
        pl.simt.threadfence()
        pl.simt.syncthreads()
        if tid == 0:
            invalid_total = pl.simt.atomic_add(hist_error[0],pl.simt.cast(0,pl.DT_INT32))
            if invalid_total > 0:
                errors[0] = invalid_total
            hist_error[0] = 0
        pl.simt.threadfence()
        pl.simt.syncthreads()
        bad = 0
        for e in pl.range(tid,dem.shape[1],threads):
            total = 0
            for c in pl.range(counts.shape[0]):
                total = total + pl.simt.cast(counts[c,e],pl.DT_INT64)
            if total != pl.simt.cast(dem[me,e],pl.DT_INT64):
                bad = 1
        if bad > 0:
            pl.simt.atomic_add(hist_error[0],pl.simt.cast(1,pl.DT_INT32))
        pl.simt.threadfence()
        pl.simt.syncthreads()
    pl.simt.threadfence()

```

moonep_plan_local_latest_pro.py · 第 56–84 行

```python
        if strict_mode == 0:
            if epoch == 1:
                _zero_partition[128](zero,bi,workers)
        # Single-rank path: device SIMT copies its own histogram; no Window.
        if bi == 0:
            _pad_tpe[1](tpe,padded_tpe)
            _unpad_dem[1](padded_tpe,dem)

        # Bounded UB working set; large R/E falls back to the existing GM path.
        padded_ranks = ((dem.shape[0]+7)//8)*8
        greedy_bytes = dem.shape[1]*padded_ranks*8 + padded_ranks*4
        ub_cols = padded_ranks if greedy_bytes <= 98304 else 8
        ub_rows = dem.shape[1] if greedy_bytes <= 98304 else 1
        if greedy_bytes <= 98304:
            ub_rem=pl.make_tile(pl.TileType(shape=[ub_rows,ub_cols],dtype=pl.DT_INT32,target_memory=pl.MemorySpace.Vec),addr=0)
            ub_order=pl.make_tile(pl.TileType(shape=[ub_rows,ub_cols],dtype=pl.DT_INT32,target_memory=pl.MemorySpace.Vec),addr=ub_rows*ub_cols*4)
            ub_loads=pl.make_tile(pl.TileType(shape=[1,ub_cols],dtype=pl.DT_INT32,target_memory=pl.MemorySpace.Vec),addr=ub_rows*ub_cols*8)
            if bi == 0:
                _stage_zero_ub[1](dem,ub_rem,ub_order,ub_loads,errors,hist_error,overflow,flat.shape[0],strict_mode)
            _publish_greedy[64](ub_rem,ub_order,ub_loads,rem,order,loads,etc,cu,fixed,overflow,me,bi,strict_mode)
        else:
            if bi == 0:
                _stage_zero_legacy_mode[1](dem,flat,rem,order,loads,errors,hist_error,overflow,etc,cu,fixed,me,topk.shape[1],strict_mode)
        if strict_mode != 0:
            _validate_tokens[64](flat,validation,topk.shape[1],dem.shape[1],bi,workers)
            _count_partition[64](flat,counts,out,zero,bi,workers,dem.shape[1])
        pl.system.sync_src(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=5)
        pl.system.sync_dst(set_pipe=pl.PipeType.V,wait_pipe=pl.PipeType.S,event_id=5)
        pl.system.dsb(scope=pl.MemDsb.DDR)
```

moonep_plan_stages_pro.py · 第 153–199 行

```python
@pl.vector_function(mode="simt", max_threads=32)
def _assign_partition(topk, pcnt, dpre, fixed, ord_rank, ord_end, jrep, scratch, state, out, worker, workers):
    tid = pl.simt.linear_thread_idx()
    threads = pl.simt.block_dim().x
    n = topk.shape[0]
    e_count = fixed.shape[0]
    ranks = jrep.shape[0]
    epn = e_count // ranks
    chunks = pcnt.shape[1]
    start = worker * threads + tid
    stride = workers * threads
    for c in pl.range(start, chunks, stride):
        for e in pl.range(e_count):
            if fixed[e] < 0:
                a = pl.simt.cast(dpre[e], pl.DT_INT64)
                b = pl.simt.cast(pcnt[e, c], pl.DT_INT64)
                scratch[tid * e_count + e, 0] = pl.simt.cast(a + b, pl.DT_INT32)
                scratch[tid * e_count + e, 1] = 0
                scratch[tid * e_count + e, 2] = -1
        end = (c + 1) * 256
        if n < end:
            end = n
        for i in pl.range(c * 256, end):
            e = pl.simt.cast(topk[i], pl.DT_INT64)
            vid = pl.simt.cast(fixed[e], pl.DT_INT64)
            if vid < 0:
                pos = pl.simt.cast(scratch[tid * e_count + e, 0], pl.DT_INT64)
                if pos >= scratch[tid * e_count + e, 1]:
                    dst = -1
                    seg = 0
                    for o in pl.range(ranks + 1):
                        if dst < 0:
                            if pos < ord_end[e, o]:
                                dst = pl.simt.cast(ord_rank[e, o], pl.DT_INT64)
                                seg = o
                    slot = e % epn
                    if seg > 0:
                        slot = epn + pl.simt.cast(jrep[dst, e], pl.DT_INT64)
                    scratch[tid * e_count + e, 1] = ord_end[e, seg]
                    scratch[tid * e_count + e, 2] = pl.simt.cast(dst * (2 * epn) + slot, pl.DT_INT32)
                vid = pl.simt.cast(scratch[tid * e_count + e, 2], pl.DT_INT64)
                scratch[tid * e_count + e, 0] = pl.simt.cast(pos + 1, pl.DT_INT32)
            out[i] = pl.simt.cast(vid, pl.DT_INT32)
        # `state` is a legacy diagnostic workspace; no algorithm reads it.
        # Keep the launch ABI stable while avoiding the unused GM mirror.
    pl.simt.threadfence()

```

## 15　如何核对本文的数字

输入来自 agent-team-20261116/small-balanced-audit/inputs.json 的 balanced 项。按 rank、token、K 槽排列成小端 int32，SHA-256 为 26580d67352cc105553197cd3f7a5cb153a9f643070567ee36b8e29592968710。

本次用固定提交的 tests/assets/moonep_plan_golden_latest_cpu.py 独立枚举任务与配额，逐条将 VID 解码还原原专家，按目的槽重新统计再核对 cu。文中中间量来自保存输入与源码重放；没有重新运行 NPU 或采集设备中间表。此前同规格四卡实验见 skill 仓库 pipeline_json/2026-11-26/greedy_ab.html。
