# Tinode Deployment for Railway - PostgreSQL build
FROM alpine:3.19

ARG VERSION=0.25.2
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
    tar \
    tzdata

WORKDIR /opt/tinode

# Download and extract tinode binary using curl (not ADD for external URLs)
RUN curl -fsSL \
    "https://github.com/tinode/chat/releases/download/v${VERSION}/tinode-${TARGET_DB}.linux-amd64.tar.gz" \
    -o /tmp/tinode.tar.gz \
    && tar -xzf /tmp/tinode.tar.gz -C /opt/tinode \
    && rm /tmp/tinode.tar.gz \
    && mkdir -p /opt/tinode/uploads /opt/tinode/static /opt/tinode/logs \
    && chmod +x /opt/tinode/init-db /opt/tinode/init-db2

# Copy entrypoint
COPY entrypoint.sh /opt/tinode/entrypoint.sh
RUN chmod +x /opt/tinode/entrypoint.sh

# Copy static web client files (will be mounted or can be added)
RUN mkdir -p /opt/tinode/static

EXPOSE 6060 16060

WORKDIR /opt/tinode
ENTRYPOINT ["/opt/tinode/entrypoint.sh"]
