# ============================================================
# Tinode v0.25.3 + Web UI 部署
# 二进制从 GitHub Releases 直接下载（之前验证可行）
# ============================================================
FROM alpine:3.22

RUN apk add --no-cache ca-certificates bash curl grep python3

WORKDIR /opt/tinode

# ── 从 GitHub Releases 下载官方 tinode-postgres 二进制 ──────────
RUN echo "Downloading Tinode v0.25.3 (postgres)..." && \
    curl -fsSL "https://github.com/tinode/chat/releases/download/v0.25.3/tinode-postgres.linux-amd64.tar.gz" \
        -o tinode-postgres.tar.gz && \
    tar -xzf tinode-postgres.tar.gz && \
    rm -f tinode-postgres.tar.gz && \
    ls -la

# ── 下载 Web UI（从 npm CDN）─────────────────────────────────────
RUN echo "Downloading tinode-web UI..." && \
    curl -fsSL "https://registry.npmjs.org/tinode-web/-/tinode-web-0.1.2.tgz" \
        -o /tmp/tinode-web.tgz && \
    mkdir -p /tmp/extracted && \
    tar -xzf /tmp/tinode-web.tgz -C /tmp/extracted && \
    mkdir -p /opt/tinode/static && \
    cp -r /tmp/extracted/package/dist/* /opt/tinode/static/ && \
    rm -rf /tmp/extracted /tmp/tinode-web.tgz && \
    ls /opt/tinode/static/

# ── 配置文件和数据 ────────────────────────────────────────────────
COPY config.template  /opt/tinode/config.template
COPY data.json        /opt/tinode/data.json
COPY entrypoint.sh    /opt/tinode/entrypoint.sh

RUN chmod +x /opt/tinode/entrypoint.sh && \
    mkdir -p /opt/tinode/uploads /opt/tinode/logs /botdata

EXPOSE 6060 16060

ENTRYPOINT ["/opt/tinode/entrypoint.sh"]
