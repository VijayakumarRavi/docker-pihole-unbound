FROM ghcr.io/klutchell/unbound:1.22.0 AS unbound

FROM pihole/pihole:2024.07.0
LABEL maintainer="Vijayakumar Ravi"

ARG SOURCE="deb http://deb.debian.org/debian testing main"
RUN echo $SOURCE > /etc/apt/sources.list

ARG UNBOUND_UID=101
ARG UNBOUND_GID=102

RUN groupadd -g ${UNBOUND_GID} unbound \
    && useradd -g unbound -d /var/unbound -u ${UNBOUND_UID} -M -s /bin/false unbound

COPY --from=unbound /usr/sbin/unbound /opt/usr/sbin/unbound

RUN mkdir -p /etc/unbound/
COPY config/unbound-pihole.conf /etc/unbound/unbound.conf

RUN mkdir -p /etc/dnsmasq.d/
COPY config/99-edns.conf /etc/dnsmasq.d/99-edns.conf

RUN mkdir -p /etc/services.d/unbound
COPY config/unbound-run /etc/services.d/unbound/run

COPY config/unbound-package-helper /usr/lib/unbound/package-helper
RUN chmod 755 /usr/lib/unbound/package-helper

RUN mkdir -p /var/lib/unbound/
RUN curl https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints
RUN chown -R unbound:unbound /var/lib/unbound/root.hints

LABEL org.opencontainers.image.authors="Vijayakumar Ravi" \
      org.opencontainers.image.title="vijaysrv/pihole-unbound" \
      org.opencontainers.image.description="Run Pi-Hole + Unbound on Docker" \
      org.opencontainers.image.url="https://github.com/VijayakumarRavi/docker-pihole-unbound" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/VijayakumarRavi/docker-pihole-unbound" \
      org.opencontainers.image.original_source="https://github.com/unclamped/docker-pihole-unbound"

ENTRYPOINT ./s6-init

