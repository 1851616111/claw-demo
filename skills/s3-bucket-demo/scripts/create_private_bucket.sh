#!/usr/bin/env bash
set -euo pipefail

PROFILE="${AWS_PROFILE_OVERRIDE:-ai}"
REGION="ap-northeast-1"
BUCKET_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket)
      BUCKET_NAME="${2:-}"
      shift 2
      ;;
    --region)
      REGION="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$BUCKET_NAME" ]]; then
  echo '{"created":false,"verified":false,"error":"bucket_name is required","next_step":"Provide a valid bucket name."}'
  exit 1
fi

if [[ ! "$BUCKET_NAME" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]; then
  echo "{\"bucket_name\":\"$BUCKET_NAME\",\"created\":false,\"verified\":false,\"error\":\"invalid bucket name\",\"next_step\":\"Use lowercase letters, digits, dots, and hyphens only.\"}"
  exit 1
fi

if aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$PROFILE" >/dev/null 2>&1; then
  echo "{\"bucket_name\":\"$BUCKET_NAME\",\"region\":\"$REGION\",\"created\":false,\"verified\":true,\"error\":\"bucket already exists or is already owned\",\"next_step\":\"Choose a new bucket name or inspect the existing bucket first.\"}"
  exit 1
fi

if [[ "$REGION" == "us-east-1" ]]; then
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --profile "$PROFILE" >/dev/null
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration "LocationConstraint=$REGION" \
    --profile "$PROFILE" >/dev/null
fi

aws s3api head-bucket --bucket "$BUCKET_NAME" --profile "$PROFILE" >/dev/null
resolved_region="$(aws s3api get-bucket-location --bucket "$BUCKET_NAME" --profile "$PROFILE" --output text)"
if [[ "$resolved_region" == "None" ]]; then
  resolved_region="us-east-1"
fi

echo "{\"bucket_name\":\"$BUCKET_NAME\",\"region\":\"$resolved_region\",\"created\":true,\"verified\":true}"

