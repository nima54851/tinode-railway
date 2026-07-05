#!/bin/bash
# Custom entrypoint for Railway deployment
# Uses Railway's standard PostgreSQL environment variables

set -e

# Use Railway's standard PG* environment variables to build POSTGRES_DSN
# These are automatically set when a Postgres database is linked
if [ -n "$PGHOST" ]; then
    export POSTGRES_DSN="postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}"
    if [ -n "$PGSSLMODE" ]; then
        export POSTGRES_DSN="${POSTGRES_DSN}?sslmode=${PGSSLMODE}"
    fi
    echo "[Railway init] Using Railway PG* env vars -> POSTGRES_DSN=$POSTGRES_DSN"
elif [ -n "$DATABASE_URL" ]; then
    # Fallback: parse DATABASE_URL manually
    # Format: postgresql://user:pass@host:port/db?params
    URI="${DATABASE_URL#*://}"          # remove "postgresql://"
    USERPASS="${URI%%@*}"               # user:pass
    HOSTPATH="${URI#*@}"               # host:port/db?params
    
    # Split host and port
    if [[ "$HOSTPATH" == *":"*"/"* ]]; then
        HOST="${HOSTPATH%%:*}"          # before first :
        REST="${HOSTPATH#*:}"          # after first :
        PORT="${REST%%/*}"             # before first /
        DBPATH="${REST#*/}"           # after first /
    elif [[ "$HOSTPATH" == *"/"* ]]; then
        HOST="${HOSTPATH%%/*}"
        DBPATH="${HOSTPATH#*/}"
        PORT="5432"
    fi
    
    # Remove leading slash from dbpath
    DBPATH="${DBPATH#/}"
    
    export POSTGRES_DSN="postgresql://${USERPASS}@${HOST}:${PORT}/${DBPATH}"
    echo "[Railway init] Parsed DATABASE_URL -> POSTGRES_DSN=$POSTGRES_DSN"
fi

# Default SMTP host URL
export SMTP_HOST_URL="${SMTP_HOST_URL:-https://tinode-chat-production.up.railway.app}"

# Skip sample data loading on Railway
export SAMPLE_DATA=""

# Delegate to the official entrypoint
exec /opt/tinode/entrypoint.sh "$@"
