#!/bin/bash
set -e

# ── Generate config via python3 ─────────────────────────────────────────────
python3 << 'PYEOF'
import json, os

auth_token_key     = os.environ.get('AUTH_TOKEN_KEY', '')
uid_encryption_key = os.environ.get('UID_ENCRYPTION_KEY', '')
api_key_salt       = os.environ.get('API_KEY_SALT', '')
smtp_host_url      = os.environ.get('SMTP_HOST_URL', 'https://tinode-chat-production.up.railway.app')
server_status_path = os.environ.get('SERVER_STATUS_PATH', '/debug/status')
default_country    = os.environ.get('DEFAULT_COUNTRY_CODE', 'US')
media_handler      = os.environ.get('MEDIA_HANDLER', 'fs')
media_max_size     = int(os.environ.get('MEDIA_MAX_SIZE', 33554432))
tls_enabled        = os.environ.get('TLS_ENABLED', 'false').lower() == 'true'
tls_domain         = os.environ.get('TLS_DOMAIN_NAME', '')
tls_contact        = os.environ.get('TLS_CONTACT_ADDRESS', '')

config = {
    "listen": ":6060",
    "api_path": "/v2",
    "cache_control": 39600,
    "static_mount": "/",
    "grpc_listen": ":16060",
    "grpc_keepalive_enabled": True,
    "max_message_size": 262144,
    "max_subscriber_count": 128,
    "max_tag_count": 16,
    "permanent_accounts": False,
    "expvar": "/debug/vars",
    "server_status": server_status_path,
    "default_country_code": default_country,
    "use_x_forwarded_for": True,
}

if api_key_salt:
    config["api_key_salt"] = api_key_salt

if media_handler:
    config["media"] = {
        "use_handler": media_handler,
        "max_size": media_max_size,
        "gc_period": 60,
        "gc_block_size": 100,
        "fs_path": "/opt/tinode/uploads",
        "fs_url_prefix": "/ui/v1/media"
    }

if tls_enabled and tls_domain:
    config["autocert"] = {
        "enabled": True,
        "cache": f"/etc/letsencrypt/live/{tls_domain}",
        "email": tls_contact,
        "domains": [tls_domain]
    }

if auth_token_key:
    config["auth_config"] = {
        "token": {"expire_in": 1209600, "serial_num": 1, "key": auth_token_key},
        "code":  {"expire_in": 900, "max_retries": 3, "code_length": 6}
    }

database_url = os.environ.get('DATABASE_URL', '')
if database_url:
    config["store_config"] = {
        "uid_key": uid_encryption_key or "",
        "max_results": 1024,
        "use_adapter": "postgres",
        "adapters": {
            "postgres": {
                "dsn": database_url,
                "max_open_conns": 100,
                "max_idle_conns": 10,
                "conn_max_lifetime": 3600,
            }
        }
    }

config["push"]    = []
config["plugins"] = []
config["logger"]   = {"level": 3, "out": "", "encoding": "console"}

output_path = '/opt/tinode/working.config'
with open(output_path, 'w') as f:
    json.dump(config, f, indent="\t", ensure_ascii=False)
print(f"[python] Config written ({os.path.getsize(output_path)} bytes)")
PYEOF

WORKING_CONFIG="/opt/tinode/working.config"

# ── Wait for DB ─────────────────────────────────────────────────────────────
DB_HOST="${PGHOST:-postgres.railway.internal}"
DB_PORT="${PGPORT:-5432}"
echo "[main] Waiting for DB at $DB_HOST:$DB_PORT..."
if command -v nc &>/dev/null; then
    cnt=30
    while ! nc -z -w2 "$DB_HOST" "$DB_PORT" 2>/dev/null; do
        cnt=$((cnt-1))
        [ $cnt -le 0 ] && break || sleep 1
    done
fi
echo "[main] DB connection ready"

# ── Init DB (if requested) ─────────────────────────────────────────────────
if [ "$RESET_DB" = "true" ] && [ -x "/opt/tinode/init-db" ]; then
    echo "[init] RESET_DB=true — initializing database..."
    /opt/tinode/init-db --config="$WORKING_CONFIG" --data=data.json --reset=true --continue \
        || echo "[init] done"
elif [ "$UPGRADE_DB" = "true" ] && [ -x "/opt/tinode/init-db" ]; then
    echo "[init] UPGRADE_DB=true — upgrading schema..."
    /opt/tinode/init-db --config="$WORKING_CONFIG" --upgrade=true --continue \
        || echo "[init] done"
fi

# ── Deploy web UI ───────────────────────────────────────────────────────────
# Web UI was downloaded to /opt/tinode/web-ui/ during Docker build.
# Copy it to /opt/tinode/static/ for Tinode to serve.
if [ -d "/opt/tinode/web-ui" ] && [ "$(ls -A /opt/tinode/web-ui)" ]; then
    mkdir -p /opt/tinode/static
    cp -r /opt/tinode/web-ui/* /opt/tinode/static/
    echo "[main] Web UI deployed to /opt/tinode/static/ ($(ls /opt/tinode/static/ | wc -l) files)"
else
    echo "[main] WARNING: web-ui not found, creating minimal index.html"
    mkdir -p /opt/tinode/static
    cat > /opt/tinode/static/index.html << 'HTMLEOF'
<!DOCTYPE html><html><head><title>Tinode</title></head>
<body><h1>Tinode v0.25.3 Online</h1><p>API: <code>/v2/</code></p></body></html>
HTMLEOF
fi

echo "[main] Static files:"
ls /opt/tinode/static/ | head -5

echo "[main] Starting tinode..."
exec /opt/tinode/tinode \
    --config="$WORKING_CONFIG" \
    --static_data=/opt/tinode/static \
    --cluster_self="${CLUSTER_SELF:-}" \
    --pprof_url="${PPROF_URL:-}"
