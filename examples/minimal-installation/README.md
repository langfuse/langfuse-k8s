# Minimal Installation Example (v2)

This example installs Langfuse with all bundled OSS sub-charts on a single `helm install`:

| Component | Bundled via |
|-----------|-------------|
| PostgreSQL | `groundhog2k/postgres` |
| ClickHouse | `ClickHouseCluster` + `KeeperCluster` CRs (managed by the cluster-wide [ClickHouse operator](https://github.com/ClickHouse/clickhouse-operator)) |
| Redis | `valkey-io/valkey` |
| Object storage | `seaweedfs/seaweedfs` (allInOne) |

The chart auto-generates credentials for every sub-component — you only need to provide the three Langfuse application secrets.

> **v2 changes**
>
> - Bitnami PostgreSQL / ClickHouse / Redis / MinIO sub-charts are replaced with the OSS stack above.
> - The chart generates `<release>-postgresql-auth`, `<release>-clickhouse-auth`, `<release>-redis-auth`, and `<release>-s3-auth` Secrets on first install. Passwords persist across upgrades via `lookup`.
> - cert-manager and the ClickHouse operator are **cluster-wide prereqs** (installed once per cluster, not per release).
> - For a near-zero-downtime migration from a v1 (Bitnami) install, see [`examples/upgrade-v1-to-v2`](../upgrade-v1-to-v2/).

## Prerequisites

The chart renders `ClickHouseCluster` / `KeeperCluster` CRs. The ClickHouse operator (not this chart) creates cert-manager `Certificate` / `Issuer` resources for its webhooks. Install these once per cluster, in order:

### 1. cert-manager

```bash
helm install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.20.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

kubectl wait --for=condition=Established \
  crd/certificates.cert-manager.io \
  crd/issuers.cert-manager.io \
  --timeout=120s
```

Skip this step if cert-manager is already running in the cluster.

### 2. ClickHouse operator

```bash
helm install clickhouse-operator oci://ghcr.io/clickhouse/clickhouse-operator-helm \
  --version 0.0.5 \
  --namespace clickhouse-operator --create-namespace

kubectl wait --for=condition=Established \
  crd/clickhouseclusters.clickhouse.com \
  crd/keeperclusters.clickhouse.com \
  --timeout=120s
```

## Installation

1. Edit `secret.yaml` and replace the placeholder values with secure secrets:

   ```bash
   openssl rand -hex 32     # salt
   openssl rand -hex 32     # encryption-key
   openssl rand -base64 32  # nextauth-secret
   ```

2. Apply the Secret:

   ```bash
   kubectl create namespace langfuse
   kubectl apply -n langfuse -f secret.yaml
   ```

3. Install the chart:

   ```bash
   helm install langfuse oci://ghcr.io/langfuse/langfuse-k8s/langfuse \
     --version 2.0.0 \
     --namespace langfuse \
     -f values.yaml
   ```

   Or with ingress enabled:

   ```bash
   helm install langfuse oci://ghcr.io/langfuse/langfuse-k8s/langfuse \
     --version 2.0.0 \
     --namespace langfuse \
     -f values.yaml -f with-ingress.yaml
   ```

4. Wait for the workloads to come up. Typical readiness order:

   - `KeeperCluster` / `ClickHouseCluster` pods (reconciled by the operator)
   - PostgreSQL StatefulSet
   - Valkey
   - SeaweedFS allInOne
   - `langfuse-web` and `langfuse-worker` Deployments

   ```bash
   kubectl get pods -n langfuse -w
   ```

5. Port-forward and sign in:

   ```bash
   kubectl port-forward -n langfuse svc/langfuse-web 3000:3000
   open http://localhost:3000
   ```

## Local testing against this repo

From `./charts/langfuse`:

```bash
helm dependency update .
helm install langfuse . \
  --namespace langfuse \
  -f ../../examples/minimal-installation/values.yaml
```

For offline `helm template` / unit tests without a live cluster, set `clickhouse.crdCheck=false`
(or pass `--api-versions clickhouse.com/v1alpha1/ClickHouseCluster`).

## External components

To bring your own Postgres, Redis, object storage, or ClickHouse instead of the bundled ones,
see [`examples/external-components`](../external-components/) — each component can be swapped
independently via `*.deploy: false`.

## Files

- [`secret.yaml`](./secret.yaml) — Langfuse application secrets (`salt`, `encryption-key`, `nextauth-secret`).
- [`values.yaml`](./values.yaml) — minimal values (all four components deployed).
- [`with-ingress.yaml`](./with-ingress.yaml) — optional ingress overlay.
- [`with-sso-secret-refs.yaml`](./with-sso-secret-refs.yaml) — optional SSO secret references.
