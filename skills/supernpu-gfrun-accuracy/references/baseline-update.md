# Baseline update and category smoke validation

Use this reference when preparing a SuperNPUBench tag or branch before detailed operator validation.

## Resolve the requested version

- Require a concrete tag or branch. If none was supplied, ask for it before changing repositories.
- Fetch tags and remote branches, resolve the requested name to a full immutable commit, and show the resolution before building.
- Preserve dirty repositories. Use a clean disposable worktree for SuperNPUBench and do not reset, clean, stash, or overwrite user changes.
- Read the selected version's README and directly linked setup/build documentation from that worktree, not from the previous checkout or the website's default branch.

## Derive and update the dependency set

- Treat the selected README as the authority for dependency repository URLs, branches, tags, commits, build order, compiler paths, and simulator/model pairing.
- Record every repository's before state: path, remote URL, branch or detached state, full commit, dirty status, and submodule state.
- Reuse an existing clean clone when its remote matches. For a dirty or mismatched clone, create a separate clone/worktree; never discard its changes.
- Fetch and check out exactly the README-pinned revision. Do not substitute a newer `main`, an old local branch, or a similarly named repository.
- Initialize/update documented submodules and download documented dependencies. Do not infer additional repositories merely because they exist nearby.
- If a pinned revision is missing, ambiguous, or incompatible, stop that component and report the precise documentation/reference failure instead of guessing.

## Build safely

- Follow the selected README's build commands and install locations. Rebuild binaries affected by changed source revisions; do not accept an existing binary until its embedded/version output matches the selected source.
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
