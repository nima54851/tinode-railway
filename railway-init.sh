#!/bin/bash
# railway-init.sh — Railway DB initialization script
# Called by preDeployCommand (isolated init container)
set -e

export RESET_DB="${RESET_DB:-false}"
export UPGRADE_DB="${UPGRADE_DB:-false}"
export SMTP_HOST_URL="${SMTP_HOST_URL:-https://tinode-chat-production.up.railway.app}"

echo "[init] Railway Tinode DB Init — $(date)"

# ── Default values for config placeholders ──────────────────────────────────
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

# ── Build POSTGRES_DSN ───────────────────────────────────────────────────────
if [ -n "$PGHOST" ]; then
    export POSTGRES_DSN="postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE:-disable}"
    echo "[init] Using PG* env vars"
elif [ -n "$DATABASE_URL" ]; then
    URI="${DATABASE_URL#*://}"
    USERPASS="${URI%%@*}"
    HOSTPATH="${URI#*@}"
    if [[ "$HOSTPATH" == *":"*"/"* ]]; then
        HOST="${HOSTPATH%%:*}"; REST="${HOSTPATH#*:}"; PORT="${REST%%/*}"; DBPATH="${REST#*/}"
    elif [[ "$HOSTPATH" == *"/"* ]]; then
        HOST="${HOSTPATH%%/*}"; DBPATH="${HOSTPATH#*/}"; PORT="5432"
    fi
    export POSTGRES_DSN="postgresql://${USERPASS}@${HOST}:${PORT}/${DBPATH}"
    echo "[init] Parsed from DATABASE_URL"
else
    echo "[init] ERROR: No DATABASE_URL or PG* vars"
    exit 1
fi
echo "[init] POSTGRES_DSN=postgresql://${PGUSER:-postgres}:***@..."

# ── Wait for DB ───────────────────────────────────────────────────────────────
DB_HOST="${PGHOST:-postgres.railway.internal}"
DB_PORT="${PGPORT:-5432}"
echo "[init] Waiting for DB at $DB_HOST:$DB_PORT..."
if command -v nc &>/dev/null; then
    until nc -z -w5 "$DB_HOST" "$DB_PORT" 2>/dev/null; do
        echo "[init] DB not ready, sleeping 3s..."
        sleep 3
    done
    echo "[init] DB is ready!"
else
    sleep 5
fi

# ── Generate working.config from template ───────────────────────────────────
export CONFIG="${CONFIG:-working.config}"
CONFIG_TEMPLATE="/opt/tinode/config.template"
WORKING_CONFIG="/opt/tinode/${CONFIG}"

if [ -f "$CONFIG_TEMPLATE" ]; then
    echo "[init] Generating $WORKING_CONFIG from template..."
    cp "$CONFIG_TEMPLATE" "$WORKING_CONFIG"

    # Replace all $VAR placeholders using Perl (available in Alpine via perl)
    if command -v perl &>/dev/null; then
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
        echo "[init] Config generated with perl"
    else
        # Fallback: use sed with careful quoting
        sed -i \
            -e "s/\\\$API_KEY_SALT\b/$API_KEY_SALT/g" \
            -e "s/\\\$SERVER_STATUS_PATH\b/$SERVER_STATUS_PATH/g" \
            -e "s/\\\$DEFAULT_COUNTRY_CODE\b/$DEFAULT_COUNTRY_CODE/g" \
            -e "s/\"\\\$FS_CORS_ORIGINS\"/\"[$FS_CORS_ORIGINS]\"/g" \
            -e "s/\\\$FS_CORS_ORIGINS\b/\"[$FS_CORS_ORIGINS]\"/g" \
            -e "s/\"\\\$AWS_CORS_ORIGINS\"/\"[$AWS_CORS_ORIGINS]\"/g" \
            -e "s/\\\$AWS_CORS_ORIGINS\b/\"[$AWS_CORS_ORIGINS]\"/g" \
            -e "s/\\\$TLS_ENABLED\b/$TLS_ENABLED/g" \
            -e "s/\\\$TLS_DOMAIN_NAME\b/$TLS_DOMAIN_NAME/g" \
            -e "s/\\\$TLS_CONTACT_ADDRESS\b/$TLS_CONTACT_ADDRESS/g" \
            -e "s/\\\$MEDIA_HANDLER\b/$MEDIA_HANDLER/g" \
            -e "s/\"\\\$MEDIA_MAX_SIZE\"/$MEDIA_MAX_SIZE/g" \
            -e "s/\\\$AWS_ACCESS_KEY_ID\b/$AWS_ACCESS_KEY_ID/g" \
            -e "s/\\\$AWS_SECRET_ACCESS_KEY\b/$AWS_SECRET_ACCESS_KEY/g" \
            -e "s/\\\$AWS_REGION\b/$AWS_REGION/g" \
            -e "s/\\\$AWS_S3_BUCKET\b/$AWS_S3_BUCKET/g" \
            -e "s/\\\$AWS_S3_ENDPOINT\b/$AWS_S3_ENDPOINT/g" \
            "$WORKING_CONFIG"
        echo "[init] Config generated with sed"
    fi
    echo "[init] Config generated ($(wc -c < $WORKING_CONFIG) bytes)"
else
    echo "[init] WARNING: $CONFIG_TEMPLATE not found"
fi

# ── Run init-db ──────────────────────────────────────────────────────────────
SAMPLE_DATA="${SAMPLE_DATA:-/opt/tinode/data.json}"
if [ ! -f "$SAMPLE_DATA" ]; then
    echo "[init] WARNING: sample data not found at $SAMPLE_DATA"
    SAMPLE_DATA=""
fi

echo "[init] Running init-db..."
cd /opt/tinode
./init-db \
    --reset="${RESET_DB}" \
    --upgrade="${UPGRADE_DB}" \
    --config="${CONFIG}" \
    --data="${SAMPLE_DATA}" \
    --no_init="false"

rc=$?
echo "[init] init-db exited with code $rc"
echo "[init] DB Init complete at $(date)"
exit 0
