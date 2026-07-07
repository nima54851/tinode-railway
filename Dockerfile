# Force rebuild at 2026-07-07T11:15:48.952267
FROM alpine:3.22

RUN apk update && \
    apk add --no-cache ca-certificates bash curl grep netcat-openbsd tzdata gettext python3

WORKDIR /opt/tinode

# Download official Tinode v0.25.3 binary from GitHub releases
RUN echo "Downloading tinode-postgres v0.25.3..." && \
    curl -fsSL "https://github.com/tinode/chat/releases/download/v0.25.3/tinode-postgres.linux-amd64.tar.gz" \
        -o tinode-postgres.tar.gz && \
    tar -xzf tinode-postgres.tar.gz && \
    rm -f tinode-postgres.tar.gz && \
    ls -la

# Copy config and scripts
COPY config.template  /opt/tinode/config.template
COPY data.json        /opt/tinode/data.json
COPY entrypoint.sh   /opt/tinode/entrypoint.sh

RUN chmod +x /opt/tinode/entrypoint.sh && \
    mkdir -p /opt/tinode/uploads /opt/tinode/static /opt/tinode/logs /botdata

EXPOSE 6060 16060

ENTRYPOINT ["/opt/tinode/entrypoint.sh"]
