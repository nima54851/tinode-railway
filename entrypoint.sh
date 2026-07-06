#!/bin/bash
# entrypoint.sh — Main container: generates config and starts tinode
set -e

export SMTP_HOST_URL="${SMTP_HOST_URL:-https://tinode-chat-production.up.railway.app}"

# ── Config placeholder defaults ─────────────────────────────────────────────
FS_CORS_ORIGINS="${FS_CORS_ORIGINS:-*}"
AWS_CORS_ORIGINS="${AWS_CORS_ORIGINS:-*}"
TLS_ENABLED="${TLS_ENABLED:-false}"
API_KEY_SALT="${API_KEY_SALT:-change_me_abcdef123456}"
SERVER_STATUS_PATH="${SERVER_STATUS_PATH:-}"
DEFAULT_COUNTRY_CODE="${DEFAULT_COUNTRY_CODE:-US}"
MEDIA_HANDLER="${MEDIA_HANDLER:-fs}"
TLS_DOMAIN_NAME="${TLS_DOMAIN_NAME:-}"
TLS_CONTACT_ADDRESS="${TLS_CONTACT_ADDRESS:-}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
AWS_REGION="${AWS_REGION:-}"
AWS_S3_BUCKET="${AWS_S3_BUCKET:-}"
AWS_S3_ENDPOINT="${AWS_S3_ENDPOINT:-}"

export CONFIG="${CONFIG:-working.config}"
CONFIG_TEMPLATE="/opt/tinode/config.template"
WORKING_CONFIG="/opt/tinode/${CONFIG}"

if [ -f "$CONFIG_TEMPLATE" ]; then
    echo "[main] Generating $WORKING_CONFIG..."
    cp "$CONFIG_TEMPLATE" "$WORKING_CONFIG"
    perl -pe "
        s/\\\$API_KEY_SALT\b/$API_KEY_SALT/g;
        s/\\\$SERVER_STATUS_PATH\b/$SERVER_STATUS_PATH/g;
        s/\\\$DEFAULT_COUNTRY_CODE\b/$DEFAULT_COUNTRY_CODE/g;
        s/\\\$FS_CORS_ORIGINS\b/[$FS_CORS_ORIGINS]/g;
        s/\\\$AWS_CORS_ORIGINS\b/[$AWS_CORS_ORIGINS]/g;
        s/\\\$TLS_ENABLED\b/$TLS_ENABLED/g;
        s/\\\$TLS_DOMAIN_NAME\b/$TLS_DOMAIN_NAME/g;
        s/\\\$TLS_CONTACT_ADDRESS\b/$TLS_CONTACT_ADDRESS/g;
        s/\\\$MEDIA_HANDLER\b/$MEDIA_HANDLER/g;
        s/\"\\\$MEDIA_MAX_SIZE\"/$MEDIA_MAX_SIZE/g;
        s/\\\$AWS_ACCESS_KEY_ID\b/$AWS_ACCESS_KEY_ID/g;
        s/\\\$AWS_SECRET_ACCESS_KEY\b/$AWS_SECRET_ACCESS_KEY/g;
        s/\\\$AWS_REGION\b/$AWS_REGION/g;
        s/\\\$AWS_S3_BUCKET\b/$AWS_S3_BUCKET/g;
        s/\\\$AWS_S3_ENDPOINT\b/$AWS_S3_ENDPOINT/g;
    " "$WORKING_CONFIG" > "${WORKING_CONFIG}.tmp" && mv "${WORKING_CONFIG}.tmp" "$WORKING_CONFIG"
    echo "[main] Config ready ($(wc -c < $WORKING_CONFIG) bytes)"
fi

echo "[main] Starting tinode..."
exec /opt/tinode/tinode \
    --config="$WORKING_CONFIG" \
    --static_data=/opt/tinode/static \
    --cluster_self="${CLUSTER_SELF:-}" \
    --pprof_url="${PPROF_URL:-}"
