#!/bin/bash
# entrypoint.sh — generates working.config, initializes DB, starts tinode

set -e

export SMTP_HOST_URL="${SMTP_HOST_URL:-https://tinode-chat-production.up.railway.app}"
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
# Export for envsubst — these are referenced in config.template but not exported above
export AUTH_TOKEN_KEY="${AUTH_TOKEN_KEY:-}"
export UID_ENCRYPTION_KEY="${UID_ENCRYPTION_KEY:-}"
export TNPG_PUSH_ENABLED="${TNPG_PUSH_ENABLED:-false}"
export TNPG_AUTH_TOKEN="${TNPG_AUTH_TOKEN:-}"
export TNPG_ORG="${TNPG_ORG:-}"

CONFIG_TEMPLATE="/opt/tinode/config.template"
WORKING_CONFIG="/opt/tinode/working.config"

if [ -f "$CONFIG_TEMPLATE" ]; then
    echo "[main] Generating $WORKING_CONFIG using envsubst..."
    export SUBST_ALL=1
    envsubst < "$CONFIG_TEMPLATE" > "$WORKING_CONFIG"
    echo "[main] Config generated ($(wc -c < "$WORKING_CONFIG") bytes)"
else
    echo "[main] WARNING: $CONFIG_TEMPLATE not found"
fi

# Wait for DB
DB_HOST="${PGHOST:-postgres.railway.internal}"
DB_PORT="${PGPORT:-5432}"
echo "[main] Waiting for DB at $DB_HOST:$DB_PORT..."
if command -v nc &>/dev/null; then
    timeout=30
    while ! nc -z -w2 "$DB_HOST" "$DB_PORT" 2>/dev/null; do
        timeout=$((timeout-1))
        if [ $timeout -le 0 ]; then
            echo "[main] DB wait timeout, continuing..."
            break
        fi
        sleep 1
    done
fi
echo "[main] DB connection ready"

# ── init-db: run ONLY when RESET_DB=true ──────────────────────────────────────
if [ "$RESET_DB" = "true" ] && [ -x "/opt/tinode/init-db" ]; then
    echo "[init] RESET_DB=true — initializing database with data.json..."
    cd /opt/tinode
    /opt/tinode/init-db         --config="$WORKING_CONFIG"         --data=data.json         --reset=true         -- continuance         || echo "[init] init-db exited (this is normal after first run)"
elif [ "$UPGRADE_DB" = "true" ] && [ -x "/opt/tinode/init-db" ]; then
    echo "[init] UPGRADE_DB=true — upgrading database schema..."
    /opt/tinode/init-db         --config="$WORKING_CONFIG"         --upgrade=true         --continue         || echo "[init] upgrade done or nothing to upgrade"
fi

echo "[main] Starting tinode..."
exec /opt/tinode/tinode     --config="$WORKING_CONFIG"     --static_data=/opt/tinode/static     --cluster_self="${CLUSTER_SELF:-}"     --pprof_url="${PPROF_URL:-}"
