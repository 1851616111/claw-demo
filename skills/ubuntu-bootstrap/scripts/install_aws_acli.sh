#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${TARGET_USER:-ubuntu}"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"

required_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

required_env AWS_AI_ACCESS_KEY_ID
required_env AWS_AI_SECRET_ACCESS_KEY
required_env ATLASSIAN_API_TOKEN
required_env ATLASSIAN_EMAIL
required_env ATLASSIAN_SITE

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "Target user not found: $TARGET_USER" >&2
  exit 1
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [[ -z "$TARGET_HOME" || ! -d "$TARGET_HOME" ]]; then
  echo "Target user home not found: $TARGET_USER" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl unzip ca-certificates

arch="$(uname -m)"
case "$arch" in
  x86_64) aws_arch="x86_64"; acli_arch="amd64" ;;
  aarch64|arm64) aws_arch="aarch64"; acli_arch="arm64" ;;
  *)
    echo "Unsupported architecture: $arch" >&2
    exit 1
    ;;
esac

if ! command -v aws >/dev/null 2>&1; then
  rm -rf /tmp/aws /tmp/awscliv2.zip
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
fi

if ! command -v acli >/dev/null 2>&1; then
  curl -fsSL "https://acli.atlassian.com/linux/latest/acli_linux_${acli_arch}/acli" -o /usr/local/bin/acli
  chmod 0755 /usr/local/bin/acli
fi

install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.aws"

cat >"$TARGET_HOME/.aws/config" <<EOF
[profile ai]
region = ${AWS_REGION}
EOF

cat >"$TARGET_HOME/.aws/credentials" <<EOF
[ai]
aws_access_key_id = ${AWS_AI_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_AI_SECRET_ACCESS_KEY}
EOF

chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.aws/config" "$TARGET_HOME/.aws/credentials"
chmod 600 "$TARGET_HOME/.aws/config" "$TARGET_HOME/.aws/credentials"

token_file="$(mktemp)"
chmod 600 "$token_file"
printf '%s' "$ATLASSIAN_API_TOKEN" >"$token_file"
chown "$TARGET_USER:$TARGET_USER" "$token_file"

sudo -u "$TARGET_USER" HOME="$TARGET_HOME" bash -lc "cat '$token_file' | /usr/local/bin/acli jira auth login --site '$ATLASSIAN_SITE' --email '$ATLASSIAN_EMAIL' --token >/tmp/acli-login.log 2>&1 || (cat /tmp/acli-login.log >&2; exit 1)"

rm -f "$token_file" /tmp/acli-login.log

echo "Ubuntu bootstrap completed for user: $TARGET_USER"

