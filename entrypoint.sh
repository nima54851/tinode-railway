#!/bin/bash
# entrypoint.sh — generates working.config and starts tinode
# Uses envsubst for safe placeholder substitution

set -e

export SMTP_HOST_URL="${SMTP_HOST_URL:-https://tinode-chat-production.up.railway.app}"

# Default values for all config placeholders
export API_KEY_SALT="${API_KEY_SALT:-change_me_abcdef123456}"
export SERVER_STATUS_PATH="${SERVER_STATUS_PATH:-}"
export DEFAULT_COUNTRY_CODE="${DEFAULT_COUNTRY_CODE:-US}"
export FS_CORS_ORIGINS="${FS_CORS_ORIGINS:-*}"
export AWS_CORS_ORIGINS="${AWS_CORS_ORIGINS:-*}"
export TLS_ENABLED="${TLS_ENABLED:-false}"
export TLS_DOMAIN_NAME="${TLS_DOMAIN_NAME:-}"
export TLS_CONTACT_ADDRESS="${TLS_CONTACT_ADDRESS:-}"
export MEDIA_HANDLER="${MEDIA_HANDLER:-fs}"
export MEDIA_MAX_SIZE="${MEDIA_MAX_SIZE:-33554432}"
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
export AWS_REGION="${AWS_REGION:-}"
export AWS_S3_BUCKET="${AWS_S3_BUCKET:-}"
export AWS_S3_ENDPOINT="${AWS_S3_ENDPOINT:-}"
export RESET_DB="${RESET_DB:-false}"
export UPGRADE_DB="${UPGRADE_DB:-false}"

CONFIG_TEMPLATE="/opt/tinode/config.template"
WORKING_CONFIG="/opt/tinode/working.config"

if [ -f "$CONFIG_TEMPLATE" ]; then
    echo "[main] Generating $WORKING_CONFIG using envsubst..."
    export SUBST_ALL=1
    envsubst < "$CONFIG_TEMPLATE" > "$WORKING_CONFIG"
    echo "[main] Config generated ($(wc -c < "$WORKING_CONFIG") bytes)"
else
    echo "[main] WARNING: $CONFIG_TEMPLATE not found, tinode may use default config"
fi

# Wait for DB to be ready
DB_HOST="${PGHOST:-postgres.railway.internal}"
DB_PORT="${PGPORT:-5432}"
echo "[main] Waiting for DB at $DB_HOST:$DB_PORT..."
if command -v nc &>/dev/null; then
    timeout=30
    while ! nc -z -w2 "$DB_HOST" "$DB_PORT" 2>/dev/null; do
        timeout=$((timeout-1))
        if [ $timeout -le 0 ]; then
            echo "[main] DB wait timeout, continuing anyway..."
            break
        fi
        sleep 1
    done
    echo "[main] DB connection ready"
fi

echo "[main] Starting tinode..."
exec /opt/tinode/tinode \
    --config="$WORKING_CONFIG" \
    --static_data=/opt/tinode/static \
    --cluster_self="${CLUSTER_SELF:-}" \
    --pprof_url="${PPROF_URL:-}"
