#!/bin/bash
# entrypoint.sh — generates working.config using python3, initializes DB, starts tinode

set -e

# ── Generate config via python3 (avoids envsubst edge cases) ─────────────────
python3 << 'PYEOF'
import json
import os

auth_token_key = os.environ.get('AUTH_TOKEN_KEY', '')
uid_encryption_key = os.environ.get('UID_ENCRYPTION_KEY', '')
database_url = os.environ.get('DATABASE_URL', '')
api_key_salt = os.environ.get('API_KEY_SALT', 'change-me')
smtp_host_url = os.environ.get('SMTP_HOST_URL', 'https://tinode-chat-production.up.railway.app')
server_status_path = os.environ.get('SERVER_STATUS_PATH', '/debug/status')
default_country_code = os.environ.get('DEFAULT_COUNTRY_CODE', 'US')
media_handler = os.environ.get('MEDIA_HANDLER', 'fs')
media_max_size = int(os.environ.get('MEDIA_MAX_SIZE', 33554432))
tls_enabled = os.environ.get('TLS_ENABLED', 'false').lower() == 'true'
tls_domain = os.environ.get('TLS_DOMAIN_NAME', '')
tls_contact = os.environ.get('TLS_CONTACT_ADDRESS', '')

# Build minimal config — only fields that are actually needed
config = {
    "listen": ":6060",
    "api_path": "/",
    "cache_control": 39600,
    "static_mount": "/",
    "grpc_listen": ":16060",
    "grpc_keepalive_enabled": True,
    "api_key_salt": api_key_salt,
    "max_message_size": 262144,
    "max_subscriber_count": 128,
    "max_tag_count": 16,
    "permanent_accounts": False,
    "expvar": "/debug/vars",
    "server_status": server_status_path,
    "default_country_code": default_country_code,
    "use_x_forwarded_for": True,
    "media": {
        "use_handler": media_handler,
        "max_size": media_max_size,
        "gc_period": 60,
        "gc_block_size": 100,
        "fs_path": "/opt/tinode/uploads",
        "fs_url_prefix": "/ui/v1/media"
    }
}

# Only include TLS if enabled
if tls_enabled and tls_domain:
    config["autocert"] = {
        "enabled": True,
        "cache": f"/etc/letsencrypt/live/{tls_domain}",
        "email": tls_contact,
        "domains": [tls_domain]
    }

# Auth section — CRITICAL: non-empty keys only
if auth_token_key:
    config["auth_config"] = {
        "token": {
            "expire_in": 1209600,
            "serial_num": 1,
            "key": auth_token_key
        },
        "code": {
            "expire_in": 900,
            "max_retries": 3,
            "code_length": 6
        }
    }

# DB section — CRITICAL: non-empty DSN only
if database_url:
    config["store_config"] = {
        "uid_key": uid_encryption_key if uid_encryption_key else "",
        "max_results": 1024,
        "use_adapter": "postgres",
        "postgres": {
            "max_open_conns": 100,
            "max_idle_conns": 10,
            "conn_max_lifetime": 3600,
            "dsn": database_url
        }
    }

config["logger"] = {
    "level": 3,
    "out": "",
    "encoding": "console"
}

output_path = '/opt/tinode/working.config'
with open(output_path, 'w') as f:
    json.dump(config, f, indent="\t", ensure_ascii=False)

print(f"[python] Config written to {output_path} ({os.path.getsize(output_path)} bytes)", flush=True)
PYEOF

WORKING_CONFIG="/opt/tinode/working.config"

# Verify key fields are non-empty
echo "[main] Verifying config fields..."
python3 -c "
import json
with open('$WORKING_CONFIG') as f:
    c = json.load(f)
errors = []
if c.get('auth_config', {}).get('token', {}).get('key', '') == '':
    errors.append('auth.token.key is EMPTY')
if c.get('store_config', {}).get('postgres', {}).get('dsn', '') == '':
    errors.append('store_config.postgres.dsn is EMPTY')
if errors:
    print('[ERROR] Config errors:')
    for e in errors:
        print(f'  - {e}')
    exit(1)
else:
    print('[OK] All critical fields are non-empty')
    print(f\"  auth.token.key = {c.get('auth_config',{}).get('token',{}).get('key','')[:20]}...\")
    print(f\"  store_config.postgres.dsn = {c.get('store_config',{}).get('postgres',{}).get('dsn','')[:50]}...\")
"

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
    echo "[init] RESET_DB=true — initializing database..."
    cd /opt/tinode
    /opt/tinode/init-db \
        --config="$WORKING_CONFIG" \
        --data=data.json \
        --reset=true \
        --continue \
        || echo "[init] init-db exited"
elif [ "$UPGRADE_DB" = "true" ] && [ -x "/opt/tinode/init-db" ]; then
    echo "[init] UPGRADE_DB=true — upgrading database schema..."
    /opt/tinode/init-db \
        --config="$WORKING_CONFIG" \
        --upgrade=true \
        --continue \
        || echo "[init] upgrade done"
fi

echo "[main] Starting tinode..."
exec /opt/tinode/tinode \
    --config="$WORKING_CONFIG" \
    --static_data=/opt/tinode/static \
    --cluster_self="${CLUSTER_SELF:-}" \
    --pprof_url="${PPROF_URL:-}"
