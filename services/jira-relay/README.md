# Jira Relay

## 目标

这个服务只做一件事：在 `8080` 端口接收 Jira 的 HTTPS 事件请求，做最小结构整理后，再固定转发到 OpenClaw 官方 `hooks` 端点。

推荐链路：

`Jira Automation / Jira Admin Webhook -> ALB (HTTPS) -> EC2:8080 -> jira-relay -> 127.0.0.1:18789/hooks/jira-relay`

## 目录

这个目录本身就是一个独立的小 Node 项目：

- `server.js`：服务入口
- `.env.example`：环境变量示例
- `smoke-test.js`：最小链路测试
- `simulate-jira-automation.js`：模拟 Jira Automation 请求

## 启动

1. 复制 `.env.example` 为 `.env`
2. 按需要修改 `RELAY_AUTH_TOKEN`
3. 如果要接 Jira 原生 admin webhook，再设置 `JIRA_WEBHOOK_SECRET`
4. 如果 OpenClaw hooks 不是监听默认地址，修改 `LOBSTER_TARGET_URL`
5. 将 `LOBSTER_AUTH_TOKEN` 设置成 OpenClaw 的专用 hook token
6. 启动服务：

```bash
npm start
```

默认监听：

- `POST /jira/events`
- `GET /healthz`

默认端口：

- `8080`

## Ubuntu 部署（systemd）

仓库内提供了可直接落地的示例文件：

- `deploy/ubuntu/jira-relay.service`：systemd unit
- `deploy/ubuntu/jira-relay.env`：环境变量模板（复制到 `/etc/jira-relay.env`）
- `deploy/ubuntu/install.sh`：一键部署脚本（同步到 `/opt/jira-relay` 并启动 systemd）

## 环境变量

| 变量 | 说明 | 默认值 |
| --- | --- | --- |
| `PORT` | 监听端口 | `8080` |
| `HOST` | 监听地址 | `0.0.0.0` |
| `RELAY_PATH` | 接收路径 | `/jira/events` |
| `HEALTH_PATH` | 健康检查路径 | `/healthz` |
| `RELAY_AUTH_TOKEN` | Jira 调用 relay 时使用的 Bearer token | 无，必填 |
| `JIRA_WEBHOOK_SECRET` | Jira 原生 admin webhook 的 HMAC secret | 默认回退到 `RELAY_AUTH_TOKEN` |
| `JIRA_BASE_URL` | Jira 站点根地址，用于补出工单链接 | 空 |
| `JIRA_BOARD_URL` | 默认看板链接，用于 Planner 消息展示 | 空 |
| `JIRA_BOARD_NAME` | 默认看板名称 | 空 |
| `LOBSTER_TARGET_URL` | 固定转发地址 | `http://127.0.0.1:18789/hooks/jira-relay` |
| `LOBSTER_AUTH_TOKEN` | relay 转发给 OpenClaw hooks 时附带的 Bearer token | 空 |
| `REQUEST_TIMEOUT_MS` | 转发超时时间 | `10000` |
| `BODY_LIMIT_BYTES` | 最大请求体大小 | `1048576` |

## 当前行为

relay 只做三件事：

1. 接收 Jira webhook
2. 校验下面两种入站鉴权之一：
   - `Authorization: Bearer <RELAY_AUTH_TOKEN>`
   - `X-Hub-Signature` / `X-Hub-Signature-256`，使用 `JIRA_WEBHOOK_SECRET` 做 HMAC 验签
3. 转发到 `LOBSTER_TARGET_URL`

如果 payload 里没有工单链接或看板链接，relay 会尝试用以下环境变量补齐：

- `JIRA_BASE_URL` -> `https://.../browse/<ISSUE_KEY>`
- `JIRA_BOARD_URL`
- `JIRA_BOARD_NAME`

如果 Jira 发来的是原生 issue webhook，relay 还会自动做这些兼容处理：

- 从 Jira 富文本 description 里提取纯文本，方便 Planner 读 `allow_execute: true`
- 从 `changelog.items` 里补出 `previousStatus`
- 用 `JIRA_BASE_URL` 自动补 `issueUrl`

## OpenClaw Hook 配置

仓库里已经放好一个和 relay 对齐的 OpenClaw 配置示例：

- `deploy/openclaw/openclaw.hooks.jira-relay.example.json`
- `deploy/openclaw/openclaw.hooks.env.example`

这份配置使用 OpenClaw 官方 `hooks.mappings` 机制，把 relay 发来的结构化 payload 映射到：

- `POST /hooks/jira-relay`
- `action: "agent"`
- `sessionKey: "hook:jira:{{issue.key}}:{{relay.correlationId}}"`
- `deliver: true`
- `channel: "slack"`
- `to: "channel:<slack-channel-id>"`

推荐让这条 hook 直接扮演 `Planner`，但要注意两点：

- 关键行为规则应放在 workspace 的 `IDENTITY.md` / `MEMORY.md` / skills 中
- hook `messageTemplate` 只保留 Jira 事件事实和结构化上下文，避免把大段提示词作为外部 webhook 文本发进去

