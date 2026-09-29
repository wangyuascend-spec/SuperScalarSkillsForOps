#!/usr/bin/env bash
set -uo pipefail

skill_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
repo_root=$(git -C "$skill_dir" rev-parse --show-toplevel)
output_rel="skills/github-open-issue-monitor/output"

if ! branch=$(git -C "$repo_root" symbolic-ref --quiet --short HEAD); then
  echo "error: refusing to publish from detached HEAD" >&2
  exit 2
fi

staged_outside=$(
  git -C "$repo_root" diff --cached --name-only |
    awk -v prefix="$output_rel/" 'index($0, prefix) != 1 {print}'
)
if [[ -n "$staged_outside" ]]; then
  echo "error: refusing to commit because unrelated paths are already staged:" >&2
  printf '%s\n' "$staged_outside" >&2
  exit 2
fi

python3 "$skill_dir/scripts/scan_open_issues.py"
scan_status=$?

git -C "$repo_root" add -- "$output_rel"

staged_outside=$(
  git -C "$repo_root" diff --cached --name-only |
    awk -v prefix="$output_rel/" 'index($0, prefix) != 1 {print}'
)
if [[ -n "$staged_outside" ]]; then
  echo "error: staged-path safety check failed:" >&2
  printf '%s\n' "$staged_outside" >&2
  exit 2
fi

if ! git -C "$repo_root" diff --cached --quiet -- "$output_rel"; then
  stamp=$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M CST')
  git -C "$repo_root" commit -m "chore(issue-monitor): update report $stamp"
fi

git -C "$repo_root" push origin "HEAD:$branch"

exit "$scan_status"
