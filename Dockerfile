# docker build -t my:dart .
# docker run --rm -it -v"$(pwd):/root/work" my:dart /bin/bash

FROM ubuntu:18.04

RUN apt-get update \
  && apt-get -y install --no-install-recommends \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    gnupg \
    wget \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN sh -c 'wget --no-check-certificate -O- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -' \
  && sh -c 'wget --no-check-certificate -O- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list' \
  && apt-get update \
  && apt-get -y install --no-install-recommends \
    dart=2.13.1-1 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /root/work
