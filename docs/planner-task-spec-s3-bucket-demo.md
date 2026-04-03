# Planner 任务模板：S3 Bucket 创建 Demo

## 目标

为 `KAN` 项目的 demo 工单提供一份可复用的 `S3 bucket 创建` 规格，让 Planner 在没有单独执行龙虾时，也能完成：

1. 工单分析
2. 自我分派
3. 安全创建 bucket
4. 输出验证证据

## 当前看板映射

`龙虾骑士 / KAN` 看板当前实际列是：

- `待办`
- `计划`
- `执行中`
- `待学习`
- `执行完毕`

由于当前没有单独的 `待执行` 列，demo 里采用下面这套语义：

- `待办`：新任务进入看板
- `计划`：Planner 分析、补信息、等待人工确认
- `执行中`：人工已批准，Planner 或执行龙虾可以开始执行
- `待学习`：沉淀复盘、改进建议或后续学习项
- `执行完毕`：执行结束，等待或完成人工验收

## 适用范围

- 任务类型：创建新的 S3 bucket
- 环境：demo / 演示环境
- 执行者：Planner 自己或未来的 AWS 执行龙虾
- 云账号：必须使用 `aws --profile ai`

## 不适用范围

- 删除 bucket
- 清空 bucket
- 修改现有 bucket 的高风险配置
- 开启公共访问
- 跨账户迁移数据

## 必填输入

最少需要这些输入 Planner 才允许直接执行：

- `bucket_name`
- `region`
  - 默认可以用 `ap-northeast-1`
- `purpose`
  - 例如：静态资源、日志归档、演示上传

建议在 Jira 描述或 `任务上下文` 中使用类似结构：

```yaml
system: aws
service: s3
action: create_bucket
bucket_name: nssclaw-demo-20260402-001
region: ap-northeast-1
purpose: demo static assets
tags:
  Environment: demo
  Owner: planner
```

## 分析检查项

Planner 在输出分析时至少要覆盖：

1. Bucket 名称是否合法、是否像 demo 名称
2. 区域是否明确；未给出则默认 `ap-northeast-1`
3. 是否只是“创建新 bucket”，没有隐含危险操作
4. 是否需要额外标签、命名规范或后续权限配置
5. 如果信息不够，缺什么

## 执行蓝图

1. 解析工单 summary / description / task context
2. 判断是否满足直接执行条件
   - 当前状态为 `执行中`
   - 或描述 / 任务上下文中明确出现 `allow_execute: true` / `允许执行: true`
   - 并且 `执行中` 的批准语义高于描述中的 `allow_execute: false`；后者只能约束 `待办` / `计划`
3. 如果满足：
   - 使用 `aws s3api create-bucket`
   - 使用 `aws s3api head-bucket` 验证
   - 使用 `aws s3api get-bucket-location` 输出区域结果
4. 如果不满足：
   - 不执行
   - 列出缺失信息和建议下一步

## 标准命令

### 东京区创建

```bash
aws s3api create-bucket \
  --bucket <bucket-name> \
  --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1 \
  --profile ai
```

### 验证

```bash
aws s3api head-bucket --bucket <bucket-name> --region ap-northeast-1 --profile ai
aws s3api get-bucket-location --bucket <bucket-name> --profile ai
```

## Slack / Jira 输出要求

执行时输出应至少包含：

- 工单链接
- 看板链接
- bucket 名称
- region
- 是否创建成功
- 验证命令结果摘要
- 如果失败，核心错误和建议下一步

## Webhook 会话要求

- Jira webhook 到 OpenClaw 时，应当把 hook 正文保持为“事件事实 + 结构化上下文”，不要把大量行为规则塞进 webhook 文本。
- Planner 的行为边界、中文输出要求、执行闸门优先级，应固化在 workspace 的身份与记忆文件中。
- hook session key 应按“单次事件”隔离，推荐包含 `relay.correlationId`，避免同一工单长期复用旧会话导致判断串味。

## 风险边界

- 不创建 public bucket
- 不做删除
- 不覆盖已有 bucket
- 如果检测到 `BucketAlreadyExists` 或 `BucketAlreadyOwnedByYou`，停止并报告

## 当前结论

这份 spec 是为了明天 demo 的最小可运行版本准备的。

- 有单独执行龙虾时：Planner 只负责分析和分派
- 没有单独执行龙虾时：Planner 可以兼任执行者，但仅限这类低风险、边界清晰的创建任务
- 当前看板没有 `待执行` 列，所以 demo 默认把 `执行中` 作为人工确认后的执行入口
