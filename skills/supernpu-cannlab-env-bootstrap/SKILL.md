---
name: supernpu-cannlab-env-bootstrap
description: Bootstrap a fresh CannLab CPU-only Linux host into a complete SuperScalar / SuperNPUBench validation environment — build or identity-verify the Linx tile toolchain (linx_blockisa_llvm_musl, clang-15, linx64v5-unknown-linux-musl), build gfrun from SuperScalarModel, prepare SuperNPUBench operator compilation (one-level-arch, res_check=on), and prove the whole chain with an end-to-end matmul precision PASS. Use when onboarding a brand-new CannLab/CPU machine, when COMPILER_DIR or gfrun is missing or broken, when toolchain/model commits need re-pinning to a SuperNPUBench tag, or as the mandatory setup gate before running supernpu-gfrun-accuracy on any fresh host.
---

# CannLab CPU 环境引导:SuperScalar 算子编译 + gfrun 执行 + 精度验证

Turn an empty CannLab CPU host into a working environment where SuperNPUBench
one-level-arch operators compile with the Linx tile toolchain, run on gfrun,
and pass numerical (res_check) validation. Every phase below ends in a gate;
do not proceed to the next phase until the gate passes.

Paths in this skill use three roots; adapt to the host:

```bash
WORK=/path/to/workspace          # persistent workspace (SuperNPUBench worktrees, artifacts)
DEPS=/path/to/deps               # toolchain-build + SuperScalarModel clones (reusable, ~12+ GB)
export ARTIFACTS=$WORK/artifacts # logs + manifest, OUTSIDE tracked source
```

## Component map (who provides what)

| Component | Repo | Role |
|---|---|---|
| SuperNPUBench | `PTO-ISA/SuperNPUBench` (public) | operator library + tests; **only `benchmark/one-level-arch/` and `microbenchmark/` compile** — `two-level-arch` requires an unsupported ISA mode, never batch-compile it |
| linx-toolchain-build | `LinxISA/linx-toolchain-build` (public) | builds the toolchain: llvm-project (`dev-llvm15_56`), linx-musl (`linx`), jemalloc (`linx`), linux headers (`main`), Linx-TileOP-API (`linx`) → `output/linx_blockisa_llvm_musl/{bin,lib,sysroot}` |
| SuperScalarModel | `LinxISA/SuperScalarModel` (**private — needs access**) | `bin/gfrun` functional model, `bin/gfsim` timing model |
| TileOP headers | installed into the toolchain's clang resource dir (`<toolchain>/lib/clang/15.0.4/include/tileop-api/`) | C++ tile-op API the kernels compile against |

**Version authority**: the README of the *selected SuperNPUBench tag* pins the
dependency set (llvm / TileOP / gfrun commits). Read that README from the
checked-out worktree, not from the website default branch. Record one immutable
source tuple per bootstrap: `SuperNPUBench tag@SHA + llvm SHA + TileOP SHA +
gfrun branch@SHA + toolchain-build SHA`, and keep it in the manifest.

## Phase 0 — Host audit (gate: host sanity)

```bash
uname -m                       # aarch64 or x86_64; gfrun builds natively on both
free -h; df -h $WORK $DEPS     # ≥ 30 GB free for deps, ≥ 5 GB for worktrees+ELFs
nproc                          # parallelism budget for builds
python3 --version; python3 -c "import numpy; print(numpy.__version__)"
python3 -c "import torch; print(torch.__version__)"   # golden scripts use torch (numpy fallback)
```

- Host build tools (linx-toolchain-build README): `git make cmake ninja-build
  gcc g++ python3 autoconf m4`. gfrun additionally needs `libelf-dev` and
  Python `toml` (`pip install toml`); ccache is auto-detected if present.
- **CannLab network reality**: GitHub git smart-HTTP can be flaky. If
  `git ls-remote` times out, retry once, then fall back to the GitHub REST API
  via `curl` (`/repos/<org>/<repo>/tags`, `/branches/main`) for version
  queries, and fetch specific SHAs with `git fetch origin <sha>`. `gh` CLI is
  not installed; API + credential-store git works for read and push.
- Gate: all commands return sane values; a 60-second `curl -sI https://github.com`
  succeeds (directly or after retries).

## Phase 1 — Toolchain: reuse-or-build decision, then identity evidence

### Decision gate (do this BEFORE building anything)

If a previous `linx-toolchain-build` clone exists (e.g. shared under DEPS),
**verify identity and reuse; do not rebuild**. A full LLVM build takes hours;
a matching prebuilt tree is the fast path.

