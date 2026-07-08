# ============================================================
# Tinode 官方镜像 + Railway Postgres 部署
# ============================================================
FROM tinode/tinode-postgres:0.25.3

USER root

# ── 下载预构建 Web UI（从 npm CDN）──────────────────────────────
# tinode-web@0.1.2 包含编译好的前端静态文件
RUN echo "Downloading tinode-web UI from npm..." && \
    apk add --no-cache nodejs npm && \
    npm install -g tinode-web@0.1.2 --quiet 2>/dev/null || true && \
    # 找到安装目录，复制到静态目录
    cp -r $(npm root -g)/tinode-web/dist /opt/tinode/static/ 2>/dev/null || \
    cp -r $(npm root -g)/tinode-web/package/dist /opt/tinode/static/ 2>/dev/null || \
    echo "[WARN] npm install failed, trying curl..." && \
    curl -fsSL "https://registry.npmjs.org/tinode-web/-/tinode-web-0.1.2.tgz" \
        -o /tmp/tinode-web.tgz && \
    mkdir -p /tmp/tinode-web && \
    tar -xzf /tmp/tinode-web.tgz -C /tmp/tinode-web && \
    mkdir -p /opt/tinode/static && \
    cp -r /tmp/tinode-web/package/dist/* /opt/tinode/static/ && \
    ls /opt/tinode/static/

USER tinode

# ── Railway 环境变量 ───────────────────────────────────────────
# DATABASE_URL 由 Railway 自动注入
# entrypoint.sh 会从 DATABASE_URL 自动解析为 POSTGRES_DSN
ENV RESET_DB="false"
ENV UPGRADE_DB="false"
ENV SAMPLE_DATA=""
ENV SMTP_HOST_URL="https://tinode-chat-production.up.railway.app"

# 复制自定义入口脚本
COPY --chmod=755 railway-entrypoint.sh /railway-entrypoint.sh

ENTRYPOINT ["/railway-entrypoint.sh"]
