#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# Railway 部署入口脚本
# 职责：从 DATABASE_URL 解析出 POSTGRES_DSN，然后调用官方 entrypoint
# ─────────────────────────────────────────────────────────────────

set -e

# ── 解析 Railway DATABASE_URL → POSTGRES_DSN ────────────────────
# Railway DATABASE_URL 格式: postgres://user:password@host:port/dbname
# Tinode 期望格式: postgresql://user:password@host:port/dbname?sslmode=...
if [ -n "$DATABASE_URL" ] && [ -z "$POSTGRES_DSN" ]; then
    URI="${DATABASE_URL#*://}"           # 去掉 postgres:// 前缀
    USERPASS="${URI%%@*}"                # user:password
    HOSTPATH="${URI#*@}"                  # host:port/dbname

    USER="${USERPASS%%:*}"
    PASS="${USERPASS#*:}"

    # Railway Postgres SSL 模式
    SSLMODE="require"

    if [[ "$HOSTPATH" == *":"*"/"* ]]; then
        HOST="${HOSTPATH%%:*}"
        REST="${HOSTPATH#*:}"
        PORT="${REST%%/*}"
        DBPATH="${REST#*/}"
    elif [[ "$HOSTPATH" == *"/"* ]]; then
        HOST="${HOSTPATH%%/*}"
        DBPATH="${HOSTPATH#*/}"
        PORT="5432"
    else
        HOST="$HOSTPATH"
        DBPATH="postgres"
        PORT="5432"
    fi

    # 去掉 dbpath 中的查询参数（如果有）
    DBPATH="${DBPATH%%\?*}"

    # 构建 DSN
    ENCODED_PASS=$(python3 -c "import urllib.parse; print(urllib.parse.quote_plus('$PASS'))" 2>/dev/null || echo "$PASS")
    export POSTGRES_DSN="postgresql://${USER}:${ENCODED_PASS}@${HOST}:${PORT}/${DBPATH}?sslmode=${SSLMODE}"
    echo "[Railway] Parsed DATABASE_URL → POSTGRES_DSN=$POSTGRES_DSN"
fi

# Railway Postgres 默认值兜底
export POSTGRES_DSN="${POSTGRES_DSN:-postgresql://postgres:postgres@postgres.railway.internal:5432/postgres?sslmode=disable}"

# 确保不重置数据库
export RESET_DB="false"
export UPGRADE_DB="false"
export SAMPLE_DATA=""

# Web UI 的公网地址（邮件验证用）
export SMTP_HOST_URL="${SMTP_HOST_URL:-https://tinode-chat-production.up.railway.app}"

# Railway 容器内主机名
export CLUSTER_SELF="${CLUSTER_SELF:-}"

echo "[Railway] POSTGRES_DSN=$POSTGRES_DSN"
echo "[Railway] Starting tinode with official entrypoint..."

# 执行官方 entrypoint（Tinode 官方镜像里的 /opt/tinode/entrypoint.sh）
exec /opt/tinode/entrypoint.sh "$@"
