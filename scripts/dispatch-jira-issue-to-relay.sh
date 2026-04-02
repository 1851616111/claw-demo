#!/usr/bin/env bash
set -euo pipefail

ISSUE_KEY="${1:-}"
EVENT_NAME="${EVENT_NAME:-issue_updated}"
RELAY_URL="${RELAY_URL:-http://127.0.0.1:8080/jira/events}"
SITE_URL="${SITE_URL:-https://netstars-sre-demo.atlassian.net}"
BOARD_URL="${BOARD_URL:-https://netstars-sre-demo.atlassian.net/jira/software/projects/KAN/boards/2}"
BOARD_NAME="${BOARD_NAME:-龙虾骑士看板}"
ACLI_RUN_AS_USER="${ACLI_RUN_AS_USER:-ubuntu}"

if [[ -z "$ISSUE_KEY" ]]; then
  echo "Usage: $0 <KAN-KEY>" >&2
  exit 1
fi

if [[ -r /etc/jira-relay.env ]]; then
  # shellcheck disable=SC1091
  source /etc/jira-relay.env
fi

if [[ -z "${RELAY_AUTH_TOKEN:-}" ]]; then
  echo "RELAY_AUTH_TOKEN is not set. Export it first or run this script with sudo so it can read /etc/jira-relay.env." >&2
  exit 1
fi

run_acli() {
  if [[ "$(id -u)" -eq 0 ]]; then
    sudo -u "$ACLI_RUN_AS_USER" -H env HOME="/home/$ACLI_RUN_AS_USER" acli "$@"
  else
    acli "$@"
  fi
}

issue_json="$(run_acli jira workitem view "$ISSUE_KEY" --json)"

payload="$(ISSUE_JSON="$issue_json" EVENT_NAME="$EVENT_NAME" SITE_URL="$SITE_URL" BOARD_URL="$BOARD_URL" BOARD_NAME="$BOARD_NAME" python3 - <<'PY'
import json
import os

data = json.loads(os.environ["ISSUE_JSON"])
fields = data.get("fields", {})
issue_key = data.get("key")
summary = fields.get("summary")
status = (fields.get("status") or {}).get("name")
issue_type = (fields.get("issuetype") or {}).get("name")
priority = ((fields.get("priority") or {}) or {}).get("name")
description = fields.get("description")

payload = {
    "event": os.environ["EVENT_NAME"],
    "issueKey": issue_key,
    "issueId": data.get("id"),
    "summary": summary,
    "projectKey": issue_key.split("-", 1)[0] if issue_key and "-" in issue_key else None,
    "status": status,
    "issueUrl": f"{os.environ['SITE_URL'].rstrip('/')}/browse/{issue_key}" if issue_key else None,
    "issueType": issue_type,
    "priority": priority,
    "context": {
        "taskGoal": summary,
        "plannerOutput": None,
        "taskContext": description,
        "description": description,
        "boardUrl": os.environ["BOARD_URL"],
        "boardName": os.environ["BOARD_NAME"],
    },
}

print(json.dumps(payload, ensure_ascii=False))
PY
)"

curl -fsS -X POST "$RELAY_URL" \
  -H "Authorization: Bearer ${RELAY_AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "$payload"
