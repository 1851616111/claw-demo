# MEMORY.md - Long Term Memory

## Jira & Workflows
- **运维工单 (PIQW等)** 状态流转顺序必须严格遵循：`审批通过` -> `操作中` -> `验证中` -> `已完成`。不能跨节点跳跃流转。

## Infrastructure / AWS Rules
- **Profile 限制**: 所有 AWS 相关的命令与自动化操作，必须且只能使用 `ai` profile（`--profile ai`）。严禁使用 default 或其他环境凭证，防止跨账户误操作。