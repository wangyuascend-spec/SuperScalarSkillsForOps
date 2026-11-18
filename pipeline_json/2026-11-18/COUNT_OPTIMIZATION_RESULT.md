# Count 优化结果

PR dead658；balanced compute 69.5145→57.433 μs，paired降低17.6%，DSL25.9988 μs，剩余2.216倍。完整调用存在长尾，未承诺稳定端到端收益。Count/Greedy重叠排队、Assign SIMD仅编译通过。
