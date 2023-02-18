ARG PIHOLE_VERSION
FROM pihole/pihole:${PIHOLE_VERSION:-latest}

ARG SOURCE="deb http://deb.debian.org/debian testing main"
RUN echo $SOURCE > /etc/apt/sources.list

RUN apt update && apt install -y -f unbound

RUN mkdir -p /var/log/unbound
RUN chown -R unbound:unbound /var/log/unbound
COPY lighttpd-external.conf /etc/lighttpd/external.conf 
COPY unbound-pihole.conf /etc/unbound/unbound.conf.d/pi-hole.conf
COPY 99-edns.conf /etc/dnsmasq.d/99-edns.conf
RUN mkdir -p /etc/services.d/unbound
COPY unbound-run /etc/services.d/unbound/run

COPY unbound-logrotate /etc/unbound/logrotate
RUN chmod 644 /etc/unbound/logrotate

COPY pihole-unbound-cron /etc/cron.d/piholeunbound
RUN chmod 644 /etc/cron.d/piholeunbound

COPY unbound-package-helper /usr/lib/unbound/package-helper
RUN chmod 755 /usr/lib/unbound/package-helper

RUN curl https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints
RUN chown -R unbound:unbound /var/lib/unbound/root.hints

COPY pihole-cloudsync/pihole-cloudsync /usr/local/bin
RUN chmod +x /usr/local/bin/pihole-cloudsync

RUN git clone https://github.com/VijayakumarRavi/docker-pihole-unbound /etc/pihole/docker-pihole-unbound

LABEL org.opencontainers.image.authors="Vijayakumar Ravi" \
      org.opencontainers.image.title="vijaysrv/pihole-unbound" \
      org.opencontainers.image.description="Run Pi-Hole + Unbound on Docker" \
      org.opencontainers.image.url="https://github.com/VijayakumarRavi/docker-pihole-unbound" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/VijayakumarRavi/docker-pihole-unbound" \
      org.opencontainers.image.original_source="https://github.com/unclamped/docker-pihole-unbound"

ENTRYPOINT ./s6-init

