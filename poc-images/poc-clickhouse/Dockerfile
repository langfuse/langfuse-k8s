# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0
# Modified by ClickHouse, Inc. from the original Bitnami Dockerfile at
# https://github.com/bitnami/containers/tree/4a21c7547a1ff857da133d3be37bcbc2886053c4 (Apache-2.0):
# Rebased onto debian:12-slim and replaced the Bitnami stacksmith tarball with official packages.clickhouse.com artifacts (ClickHouse 25.8 LTS).
#
# PoC rebuild of the Bitnami ClickHouse image from the last Apache-2.0 state of
# github.com/bitnami/containers (commit 4a21c7547a1ff857da133d3be37bcbc2886053c4,
# bitnami/clickhouse/25/debian-12), with:
#   - a NEWER official ClickHouse release (25.8 LTS) assembled from
#     packages.clickhouse.com artifacts instead of the Bitnami stacksmith tarball
#   - debian:12-slim as the base instead of bitnami/minideb:bookworm
#     (the prebuildfs supplies /usr/sbin/install_packages, which is the only
#     minideb feature the original Dockerfile relies on)
# prebuildfs/ and rootfs/ are byte-for-byte pristine copies from that commit
# (Apache-2.0, Copyright Broadcom, Inc. headers retained).

ARG BASE_IMAGE=debian:12-slim

########################################################################
# Stage 1: assemble /opt/bitnami/clickhouse from OFFICIAL ClickHouse
# artifacts, replicating the layout of the Bitnami stacksmith tarball
# (verified byte-identical to official packages for 25.6.4 provenance).
########################################################################
FROM ${BASE_IMAGE} AS assembler

ARG TARGETARCH
ARG CLICKHOUSE_VERSION="26.2.19.43"
ARG CLICKHOUSE_TGZ_CHANNEL="stable"

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

