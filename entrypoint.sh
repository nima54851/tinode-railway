#!/bin/bash
set -e

echo "=== Tinode Railway Entrypoint ==="

# Railway provides DATABASE_URL for PostgreSQL
# Format: postgresql://user:password@host:port/dbname
if [ ! -z "$DATABASE_URL" ]; then
  echo "DATABASE_URL detected, configuring PostgreSQL connection..."
  # DATABASE_URL already has the right format, just ensure sslmode
  if echo "$DATABASE_URL" | grep -q "sslmode"; then
    POSTGRES_DSN="$DATABASE_URL"
  else
    POSTGRES_DSN="${DATABASE_URL}?sslmode=disable&connect_timeout=10"
  fi
  
  # Replace the DSN in the config
  sed -i "s|PLACEHOLDER_DSN|${POSTGRES_DSN}|g" /opt/tinode/tinode.conf.template 2>/dev/null || true
  
  # Create the actual config
  cat > /opt/tinode/tinode.conf << 'CONFEOF'
{
  "listen": ":6060",
  "api_path": "/",
  "static_mount": "./static",
  "cache_control": 39600,
  "ws_compression_disabled": false,
  "use_x_forwarded_for": true,
  "default_country_code": "",
  "max_message_size": 262144,
  "max_subscriber_count": 128,
  "max_tag_count": 16,
  "permanent_accounts": false,
  "expvar": "/debug/vars",
  "server_status": "/debug/status",
  "auth_config": {
    "basic": {
      "add_to_tags": true,
      "min_login_length": 4,
      "min_password_length": 6
    },
    "token": {
      "expire_in": 1209600,
      "serial_num": 1,
      "key": "wfaY2RgF2S1OQI/ZlK+LSrp1KB2jwAdGAIHQ7JZn+Kc="
    },
    "code": {
      "expire_in": 900,
      "max_retries": 3,
      "code_length": 6
    }
  },
  "store_config": {
    "uid_key": "la6YsO+bNX/+XIkOqc5Svw==",
    "max_results": 1024,
    "use_adapter": "postgres",
    "adapters": {
      "postgres": {
        "dsn": "DSN_PLACEHOLDER",
        "max_open_conns": 50,
        "max_idle_conns": 10,
        "conn_max_lifetime": 60,
        "sql_timeout": 10
      }
    }
  },
  "acc_gc_config": {
    "enabled": true,
    "gc_period": 3600,
    "gc_block_size": 10,
    "gc_min_account_age": 30
  },
  "media": {
    "use_handler": "fs",
    "max_size": 8388608,
    "gc_period": 60,
    "gc_block_size": 100,
    "handlers": {
      "fs": {
        "upload_dir": "uploads",
        "cache_control": "max-age=86400",
        "cors_origins": ["*"]
      }
    }
  }
}
CONFEOF

  # Replace DSN placeholder with actual connection string
  ESCAPED_DSN=$(echo "$POSTGRES_DSN" | sed 's/[\/&]/\\&/g')
  sed -i "s|DSN_PLACEHOLDER|${ESCAPED_DSN}|g" /opt/tinode/tinode.conf
  echo "Config written."
else
  echo "ERROR: DATABASE_URL not set. Railway PostgreSQL plugin must be enabled."
  echo "Add a PostgreSQL plugin to this service in Railway dashboard."
  exit 1
fi

# Wait for database to be ready
echo "Waiting for PostgreSQL to be ready..."
HOST=$(echo "$DATABASE_URL" | sed -E 's|.*@([^:]+):([0-9]+)/.*|\1 \2|')
DB_HOST=$(echo "$HOST" | awk '{print $1}')
DB_PORT=$(echo "$HOST" | awk '{print $2}')

if [ -z "$DB_PORT" ]; then DB_PORT=5432; fi

until nc -z -w10 "$DB_HOST" "$DB_PORT" 2>/dev/null; do
  echo "  Waiting for $DB_HOST:$DB_PORT..."
  sleep 3
done
echo "PostgreSQL is ready."

# Initialize database
echo "Initializing database..."
/opt/tinode/init-db \
  --reset=false \
  --upgrade=false \
  --config=/opt/tinode/tinode.conf \
  --no_init=false 2>&1 | head -5

# Create admin user
echo "Creating admin user..."
/opt/tinode/init-db \
  --add_root="admin:admin123" \
  --config=/opt/tinode/tinode.conf 2>&1 | head -3 || true

echo "=== Starting Tinode server on port 6060 ==="

# Run the server
exec /opt/tinode/tinode \
  --config=/opt/tinode/tinode.conf \
  --static_data=/opt/tinode/static \
  2>&1
