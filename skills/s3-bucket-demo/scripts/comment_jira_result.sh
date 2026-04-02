#!/usr/bin/env bash
set -euo pipefail

ISSUE_KEY=""
BODY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)
      ISSUE_KEY="${2:-}"
      shift 2
      ;;
    --body)
      BODY="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$ISSUE_KEY" || -z "$BODY" ]]; then
  echo "Both --issue and --body are required." >&2
  exit 1
fi

acli jira workitem comment create --key "$ISSUE_KEY" --body "$BODY"

