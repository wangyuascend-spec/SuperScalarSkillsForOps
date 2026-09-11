# gfsim performance-analysis escalation

Use this reference only when the user asks where time is spent, requests a bottleneck analysis, or a passing case has a performance regression.

Follow the current SuperScalarModel [performance analysis guide](https://github.com/LinxISA/SuperScalarModel/blob/main/modelSpec/performance_analysis_guide.md). Fetch or open the guide at execution time because counter meanings and visualization options can change.

## Escalation order

1. Run ordinary gfsim with PMU and no visualization. Identify the dominant top-down engine/category.
2. Add SwimLane only when macro overlap, starvation, or cross-engine ordering needs inspection.
3. Add PipeView with an engine filter and bounded block/cycle window for instruction/uop stalls.

Do not enable a full unbounded trace as the first run. Large traces can consume hundreds of MiB and distort a memory-constrained WSL workflow.

## Counter invariants

- Use `Total Cycles` as wall-clock model time.
- Check that `Run Tileop Total Cycles + All Cores Idle` is consistent with wall time.
- Do not interpret `superScalar Tileop Total Cycles` as wall time when it sums activity across PEs.
- Counter children under Cube/Vector/TLSU totals may be event counts rather than cycles; follow the current guide's definitions.
- CellReg byte labels and physical beats may differ; use the guide's current beat-size interpretation.
- Do not compare read/write event counts across PE types without normalizing their semantics.

## Attribution discipline

Separate root cause from downstream waiting. Examples:

- TSTORE occupancy dominated by `tile data not ready` points to the producer engine, not necessarily store bandwidth.
- balanced PE utilization plus near-zero all-core idle excludes PE imbalance/starvation.
- high Vector source-buffer blocked cycles together with wide Tile uop splits identifies Vector dispatch pressure more directly than a high aggregate TLSU occupancy number.

For an optimization A/B, keep the model commit, ELF inputs, PE config, and L2 mode fixed. Re-run numerical accuracy separately when kernel code changes.
