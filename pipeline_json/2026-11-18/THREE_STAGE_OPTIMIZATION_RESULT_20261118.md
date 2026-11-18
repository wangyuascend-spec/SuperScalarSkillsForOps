# MoonEP 三阶段优化结果

Count dead658已合入：balanced compute配对降低17.6%。Count/Greedy重叠因mode2退化约36%淘汰。Assign SIMD最终提交60c9288，以下为验收原文。各批次统计独立，不跨批拼算。

# Assign SIMD 快慢分流验收（2026-11-18）

本次基于 `dead658` 的 Count 优选版本，仅优化 `LatestDistributedPlan` 的 distributed trusted mode1、E=16 且 256<N=S*K<=4096 的 Assign。单rank local、strict、mode0/2和其他规格保留原路径。Count/Greedy投机重叠因mode2计算恶化35%～36%而淘汰，未合入本次变更。通信未修改，也没有增加设备输入校验。

## 实现与精度

SIMD gather 使用 U32 专家索引映射 I32 fixed VID；负 VID 位置通过 STORE_REG squeeze 稳定压缩。原整数慢路仅遍历这些位置，保留 dpre+pcnt、segment、jrep 与 VID 整数算术及源内顺序。VID和位置未转换为浮点。谓词计数最多256个0/1，FP32加和精确可表示，再转I32。新增UB布局为 scratch[0,512)、fixed[512,576)、top[576,1600)、values[1600,2624)、slow[2624,3648)、count[3648,3680)，无重叠。idle AIV 以valid_count=0统一发起VF，避免部分核调用差异。

所有函数/类AST与通过回归的最终候选一致；去掉新增import、将唯一SIMD条件替换为原fallback并恢复模块说明，可精确恢复基线整个模块AST。外部JIT launch参数AST完全未变。

首轮screen虽然112项API和六组性能case五输出均通过，但R4E16S257K1/W1多wave尾块失败，故被明确判FAIL。独立检查actual CCE定位到wave末MTE3→V未给下一次MTE2 load建立top UB复用依赖。只将event3改为MTE3→MTE2，保留V→MTE3链；没有新增全局屏障、cachefence或按失败shape跳过。最小修改后原失败shape及增强尾块全部通过。原失败证据保留，不用初筛速度代替最终通过数据。

## 数值验收

全部NPU执行经共享机器qrun FIFO：

- API：4种fixed布局、14种valid_count（含0和256）、2次重复，共112项；投影VID、精确计数、稳定位置逐元素通过。
- 修复回归：R4E16S257K1W1、R4E16S129K3W1、R4E16S1024K4W32、R4E16S129K2W32、strict R1E16S129K2W32、R4E12S129K2W4，各9轮，共189 rank-round。包括多wave、尾1/131/2、idle AIV及mode0/1/2反复切换；五输出独立golden、queued复用和生命周期保护全部通过。
- R2补验：R2E16S129K3W1、R2E16S1024K4W32，各9轮，共36 rank-round；五输出、queued复用、shape/stream保护全部通过。
- 正式性能同时验证：六组scope/路由，每组4rank各69次调用（每版本3次预热+20次计时）；全部五业务输出同时对实际DSL和独立golden逐元素相等。
- CPU：原19项加实际整数慢路300个rank/mode语义场景的新测试，共20项unittest通过。CPU的投影/压缩由整数构造，仅验证整数慢路算法，不模拟SIMD、缓存或同步。
- R8E16S129K3及默认R8E224S8192K16仅真实纯编译通过，不代表八卡硬件验证。

可复跑CPU：`python3 -m unittest discover -s tests -p 'test_*cpu.py'`。真实设备回归入口为 `tests/native_latest_check.py`，例如 `--ranks 2 --experts 16 --tokens 129 --topk 3 --workers 1 --rounds 9 --trusted`；在共享环境仍必须经qrun。

## 同批性能

共同输入：4卡，每卡S1024、K4、总专家E16、seed42、实际32 AIV。balanced为每token从E16随机无重复选4；skewed为专家0..3随机顺序；extreme固定[0,1,2,3]，后两者直方图相同并走mode2。不是默认八卡S8192/K16/E224的性能。

旧版A=`dead658`，候选B=本次SIMD，DSL=用户快照关闭SIMD Count的scalar诊断参考。保留这一来源标注；不能把它冒充未修改DSL性能。三个版本同一batch同输入逐元素精度对照。计时为msprof Task Duration，精确核对SO/source/PID/device/symbol和Block Num=32。所有20个样本及长尾原样保存在验收JSON，未按“稳定段”筛选。

balanced compute：四rank中位数的中位数，旧57.7635 μs、新35.1635 μs、DSL25.8835 μs。每rank逐次配对比中位数的中位数，新/旧0.6080378，降低39.20%；80/80配对改善，范围0.58804～0.634995。新/DSL为1.3560358，仍慢35.6%，尚未达到10%以内。旧/DSL为2.2354007。

skewed compute：旧14.220、新13.803、DSL34.742 μs，配对新/旧0.976051。extreme compute：旧14.2035、新13.82225、DSL34.63325 μs，配对0.985505；保留mode2快路，未见此前投机重叠的明显退化。它们是不同输入，不能与balanced交叉拼比值。

balanced full：旧79.716、新52.74925、DSL41.8265 μs，配对新/旧0.680988，新/DSL1.256564。但完整路径受到达偏斜影响，不能把上述compute收益直接等同所有路由端到端收益：skewed full配对0.975374，extreme full配对1.024667；extreme候选最大样本6528.445 μs仍原样保留。没有剔除长尾，也没有用full减compute推算通信时间。本轮未重新采集通信-only，不宣称通信本身提速。

## 证据与范围

正式qrun `l00805731-moon-assign-simd-confirm-20261118` 于21:56:03 exit0；修复强回归21:26:17 exit0；R2补验22:12:31 exit0。源SHA、每rank20个原始时间、配对比、实际SO和符号绑定、API/回归日志SHA见 [`tests/assets/assign_simd_validation_20261118.json`](tests/assets/assign_simd_validation_20261118.json)。原始自有JSON/CSV保存在实验结果目录；不发布含其他用户队列表的前台日志。没有八卡性能、性能追平或所有shape性能泛化声明。
