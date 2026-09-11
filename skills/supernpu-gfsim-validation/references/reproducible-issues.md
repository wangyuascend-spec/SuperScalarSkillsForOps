# Reproducible gfsim issues

Read this reference only when the user asks to create or update an issue.

## Ownership and title

- File a model assertion, deadlock, unsupported timing behavior, or incorrect PMU result in `LinxISA/SuperScalarModel`.
- File an invalid kernel, test invocation, shape, tiling rule, or missing oracle in `PTO-ISA/SuperNPUBench`.
- File a compiler-generated instruction/metadata defect in the compiler repository after proving the source/kernel contract is valid.

Use exactly one execution prefix and one responsible module:

```text
[gfsim][VECTOR] concise failure description
[gfsim][TLSU] concise failure description
[gfsim][BFU] concise failure description
```

Do not use an operator category such as `normalization` as the model module when the failing unit is known.

## Required reproduction bundle

Include:

- complete source tuple and host architecture;
- gfsim build command, MD5, and model full commit;
- ELF build command, SHA256, shape, dtype, PE count, and whether it is RES_CHECK;
- exact command from the SuperScalarModel root;
- effective `fourpe` and explicit real/fake-L2 log lines;
- exit code, timeout, cycle, thread, block, first stalled instruction, and first assertion;
- a passing single-variable comparison when available;
- expected behavior and checkable acceptance criteria.

Make the ELF downloadable when practical. If the issue interface cannot upload a binary, use an authorized durable artifact location, include its SHA256, and provide exact decode/download commands. Never link a local path as if another environment could access it.

Before filing, search open and closed issues for the same instruction and failure signature. A new issue that follows an older fix should state the old issue/PR and the exact remaining condition rather than duplicating the original scope.

Do not create, edit, close, or comment on an issue without explicit user authorization.
