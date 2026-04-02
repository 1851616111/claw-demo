# claw-demo

This repository stores the operating model for the "Lobster Knight" human-agent collaboration demo.

## 龙虾骑士线上入口（本项目默认）

在本仓库内讨论、查询或跳转 **Wiki / Jira** 时，默认使用以下地址（勿混用其他站点，除非用户另有说明）：

| 用途 | 地址 |
| --- | --- |
| Confluence Wiki（站点首页） | https://netstars-sre-demo.atlassian.net/wiki/home |
| Jira 龙虾骑士看板（项目 KAN，board id 2） | https://netstars-sre-demo.atlassian.net/jira/software/projects/KAN/boards/2 |

JQL / `acli` 等项目键：**KAN**；站点：`netstars-sre-demo.atlassian.net`。

Current docs:

- [龙虾骑士看板模板](docs/lobster-board-template.md)
- [Jira Relay](services/jira-relay/README.md)
- [Planner 任务模板（SPEC / 提示词规格）](docs/planner-task-spec-templates.md) — 经人工验证后固化的 Planner 规格，减少复杂任务多轮来回
- [Confluence 空间源稿（分类任务页）](docs/confluence-space/README.md)
