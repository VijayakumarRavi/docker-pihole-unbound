ARG PIHOLE_VERSION
ARG GIT_KEY

FROM debian:bookworm AS openssl
LABEL maintainer="Vijayakumar Ravi"

ENV VERSION_OPENSSL=openssl-3.3.1 \
    SHA256_OPENSSL=777cd596284c883375a2a7a11bf5d2786fc5413255efab20c50d6ffe6d020b7e \
    SOURCE_OPENSSL=https://www.openssl.org/source/ \
    # OpenSSL OMC
    OPGP_OPENSSL_1=EFC0A467D613CB83C7ED6D30D894E2CE8B3D79F5 \
    # Richard Levitte
    OPGP_OPENSSL_2=7953AC1FBC3DC8B3B292393ED5E9E43F7DF9EE8C \
    # Matt Caswell
    OPGP_OPENSSL_3=8657ABB260F056B1E5190839D9C4D26D0E604491 \
    # Paul Dale
    OPGP_OPENSSL_4=B7C1C14360F353A36862E4D5231C84CDDCC69C45 \
    # Tomas Mraz
    OPGP_OPENSSL_5=A21FAB74B0088AA361152586B8EF1A6BA9DA2D5C

WORKDIR /tmp/src

RUN set -e -x && \
    build_deps="build-essential ca-certificates curl dirmngr gnupg libidn2-0-dev libssl-dev" && \
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
      $build_deps && \
    curl -L $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz -o openssl.tar.gz && \
    echo "${SHA256_OPENSSL} ./openssl.tar.gz" | sha256sum -c - && \
    curl -L $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz.asc -o openssl.tar.gz.asc && \
    GNUPGHOME="$(mktemp -d)" && \
    export GNUPGHOME && \
    gpg --no-tty --keyserver keyserver.ubuntu.com --recv-keys "$OPGP_OPENSSL_1" "$OPGP_OPENSSL_2" "$OPGP_OPENSSL_3" "$OPGP_OPENSSL_4" "$OPGP_OPENSSL_5" && \
    gpg --batch --verify openssl.tar.gz.asc openssl.tar.gz && \
    tar xzf openssl.tar.gz && \
    cd $VERSION_OPENSSL && \
    ./config \
      --prefix=/opt/openssl \
      --openssldir=/opt/openssl \
      no-weak-ssl-ciphers \
      no-ssl3 \
      no-shared \
      enable-ec_nistp_64_gcc_128 \
      -DOPENSSL_NO_HEARTBEATS \
      -fstack-protector-strong && \
    make depend && \
    nproc | xargs -I % make -j% && \
    make install_sw && \
    apt-get purge -y --auto-remove \
      $build_deps && \
    rm -rf \
        /tmp/* \
        /var/tmp/* \
        /var/lib/apt/lists/*

FROM debian:bookworm AS unbound
LABEL maintainer="Vijayakumar Ravi"

ENV NAME=unbound \
    UNBOUND_VERSION=1.20.0 \
    UNBOUND_SHA256=56b4ceed33639522000fd96775576ddf8782bb3617610715d7f1e777c5ec1dbf \
    UNBOUND_DOWNLOAD_URL=https://nlnetlabs.nl/downloads/unbound/unbound-1.20.0.tar.gz

WORKDIR /tmp/src

COPY --from=openssl /opt/openssl /opt/openssl

RUN build_deps="curl gcc libc-dev libevent-dev libexpat1-dev libnghttp2-dev make" && \
    set -x && \
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
      $build_deps \
      bsdmainutils \
      ca-certificates \
      ldnsutils \
      libevent-2.1-7 \
      libexpat1 \
      libprotobuf-c-dev \
      protobuf-c-compiler && \
    curl -sSL $UNBOUND_DOWNLOAD_URL -o unbound.tar.gz && \
    echo "${UNBOUND_SHA256} *unbound.tar.gz" | sha256sum -c - && \
    tar xzf unbound.tar.gz && \
    rm -f unbound.tar.gz && \
    cd unbound-1.20.0 && \
    groupadd _unbound && \
    useradd -g _unbound -s /dev/null -d /etc _unbound && \
    ./configure \
        --disable-dependency-tracking \
        --prefix=/opt/unbound \
        --with-pthreads \
        --with-username=_unbound \
        --with-ssl=/opt/openssl \
        --with-libevent \
        --with-libnghttp2 \
        --enable-dnstap \
        --enable-tfo-server \
        --enable-tfo-client \
        --enable-event-api \
        --enable-subnet && \
    make install && \
    mv /opt/unbound/etc/unbound/unbound.conf /opt/unbound/etc/unbound/unbound.conf.example && \
    apt-get purge -y --auto-remove \
      $build_deps && \
    rm -rf \
        /opt/unbound/share/man \
        /tmp/* \
        /var/tmp/* \
        /var/lib/apt/lists/*

FROM pihole/pihole:${PIHOLE_VERSION:-latest}
LABEL maintainer="Vijayakumar Ravi"

# ARG SOURCE="deb http://deb.debian.org/debian testing main"
# RUN echo $SOURCE > /etc/apt/sources.list

# RUN apt update && apt install -y -f unbound

COPY --from=unbound /opt/unbound /opt/unbound


RUN set -x && \
    DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
      bsdmainutils \
      ca-certificates \
      ldnsutils \
      libevent-2.1-7 \
      libnghttp2-14 \
      libexpat1 \
      libprotobuf-c1 && \
    groupadd unbound && \
    useradd -g unbound -s /dev/null -d /opt/unbound unbound && \
    apt-get purge -y --auto-remove \
      $build_deps && \
    rm -rf \
        /opt/unbound/share/man \
        /tmp/* \
        /var/tmp/* \
        /var/lib/apt/lists/*

RUN mkdir -p /var/log/unbound
RUN chown -R unbound:unbound /var/log/unbound
COPY lighttpd-external.conf /etc/lighttpd/external.conf 

RUN mkdir -p /etc/unbound/
COPY unbound-pihole.conf /etc/unbound/unbound.conf

RUN mkdir -p /etc/dnsmasq.d/
COPY 99-edns.conf /etc/dnsmasq.d/99-edns.conf

RUN mkdir -p /etc/services.d/unbound
COPY unbound-run /etc/services.d/unbound/run

COPY unbound-logrotate /etc/unbound/logrotate
RUN chmod 644 /etc/unbound/logrotate

COPY pihole-unbound-cron /etc/cron.d/piholeunbound
RUN chmod 644 /etc/cron.d/piholeunbound

COPY unbound-package-helper /usr/lib/unbound/package-helper
RUN chmod 755 /usr/lib/unbound/package-helper

RUN mkdir -p /var/lib/unbound/
RUN curl https://www.internic.net/domain/named.root -o /var/lib/unbound/root.hints
RUN chown -R unbound:unbound /var/lib/unbound/root.hints

COPY pihole-cloudsync/pihole-cloudsync /usr/local/bin
RUN chmod +x /usr/local/bin/pihole-cloudsync

ENV PATH=/opt/unbound/sbin:"$PATH"

#RUN git clone https://${GIT_KEY}@github.com/VijayakumarRavi/docker-pihole-unbound /etc/pihole/docker-pihole-unbound

LABEL org.opencontainers.image.authors="Vijayakumar Ravi" \
      org.opencontainers.image.title="vijaysrv/pihole-unbound" \
      org.opencontainers.image.description="Run Pi-Hole + Unbound on Docker" \
      org.opencontainers.image.url="https://github.com/VijayakumarRavi/docker-pihole-unbound" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/VijayakumarRavi/docker-pihole-unbound" \
      org.opencontainers.image.original_source="https://github.com/unclamped/docker-pihole-unbound"

ENTRYPOINT ./s6-init

