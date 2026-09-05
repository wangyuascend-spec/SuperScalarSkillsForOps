# Baseline update and category smoke validation

Use this reference when preparing a SuperNPUBench tag or branch before detailed operator validation.

## Resolve the requested version

- Always run this step, including targeted operator reruns. Such a request may skip category smoke, but never version preflight.
- Fetch tags and remote branches first. Resolve a supplied tag/branch to a full immutable commit. If the user asks for "current" or supplies no version, select the latest published remote release tag using the repository's documented release/tag convention; report candidate tags and the selected tag instead of treating the local checkout as current.
- Show the resolved baseline ref and full SHA before building. Record the command and remote state used to select "latest" so the decision is reproducible.
- Preserve dirty repositories. Use a clean disposable worktree for SuperNPUBench and do not reset, clean, stash, or overwrite user changes.
- Read the selected version's README and directly linked setup/build documentation from that worktree, not from the previous checkout or the website's default branch.

## Derive and update the dependency set

- Treat the selected README as the authority for dependency repository URLs, branches, tags, commits, build order, compiler paths, and simulator/model pairing.
- Record every repository's before state: path, remote URL, branch or detached state, full commit, dirty status, and submodule state.
- Reuse an existing clean clone when its remote matches. For a dirty or mismatched clone, create a separate clone/worktree; never discard its changes.
- Fetch and check out exactly the README-pinned revision. Do not substitute a newer `main`, an old local branch, or a similarly named repository.
- Initialize/update documented submodules and download documented dependencies. Do not infer additional repositories merely because they exist nearby.
- If a pinned revision is missing, ambiguous, or incompatible, stop that component and report the precise documentation/reference failure instead of guessing.

## Decide what actually needs rebuilding

Make this decision before running CMake, Ninja, Make, or a generator. Load the latest complete manifest for the candidate artifact set and compare it with the new immutable source tuple.

### Fast-path order

1. Resolve all requested commits and dirty states without building.
2. Compare compiler version/hash, installed TileOP header hash, target triple, build flags, target sysroot hash, model commit/hash, SuperNPUBench integration SHA, and per-case input fingerprint.
3. Compute the transitive invalidation closure below.
4. Print the planned `REUSED`/`REBUILT`/`NEW`/`BLOCKED` decisions and reasons.
5. Build only the planned closure, then atomically replace the manifest only after successful completion.

A fetch alone is not a rebuild trigger. Modification time alone is never identity evidence.

### Invalidation matrix

| Changed input | Rebuild | May reuse |
|---|---|---|
| SuperNPUBench kernel/test only | Affected input/golden data when their producer changed; affected operator ELF | Toolchain, coherent sysroot, model, unrelated ELFs |
| TileOP headers only | Install headers; ELFs whose include closure consumes changed headers | LLVM/compiler, sysroot runtimes, model, unaffected ELFs |
| SuperScalarModel only | Required runner, normally `gfrun`; rerun selected ELFs | Matching compiler/sysroot and ELFs |
| LLVM/compiler binary or target ABI | Compiler plus every target runtime/object/archive built by the prior compiler; then affected ELFs | Model when its own source/build inputs match |
| Target triple, linker behavior, ABI flags, or sysroot inputs | Entire consuming target sysroot closure and affected ELFs | Unrelated host tools and model when compatible |
| Generator/shape/seed/dtype/oracle | That case's data, ELF when embedded paths/data/defines change, and accuracy result | Other cases and unchanged dependencies |
| gfrun arguments only | Rerun affected cases | ELF and data when their fingerprints match |

An LLVM source change invalidates old target libraries even when musl, libc++, or jemalloc source commits did not change. A new compiler linked against an old sysroot can fail with format/ABI errors such as `incompatible with elf64llinxv5`; never assemble that mixed toolchain.

### Artifact evidence

