#!/bin/bash
# entrypoint.sh — Main container entrypoint
# Generates config from template and starts tinode server
set -e

export SMTP_HOST_URL="${SMTP_HOST_URL:-https://tinode-chat-production.up.railway.app}"

echo "[main] Generating working.config from template..."
export CONFIG="${CONFIG:-working.config}"

if [ -f "/opt/tinode/config.template" ]; then
    sed -e "s|\$API_KEY_SALT|${API_KEY_SALT:-default_salt_change_me}|g" \
        -e "s|\$SERVER_STATUS_PATH|${SERVER_STATUS_PATH:-}|g" \
        -e "s|\$DEFAULT_COUNTRY_CODE|${DEFAULT_COUNTRY_CODE:-US}|g" \
        -e "s|\$FS_CORS_ORIGINS|${FS_CORS_ORIGINS:-\"*\"}|g" \
        -e "s|\$TLS_ENABLED|${TLS_ENABLED:-false}|g" \
        -e "s|\$TLS_DOMAIN_NAME|${TLS_DOMAIN_NAME:-}|g" \
        -e "s|\$TLS_CONTACT_ADDRESS|${TLS_CONTACT_ADDRESS:-}|g" \
        -e "s|\$MEDIA_HANDLER|${MEDIA_HANDLER:-fs}|g" \
        -e "s|\"$MEDIA_MAX_SIZE\"|${MEDIA_MAX_SIZE:-33554432}|g" \
        /opt/tinode/config.template > "/opt/tinode/$CONFIG"
    echo "[main] working.config generated"
fi

echo "[main] Starting tinode on :6060..."
exec /opt/tinode/tinode \
    --config="/opt/tinode/${CONFIG}" \
    --static_data=/opt/tinode/static \
    --cluster_self="${CLUSTER_SELF:-}" \
    --pprof_url="${PPROF_URL:-}"
