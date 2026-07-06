#!/bin/bash
# Custom entrypoint for Railway deployment
# Uses Railway's standard PostgreSQL environment variables

# IMPORTANT: Do NOT use 'exec' here.
# init-db returns exit code 1 when there's no sample data,
# but we need to catch that and keep the container alive (run tinode).
# Using exec would replace this shell and prevent our error handling.

# ── CRITICAL: Force RESET_DB=false ──────────────────────────────────────────
export RESET_DB="false"
export UPGRADE_DB="${UPGRADE_DB:-false}"
echo "[Railway init] RESET_DB forced to false (Railway env override)"
# ─────────────────────────────────────────────────────────────────────────────

# Use Railway's standard PG* environment variables to build POSTGRES_DSN
if [ -n "$PGHOST" ]; then
    export POSTGRES_DSN="postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}?sslmode=${PGSSLMODE:-disable}"
    echo "[Railway init] Using Railway PG* env vars -> POSTGRES_DSN=$POSTGRES_DSN"
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
    export POSTGRES_DSN="postgresql://${USERPASS}@${HOST}:${PORT}/${DBPATH#/}"
    echo "[Railway init] Parsed DATABASE_URL -> POSTGRES_DSN=$POSTGRES_DSN"
fi

# Default SMTP host URL
export SMTP_HOST_URL="${SMTP_HOST_URL:-https://tinode-chat-production.up.railway.app}"

# Run the official entrypoint (NOT with exec, so we can catch its exit code)
# The official entrypoint.sh runs init-db then exec's tinode.
# If init-db returns 1 (no sample data), entrypoint.sh exits 1 → we catch it below.
set +e
/opt/tinode/entrypoint.sh "$@"
exit_code=$?
set -e

if [ $exit_code -eq 0 ]; then
    echo "[Railway init] entrypoint.sh exited successfully"
elif [ $exit_code -eq 1 ]; then
    # init-db returned 1 (no sample data) but DB was already correct.
    # The official entrypoint printed "All done" then exited.
    # This is OK — tinode was started via exec in entrypoint.sh so we never reach here.
    # If we DO reach here, it means init-db failed but we still want tinode to start.
    echo "[Railway init] init-db returned 1 (no sample data) — starting tinode directly"
    exec /opt/tinode/tinode \
        --config=working.config \
        --static_data=/opt/tinode/static \
        --cluster_self="$CLUSTER_SELF" \
        --pprof_url="$PPROF_URL" \
        2>> /var/log/tinode.log
else
    echo "[Railway init] entrypoint.sh failed with exit code $exit_code"
    exit $exit_code
fi
