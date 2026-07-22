# Self-built Bitnami-compatible images

Drop-in replacements for `bitnami/clickhouse` and `bitnami/zookeeper` as consumed by the
Bitnami ClickHouse Helm chart 8.0.5 (the `clickhouse` dependency of this repository's
langfuse chart). Broadcom stopped publishing public Bitnami images in August 2025
([bitnami/containers#83267](https://github.com/bitnami/containers/issues/83267)); the
frozen `bitnamilegacy` mirror receives no updates and accumulates unfixed CVEs.

These images are rebuilt from the last Apache-2.0-licensed state of
[bitnami/containers](https://github.com/bitnami/containers/tree/4a21c7547a1ff857da133d3be37bcbc2886053c4)
(commit `4a21c7547a1ff857da133d3be37bcbc2886053c4`) with newer upstream releases.
Nothing is pulled from Bitnami/Broadcom infrastructure at build or run time:

| Input | Source |
|---|---|
| Base image | `debian:12-slim` (Docker official) |
| ClickHouse | `packages.clickhouse.com` official tgz, sha512-verified |
| ZooKeeper | `archive.apache.org` official binary release, sha512-verified |
| JRE | Eclipse Temurin 17 (Adoptium GitHub releases), sha256-verified |
| `wait-for-port` | bash reimplementation in `poc-zookeeper/wait-for-port` |
| Boot scripts | vendored byte-identical from the pinned commit (Apache-2.0) |

## Layout

Each image directory mirrors the upstream Bitnami build layout:

- `Dockerfile` — rewritten: assembles the `/opt/bitnami/<app>` tree from official
  artifacts instead of Bitnami "stacksmith" tarballs (which repackaged the identical
  official binaries byte-for-byte).
- `prebuildfs/`, `rootfs/` — the Bitnami runtime scripts, byte-identical to the pinned
  commit, reduced to the subset that is actually sourced at build or run time.
  Do not edit these files; chart compatibility depends on them.

## Building locally

```bash
docker build -t registry.example.com/langfuse/clickhouse:26.2.19.43 poc-clickhouse
```

```bash
docker build -t registry.example.com/langfuse/zookeeper:3.9.3 poc-zookeeper
```

Multi-arch (both Dockerfiles plumb `TARGETARCH`; amd64 artifact URLs are published,
but only linux/arm64 builds have been boot-tested so far):

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t registry.example.com/langfuse/clickhouse:26.2.19.43 --push poc-clickhouse
```

### Bumping versions

ClickHouse (`poc-clickhouse/Dockerfile`): set `CLICKHOUSE_VERSION` (full four-part
upstream version) and `CLICKHOUSE_TGZ_CHANNEL` (`lts` or `stable`). Checksums are
fetched and verified from the package server automatically.

ZooKeeper (`poc-zookeeper/Dockerfile`): set `ZK_VERSION` + `ZK_SHA512` (from the
`.sha512` file next to the tarball on `archive.apache.org`/`downloads.apache.org`) and,
when bumping the JRE, `TEMURIN_RELEASE` + `TEMURIN_SHA256_ARM64`/`TEMURIN_SHA256_AMD64`
(from the Adoptium release page checksums).

```bash
docker build --build-arg CLICKHOUSE_VERSION=26.2.19.43 --build-arg CLICKHOUSE_TGZ_CHANNEL=stable -t registry.example.com/langfuse/clickhouse:26.2.19.43 poc-clickhouse
```

## Quick verification

ClickHouse:

```bash
docker run -d --name ch-check -p 8123:8123 -e ALLOW_EMPTY_PASSWORD=yes registry.example.com/langfuse/clickhouse:26.2.19.43 && sleep 10 && curl -s http://localhost:8123/ping && docker exec ch-check clickhouse-client -q 'SELECT 1' && docker rm -f ch-check
```

ZooKeeper (the default four-letter-word whitelist is `srvr,mntr`):

```bash
docker run -d --name zk-check -e ALLOW_ANONYMOUS_LOGIN=yes -e ZOO_SERVER_ID=1 registry.example.com/langfuse/zookeeper:3.9.3 && sleep 12 && docker exec zk-check bash -c 'echo srvr | nc -w 3 localhost 2181' && docker rm -f zk-check
```

## Using with the langfuse Helm chart

See [examples/self-built-images](../examples/self-built-images) for a complete
installation example. In short: the chart only needs the image coordinates overridden
(`clickhouse.image.*` and `clickhouse.zookeeper.image.*` — including the **tag**, since
the chart otherwise keeps its stale default tags), and
`global.security.allowInsecureImages: true`, which is already this chart's default.

## Licensing and distribution notes

The vendored `prebuildfs/` and `rootfs/` scripts are Apache-2.0, Copyright Broadcom,
Inc.; their license headers must be retained (Apache-2.0 §4(c)), and the Dockerfiles
carry modification notices for the rewritten parts. The built images ship the full
license text at `/opt/bitnami/licenses/Apache-2.0.txt`. "Bitnami" is a Broadcom
trademark: keeping the functional `/opt/bitnami` paths for chart compatibility is fine,
but do not publish these images under a Bitnami-branded name, and set the
`org.opencontainers.image.source` label in both Dockerfiles (currently a `CHANGEME`
placeholder) to the repository you publish from.
