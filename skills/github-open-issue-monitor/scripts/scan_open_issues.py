#!/usr/bin/env python3
"""Write a Markdown snapshot of monitored authors' open GitHub issues."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo


SKILL_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = SKILL_ROOT / "references" / "targets.json"
DEFAULT_OUTPUT = SKILL_ROOT / "output"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    return parser.parse_args()


def load_config(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        config = json.load(handle)

    accounts = config.get("accounts", [])
    repositories = config.get("repositories", [])
    if not accounts or not repositories:
        raise ValueError("config must contain non-empty accounts and repositories")

    logins = [item["login"].casefold() for item in accounts]
    if len(logins) != len(set(logins)):
        raise ValueError("duplicate GitHub login in accounts")
    return config


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, capture_output=True, check=False)


def query_open_issues(repository: str) -> list[dict]:
    fields = "number,title,url,author,createdAt,updatedAt,labels"
    result = run(
        [
            "gh",
            "issue",
            "list",
            "--repo",
            repository,
            "--state",
            "open",
            "--limit",
            "1000",
            "--json",
            fields,
        ]
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown gh error"
        raise RuntimeError(detail)
    return json.loads(result.stdout)


def clean_cell(value: object) -> str:
    return str(value or "").replace("|", "\\|").replace("\n", " ").strip()


def display_time(value: str) -> str:
    if not value:
        return ""
    return value.replace("T", " ").replace("Z", " UTC")


def build_report(
    *,
    generated_at: datetime,
    config: dict,
    issues_by_repo: dict[str, list[dict]],
    errors: dict[str, str],
) -> str:
    account_map = {
        item["login"].casefold(): item["name"] for item in config["accounts"]
    }
    total = sum(len(items) for items in issues_by_repo.values())
    lines = [
        "# 监控账号未关闭 Issue 报告",
        "",
        f"- 生成时间：{generated_at.isoformat(timespec='seconds')}",
        f"- 时区：{config['timezone']}",
        f"- 监控账号：{len(config['accounts'])}",
        f"- 目标仓库：{len(config['repositories'])}",
        f"- 匹配的未关闭 Issue：{total}",
        "",
        "## 汇总",
        "",
        "| 类型 | 仓库 | 未关闭 Issue | 查询状态 |",
        "| --- | --- | ---: | --- |",
    ]

    for target in config["repositories"]:
        repo = target["name"]
        status = "失败" if repo in errors else "成功"
        lines.append(
            f"| {clean_cell(target['category'])} | "
            f"[{repo}](https://github.com/{repo}) | "
            f"{len(issues_by_repo.get(repo, []))} | {status} |"
        )

    for target in config["repositories"]:
        repo = target["name"]
        issues = issues_by_repo.get(repo, [])
        lines.extend(["", f"## {repo}", ""])

        if repo in errors:
            lines.append(f"查询失败：`{clean_cell(errors[repo])}`")
            continue
        if not issues:
            lines.append("没有匹配监控账号的未关闭 Issue。")
            continue

        lines.extend(
            [
                "| Issue | 作者 | 标题 | 创建时间 | 更新时间 | 标签 |",
                "| ---: | --- | --- | --- | --- | --- |",
            ]
        )
        for issue in issues:
            author = (issue.get("author") or {}).get("login") or "unknown"
            owner_name = account_map.get(author.casefold(), "")
            author_text = f"{owner_name} (`{author}`)" if owner_name else f"`{author}`"
            labels = ", ".join(
                clean_cell(label.get("name")) for label in issue.get("labels", [])
            )
            lines.append(
                f"| [#{issue['number']}]({issue['url']}) | {author_text} | "
                f"{clean_cell(issue['title'])} | {display_time(issue['createdAt'])} | "
                f"{display_time(issue['updatedAt'])} | {labels or '-'} |"
            )

    lines.extend(["", "## 监控账号", ""])
    for item in config["accounts"]:
        lines.append(
            f"- {item['name']} — [`{item['login']}`]"
            f"(https://github.com/{item['login']})"
        )

    if errors:
        lines.extend(["", "## 查询错误", ""])
        for repo, detail in errors.items():
            lines.append(f"- `{repo}`：{clean_cell(detail)}")

    lines.append("")
    return "\n".join(lines)


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(
        dir=path.parent, prefix=f".{path.name}.", text=True
    )
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> int:
    args = parse_args()
    if shutil.which("gh") is None:
        print("error: GitHub CLI 'gh' is not installed", file=sys.stderr)
        return 2

    auth = run(["gh", "auth", "status", "--hostname", "github.com"])
    if auth.returncode != 0:
        detail = auth.stderr.strip() or auth.stdout.strip()
        print(f"error: GitHub authentication failed: {detail}", file=sys.stderr)
        return 2

    try:
        config = load_config(args.config)
        timezone = ZoneInfo(config["timezone"])
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"error: invalid configuration: {error}", file=sys.stderr)
        return 2

    monitored = {item["login"].casefold() for item in config["accounts"]}
    issues_by_repo: dict[str, list[dict]] = {}
    errors: dict[str, str] = {}

    for target in config["repositories"]:
        repo = target["name"]
        try:
            issues = query_open_issues(repo)
            matched = [
                issue
                for issue in issues
                if ((issue.get("author") or {}).get("login") or "").casefold()
                in monitored
            ]
            issues_by_repo[repo] = sorted(
                matched, key=lambda item: item["updatedAt"], reverse=True
            )
        except (RuntimeError, json.JSONDecodeError) as error:
            issues_by_repo[repo] = []
            errors[repo] = str(error)

    generated_at = datetime.now(timezone)
    report = build_report(
        generated_at=generated_at,
        config=config,
        issues_by_repo=issues_by_repo,
        errors=errors,
    )
    dated_path = (
        args.output_dir
        / generated_at.strftime("%Y-%m-%d")
        / f"{generated_at.strftime('%H%M%S')}-open-issues.md"
    )
    latest_path = args.output_dir / "latest.md"
    atomic_write(dated_path, report)
    atomic_write(latest_path, report)

    print(dated_path)
    print(latest_path)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
