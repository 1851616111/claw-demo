# Ubuntu Bootstrap Reference

## Purpose

These notes support `ubuntu-bootstrap` when preparing an Ubuntu host for Planner or OpenClaw execution.

## Environment variables

The installation script expects secrets to be provided through environment variables on the Ubuntu host.

Required:

- `AWS_AI_ACCESS_KEY_ID`
- `AWS_AI_SECRET_ACCESS_KEY`
- `ATLASSIAN_API_TOKEN`
- `ATLASSIAN_EMAIL`
- `ATLASSIAN_SITE`

Optional:

- `TARGET_USER`
  - default: `ubuntu`
- `AWS_REGION`
  - default: `ap-northeast-1`

## What gets configured

- `aws` installed to `/usr/local/bin/aws`
- `acli` installed to `/usr/local/bin/acli`
- `~/.aws/config`
- `~/.aws/credentials`
- `acli jira` login stored for the target user

## Safety notes

- Secrets must never be written into repo files.
- The script is allowed to write runtime credentials into the target user's home directory because that is operational state, not source code.
- Clean up temporary token files immediately after login.

## Example usage

```bash
export TARGET_USER=ubuntu
export AWS_REGION=ap-northeast-1
export AWS_AI_ACCESS_KEY_ID='...'
export AWS_AI_SECRET_ACCESS_KEY='...'
export ATLASSIAN_EMAIL='pan.xinyuan@netstars.co.jp'
export ATLASSIAN_SITE='netstars-sre-demo.atlassian.net'
export ATLASSIAN_API_TOKEN='...'

sudo bash scripts/install_aws_acli.sh
sudo bash scripts/verify_aws_acli.sh
```

## Tool verification expectations

Expected checks:

```bash
aws --version
acli --version
sudo -u ubuntu HOME=/home/ubuntu aws sts get-caller-identity --profile ai
sudo -u ubuntu HOME=/home/ubuntu acli jira auth status
```
