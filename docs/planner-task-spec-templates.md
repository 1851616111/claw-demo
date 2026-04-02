# Planner 任务模板（SPEC / 提示词规格）

## 含义（与「工单字段模板」的区别）

这里的 **任务模板** 指：**已经人工验收通过**的、较复杂的运维任务，将其 **可复用的分析方式与执行边界** 固化成一份 **SPEC**（结构化提示词 / 规格），交给 Planner 作为 **首选上下文**。

- **目的**：减少 Planner 对同一类问题反复试探、多轮来回；把「上次怎么分析、拆哪些资源、注意哪些约束」一次说清。  
- **形态**：可以是 YAML + 自然语言段落、或一整段可复制给模型的「系统/用户提示」；存放在 Wiki、Git 或 Skill 的 `references/` 均可，关键是 **版本化** 与 **可检索**。  
- **与看板的关系**：Jira 工单仍走 [龙虾骑士看板模板](lobster-board-template.md) 的状态与字段；SPEC 主要写在 **`Planner输出` 引用** 或 **任务上下文** 里的 `spec_ref` / 内联块。

## 生命周期建议

1. **首次执行**：无 SPEC → Planner 自由规划 → 人工确认 → 执行 → **人工验收**。  
2. **沉淀**：验收通过后，由人（或复盘）把本次 **有效约束、资源清单维度、步骤骨架、常见坑** 抽成 SPEC v1。  
3. **复用**：同类新工单在「规划中」**先挂载对应 SPEC**，Planner 只做 **参数填空与差异分析**，并显式列出相对 SPEC 的 **delta**。  
4. **迭代**：再次验收失败或环境大变 → 升版 SPEC，并写 **适用前提 / 最后验证日期**。

## SPEC 推荐结构（最小集）

Planner 收到 SPEC 后应能直接回答下面几块（可按任务类型删减）：

| 块 | 说明 |
| --- | --- |
| `template_id` / `version` | 便于引用与审计 |
| `goal` | 任务目标一句话 |
| `inputs` | 必须由人工/工单提供的参数（区域、集群名、版本、账号等） |
| `scope` | 涉及资源类型与边界（创建 / 变更 / 只读） |
| `constraints` | 硬约束：合规、禁止操作、必须使用的命名/标签 |
| `analysis_checklist` | Planner 分析时必须逐条覆盖的检查项 |
| `execution_blueprint` | 步骤骨架（不必写到命令级，但要有时序与依赖） |
| `acceptance_hints` | 与人工验收对齐的验证点 |
| `rollback_hints` | 回滚或止损要点 |

## 示例：创建 EKS 集群（多资源、已验证类任务）

以下是一份 **可直接复制** 给 Planner 的 SPEC 示例；`{{ ... }}` 为工单填写区。

```text
--- planner_task_spec ---
template_id: eks.cluster.create.standard
version: "1.0"
goal: 在指定 AWS 账号与区域创建符合组织基线的 EKS 数据面与控制面相关资源，并产出可验收证据。

inputs:
  account_id: "{{ AWS 账号 ID 或别名 }}"
  region: "{{ 如 ap-northeast-1 }}"
  cluster_name: "{{ 集群名，需符合命名规范 }}"
  kubernetes_version: "{{ 目标版本，如 1.31 }}"
  vpc_layout: "{{ 复用已有 VPC / 新建 —— 若复用则提供 vpc_id、private_subnet_ids }}"
  nodegroup_profile: "{{ 实例族、容量、是否 GPU、是否 Spot 比例 }}"
  addons_min: ["vpc-cni", "coredns", "kube-proxy", "ebs-csi"]  # 可按组织基线调整

constraints:
  - 所有可标记资源必须带标准标签：Environment, Owner, CostCenter, ClusterName（值与工单一致）。
  - 生产集群默认：API endpoint 非公网或受控、节点仅私有子网、禁止控制台随意开放 0.0.0.0/0 到 API。
  - IAM 权限遵循最小权限；节点实例角色与 IRSA 需求在规划中单独列出。
  - 不在此 SPEC 范围内：业务工作负载 Helm 发布（可列为后续子任务）。

analysis_checklist:
  - 确认账号配额：EKS 集群数、EC2、EIP、VPC 等是否足够。
  - 子网：每 AZ 至少一个可用于节点的私有子网；路由与 NAT/终端节点策略是否满足镜像拉取。
  - 与现有集群/对等连接/DNS 是否冲突；Service CIDR 与 VPC CIDR 不重叠。
  - 控制面日志类型是否按合规启用；审计与保留周期是否符合策略。
  - 节点组启动模板 / AMI 类型与 kubernetes_version 兼容矩阵。

execution_blueprint:
  1) 网络前置：安全组、子网标签、必要的 Endpoints（若私有集群）。
  2) 控制面：创建集群（版本、角色、子网、endpoint 配置、日志）。
  3) 节点组：启动模板或托管节点组参数、伸缩配置、标签与污点（若需要）。
  4) 插件：按 addons_min 顺序与依赖安装/升级。
  5) 访问：集群管理员映射（aws-auth / EKS API）、kubectl 上下文说明（勿在 SPEC 内写密钥）。
  6) 验证：节点 Ready、系统 Pod、核心监控与告警接入（若组织要求）。

acceptance_hints:
  - kubectl get nodes 全 Ready；关键系统命名空间 Pod 健康。
  - 组织必选的监控/日志代理已运行。
  - 提供变更与验证证据链接（控制台/API 输出摘要，敏感打码）。

rollback_hints:
  - 若在节点组前失败：删除未完成的集群与依赖安全组规则（按依赖逆序）。
  - 若数据面已接流量：回滚前确认无生产负载，必要时先摘流。

delta_instruction: |
  若本工单与 SPEC 有差异（例如少装某个 addon、使用已有 VPC），Planner 必须在输出中显式列出「相对 template_id v1 的 delta」与风险。
--- end ---
```

## 在 Jira 里怎么用（简）

- **规划中**：Planner 输出首段写「依据 `eks.cluster.create.standard@v1.0`」，并贴 **填好 inputs 的 SPEC** 或链接到 Confluence/Git 上的同版本页。  
- **待人工确认**：确认人核对 **delta** 与 **constraints** 是否仍成立。  
- **待人工验收**：按 `acceptance_hints` 勾验。

## 与 Confluence / Skill 的分工

- **Confluence**：存放 **带版本号** 的 SPEC 全文与变更说明，便于 Planner 检索与人工审阅。  
- **Skill**：可只放 **短触发说明 + `references/spec-eks-cluster-v1.md`**，避免把长 SPEC 塞进对话上下文时重复传输（按需加载）。

---

维护本文件时：新增任务类型时复制「推荐结构」增删块即可；**每份对外 SPEC 应有 `template_id` 与 `version`**，与验收记录对应。

## Demo 补充

仓库里还提供了一份更轻量、适合明天演示直接使用的 S3 bucket 规格：

- [S3 Bucket 创建 Demo SPEC](planner-task-spec-s3-bucket-demo.md)
