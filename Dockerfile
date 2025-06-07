FROM ghcr.io/klutchell/unbound:1.23.0 AS unbound

FROM pihole/pihole:2025.06.1
LABEL maintainer="Vijayakumar Ravi"

ARG SOURCE="deb http://deb.debian.org/debian testing main"
RUN echo $SOURCE > /etc/apt/sources.list

ARG UNBOUND_UID=101
ARG UNBOUND_GID=102

RUN groupadd -g ${UNBOUND_GID} unbound \
    && useradd -g unbound -d /var/unbound -u ${UNBOUND_UID} -M -s /bin/false unbound

COPY --from=unbound /lib/ld-musl*.so.1 /lib/
COPY --from=unbound /usr/lib/libgcc_s.so.1 /usr/lib/
COPY --from=unbound /lib/libcrypto.so.3 /lib/libssl.so.3 /lib/
COPY --from=unbound /usr/lib/libsodium.so.* /usr/lib/libevent-2.1.so.* /usr/lib/libexpat.so.* /usr/lib/libhiredis.so.* /usr/lib/libnghttp2.so.* /usr/lib/
COPY --from=unbound /etc/ssl/ /etc/ssl/

COPY --from=unbound /usr/sbin/ /usr/sbin/

COPY --from=unbound /usr/bin/ /usr/bin/

COPY --from=unbound /usr/bin/drill-hc /usr/bin/drill-hc

COPY --from=unbound --chown=unbound:unbound /var/unbound/root.hints /var/unbound/root.hints
COPY --from=unbound --chown=unbound:unbound /var/unbound/root.key /var/unbound/root.key

RUN mkdir -p /etc/unbound/
COPY config/unbound-pihole.conf /etc/unbound/unbound.conf

RUN mkdir -p /etc/dnsmasq.d/
COPY config/99-edns.conf /etc/dnsmasq.d/99-edns.conf

RUN mkdir -p /etc/services.d/unbound
COPY config/unbound-run /etc/services.d/unbound/run

COPY config/unbound-package-helper /usr/lib/unbound/package-helper
RUN chmod 755 /usr/lib/unbound/package-helper

LABEL org.opencontainers.image.authors="Vijayakumar Ravi" \
      org.opencontainers.image.title="vijaysrv/pihole-unbound" \
      org.opencontainers.image.description="Run Pi-Hole + Unbound on Docker" \
      org.opencontainers.image.url="https://github.com/VijayakumarRavi/docker-pihole-unbound" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/VijayakumarRavi/docker-pihole-unbound" \
      org.opencontainers.image.original_source="https://github.com/unclamped/docker-pihole-unbound"

ENTRYPOINT ./s6-init