```bash
TC=$DEPS/linx-toolchain-build
git -C $TC rev-parse --short HEAD && git -C $TC status --porcelain | head   # record, expect clean
for c in llvm-project musl jemalloc linux-linxisa Linx-TileOP-API; do
  echo "$c: $(git -C $TC/src/$c rev-parse --short=8 HEAD) dirty=$(git -C $TC/src/$c status --porcelain | wc -l)"
done
ls $TC/stamps/   # 10 complete stamps: llvm, kernel-header, musl, compiler-rt,
                 # libcxx/libcxxabi/libunwind (musl), jemalloc, tileopapi, check-write-permission
$TC/output/linx_blockisa_llvm_musl/bin/clang --version
# MUST print: clang version 15.0.4 (... <llvm-SHA> ...) Target: linx64v5-unknown-linux-musl
```

Reuse is valid only when **all** hold: component SHAs match the SuperNPUBench
tag README pins, worktrees clean (untracked autotools temp files like
`configure~` are harmless), stamps complete, and `clang --version` embeds the
pinned llvm SHA. Record the verdict as `REUSED` with the evidence in the
manifest. A mismatch on ANY component → classify the affected artifacts and
rebuild per the invalidation rules in `skills/supernpu-gfrun-accuracy`.

### Cold build path (only when no reusable tree exists)

```bash
git clone https://github.com/LinxISA/linx-toolchain-build.git $TC && cd $TC
sudo apt-get install -y git make cmake ninja-build gcc g++ python3 autoconf m4
make init-src        # clones the 5 component repos on their pinned branches
make WITH_TARGET=linx64v5-linux-musl
```

- Output tree lands in `output/linx_blockisa_llvm_musl/` (bin/lib/sysroot);
  progress is tracked by stamp files under `stamps/`, so a killed build
  **resumes** — never `make clean` to "fix" an interrupted build.
- **Memory discipline** (matters on small hosts): before any build check
  `free -h` and that no other `ninja/make/cc1plus` is active; keep compile
  jobs ≤ 2 (LLVM/Clang Sema targets: 1) and link pool 1; never overlap builds.
  On the WSL-class host documented upstream this is mandatory; on ≥ 32 GB
  hosts `-j$(nproc)` for the musl/jemalloc stages is fine, keep LLVM at -j2.
- Gate: `clang --version` prints the pinned llvm SHA with target
  `linx64v5-unknown-linux-musl`, and `$TC/stamps/` lists all 10 stamps.

## Phase 2 — gfrun (SuperScalarModel)

```bash
git clone https://github.com/LinxISA/SuperScalarModel.git $DEPS/SuperScalarModel
cd $DEPS/SuperScalarModel
# branch discipline: SuperNPUBench README pins a specific branch; check it out
git checkout <pinned-branch>
sudo apt-get install -y libelf-dev && pip install toml
python3 build.py build --target gfrun -j8     # output: bin/gfrun in source tree (gitignored)
```

- **Identity evidence (mandatory)**: rerun `python3 build.py build --target
  gfrun -j8` — it must be a no-op (`[100%] Built target gfrun`, binary mtime
  unchanged). This proves bin/gfrun matches the checked-out source; a stale
  binary from a previous branch is the classic silent-failure source.
- **Pin hazards** (both observed in the wild): a README-pinned gfrun *commit*
  can be unreachable after branch rebase — fall back to the pinned *branch*'s
  current HEAD and record the deviation; and a README may document a worktree
  that contained **uncommitted** TileOP header changes — those cannot be
  reproduced from any commit and must be reported, not silently substituted.
- Gate: `bin/gfrun` exists, rebuild is a no-op, and `gfrun` with no args exits
  with the usage banner (not a loader error).

## Phase 3 — SuperNPUBench checkout + compile smoke

```bash
# bare clone + worktree keeps the tag immutable and shareable across runs
git clone --bare https://github.com/PTO-ISA/SuperNPUBench.git $WORK/supernpubench.git
git -C $WORK/supernpubench.git fetch origin '+refs/heads/*:refs/heads/*' --prune
git -C $WORK/supernpubench.git ls-remote origin 'refs/tags/*'   # resolve LATEST tag remotely — never trust a local checkout
git -C $WORK/supernpubench.git worktree add $WORK/wt/<tag> refs/tags/<tag>
export COMPILER_DIR=$TC/output/linx_blockisa_llvm_musl/bin
```

Read that worktree's README **before** compiling: it pins the dependency set
and documents known per-operator compile/run status. Then smoke-compile one
known-good case (matmul MASK FP32 base variant):

```bash
cd $WORK/wt/<tag>/benchmark/one-level-arch/test/kernel/matmul
make TESTCASE=matmul TYPE=MASK MODE=MASK_FP32 \
     M=256 N=256 K=256 tM=32 tN=32 tK=32 res_check=on
# expect exit 0; ELF at benchmark/one-level-arch/output/kernel/matmul/elf/kernel_matmul/
```

