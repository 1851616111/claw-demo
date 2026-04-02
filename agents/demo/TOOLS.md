# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

## Demo Environment

### Workspace

- Repo root: `C:\Users\18516\Desktop\claw-aaa\claw-demo`
- Server sync target: `/home/ubuntu/claw-demo`
- Agent identity source of truth: `agents/demo/*.md`

### Jira

- Site: `https://netstars-sre-demo.atlassian.net`
- Board: `https://netstars-sre-demo.atlassian.net/jira/software/projects/KAN/boards/2`
- Project key: `KAN`
- Default relay path: `/jira/events`

### AWS

- Required profile: `ai`
- Default region: `ap-northeast-1`
- Caller identity check:
  - `aws sts get-caller-identity --profile ai`

### S3 Demo Commands

- Create bucket in Tokyo:
  - `aws s3api create-bucket --bucket <bucket-name> --region ap-northeast-1 --create-bucket-configuration LocationConstraint=ap-northeast-1 --profile ai`
- Verify bucket exists:
  - `aws s3api head-bucket --bucket <bucket-name> --region ap-northeast-1 --profile ai`
- Check bucket region:
  - `aws s3api get-bucket-location --bucket <bucket-name> --profile ai`

### Jira CLI

- Comment back to issue:
  - `acli jira workitem comment create --key <KAN-KEY> --body "<message>"`
- Transition issue:
  - `acli jira workitem transition --key <KAN-KEY> --status "<status>" --yes`

Add whatever helps you do your job. This is your cheat sheet.
