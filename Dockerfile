# Tinode Deployment for Railway
# Uses official tinode/tinode image with alldbs build (PostgreSQL configured at runtime)

FROM alpine:3.22

ARG VERSION=0.25
ARG TARGET_DB=postgres

LABEL maintainer="Tinode Deployment"
LABEL version=${VERSION}

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    bash \
    grep \
    netcat-openbsd \
    curl \
    tar

WORKDIR /opt/tinode

# Download and extract tinode binary
ADD https://github.com/tinode/chat/releases/download/v${VERSION}/tinode-${TARGET_DB}.linux-amd64.tar.gz /tmp/tinode.tar.gz

RUN tar -xzf /tmp/tinode.tar.gz -C /opt/tinode \
    && rm /tmp/tinode.tar.gz \
    && mkdir -p /opt/tinode/uploads /opt/tinode/static /opt/tinode/logs \
    && chmod +x /opt/tinode/init-db /opt/tinode/init-db2

# Download and install web client static files
RUN curl -sL "https://raw.githubusercontent.com/tinode/webapp/master/index.html" \
    -o /opt/tinode/static/index.html 2>/dev/null || true

# Create entrypoint
COPY entrypoint.sh /opt/tinode/entrypoint.sh
RUN chmod +x /opt/tinode/entrypoint.sh

# Create working config template
RUN echo '{"listen":":6060","api_path":"/","static_mount":"./static","use_x_forwarded_for":true,"auth_config":{"token":{"key":"wfaY2RgF2S1OQI/ZlK+LSrp1KB2jwAdGAIHQ7JZn+Kc="}},"store_config":{"uid_key":"la6YsO+bNX/+XIkOqc5Svw==","use_adapter":"postgres","adapters":{"postgres":{"dsn":"PLACEHOLDER_DSN"}}}}' > /opt/tinode/tinode.conf.template || true

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD nc -z localhost 6060 || exit 1

EXPOSE 6060 16060

WORKDIR /opt/tinode
ENTRYPOINT ["/opt/tinode/entrypoint.sh"]
