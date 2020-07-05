FROM ubuntu:18.04

ARG DOCKER_VER=19.03.11

# Install build essentail tools
RUN \
  apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git curl wget fakeroot rsync pv bsdmainutils ca-certificates openssl xz-utils make \
  && rm -rf /var/cache/debconf/* /var/lib/apt/lists/* /var/log/*

# Install QDK
RUN \
  git clone https://github.com/qnap-dev/QDK.git \
  && cd QDK \
  && ./InstallToUbuntu.sh install

# Install docker client
RUN \
  curl -sq https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_VER.tgz \
  | tar zxf - -C /usr/bin docker/docker --strip-components=1 \
  && chown root:root /usr/bin/docker

WORKDIR /work
