# ============================================================
# Tinode v0.25.3 + 完整 Web UI
# 二进制: GitHub Releases
# Web UI: npm CDN → /opt/tinode/web-ui/ → 运行时覆盖 /opt/tinode/static/
# ============================================================
FROM alpine:3.22

RUN apk add --no-cache ca-certificates bash curl grep python3

WORKDIR /opt/tinode

# ── 从 GitHub Releases 下载官方二进制 ──────────────────────────
RUN echo "Downloading Tinode v0.25.3..." && \
    curl -fsSL "https://github.com/tinode/chat/releases/download/v0.25.3/tinode-postgres.linux-amd64.tar.gz" \
        -o tinode-postgres.tar.gz && \
    tar -xzf tinode-postgres.tar.gz && \
    rm -f tinode-postgres.tar.gz && \
    echo "Binary OK" && ls /opt/tinode/

# ── 从 npm CDN 下载 Web UI ──────────────────────────────────────
RUN echo "Downloading web UI..." && \
    curl -fsSL "https://registry.npmjs.org/tinode-web/-/tinode-web-0.1.2.tgz" \
        -o /tmp/tinode-web.tgz && \
    mkdir -p /tmp/extracted && \
    tar -xzf /tmp/tinode-web.tgz -C /tmp/extracted && \
    mkdir -p /opt/tinode/web-ui && \
    cp -r /tmp/extracted/package/dist/* /opt/tinode/web-ui/ && \
    rm -rf /tmp/extracted /tmp/tinode-web.tgz && \
    echo "Web UI downloaded:" && ls /opt/tinode/web-ui/

# ── 复制脚本和配置 ──────────────────────────────────────────────
COPY config.template  /opt/tinode/config.template
COPY data.json         /opt/tinode/data.json
COPY entrypoint.sh    /opt/tinode/entrypoint.sh

RUN chmod +x /opt/tinode/entrypoint.sh && \
    mkdir -p /opt/tinode/static /opt/tinode/uploads /opt/tinode/logs /botdata

EXPOSE 6060 16060

ENTRYPOINT ["/opt/tinode/entrypoint.sh"]
