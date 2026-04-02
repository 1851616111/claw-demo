# 龙虾骑士 Wiki

人机与多只「龙虾」Agent 协作的 SRE 运维 demo 知识库。流程与状态机见 Jira **龙虾骑士（KAN）** 看板；本空间存放 **任务模板 / Runbook 草案**，供 Planner 检索与复用。

## 快速链接

- **Jira 看板（KAN）**：[打开看板](https://netstars-sre-demo.atlassian.net/jira/software/projects/KAN/boards/2)
- **Confluence 站点**：[Wiki 首页](https://netstars-sre-demo.atlassian.net/wiki/home)
- **仓库看板模板**（字段与状态说明）：`claw-demo/docs/lobster-board-template.md`

## 任务模板（按云与编排分类）

| 分类 | 页面 | 典型场景 |
| --- | --- | --- |
| **AWS** | 模板 · AWS | EC2、VPC、IAM、RDS、S3、CloudWatch 等通用变更与排障 |
| **GCP** | 模板 · GCP | Compute、VPC、IAM、GCS、Cloud Logging 等通用变更与排障 |
| **EKS** | 模板 · EKS | 集群版本、节点组、插件、工作负载、网络策略 |
| **GKE** | 模板 · GKE | 集群升级、节点池、Workload Identity、Ingress / Gateway |

新建 Jira 工单时：在描述或自定义字段中引用本空间对应模板页，并把具体参数放进 **任务上下文**（YAML/结构化文本）。

## Planner 检索建议

1. 先按 **服务域**（AWS / GCP / EKS / GKE）打开上表对应模板。
2. 在模板内补齐 **任务上下文** 与 **Runbook 步骤**；无先例时在工单中标注「无历史 Runbook，新建草案」。
3. 执行与证据链接回写到工单，便于事后沉淀为新页面或更新本模板。

## 空间维护

- 模板变更尽量走 **小步修订**，并在页脚更新「适用前提 / 最后验证日期」。
- 与生产强相关的命令与账号信息 **不要** 写入公开页面正文，使用占位符与内部密钥管理。