- 使用简体中文
- 显示可点击的工单链接
- 显示可点击的看板链接
- 给出任务初步分析，而不是只做“收到”确认
- 对边界清晰的 demo 任务，可以由 Planner 直接兼任执行者

当前 demo 推荐直接支持：

- `创建 S3 bucket`
  - 使用 `aws --profile ai`
  - 默认 `ap-northeast-1`
  - 只允许创建新的私有 bucket
  - 不允许 public ACL / public policy / delete

建议：

1. 使用专用 hook token，不要复用 gateway token
2. 将该 token 同时填到：
   - OpenClaw 配置里的 `hooks.token`
   - relay 的 `LOBSTER_AUTH_TOKEN`
3. 如果你希望 Jira 事件直接发到 Slack，把映射里的 `deliver` 打开，并设置：
   - `channel: "slack"`
   - `to: "channel:<你的频道ID>"`
4. 对 Slack 频道入口，建议同时配置：
   - `channels.slack.groupPolicy: "allowlist"`
   - `channels.slack.channels.<id>.allow: true`
   - `channels.slack.channels.<id>.requireMention: false`
     如果你只希望机器人在被 `@OpenClaw` 时回复，再改成 `true`
5. 保持 OpenClaw hooks 只暴露在 loopback，由 relay 本地转发

## Jira Automation 请求体示例

```json
{
  "event": "issue_created",
  "issueKey": "{{issue.key}}",
  "summary": {{issue.summary.asJsonString}},
  "projectKey": "{{issue.project.key}}",
  "status": "{{issue.status.name}}",
  "issueUrl": {{issue.url.asJsonString}},
  "issueType": "{{issue.issueType.name}}",
  "priority": {{issue.priority.name.asJsonString}},
  "serviceDomain": {{issue.服务域.asJsonString}},
  "executionMode": {{issue.执行模式.asJsonString}},
  "context": {
    "taskGoal": {{issue.任务目标.asJsonString}},
    "plannerOutput": {{issue.Planner输出.asJsonString}},
    "taskContext": {{issue.任务上下文.asJsonString}},
    "description": {{issue.description.asJsonString}},
    "boardUrl": "https://netstars-sre-demo.atlassian.net/jira/software/projects/KAN/boards/2",
    "boardName": "龙虾骑士看板"
  }
}
```

请求头：

```text
Authorization: Bearer <RELAY_AUTH_TOKEN>
Content-Type: application/json
```

## Jira Admin Webhook 示例

Atlassian 官方支持通过 Jira 原生 webhook 推送多个 issue/comment 事件到同一个端点：

- issue: `jira:issue_created` `jira:issue_updated` `jira:issue_deleted`
- comment: `comment_created` `comment_updated` `comment_deleted`

注册时推荐：

- `url`: `https://weaclaw-dp-oghwck1gy3hj.nssclaw.com/jira/events`
- `filters.issue-related-events-section`: `project = KAN`
- `excludeBody`: `false`
- `secret`: 使用 `JIRA_WEBHOOK_SECRET`

官方文档：

- Jira webhooks: `https://developer.atlassian.com/cloud/jira/software/webhooks/`

## 转发后的结构

relay 发给 OpenClaw hooks 的 body 结构如下：

```json
{
  "relay": {
    "service": "jira-relay",
    "version": "0.1.0",
    "correlationId": "uuid",
    "targetUrl": "http://127.0.0.1:18789/hooks/jira-relay",
    "receivedAt": "2026-04-02T08:00:00.000Z",
    "source": {
      "method": "POST",
      "path": "/jira/events",
      "remoteAddress": "::ffff:10.0.0.10",
      "userAgent": "Atlassian HttpClient"
    }
  },
  "event": {
    "name": "issue_created",
    "status": "待办",
    "previousStatus": null,
    "serviceDomain": "aws",
    "executionMode": "单Agent"
  },
  "issue": {
    "key": "KAN-1",
    "id": "10014",
    "summary": "创建 demo 环境",
    "projectKey": "KAN",
    "status": "待办",
    "issueUrl": "https://...",
    "issueType": "任务",
    "priority": "Medium",
    "labels": [
      "demo"
    ]
  },
  "context": {
    "taskGoal": "...",
    "plannerOutput": "...",
    "taskContext": "...",
    "boardUrl": "https://...",
    "boardName": "龙虾骑士看板",
    "description": "..."
  },
  "raw": {
    "...": "Jira 原始 payload"
  }
}
```

OpenClaw 映射里可以直接读取这些字段，例如：

- `{{event.name}}`
- `{{issue.key}}`
- `{{issue.summary}}`
- `{{issue.issueUrl}}`
- `{{context.boardUrl}}`
- `{{context.boardName}}`
- `{{context.taskGoal}}`
- `{{context.plannerOutput}}`
- `{{context.taskContext}}`

如果你准备做“Planner 兼任执行者”的 demo，建议在 Jira 描述或 `任务上下文` 中直接写出：

- `bucket_name`
- `region`
- `purpose`
- 是否只创建 private bucket

## 测试

语法检查：

```bash
npm run check
```

本地最小测试：

```bash
npm run smoke
```

模拟 Jira Automation 请求：

```bash
npm run simulate:jira
```
