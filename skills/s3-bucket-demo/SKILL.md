---
name: s3-bucket-demo
description: Create and verify a new private S3 bucket for the lobster demo using aws CLI with the ai profile, and optionally comment the result back to Jira with acli. Use when a Jira or Slack task asks Planner to create an S3 bucket, validate bucket existence, or report the outcome for the KAN demo flow.
---

# S3 Bucket Demo

Use this skill when Planner receives a Jira or Slack task to create a new S3 bucket in the demo AWS account.

## What this skill covers

- Validate whether a bucket request is safe to execute
- Create a new private bucket with `aws --profile ai`
- Verify the bucket exists and report the resolved region
- Optionally comment the result back to Jira with `acli`

## Guardrails

- Always use `--profile ai`
- Default region is `ap-northeast-1`
- Only create new private buckets
- Do not enable public ACL or public policy
- Do not delete or overwrite existing buckets
- If the bucket name is missing or invalid, stop and ask for the missing info
- If `head-bucket` shows the bucket already exists, stop and report instead of retrying destructive actions

## Inputs

Minimum required:

- `bucket_name`

Optional:

- `region`
- `jira_issue_key`
- `purpose`

## Recommended workflow

1. Read the task and extract `bucket_name`, `region`, and `jira_issue_key` if present.
2. If `region` is missing, use `ap-northeast-1`.
3. Run `scripts/create_private_bucket.sh --bucket <name> --region <region>`.
4. Review the JSON result.
5. If Jira issue key is available and `acli` is logged in, use `scripts/comment_jira_result.sh` to write back the summary.
6. In Slack, summarize:
   - what was requested
   - whether Planner executed it
   - bucket name
   - region
   - verification result
   - whether the task is ready for human acceptance

## Scripts

- Create and verify: [scripts/create_private_bucket.sh](scripts/create_private_bucket.sh)
- Comment back to Jira: [scripts/comment_jira_result.sh](scripts/comment_jira_result.sh)

## Output expectations

Successful execution should include:

- `bucket_name`
- `region`
- `created: true`
- `verified: true`

Failed or blocked execution should include:

- `bucket_name`
- `created: false`
- `error`
- `next_step`

