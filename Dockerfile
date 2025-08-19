# Start with alpine
FROM alpine:3.22

ENV USER= \
    PASSWORD= \
    REGION="Netherlands" \
    PORT_FORWARDING=false \
    LEGACY_IPTABLES=false \
    WEBUI_PORT=8888 \
    DNS_SERVERS=9.9.9.9,149.112.112.112 \
    UID=700 \
    GID=700

# Download Folder
VOLUME /downloads

# qBittorrent Config Folder
VOLUME /config

# Port for qBittorrent
EXPOSE 8888

ENV DEBIAN_FRONTEND=noninteractive

# Ok lets install everything
RUN apk add --no-cache -t .build-deps autoconf automake build-base cmake git libtool linux-headers perl pkgconf python3-dev re2c tar unzip icu-dev openssl-dev qt6-qtbase-dev qt6-qttools-dev zlib-dev qt6-qtsvg-dev && \
	apk add --no-cache ca-certificates libressl qt6-qtbase qt6-qtbase-private-dev qt6-qtbase-sqlite iptables iptables-legacy openvpn ack bind-tools python3 doas tzdata curl jq && \
  if [ ! -e /usr/bin/python ]; then ln -sf python3 /usr/bin/python ; fi && \
  curl -sNLk --retry 5 https://github.com/boostorg/boost/releases/download/boost-1.86.0/boost-1.86.0-b2-nodocs.tar.gz | tar xzC /tmp && \
  curl -sSL --retry 5 https://github.com/ninja-build/ninja/archive/refs/tags/v1.11.1.tar.gz | tar xzC /tmp && \
	cd /tmp/*ninja* && \
  cmake -Wno-dev -B build \
  	-D CMAKE_CXX_STANDARD=17 \
  	-D CMAKE_INSTALL_PREFIX="/usr/local" && \
  cmake --build build -j $(nproc) && \
  cmake --install build && \
  curl -sSL --retry 5 https://github.com/arvidn/libtorrent/releases/download/v2.0.11/libtorrent-rasterbar-2.0.11.tar.gz | tar xzC /tmp && \
	cd /tmp/*libtorrent* && \
  cmake -Wno-dev -G Ninja -B build \
    -D CMAKE_BUILD_TYPE="Release" \
    -D CMAKE_CXX_STANDARD=17 \
    -D BOOST_INCLUDEDIR="/tmp/boost-1.86.0/" \
    -D CMAKE_INSTALL_LIBDIR="lib" \
    -D CMAKE_INSTALL_PREFIX="/usr/local" && \
  cmake --build build -j $(nproc) && \
  cmake --install build && \
  curl -sSL --retry 5 https://api.github.com/repos/qbittorrent/qBittorrent/tarball/release-5.1.2 | tar xzC /tmp && \
	cd /tmp/*qBittorrent* && \
  cmake -Wno-dev -G Ninja -B build \
    -D CMAKE_BUILD_TYPE="release" \
    -D GUI=OFF \
    -D CMAKE_CXX_STANDARD=17 \
    -D BOOST_INCLUDEDIR="/tmp/boost-1.86.0/" \
    -D CMAKE_INSTALL_PREFIX="/usr/local" && \
  cmake --build build -j $(nproc) && \
  cmake --install build && \
  mkdir /tmp/openvpn && \
  cd /tmp/openvpn && \
  curl -sSL --retry 5 https://www.privateinternetaccess.com/openvpn/openvpn.zip -o openvpn-nextgen.zip && \
  mkdir -p /openvpn/target && \
  unzip -q openvpn-nextgen.zip -d /openvpn/nextgen && \
  rm *.zip &&  \
  apk del --purge .build-deps && \
	cd / && \
	rm -rf /tmp/* /var/tmp/* /var/cache/apk/* /var/cache/distfiles/* /usr/include/* 

COPY ./entrypoint.sh ./healthcheck.sh ./qBittorrent.conf /

# Add qBittorrent User
RUN adduser \
        -D \
        -H \
        -s /sbin/nologin \
        -u $UID \
        qbtUser && \
    echo "permit nopass :root" >> "/etc/doas.d/doas.conf"

RUN chmod 500 /entrypoint.sh

# Start point for docker
ENTRYPOINT ["/entrypoint.sh"]

# Helthcheck by polling web ui and checking vpn connection
HEALTHCHECK --interval=1m --timeout=3s --start-period=60s --retries=1 CMD /healthcheck.sh
