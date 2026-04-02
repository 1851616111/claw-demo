# 任务模板 · EKS（Amazon Kubernetes）

**分类**：EKS  
**服务域**：AWS（编排：EKS）  
**适用**：集群生命周期、节点组、插件、工作负载发布与回滚、网络与安全策略、控制面/数据面升级相关任务。

> **说明**：若你所说的「任务模板」是指给 Planner 用的 **SPEC / 提示词规格**（经人工验证、减少多轮分析），请以仓库 [`docs/planner-task-spec-templates.md`](../../planner-task-spec-templates.md) 为准；本页可作为 Wiki 侧的 **工单字段 + Runbook 占位**，与 SPEC 并存：SPEC 管「怎么想和拆」，本页管「字段与证据链」。

---

## 与看板字段对齐（必填摘要）

| 字段 | 本任务取值示例 |
| --- | --- |
| 任务目标 |  |
| 任务类型 | 部署 / 变更 / 巡检 / 故障 / 优化 |
| 服务域 | AWS · EKS |
| 优先级 |  |
| 风险等级 | Low / Medium / High |
| Planner输出 |  |
| 人工确认人 |  |
| 验收人 |  |
| 验收标准 |  |
| 任务上下文 | 见下文 YAML |

---

## 任务上下文（YAML 示例）

```yaml
system: aws
orchestrator: eks
cluster_name: ""
region: ap-northeast-1
account_id: ""
kubernetes_version_target: ""
nodegroups:
  - name: ""
    ami_release_version: ""
addons:
  - vpc-cni | coredns | kube-proxy | ebs-csi | other
workloads:
  namespace: ""
  deployment: ""
network:
  vpc_id: ""
  private_only: true | false
inputs:
  change_ticket: ""
  maintenance_window: ""
dependencies:
  - ""
notes:
  - ""
```

---

## Runbook 步骤（占位）

1. **前置检查**：控制面版本、节点组状态、`kubectl` 上下文、Pod 安全策略/准入、镜像拉取与 IRSA。  
2. **执行**：AWS 侧（EKS API / 节点组）与 K8s 侧（滚动更新 / 金丝雀）步骤分拆列出。  
3. **验证**：`kubectl get nodes`、关键 Deployment Ready、HPA、CoreDNS、指标与告警。  
4. **回滚**：Deployment 回滚 / 节点组降级 / Addon 版本回退路径。  
5. **证据**：`kubectl describe`、EKS 事件、日志链接 → Jira。

---

## 人工关口检查提示

- **待人工确认**：是否涉及生产数据面中断、是否需 PDB/优雅下线、是否已备份 etcd 无关但业务状态需确认。  
- **待人工验收**：业务黄金指标、集群 SLO、成本突变（若相关）。

---

## 与「模板 · AWS」的关系

账号、IAM、VPC 底层变更以 **AWS 通用模板** 为主；本页聚焦 **Kubernetes 与 EKS 控制面/数据面**。

---

**最后验证日期**：  
**适用前提**：