- Reuse a dependency binary only when its source and submodule commits, dirty state, build configuration, compiler/upstream identities, artifact SHA-256, and completion status all match.
- Prefer build-system dependency information, depfiles, CMake/Ninja metadata, or a prior complete manifest to calculate consumers.
- Derive an ELF fingerprint from the test and kernel sources, transitive project headers when available, Makefile and compile flags, generated inputs/golden data, compiler binary/version, installed TileOP headers, linker inputs, and selected SuperNPUBench integration commit.
- A change in one operator does not invalidate unrelated ELFs. A model-only change requires rerunning, not recompiling, a matching ELF.
- A missing, partial, failed, or mismatched manifest invalidates reuse. Rebuild once and record reliable evidence instead of guessing.
- Keep the manifest outside tracked source. Record artifact path/hash, fingerprint, source identities, full build command, start/completion time, and status. Update it only after the artifact is complete and readable.

## Build safely

- Follow the selected README's build commands and install locations. Build only artifacts selected by the rebuild decision above; do not accept an existing binary until its identity matches the selected inputs.
- On this WSL host, keep compile concurrency at 2 and link concurrency at 1. Use one compile job for LLVM/Clang Sema or any observed high-memory target. Check available memory and active compiler processes before each large build.
- Preserve complete commands and logs, and record binary version output or another reproducible source-to-binary identity check.
- A failed dependency or binary build blocks downstream smoke cases that require it; classify them as `BLOCKED_BY_BUILD`, not operator failures.

## Select one case per one-level category

- Discover categories from the selected version under `benchmark/one-level-arch/test/kernel`; do not use a hard-coded category list from another release.
- Interpret a category as each immediate maintained grouping exposed by that tree and its build orchestration. If the repository has both top-level domains and nested operator families, report the discovered grouping and choose one representative per top-level domain unless its README/compile script defines a different official classification.
- Prefer, in order: an official smoke/default case, the first maintained `compile.all` case, then the smallest deterministic case that enables `res_check=on`.
- Avoid cases documented as unsupported, stress-only, excessively large, or requiring unavailable external data. Record why the chosen case represents its category.
- Compile the selected case with its documented precision switch and run bounded gfrun. Apply the same oracle checks as the main skill: execution alone is not an accuracy PASS.
- If a category has no numerical oracle, still run its representative execution case when possible and mark it `EXECUTION_ONLY` or `NO_ACCURACY_ORACLE`.

## Approval checkpoint

After the category smoke pass, report:

- resolved SuperNPUBench tag/branch and commit;
- every dependency and binary revision;
- build status and log locations;
- one row per discovered one-level category with chosen case, oracle, gfrun result, and cause of failure;
- PR state/head summary for the selected operator inventory, without checking out or running those PRs yet.

Then explicitly ask whether to proceed with detailed validation of the listed PR implementations and current-tree kernels. Do not fetch PR worktrees, build their cases, or run their gfrun accuracy suite before confirmation unless the user's original request explicitly authorized both phases.

## Compose a PR with the selected baseline

Whenever detailed validation includes an open PR:

1. Query its live state and head SHA; do not rely on an inventory observation date.
2. Fetch both the selected baseline commit and `refs/pull/<N>/head`.
3. Run `git merge-base --is-ancestor <baseline-sha> <pr-head-sha>` and record the exit status.
4. If the PR contains the baseline, use its head. Otherwise create a disposable worktree from the PR head and merge the baseline locally. Record the integration SHA and any explicitly authorized conflict resolution. Resolve only actual conflicts: preserve the PR's existing file layout and intent unless compilation proves a move is required. Do not relocate code merely to match a new directory convention, and retain non-conflicting baseline additions unchanged.
5. Derive every operator ELF fingerprint from this tested source. Never reuse an ELF built from the baseline alone, stale PR head, or a prior integration commit.
6. Keep exact-head-only results separate and labeled; they are not validation against the selected/current release.

Do not mutate or push the PR branch during validation. Treat merge conflicts as a source-integration result, not a kernel accuracy failure.