`res_check=on` mechanics (one-level-arch `test/common/Makefile.common`):
adds `-DRES_CHECK -DENABLE_BINARY_OUTPUT -DCHK_DIR="$(ROOT)/compare/<elf-stem>"`,
empties `CC_LINK` and links `group_worker_runtime.o` (hosted-libc build). The
hosted ELF is the 4-PE ABI: gfrun starts PE0 at the ELF entry and PE1..PE3 at
`__linx_group_worker_start` — **a multi-PE kernel compiled WITHOUT
res_check=on has no worker entry and deadlocks at 4 PE** (observed: hangs
forever after `Starting PE0`).

Gate: the smoke case compiles; `Starting PE1..PE3 from lightweight worker
entry` appears in gfrun output.

## Phase 4 — End-to-end precision gate (must PASS)

Run the authoritative oracle for the smoke case —
`multi_thread/matmul/src/gfrun_matmul.py` (covers single-thread MASK and
multi-thread matmul; torch golden with numpy fallback; auto-injects
`-s softcore.multiThreadNum=4` for mt ELFs):

```bash
cd $WORK/wt/<tag>/benchmark/one-level-arch/test/kernel/multi_thread/matmul
python3 src/gfrun_matmul.py --gfrun $DEPS/SuperScalarModel/bin/gfrun \
    -d ../../../../output/kernel/matmul/elf/kernel_matmul/matmul_MASK_MASK_FP32_M256_N256_K256_tM32_tN32_tK32.elf
# expect: run_status: PASS chk_status: PASS metric mse ~1e-15, max_abs ~1e-7
```

PASS requires **all four**: gfrun exit code 0, output contains
`Reach the End of Benchmark`, `R2 = 0`, **and** the oracle (golden compare)
actually executed. This single PASS proves the entire chain: toolchain →
TileOP headers → kernel compile → ELF → gfrun execution → hosted file I/O →
golden comparison. If it passes, the environment is ready for
`supernpu-gfrun-accuracy`. If it fails, bisect at the first broken layer:
compile failure → Phase 1; gfrun assertion/crash → Phase 2; wrong numbers →
pairing (see hazards) or oracle misuse.

Fallback when torch is unavailable: any embedded-oracle case works without
external scripts, e.g. `sort` topk (`make TESTCASE=topk` → `gfrun -f
output/.../topk.elf`, embedded expected data, R2=1 = real accuracy FAIL on a
healthy env — so expect `Reach the End` + R2 reflecting the kernel's known
status) — use it to prove execution only, never as an accuracy PASS.

## Operational knowledge (gfrun invocation cheatsheet)

- `gfrun -t 1 -f <elf>`: **`-t` is a trace/log-level flag** (`1` = basic
  per-instruction log, `2` = tile data dump), NOT a syscall switch. Hosted
  file syscalls (open/read/write for RES_CHECK bins) are built-in and work
  without `-t`. Trace output is huge (topk: 1.0e8 instructions → 13M log
  lines); for big cases run without `-t` and allow ≥ 300 s.
- PE count: hosted ELFs default to 4 PE; single-threaded kernels that read
  inputs themselves can be forced 1 PE with `-s softcore.multiThreadNum=1`
  (4 PE runs the same main 4× — harmless for deterministic file I/O, wasteful
  otherwise). Multi-PE cooperative kernels REQUIRE 4 PE.
- Oracle taxonomy per operator — inspect the test dir before trusting green:
  1. **external golden script** (`gfrun_matmul.py`, `run_precision_check.py`,
     `gen_*_data.py` + `*_data_compare.py` pairs) — authoritative;
  2. **embedded verify** (topk, control hashtable, mega_moe, PR-era
     gather_v2/view_copy: host reference + tolerance compiled into main,
     mismatch → return 1 → R2=1);
  3. **RES_CHECK file I/O with no script** (writes `res.bin` under
     `compare/<elf-stem>/`, inputs must be pre-generated, res.bin
     pre-allocated — the guest cannot create files). Without a maintained
     script, supply your own numpy golden and label one-off runners clearly;
  4. **execution-only** (no oracle) — never report as accuracy PASS; label
     `EXECUTION_ONLY` / `NO_ACCURACY_ORACLE`.
- **Python batch runners can deadlock** on CannLab (ThreadPoolExecutor +
  torch: 53 futex-parked threads, zero progress). If a batch oracle hangs,
  kill it and run per-ELF invocations of the same script (`-d <elf>`, fresh
  process each) — verified workaround.
- Keep raw logs outside tracked source (`$ARTIFACTS/logs/`); compare dirs
  (`benchmark/one-level-arch/compare/<elf-stem>/`) are untracked by design.

## Report

Record in `$ARTIFACTS/manifest_<tag>.md`: the source tuple, reuse/build
verdict + evidence for toolchain and gfrun, Phase 4 gate result with metrics,
and every deviation (unreachable pinned SHA, missing uncommitted change,
fallback used). An environment without a recorded, passing Phase 4 gate is
not a valid baseline for accuracy validation.
