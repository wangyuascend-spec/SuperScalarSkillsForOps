---
name: github-open-issue-monitor
description: Scan five PTO/SuperNPU GitHub repositories for open issues authored by a fixed monitored-account list and write timestamped local Markdown reports. Use for scheduled or on-demand monitoring of those authors' unresolved issues; never use it to create, edit, comment on, or close GitHub issues.
---

# GitHub 未关闭 Issue 监控

检查 [目标配置](references/targets.json) 中的 GitHub 仓库，筛选 author login 属于监控账号列表且状态为 open 的 Issue，并把结果写入本 Skill 的 `output/`。

## 执行

在 Skill 根目录运行：

```bash
python3 scripts/scan_open_issues.py
```

脚本使用当前已登录的 GitHub CLI，只读查询 Issue。不得创建、编辑、评论、关闭 Issue，也不得把 Pull Request 当成 Issue。

每次运行生成：

- `output/YYYY-MM-DD/HHMMSS-open-issues.md`：本次不可变快照；
- `output/latest.md`：最新一次快照。

报告必须包含抓取时间、目标仓库、每条 Issue 的编号、标题、作者、创建/更新时间、标签和链接。没有匹配项的仓库也要明确记录为 0。

## 失败处理

- 先要求 `gh auth status` 成功；私有模型仓库不可访问时不得静默跳过。
- 任一仓库查询失败时，仍写报告并列出失败仓库和错误摘要，然后以非零状态退出。
- 不要用陈旧报告冒充本次结果，不要删除历史快照。
- 修改账号或仓库范围时，只更新 `references/targets.json`，并在下一次报告中使用新配置。
