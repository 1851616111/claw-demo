#!/usr/bin/env bash
set -euo pipefail

# Jira Relay Ubuntu installer
# - Copies current repo service to /opt/jira-relay
# - Installs Node deps
# - Installs /etc/jira-relay.env
# - Installs & starts systemd service
# - Optionally installs an nginx reverse proxy (80 -> 8080)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

APP_USER="${APP_USER:-jira-relay}"
APP_GROUP="${APP_GROUP:-jira-relay}"
APP_DIR="${APP_DIR:-/opt/jira-relay}"

ENV_FILE_DST="${ENV_FILE_DST:-/etc/jira-relay.env}"
UNIT_FILE_DST="${UNIT_FILE_DST:-/etc/systemd/system/jira-relay.service}"

ENABLE_NGINX="${ENABLE_NGINX:-0}" # set to 1 to install nginx config
NGINX_SITE_NAME="${NGINX_SITE_NAME:-jira-relay}"
NGINX_SITE_PATH_AVAILABLE="/etc/nginx/sites-available/${NGINX_SITE_NAME}"
NGINX_SITE_PATH_ENABLED="/etc/nginx/sites-enabled/${NGINX_SITE_NAME}"

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
  fi
}

need_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}" >&2
    exit 1
  fi
}

need_root
need_cmd rsync
need_cmd systemctl

echo "[1/7] Creating system user (if needed)"
if ! id -u "${APP_USER}" >/dev/null 2>&1; then
  useradd --system --home "${APP_DIR}" --shell /usr/sbin/nologin "${APP_USER}"
fi
if ! getent group "${APP_GROUP}" >/dev/null 2>&1; then
  groupadd --system "${APP_GROUP}" || true
fi
usermod -a -G "${APP_GROUP}" "${APP_USER}" || true

echo "[2/7] Syncing service files to ${APP_DIR}"
mkdir -p "${APP_DIR}"
rsync -a --delete \
  --exclude "node_modules" \
  --exclude ".env" \
  --exclude ".git" \
  "${SERVICE_DIR}/" "${APP_DIR}/"
chown -R "${APP_USER}:${APP_GROUP}" "${APP_DIR}"

echo "[3/7] Installing Node dependencies (if package-lock exists use npm ci)"
need_cmd node
need_cmd npm

if [[ -f "${APP_DIR}/package-lock.json" ]]; then
  sudo -u "${APP_USER}" bash -lc "cd '${APP_DIR}' && npm ci --omit=dev"
else
  sudo -u "${APP_USER}" bash -lc "cd '${APP_DIR}' && npm install --omit=dev"
fi

echo "[4/7] Installing env file at ${ENV_FILE_DST}"
if [[ -f "${ENV_FILE_DST}" ]]; then
  echo "Env file already exists: ${ENV_FILE_DST} (will NOT overwrite)."
  echo "Edit it to set RELAY_AUTH_TOKEN and target URL if needed."
else
  install -m 600 "${SCRIPT_DIR}/jira-relay.env" "${ENV_FILE_DST}"
  echo "Created ${ENV_FILE_DST}. You MUST edit RELAY_AUTH_TOKEN before exposing the endpoint."
fi

echo "[5/7] Installing systemd unit at ${UNIT_FILE_DST}"
install -m 644 "${SCRIPT_DIR}/jira-relay.service" "${UNIT_FILE_DST}"
systemctl daemon-reload
systemctl enable --now jira-relay.service

echo "[6/7] Service status"
systemctl --no-pager --full status jira-relay.service || true

if [[ "${ENABLE_NGINX}" == "1" ]]; then
  echo "[7/7] Installing nginx reverse proxy (80 -> 8080)"
  need_cmd nginx

  if [[ ! -d "/etc/nginx/sites-available" ]]; then
    echo "nginx sites-available not found; is this Debian/Ubuntu nginx packaging?" >&2
    exit 1
  fi

  install -m 644 "${SCRIPT_DIR}/nginx-jira-relay.conf" "${NGINX_SITE_PATH_AVAILABLE}"
  ln -sf "${NGINX_SITE_PATH_AVAILABLE}" "${NGINX_SITE_PATH_ENABLED}"
  nginx -t
  systemctl reload nginx
  echo "nginx site enabled: ${NGINX_SITE_NAME}"
else
  echo "[7/7] nginx step skipped. (Set ENABLE_NGINX=1 to enable 80 -> 8080 proxy)"
fi

echo "Done."
echo "Next:"
echo "- Edit ${ENV_FILE_DST} (set RELAY_AUTH_TOKEN)"
echo "- Verify: curl -sS http://127.0.0.1:8080/healthz"

