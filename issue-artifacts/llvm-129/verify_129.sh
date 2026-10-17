#!/bin/bash
# ============================================================================
# llvm-project#129 验收脚本 —— 编译通过 ≠ 修复完成
# 完整验收 = ① compile.all rc=0  ② gfrun 跑到终点输出 R2  ③ gfsim 出现 Report Stop
# 用法:
#   COMPILER_DIR=/path/to/linx_blockisa_llvm_musl/bin \
#   SNB=/path/to/SuperNPUBench SSM=/path/to/SuperScalarModel ./verify_129.sh
# 判据:
#   gfrun PASS = 日志含 "R2 = 0"（gather_v2/view_copy 例外: 已知 MGATHER 索引
#                问题未合入元素语义修复前, 健康基线是 "跑到终点 R2 = 1", 不挂死即可）
#   gfsim DONE = 日志含 "SuperScalar Report Stop"
# ============================================================================
set -u
SNB=${SNB:?set SNB=/path/to/SuperNPUBench}
SSM=${SSM:?set SSM=/path/to/SuperScalarModel}
COMPILER_DIR=${COMPILER_DIR:?set COMPILER_DIR=<linx_blockisa_llvm_musl>/bin}
export baremetal=off
OUT=$SNB/benchmark/one-level-arch/output/solution
UNITS="conv2d gather_v2 group_token_old group_token_vec matmul_test mega_moe \
       moe_combine moe_dispatch normalization/group_norm_grad normalization/rms_norm \
       quant/dynamic_mx_quant view_copy"

echo "==================== ① 编译 ===================="
for u in $UNITS; do
  (cd "$SNB/benchmark/one-level-arch/test/solution/$u" && bash compile.all) \
    > /tmp/verify129_build_$(echo $u | tr / _).log 2>&1
  rc=$?
  nelf=$(find "$OUT/$u" -name '*.elf' 2>/dev/null | wc -l)
  err=$(grep -m1 -oE "error in backend: [^\"]{0,55}" /tmp/verify129_build_$(echo $u | tr / _).log 2>/dev/null)
  echo "compile rc=$rc elf=$nelf  $u  ${err:+→ $err}"
done

run_gfrun() {  # $1=elf $2=pe4(true/false)
  log=/tmp/verify129_gfrun_$(basename $1).log
  if [ "$2" = true ]; then
    timeout 900 $SSM/bin/gfrun -s softcore.multiThreadNum=4 -f "$1" > "$log" 2>&1
  else
    timeout 900 $SSM/bin/gfrun -f "$1" > "$log" 2>&1
  fi
  rc=$?
  if   grep -q "R2 = 0" "$log"; then echo "PASS(rc=$rc)"
  elif grep -q "R2 = 1" "$log"; then echo "END_R2=1(rc=$rc)"
  elif grep -q "ASSERTION" "$log"; then echo "ASSERT(rc=$rc)"
  elif [ $rc -eq 124 ]; then echo "HANG(timeout)"
  else echo "NOEND(rc=$rc)"; fi
}
run_gfsim() {  # $1=elf-abs $2=pe4(true/false)  —— 必须在 SSM 目录下运行（--conf 按 CWD 解析）
  log=/tmp/verify129_gfsim_$(basename $1).log
  cd "$SSM" || return 1
  if [ "$2" = true ]; then
    timeout 1800 $SSM/bin/gfsim --conf fourpe -f "$1" > "$log" 2>&1
  else
    timeout 1800 $SSM/bin/gfsim -f "$1" > "$log" 2>&1
  fi
  rc=$?
  if   grep -q "SuperScalar Report Stop" "$log"; then echo "DONE(rc=$rc)"
  elif grep -q "ASSERTION" "$log"; then echo "ASSERT(rc=$rc)"
  elif [ $rc -eq 124 ]; then echo "HANG(timeout)"
  else echo "FAIL(rc=$rc)"; fi
}

echo; echo "==================== ② gfrun / ③ gfsim ===================="
cd "$OUT" || exit 1
find . -name "*.elf" | sort | while read -r rel; do
  name=$(basename "$rel"); pe4=false
  case "$name" in *_mt*|*PE4*|*_4pe*) pe4=true;; esac
  g=$(run_gfrun "$rel" $pe4)
  s=$(run_gfsim "$OUT/${rel#./}" $pe4)
  printf "%-12s %-9s %-60s\n" "$g" "$s" "$name"
done
echo
echo "判据回顾: gfrun PASS=「R2 = 0」(gather_v2/view_copy 允许 END_R2=1); gfsim DONE=「SuperScalar Report Stop」"
echo "任何 HANG/ASSERT/FAIL/NOEND 都表示修复不完整 —— 编译通过不等于问题解决。"
