#!/bin/bash
# Custom entrypoint for Railway deployment
# Parses DATABASE_URL to extract PostgreSQL connection info

set -e

# Parse DATABASE_URL to set POSTGRES_DSN
# Expected format: postgresql://user:password@host:port/dbname?params
if [ -n "$DATABASE_URL" ]; then
    # Remove leading 'postgresql://' or 'postgres://'
    URI="${DATABASE_URL#*://}"
    
    # Split at '@' to get user:pass and host:port/db
    AUTH="${URI%%@*}"
    REST="${URI#*@}"
    
    # Split REST at ':' for host and rest
    HOST_PORT="${REST%%/*}"
    DBNAME_PARAMS="/${REST#*/}"
    
    # Split HOST_PORT at ':' for host and port
    HOST="${HOST_PORT%:*}"
    PORT="${HOST_PORT#*:}"
    
    # Build POSTGRES_DSN
    export POSTGRES_DSN="postgresql://${AUTH}@${HOST}:${PORT}/${DBNAME_PARAMS}"
    echo "[Railway init] Parsed DATABASE_URL -> POSTGRES_DSN=$POSTGRES_DSN"
fi

# Default SMTP host URL to our public domain
export SMTP_HOST_URL="${SMTP_HOST_URL:-https://tinode-chat-production.up.railway.app}"

# Use Railway's internal Postgres hostname (postgres.railway.internal) instead of TCP proxy
# The TCP proxy (hayabusa.proxy.rlwy.net) is for external access, internal is faster
# But if the internal doesn't work, fall back to whatever is in POSTGRES_DSN
echo "[Railway init] POSTGRES_DSN=$POSTGRES_DSN"

# Skip sample data loading on Railway (already have DB schema)
export SAMPLE_DATA=""
export NO_DB_INIT="false"

# Delegate to the official entrypoint
exec /opt/tinode/entrypoint.sh "$@"