RUN ARCH="${TARGETARCH:-amd64}" ; \
    BASE_URL="https://packages.clickhouse.com/tgz/${CLICKHOUSE_TGZ_CHANNEL}" ; \
    mkdir -p /build ; cd /build ; \
    for pkg in clickhouse-common-static clickhouse-server clickhouse-client; do \
      TGZ="${pkg}-${CLICKHOUSE_VERSION}-${ARCH}.tgz" ; \
      curl -SsLf "${BASE_URL}/${TGZ}" -O ; \
      curl -SsLf "${BASE_URL}/${TGZ}.sha512" -O ; \
      sha512sum -c "${TGZ}.sha512" ; \
      tar -xzf "${TGZ}" ; \
      rm -f "${TGZ}" "${TGZ}.sha512" ; \
    done ; \
    CH="/opt/bitnami/clickhouse" ; \
    mkdir -p "${CH}/bin" "${CH}/etc" "${CH}/licenses" ; \
    # The single multi-call binary (identical to what Bitnami shipped)
    cp "/build/clickhouse-common-static-${CLICKHOUSE_VERSION}/usr/bin/clickhouse" "${CH}/bin/clickhouse" ; \
    chmod 755 "${CH}/bin/clickhouse" ; \
    # chdig: real binary in <=25.6 client packages, a symlink to clickhouse afterwards
    if [[ -f "/build/clickhouse-client-${CLICKHOUSE_VERSION}/usr/bin/chdig" && ! -L "/build/clickhouse-client-${CLICKHOUSE_VERSION}/usr/bin/chdig" ]]; then \
      cp "/build/clickhouse-client-${CLICKHOUSE_VERSION}/usr/bin/chdig" "${CH}/bin/chdig" ; chmod 755 "${CH}/bin/chdig" ; \
    else \
      ln -s clickhouse "${CH}/bin/chdig" ; \
    fi ; \
    # Multi-call symlinks — the same set the Bitnami stacksmith tarball shipped
    cd "${CH}/bin" ; \
    for tool in ch chc chl clickhouse-benchmark clickhouse-chdig clickhouse-client \
                clickhouse-compressor clickhouse-extract-from-config clickhouse-format \
                clickhouse-keeper clickhouse-keeper-client clickhouse-keeper-converter \
                clickhouse-local clickhouse-obfuscator clickhouse-server; do \
      [[ -e "${tool}" || -L "${tool}" ]] || ln -s clickhouse "${tool}" ; \
    done ; \
    # Stock upstream configs (Bitnami shipped these byte-identical; all Bitnami
    # customization happens later in postunpack.sh via xmlstarlet)
    cp "/build/clickhouse-server-${CLICKHOUSE_VERSION}/etc/clickhouse-server/config.xml" "${CH}/etc/config.xml" ; \
    cp "/build/clickhouse-server-${CLICKHOUSE_VERSION}/etc/clickhouse-server/users.xml" "${CH}/etc/users.xml" ; \
    if [[ -f "/build/clickhouse-server-${CLICKHOUSE_VERSION}/etc/clickhouse-keeper/keeper_config.xml" ]]; then \
      cp "/build/clickhouse-server-${CLICKHOUSE_VERSION}/etc/clickhouse-keeper/keeper_config.xml" "${CH}/etc/keeper_config.xml" ; \
    fi ; \
    chmod 644 "${CH}"/etc/*.xml ; \
    # Real Apache-2.0 LICENSE shipped in the official tgz: one copy for the
    # ClickHouse component, one at /opt/bitnami/licenses (the same license also
    # covers the vendored Bitnami scripts in prebuildfs/ and rootfs/)
    install -m 644 "/build/clickhouse-common-static-${CLICKHOUSE_VERSION}/usr/share/doc/clickhouse-common-static/LICENSE" "${CH}/licenses/clickhouse-${CLICKHOUSE_VERSION}.LICENSE" ; \
    install -D -m 644 "/build/clickhouse-common-static-${CLICKHOUSE_VERSION}/usr/share/doc/clickhouse-common-static/LICENSE" /opt/bitnami/licenses/Apache-2.0.txt ; \
    rm -rf /build

########################################################################
# Stage 2: the actual image — mirrors the pinned Bitnami Dockerfile
# step by step, with the stacksmith download replaced by COPY --from.
########################################################################
FROM ${BASE_IMAGE}

ARG TARGETARCH
ARG CLICKHOUSE_VERSION="26.2.19.43"
ARG OS_FLAVOUR="debian-12"

LABEL org.opencontainers.image.base.name="docker.io/debian:12-slim" \
      org.opencontainers.image.description="ClickHouse packaged following the Bitnami container conventions (Apache-2.0 rebuild)" \
      org.opencontainers.image.documentation="https://github.com/bitnami/containers/tree/4a21c7547a1ff857da133d3be37bcbc2886053c4/bitnami/clickhouse/README.md" \
      org.opencontainers.image.title="clickhouse" \
      org.opencontainers.image.version="${CLICKHOUSE_VERSION}" \
      upstream.bitnami.commit="4a21c7547a1ff857da133d3be37bcbc2886053c4"
# TODO: replace with the real repository that will host these Dockerfiles
LABEL org.opencontainers.image.source="https://github.com/CHANGEME/your-images-repo"

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="${OS_FLAVOUR}" \
    OS_NAME="linux"

COPY prebuildfs /
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]
# Install required system packages and dependencies
# (curl omitted: the original image downloads its component tarball with curl and
#  then uninstalls it; we COPY the component from the assembler stage instead)
RUN install_packages ca-certificates procps xmlstarlet
# Component: official ClickHouse artifacts laid out exactly like the extracted
# Bitnami stacksmith tarball
COPY --from=assembler /opt/bitnami/clickhouse /opt/bitnami/clickhouse
# Apache-2.0 full text (covers the ClickHouse binaries and the vendored Bitnami scripts)
COPY --from=assembler /opt/bitnami/licenses /opt/bitnami/licenses
# Refresh component metadata (informational only; nothing reads it at runtime)
RUN echo "{\"clickhouse\":{\"arch\":\"${OS_ARCH}\",\"distro\":\"${OS_FLAVOUR}\",\"type\":\"NAMI\",\"version\":\"${CLICKHOUSE_VERSION}\"}}" > /opt/bitnami/.bitnami_components.json
RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives
RUN chmod g+rwX /opt/bitnami
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

COPY rootfs /
RUN /opt/bitnami/scripts/clickhouse/postunpack.sh
ENV APP_VERSION="${CLICKHOUSE_VERSION}" \
    BITNAMI_APP_NAME="clickhouse" \
    DISABLE_WELCOME_MESSAGE="true" \
    PATH="/opt/bitnami/clickhouse/bin:/opt/bitnami/common/bin:$PATH" \
    clickhouseCTL_API="3"

EXPOSE 8123 9000 9004 9005 9009

USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/clickhouse/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/clickhouse/run.sh", "--", "--listen_host=0.0.0.0" ]
