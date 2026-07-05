# v=BUILD_TIMESTAMP - Railway will see a changed Dockerfile and NOT use old snapshot
ARG BUILD_EPOCH=0
FROM alpine:3.22

ENV BUILD_EPOCH=${BUILD_EPOCH}

RUN apk update && \
    apk add --no-cache ca-certificates bash curl nc

WORKDIR /opt/tinode

# Download official Tinode v0.25.3 PostgreSQL binary directly
RUN echo "Downloading tinode-postgres v0.25.3..." && \
    curl -fsSL "https://github.com/tinode/chat/releases/download/v0.25.3/tinode-postgres.linux-amd64.tar.gz" \
        -o tinode-postgres.tar.gz && \
    tar -xzf tinode-postgres.tar.gz && \
    rm -f tinode-postgres.tar.gz && \
    echo "Binary downloaded, files:" && ls -la

# Copy entry scripts
COPY entrypoint.sh /opt/tinode/entrypoint.sh
COPY config.template /opt/tinode/config.template
COPY railway-entrypoint.sh /opt/tinode/railway-entrypoint.sh

RUN chmod +x /opt/tinode/entrypoint.sh /opt/tinode/railway-entrypoint.sh

# Create required directories
RUN mkdir -p /opt/tinode/uploads /opt/tinode/static /opt/tinode/logs /botdata

EXPOSE 6060 16060

# Railway-entrypoint parses DATABASE_URL and calls official entrypoint
CMD ["/opt/tinode/railway-entrypoint.sh"]
