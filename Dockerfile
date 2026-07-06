FROM alpine:3.22

RUN apk update && \
    apk add --no-cache ca-certificates bash curl grep netcat-openbsd tzdata gettext

WORKDIR /opt/tinode

COPY tinode           /opt/tinode/tinode
COPY config.template  /opt/tinode/config.template
COPY data.json        /opt/tinode/data.json
COPY entrypoint.sh    /opt/tinode/entrypoint.sh

RUN chmod +x /opt/tinode/tinode /opt/tinode/entrypoint.sh && \
    mkdir -p /opt/tinode/uploads /opt/tinode/static /opt/tinode/logs /botdata

EXPOSE 6060 16060
ENTRYPOINT ["/opt/tinode/entrypoint.sh"]
