# llvm-project #129 复现产物包

问题：`910e5c8a` 修复后 ① 4 例仍编译失败 ② 新编 ELF 17 例运行期损坏（15 例 gfrun 启动挂死 + conv2d ×2 PE mask 错误发射）。

环境：llvm `910e5c8a` / TileOP `315f3972` / SNB `1f23cc8c` / SSM `91d73841`。

## 目录

| 路径 | 内容 |
|---|---|
| `elf-broken-910e5c8a/` | 17 个坏 ELF（全部由 910e5c8a 编出）。`gfrun -f <elf>` 的预期结果：conv2d ×2 立即断言 `Shared TIMG2COL requires a selected one-hot or all-PE mask`（TMAEngine.cpp:674）；其余 15 个卡死在 `Starting PE0`（无输出，任意超时阈值都杀不掉正常结束） |
| `logs/` | 代表性日志：conv2d 断言全文、gt_old / view_copy 挂死（尾部停在 `Starting PE0`）、gt_old tip 重编后再挂的自证（`gtold_tip_run.log`，rc=124）、group_token_vec 与 dmxq 的编译失败日志（SizeCode 报错） |
| `diss/` | conv2d ×2 与 gt_old ×2 的 `llvm-objdump -dl` 反汇编（conv2d 的 Shared TIMG2COL PE mask 编码可在此直接核对） |

## 最小复现（与 issue #129 一致）

```bash
# 编译失败（问题 A）
cd SuperNPUBench/benchmark/one-level-arch/test/solution/group_token_old/../group_token_vec && bash compile.all
# → error in backend: Local tile descriptor geometry does not fit its SizeCode

# 运行挂死（问题 B，A/B 对照）
cd SuperNPUBench/benchmark/one-level-arch/test/solution/group_token_old && bash compile.all   # 910e5c8a 编译 rc=0
gfrun -f <output>/solution/group_token_old/elf/..._group_token_old.elf                        # → 卡死 Starting PE0
# 同一源码用 25f419f4 编译 → 同一 gfrun 秒级 R2=0（判决性对照，见 issue）
```

## 判决性对照（已在 issue #129 记录）

同一 gt_old 源码：`25f419f4` 编译的 ELF 在 gfrun `91d73841` 上 2/2 秒过 R2=0；`910e5c8a` 编译的 ELF 启动挂死。SSM 自带旧 prebuilt ELF 同一 gfrun 全部正常。→ 损坏在 `910e5c8a` 生成的机器码。
