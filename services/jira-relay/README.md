# Jira Relay

## 目标

这个服务只做一件事：在 `8080` 端口接收 Jira Automation 的 HTTPS 转发请求，做最小结构整理后，再固定转发到龙虾的 `18789` 端口。

推荐链路：

`Jira Automation -> ALB (HTTPS) -> EC2:8080 -> jira-relay -> 127.0.0.1:18789`

## 目录

这个目录本身就是一个独立的小 Node 项目：

- `server.js`：服务入口
- `.env.example`：环境变量示例
- `smoke-test.js`：最小链路测试
- `simulate-jira-automation.js`：模拟 Jira Automation 请求

## 启动

1. 复制 `.env.example` 为 `.env`
2. 按需要修改 `RELAY_AUTH_TOKEN`
3. 如果龙虾不是监听 `18789`，修改 `LOBSTER_TARGET_URL`
4. 启动服务：

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
| `LOBSTER_TARGET_URL` | 固定转发地址 | `http://127.0.0.1:18789/jira/events` |
| `LOBSTER_AUTH_TOKEN` | relay 转发给龙虾时附带的 Bearer token | 空 |
| `REQUEST_TIMEOUT_MS` | 转发超时时间 | `10000` |
| `BODY_LIMIT_BYTES` | 最大请求体大小 | `1048576` |

## 当前行为

relay 只做三件事：

1. 接收 Jira webhook
2. 校验 `Authorization: Bearer <RELAY_AUTH_TOKEN>`
3. 转发到 `LOBSTER_TARGET_URL`

## Jira Automation 请求体示例

```json
{
  "event": "issue_created",
  "issueKey": "{{issue.key}}",
  "summary": {{issue.summary.asJsonString}},
  "projectKey": "{{issue.project.key}}",
  "status": "{{issue.status.name}}",
  "serviceDomain": {{issue.服务域.asJsonString}},
  "executionMode": {{issue.执行模式.asJsonString}},
  "context": {
    "taskGoal": {{issue.任务目标.asJsonString}},
    "plannerOutput": {{issue.Planner输出.asJsonString}},
    "taskContext": {{issue.任务上下文.asJsonString}}
  }
}
```

请求头：

```text
Authorization: Bearer <RELAY_AUTH_TOKEN>
Content-Type: application/json
```

## 转发后的结构

relay 发给龙虾的 body 结构如下：

```json
{
  "relay": {
    "service": "jira-relay",
    "version": "0.1.0",
    "correlationId": "uuid",
    "targetUrl": "http://127.0.0.1:18789/jira/events",
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
    "issueUrl": "https://..."
  },
  "context": {
    "taskGoal": "...",
    "plannerOutput": "...",
    "taskContext": "..."
  },
  "raw": {
    "...": "Jira 原始 payload"
  }
}
```

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
