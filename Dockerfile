# ============================================================
# Tinode 官方镜像 + Railway Postgres 部署
# ============================================================
FROM tinode/tinode-postgres:0.25.3

USER root

# ── 下载预构建 Web UI（直接用 curl 从 npm CDN 下载）──────────────
# npm registry 可访问，curl 已内置于 alpine
RUN echo "Downloading tinode-web UI..." && \
    mkdir -p /opt/tinode/static && \
    curl -fsSL "https://registry.npmjs.org/tinode-web/-/tinode-web-0.1.2.tgz" \
        -o /tmp/tinode-web.tgz && \
    mkdir -p /tmp/extracted && \
    tar -xzf /tmp/tinode-web.tgz -C /tmp/extracted && \
    cp -r /tmp/extracted/package/dist/* /opt/tinode/static/ && \
    rm -rf /tmp/extracted /tmp/tinode-web.tgz && \
    ls /opt/tinode/static/

USER tinode

# ── Railway 环境变量 ───────────────────────────────────────────
ENV RESET_DB="false"
ENV UPGRADE_DB="false"
ENV SAMPLE_DATA=""
ENV SMTP_HOST_URL="https://tinode-chat-production.up.railway.app"

# ── 自定义入口脚本（解析 DATABASE_URL → POSTGRES_DSN）──────────
COPY --chmod=755 railway-entrypoint.sh /railway-entrypoint.sh

ENTRYPOINT ["/railway-entrypoint.sh"]
