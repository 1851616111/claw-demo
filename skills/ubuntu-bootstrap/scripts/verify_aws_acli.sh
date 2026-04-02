#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

if [[ -z "$TARGET_HOME" || ! -d "$TARGET_HOME" ]]; then
  echo "Target user home not found: $TARGET_USER" >&2
  exit 1
fi

echo "== Versions =="
aws --version
acli --version

echo "== AWS identity =="
sudo -u "$TARGET_USER" HOME="$TARGET_HOME" aws sts get-caller-identity --profile ai --output json

echo "== Jira auth =="
sudo -u "$TARGET_USER" HOME="$TARGET_HOME" acli jira auth status
