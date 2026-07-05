#!/bin/bash
# Custom entrypoint for Railway deployment
# Uses Railway's standard PostgreSQL environment variables

set -e

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
exec /opt/tinode/entrypoint.sh "$@"
