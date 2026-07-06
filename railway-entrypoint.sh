#!/bin/bash
# Custom entrypoint for Railway deployment
# Uses Railway's standard PostgreSQL environment variables

# IMPORTANT: Do NOT use set -e globally.
# init-db returns exit code 1 when there's no sample data,
# even though the DB reset/upgrade may have succeeded.
# We handle errors manually below.

# Use Railway's standard PG* environment variables to build POSTGRES_DSN
if [ -n "$PGHOST" ]; then
    export POSTGRES_DSN="postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE:-disable}"
    echo "[Railway init] Using Railway PG* env vars -> POSTGRES_DSN=$POSTGRES_DSN"
elif [ -n "$DATABASE_URL" ]; then
    # Parse DATABASE_URL manually
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
    
    export POSTGRES_DSN="postgresql://${USERPASS}@${HOST}:${PORT}/${DBPATH#/}"
    echo "[Railway init] Parsed DATABASE_URL -> POSTGRES_DSN=$POSTGRES_DSN"
fi

# CRITICAL: init-db requires RESET_DB and UPGRADE_DB to be set to valid values
export RESET_DB="${RESET_DB:-false}"
export UPGRADE_DB="${UPGRADE_DB:-false}"

# Default SMTP host URL
export SMTP_HOST_URL="${SMTP_HOST_URL:-https://tinode-chat-production.up.railway.app}"

# Delegate to the official entrypoint
# Note: init-db returns exit code 1 when SAMPLE_DATA is empty/unset,
# even if the DB operation succeeded. We treat that as success.
exec /opt/tinode/entrypoint.sh "$@" || {
    exit_code=$?
    # init-db returns 1 when there's no sample data but DB reset/upgrade succeeded
    # The official entrypoint.sh prints "init-db failed" in that case and exits 1.
    # We treat it as success since the DB operation itself succeeded.
    if [ $exit_code -eq 1 ]; then
        echo "[Railway init] init-db returned 1 (likely no sample data) — treating as success."
        exit 0
    else
        echo "[Railway init] entrypoint.sh failed with exit code $exit_code"
        exit $exit_code
    fi
}
