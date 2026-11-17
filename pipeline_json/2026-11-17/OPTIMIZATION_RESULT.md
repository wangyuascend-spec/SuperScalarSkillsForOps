# Publish coherent-read broadcast validation

Baseline: `bef6929`. Only `_publish_greedy` changes. Worker 0 / lane 0 performs one coherent `atomic_add(flag[0], 0)` and broadcasts its result in UB, replacing 64 lanes contending on the same GM address. All lanes/AIV execute unconditional `syncthreads`; strict mode neither overwrites nor reads the broadcast. No routing arithmetic, communication, launch count, phase barrier or workspace allocation changes.

UB lifetime: `ub_loads[0,0]` is overwritten only after its sole reader (lane 0) has published the original load to GM. Other lanes publish distinct load slots. No later consumer reads the original UB loads; next-call Greedy initializes them. Actual generated kernel.cpp was downloaded and SHA-verified: A has the lane-wide atomic, B has a tid0 atomic, UB store, `__sync_workitems` and UB load. Production comments/license/formatting are preserved; all function ASTs exactly match the board candidate. Both source hashes are recorded.

A serialized stage diagnostic on small balanced found worker 0 Publish about 19,195 raw cycles, including publication and coherent reads. Extra trace fences alter overlap, so these raw cycles are not production microseconds or additive percentage attribution.

## Full fused A/B confirmation

R4, matched 32 AIV, seed42, separate A/B Window groups in one process. Three warmups and twenty measured calls per side, alternating AB/BA; all tails retained. Each configuration has 4 ranks x 46 exact calls (736 calls across four cases). Actual source/SO hashes, complete Ascend symbols, PID/device mapping and profiler task counts were checked: 32 SO identities.

- S1024/K4/E16 balanced: per-rank paired B/A medians 0.8211–0.8800 (12.0–17.9% lower); median of rank medians 108.320 -> 90.318 us.
- Same small shape skewed: paired 0.5542–0.7729 (22.7–44.6% lower); 58.296 -> 40.853 us.
- S8192/K16/E112 balanced: paired 0.9384–0.9661 (3.4–6.2% lower); 305.410 -> 288.136 us.
- Same large shape skewed: paired 0.9551–0.9659 (3.4–4.5% lower); 389.567 -> 376.626 us.

Independent medians and paired medians use different aggregation. Small balanced still has arrival outliers up to paired 11.14x; all ranks have a majority of winning samples. This is full fusion against the previous PyPTO version, **not** a new compute-only comparison with DSL. The previously measured compute-only gap remains separate.

## Numerical and lifecycle regression

Foreground FIFO qrun `l00805731-moon-publish-confirm-20261117` ended 2026-11-17 13:33:17, exit0. Four additional native cases each passed nine rounds:

- Strict R4/E12/S129/K2/w4 (partial chunks, invalid inputs).
- Strict R1/E1/S7/K1/w1 (strict bypass and single-rank path).
- Trusted R4/E1024/S129/K2/w8 (large UB/workspace shape).
- Trusted R1/E4/S129/K2/w4 (explicit mode0 and partial chunks).

Every case checks golden outputs/status, queued asynchronous reuse, shape/stream/epoch/closed guards; strict cases also reject invalid inputs. Paired inputs cover mode1 and mode2. The extra mode0 case used a versioned immutable launcher appended while cmd_pid=0; its actual execution marker and hashes are retained. No queue entry or other task was changed.

Evidence: `tests/assets/publish_broadcast_validation_20261117.json`; workspace `agent-team-20261117/publish-broadcast/confirm`; remote `logs/publish-broadcast-confirm-20261117`. CPU18 and whitespace checks are rerun after integration. CPU models algorithmic semantics, not hardware concurrency. Eight-card execution and new compute-only/DSL timings are untested.
