# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.20

# set version label
ARG BUILD_DATE
ARG VERSION
ARG OSCAM_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="saarg"

ENV MAKEFLAGS="-j4"

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    build-base \
    libdvbcsa-dev \
    libusb-dev \
    linux-headers \
    openssl-dev \
    pcsc-lite-dev && \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    ccid \
    libdvbcsa \
    libusb \
    openssl \
    pcsc-lite \
    pcsc-lite-libs && \
  echo "**** compile oscam ****" && \
  if [ -z ${OSCAM_VERSION+x} ]; then \
    OSCAM_VERSION=$(curl -s https://git.streamboard.tv/api/v4/projects/11/repository/tags | jq -r '.[0].name'); \
  fi && \
  mkdir -p /tmp/oscam && \
  curl -o \
    /tmp/oscam.tar.gz -L \
    "https://git.streamboard.tv/common/oscam/-/archive/${OSCAM_VERSION}/oscam-${OSCAM_VERSION}.tar.gz" && \
  tar xf \
    /tmp/oscam.tar.gz -C \
    /tmp/oscam --strip-components=1 && \
  cd /tmp/oscam && \
  ./config.sh \
    --enable all \
    --disable \
    CARDREADER_DB2COM \
    CARDREADER_INTERNAL \
    CARDREADER_STINGER \
    CARDREADER_STAPI \
    CARDREADER_STAPI5 \
    IPV6SUPPORT \
    LCDSUPPORT \
    LEDSUPPORT \
    READ_SDT_CHARSETS && \
  make \
    CONF_DIR=/config \
    DEFAULT_PCSC_FLAGS="-I/usr/include/PCSC" \
    NO_PLUS_TARGET=1 \
    OSCAM_BIN=/usr/bin/oscam \
    pcsc-libusb && \
  echo "**** fix PCSC permissions ****" && \
  chown root:root \
    /usr/sbin/pcscd && \
  chmod 755 \
    /usr/sbin/pcscd && \
  echo "**** install PCSC drivers (Linuxserver S3 mirror) ****" && \
  mkdir -p \
    /tmp/omnikey && \
  curl -o \
    /tmp/omnikey.tar.gz -L \
    "https://ci-tests.linuxserver.io/artifacts/ifdokccid_linux_x86_64-v4.2.8.tar.gz" && \
  tar xzf \
    /tmp/omnikey.tar.gz -C \
    /tmp/omnikey --strip-components=2 && \
  cd /tmp/omnikey && \
  ./install && \
  echo "**** fix group for card readers and add abc to dialout group ****" && \
  groupmod -g 24 cron && \
  groupmod -g 16 dialout && \
  usermod -a -G 16 abc && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/*

# Copy local files and fix permissions for s6-init scripts
COPY root/ /
RUN find /etc/s6-overlay/s6-rc.d/ -type f \( -name run -o -name finish \) -exec chmod 755 {} +

# Ports and volumes
EXPOSE 8000

VOLUME /config
