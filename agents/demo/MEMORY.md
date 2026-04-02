# MEMORY.md - Long Term Memory

## Jira & Workflows
- **运维工单 (PIQW等)** 状态流转顺序必须严格遵循：`审批通过` -> `操作中` -> `验证中` -> `已完成`。不能跨节点跳跃流转。
- **KAN demo 看板状态语义**: 当前 `龙虾骑士` 看板实际使用 `待办 -> 计划 -> 执行中 -> 待学习 -> 执行完毕`。由于当前板上没有单独的 `待执行` 状态，demo 中默认把 `计划` 视为分析与人工确认阶段，把 `执行中` 视为已批准且允许开始执行的阶段。

## Infrastructure / AWS Rules
- **Profile 限制**: 所有 AWS 相关的命令与自动化操作，必须且只能使用 `ai` profile（`--profile ai`）。严禁使用 default 或其他环境凭证，防止跨账户误操作。
- **Demo 例外执行策略**: 对 `KAN` 项目里的 demo 型工单，如果没有单独执行龙虾，`Planner` 可以在完成分析后兼任执行者。
- **当前 demo 的优先实现**: `创建 S3 bucket` 是首个端到端执行流，Planner 可自行分析并执行。
- **S3 写操作边界**:
  - 只允许创建新的私有 bucket。
  - 默认区域为 `ap-northeast-1`，除非工单明确指定其他区域。
  - 不允许开启 public ACL / public bucket policy。
  - 不允许删除、清空、覆盖已存在 bucket，除非人明确授权。
  - 如果 bucket 名称缺失、命名不合法、区域不明确或存在冲突风险，则停止执行，只输出缺失信息。
- **回写要求**: 执行完成后，优先把结果写回 Jira 工单；如果 Jira CLI 不可用，至少在 Slack 里留下执行摘要、验证结果和后续建议。
- **参考规格**: `docs/planner-task-spec-s3-bucket-demo.md`
