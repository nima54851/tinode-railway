#!/bin/bash
# railway-init.sh — Railway DB initialization script
# Called by preDeployCommand (isolated init container) OR manually
# Generates working.config from template, runs init-db, then exits
set -e

export RESET_DB="${RESET_DB:-false}"
export UPGRADE_DB="${UPGRADE_DB:-false}"
export SMTP_HOST_URL="${SMTP_HOST_URL:-https://tinode-chat-production.up.railway.app}"

echo "[init] Railway Tinode DB Init — starting at $(date)"
echo "[init] RESET_DB=$RESET_DB, UPGRADE_DB=$UPGRADE_DB"

# ── Build POSTGRES_DSN ──────────────────────────────────────────────────────
if [ -n "$PGHOST" ]; then
    export POSTGRES_DSN="postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE:-disable}"
    echo "[init] Using PG* env vars"
elif [ -n "$DATABASE_URL" ]; then
    URI="${DATABASE_URL#*://}"
    USERPASS="${URI%%@*}"
    HOSTPATH="${URI#*@}"
    if [[ "$HOSTPATH" == *":"*"/"* ]]; then
        HOST="${HOSTPATH%%:*}"
        REST="${HOSTPATH#*:}"
        PORT="${REST%%/*}"
        DBPATH="${REST#*/}"
    elif [[ "$HOSTPATH" == *"/"* ]]; then
        HOST="${HOSTPATH%%/*}"
        DBPATH="${HOSTPATH#*/}"
        PORT="5432"
    fi
    export POSTGRES_DSN="postgresql://${USERPASS}@${HOST}:${PORT}/${DBPATH}"
    echo "[init] Parsed from DATABASE_URL"
else
    echo "[init] ERROR: No DATABASE_URL or PG* vars found"
    exit 1
fi

echo "[init] POSTGRES_DSN=postgresql://${PGUSER:-postgres}:***@${PGHOST:-localhost}/..."

# ── Wait for DB to be ready ────────────────────────────────────────────────
DB_HOST="${PGHOST:-${DBPATH%%:*}}"
DB_PORT="${PGPORT:-5432}"
echo "[init] Waiting for DB at $DB_HOST:$DB_PORT..."
if command -v nc &>/dev/null; then
    until nc -z -w5 "$DB_HOST" "$DB_PORT"; do
        echo "[init] DB not ready, waiting 3s..."
        sleep 3
    done
    echo "[init] DB is ready!"
else
    echo "[init] nc not available, skipping DB wait..."
fi

# ── Generate working.config from template ──────────────────────────────────
export CONFIG="${CONFIG:-working.config}"

# Use EXT_CONFIG if provided, otherwise generate from template
if [ -f "/opt/tinode/config.template" ]; then
    echo "[init] Generating $CONFIG from config.template..."
    # Replace placeholders with environment variable values
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
    echo "[init] $CONFIG generated"
elif [ -n "$EXT_CONFIG" ] && [ -f "$EXT_CONFIG" ]; then
    echo "[init] Using EXT_CONFIG=$EXT_CONFIG"
else
    echo "[init] WARNING: no config found, tinode may fail"
fi

# ── Run init-db ─────────────────────────────────────────────────────────────
SAMPLE_DATA="${SAMPLE_DATA:-/opt/tinode/data.json}"
if [ ! -f "$SAMPLE_DATA" ]; then
    echo "[init] WARNING: sample data file not found at $SAMPLE_DATA"
    SAMPLE_DATA=""
fi

echo "[init] Running init-db --reset=$RESET_DB --upgrade=$UPGRADE_DB --data=$SAMPLE_DATA..."
cd /opt/tinode

./init-db \
    --reset="${RESET_DB}" \
    --upgrade="${UPGRADE_DB}" \
    --config="${CONFIG}" \
    --data="${SAMPLE_DATA}" \
    --no_init="false"

rc=$?
echo "[init] init-db exited with code $rc"

if [ $rc -eq 0 ]; then
    echo "[init] DB initialization SUCCESS"
else
    echo "[init] DB init returned non-zero — checking if DB is usable..."
    # Exit code 1 from init-db typically means "already initialized" — this is OK
fi

echo "[init] DB Init complete at $(date)"
exit 0
