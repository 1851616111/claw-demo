---
name: ubuntu-bootstrap
description: Install and verify Ubuntu server dependencies for agent execution, especially AWS CLI v2, Atlassian CLI (acli), curl, unzip, and per-user auth setup using environment variables instead of hardcoded secrets. Use when preparing an Ubuntu host for OpenClaw or Planner execution, configuring the ai AWS profile, or setting up Jira CLI access safely.
---

# Ubuntu Bootstrap

Use this skill when an Ubuntu server needs command-line dependencies before an agent can execute cloud or Jira tasks.

## What this skill is for

- Install `aws` CLI v2
- Install `acli`
- Ensure `curl`, `unzip`, and `ca-certificates` exist
- Configure the `ai` AWS profile for a target Linux user
- Log `acli jira` in with a token provided through environment variables
- Verify the host is ready for Planner-style execution

## Guardrails

- Never hardcode `AK/SK`, API token, or hook token into repo files.
- Read secrets only from environment variables on the target server.
- Do not echo secrets back to the terminal.
- Do not commit generated `~/.aws/credentials`, `.env`, or login artifacts.
- Prefer installing tools system-wide, but configure credentials per target user.

## Required environment variables

Read [references/installing-cli-tools.md](references/installing-cli-tools.md) for the exact variables and usage examples.

Minimum set for full setup:

- `AWS_AI_ACCESS_KEY_ID`
- `AWS_AI_SECRET_ACCESS_KEY`
- `ATLASSIAN_API_TOKEN`
- `ATLASSIAN_EMAIL`
- `ATLASSIAN_SITE`

Optional:

- `TARGET_USER` (defaults to `ubuntu`)
- `AWS_REGION` (defaults to `ap-northeast-1`)

## Workflow

1. Confirm OS, architecture, current binaries, and current user.
2. Export the required environment variables on the Ubuntu server.
3. Run `scripts/install_aws_acli.sh` as `root` or with `sudo`.
4. Run `scripts/verify_aws_acli.sh` to confirm:
   - `aws` exists
   - `acli` exists
   - `aws sts get-caller-identity --profile ai` works
   - `acli jira auth status` works for the target user
5. Only after verification should the agent attempt AWS or Jira write actions.

## When to stop instead of continuing

- Missing any required environment variable
- Ubuntu package manager errors
- Atlassian auth fails
- AWS identity check fails
- The target user home directory does not exist

## Scripts

- Install and configure: [scripts/install_aws_acli.sh](scripts/install_aws_acli.sh)
- Verify readiness: [scripts/verify_aws_acli.sh](scripts/verify_aws_acli.sh)

