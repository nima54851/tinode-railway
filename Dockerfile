# Tinode Deployment on Railway - PostgreSQL
FROM alpine:3.19

ARG VERSION=0.25.2
ARG TARGET_DB=postgres

LABEL maintainer="Tinode"

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates bash grep netcat-openbsd curl tar tzdata

WORKDIR /opt/tinode

# Download and extract tinode binary
RUN curl -fsSL \
    "https://github.com/tinode/chat/releases/download/v${VERSION}/tinode-${TARGET_DB}.linux-amd64.tar.gz" \
    -o /tmp/tinode.tar.gz && \
    tar -xzf /tmp/tinode.tar.gz && \
    rm /tmp/tinode.tar.gz && \
    mkdir -p uploads static logs && \
    chmod +x init-db init-db2 tinode

# Copy entrypoint
COPY entrypoint.sh /opt/tinode/entrypoint.sh
RUN chmod +x /opt/tinode/entrypoint.sh

EXPOSE 6060 16060

ENTRYPOINT ["/opt/tinode/entrypoint.sh"]
