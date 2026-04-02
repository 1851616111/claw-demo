# 龙虾骑士 Confluence 空间（本地源稿）

本目录是 **netstars-sre-demo** 上「龙虾骑士」Wiki 空间的**内容与结构源稿**，按分类提供任务模板（与 [龙虾骑士看板模板](../lobster-board-template.md) 字段对齐）。

## 建议空间设置

| 项 | 建议值 |
| --- | --- |
| 空间名称 | 龙虾骑士 |
| 空间 Key | `LOBK` |
| 说明 | 人机协作 SRE demo：Runbook / 任务模板 / 与 Jira KAN 联动 |

发布后首页 URL 形态：

`https://netstars-sre-demo.atlassian.net/wiki/spaces/LOBK`

## 分类与页面映射

| 分类 | 源文件 | 用途 |
| --- | --- | --- |
| 空间首页 | [home.md](home.md) | 导航、与 Jira 看板链接、使用说明 |
| AWS | [templates/aws-generic.md](templates/aws-generic.md) | 通用 AWS 变更 / 权限 / 资源类任务模板 |
| GCP | [templates/gcp-generic.md](templates/gcp-generic.md) | 通用 GCP 变更 / IAM / 资源类任务模板 |
| EKS | [templates/eks-generic.md](templates/eks-generic.md) | Amazon EKS 集群与工作负载运维模板 |
| GKE | [templates/gke-generic.md](templates/gke-generic.md) | Google GKE 集群与节点池类模板 |

## 发布到 Confluence（demo 站点）

当前 `acli` 的 Confluence 登录可能与 Jira 不在同一站点；**在 netstars-sre-demo 创建空间前**请先完成 Confluence 认证：

```bash
acli confluence auth login --site netstars-sre-demo.atlassian.net --email "你的邮箱" --token
```

创建空间（若尚未创建）：

```bash
acli confluence space create --key LOBK --name "龙虾骑士" --description "人机协作 SRE demo：任务模板与 Runbook"
```

将本目录页面批量创建/更新到该空间（需 API Token，与 Jira 同站点可用同一 Token）：

```bash
cd claw-demo
set CONFLUENCE_SITE=netstars-sre-demo.atlassian.net
set CONFLUENCE_EMAIL=你的邮箱
set CONFLUENCE_API_TOKEN=你的API令牌
python scripts/publish_lobster_confluence.py
```

仅检查不写入：

```bash
python scripts/publish_lobster_confluence.py --dry-run
```

也可在 Confluence 中 **手动新建页面**，将各 `.md` 内容粘贴后保存（表格建议用 Confluence 表格重排）。
