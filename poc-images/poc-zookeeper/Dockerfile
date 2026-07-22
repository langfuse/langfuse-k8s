# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
# Modified by ClickHouse, Inc. from the original Bitnami Dockerfile at
# https://github.com/bitnami/containers/tree/4a21c7547a1ff857da133d3be37bcbc2886053c4 (Apache-2.0):
# Rebased onto debian:12-slim; ZooKeeper, JRE and wait-for-port replaced with official Apache, Eclipse Temurin and clean-room Apache-2.0 artifacts.
#
# Rebuild of bitnami/zookeeper:3.9.3-debian-12 with ZERO Bitnami-sourced artifacts.
# - Base: docker.io/debian:12-slim (instead of bitnami/minideb:bookworm)
# - ZooKeeper: official Apache binary release (archive.apache.org), sha512-verified
# - JRE: Eclipse Temurin 17 (Adoptium GitHub releases), sha256-verified
# - wait-for-port: Apache-2.0 bash drop-in replacement (same CLI as bitnami/wait-for-port)
# - prebuildfs/rootfs: pristine Apache-2.0 scripts from bitnami/containers
#   commit 4a21c7547a1ff857da133d3be37bcbc2886053c4 (last Apache-2.0 licensed commit)
FROM docker.io/debian:12-slim

ARG TARGETARCH
ARG ZK_VERSION="3.9.3"
ARG ZK_SHA512="d44d870c1691662efbf1a8baf1859c901b820dc5ff163b36e81beb27b6fbf3cd31b5f1f075697edaaf6d3e7a4cb0cc92f924dcff64b294ef13d535589bdaf143"
ARG TEMURIN_RELEASE="jdk-17.0.19+10"
ARG TEMURIN_SHA256_ARM64="aae834297a87736869745be7c1fca3207ea9167c5824f41c88b0ebb2e3ccb9b1"
ARG TEMURIN_SHA256_AMD64="adb5a2364baa51de1ef91bb9911f5a61d24b045fe1d6647cb8050272a3a8ee75"

LABEL org.opencontainers.image.base.name="docker.io/debian:12-slim" \
      org.opencontainers.image.description="Apache ZooKeeper packaged from official Apache artifacts, Bitnami-image compatible" \
      org.opencontainers.image.documentation="https://github.com/bitnami/containers/tree/4a21c7547a1ff857da133d3be37bcbc2886053c4/bitnami/zookeeper/README.md" \
      org.opencontainers.image.title="zookeeper" \
      org.opencontainers.image.version="${ZK_VERSION}" \
      upstream.bitnami.commit="4a21c7547a1ff857da133d3be37bcbc2886053c4"
# TODO: replace with the real repository that will host these Dockerfiles
LABEL org.opencontainers.image.source="https://github.com/CHANGEME/your-images-repo"

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux" \
    PATH="/opt/bitnami/common/bin:/opt/bitnami/java/bin:/opt/bitnami/zookeeper/bin:$PATH"

COPY prebuildfs /
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]
# Same package set as the original Dockerfile
RUN install_packages ca-certificates curl netcat-openbsd procps xmlstarlet zlib1g

# ZooKeeper: official Apache binary release (sha512-verified).
# The Bitnami tarball is the pristine Apache layout (bin/, conf/, lib/, docs/) at /opt/bitnami/zookeeper.
RUN mkdir -p /opt/bitnami/zookeeper && \
    cd /tmp && \
    curl -SsLf "https://archive.apache.org/dist/zookeeper/zookeeper-${ZK_VERSION}/apache-zookeeper-${ZK_VERSION}-bin.tar.gz" -o zookeeper.tar.gz && \
    echo "${ZK_SHA512}  zookeeper.tar.gz" | sha512sum -c - && \
    tar -zxf zookeeper.tar.gz -C /opt/bitnami/zookeeper --strip-components=1 --no-same-owner && \
    rm -f zookeeper.tar.gz && \
    # Apache-2.0 full text at /opt/bitnami/licenses, from the ZooKeeper release
    # LICENSE.txt (the same license also covers the vendored Bitnami scripts)
    install -D -m 644 /opt/bitnami/zookeeper/LICENSE.txt /opt/bitnami/licenses/Apache-2.0.txt

# JRE: Eclipse Temurin 17 at /opt/bitnami/java (sha256-verified).
# ZooKeeper 3.9 supports Java 11/17/21; Bitnami shipped JRE 11.
RUN case "${OS_ARCH}" in \
      arm64) TEMURIN_ARCH="aarch64"; TEMURIN_SHA256="${TEMURIN_SHA256_ARM64}" ;; \
      amd64) TEMURIN_ARCH="x64"; TEMURIN_SHA256="${TEMURIN_SHA256_AMD64}" ;; \
      *) echo "Unsupported arch: ${OS_ARCH}" >&2; exit 1 ;; \
    esac && \
    TEMURIN_VER="${TEMURIN_RELEASE#jdk-}" && \
    mkdir -p /opt/bitnami/java && cd /tmp && \
    curl -SsLf "https://github.com/adoptium/temurin17-binaries/releases/download/${TEMURIN_RELEASE/+/%2B}/OpenJDK17U-jre_${TEMURIN_ARCH}_linux_hotspot_${TEMURIN_VER/+/_}.tar.gz" -o jre.tar.gz && \
    echo "${TEMURIN_SHA256}  jre.tar.gz" | sha256sum -c - && \
    tar -zxf jre.tar.gz -C /opt/bitnami/java --strip-components=1 --no-same-owner && \
    rm -f jre.tar.gz
ENV JAVA_HOME="/opt/bitnami/java"

# wait-for-port: Apache-2.0 bash drop-in replacement (only used by
# zookeeper_configure_acl when ZOO_ENABLE_AUTH=yes on first boot)
COPY wait-for-port /opt/bitnami/common/bin/wait-for-port
RUN chmod 755 /opt/bitnami/common/bin/wait-for-port

RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives
RUN chmod g+rwX /opt/bitnami
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true
RUN ln -s /opt/bitnami/scripts/zookeeper/entrypoint.sh /entrypoint.sh
RUN ln -s /opt/bitnami/scripts/zookeeper/run.sh /run.sh

COPY rootfs /
RUN /opt/bitnami/scripts/zookeeper/postunpack.sh
ENV APP_VERSION="3.9.3" \
    BITNAMI_APP_NAME="zookeeper" \
    DISABLE_WELCOME_MESSAGE="true"

EXPOSE 2181 2888 3888 8080

USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/zookeeper/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/zookeeper/run.sh" ]
