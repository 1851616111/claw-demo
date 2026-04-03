#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-/home/ubuntu/claw-demo}"
AGENT_SOURCE_DIR="${AGENT_SOURCE_DIR:-$REPO_ROOT/agents/demo}"
SKILLS_SOURCE_DIR="${SKILLS_SOURCE_DIR:-$REPO_ROOT/skills}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/home/ubuntu/.openclaw/workspace}"

if [[ ! -d "$AGENT_SOURCE_DIR" ]]; then
  echo "Agent source directory not found: $AGENT_SOURCE_DIR" >&2
  exit 1
fi

if [[ ! -d "$WORKSPACE_DIR" ]]; then
  echo "Workspace directory not found: $WORKSPACE_DIR" >&2
  exit 1
fi

install -d -m 755 "$WORKSPACE_DIR"

find "$AGENT_SOURCE_DIR" -maxdepth 1 -type f -name '*.md' | while read -r file; do
  cp "$file" "$WORKSPACE_DIR/"
done

if [[ -d "$SKILLS_SOURCE_DIR" ]]; then
  install -d -m 755 "$WORKSPACE_DIR/skills"
  cp -R "$SKILLS_SOURCE_DIR/." "$WORKSPACE_DIR/skills/"
  find "$WORKSPACE_DIR/skills" -type f -name '*.sh' -exec chmod +x {} +
fi

echo "Synced markdown files from: $AGENT_SOURCE_DIR"
echo "Synced skills from: $SKILLS_SOURCE_DIR"
echo "Workspace target: $WORKSPACE_DIR"
