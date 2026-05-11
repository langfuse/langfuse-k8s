# Minimal Installation Example (v2)

This example installs Langfuse with all bundled sub-charts (PostgreSQL, ClickHouse, Valkey, SeaweedFS) on a single `helm install`.
The chart auto-generates credentials for every sub-component — you only need to provide the three Langfuse application secrets.

> **v2 changes**
>
> - Bitnami PostgreSQL / ClickHouse / Redis / MinIO sub-charts have been replaced with `groundhog2k/postgres`, the upstream `ClickHouse/clickhouse-operator`, `valkey-io/valkey`, and `seaweedfs/seaweedfs`.
> - The chart now generates `<release>-postgresql-auth`, `<release>-clickhouse-auth`, `<release>-redis-auth`, and `<release>-s3-auth` Secrets on first install. Passwords persist across upgrades via `lookup`.
> - There is no automatic data migration from v1. To upgrade, dump v1 data, install v2 in a new namespace, and restore.

## Installation

1. Edit `secret.yaml` and replace the placeholder values with secure secrets:

   ```bash
   # SALT — random 32-byte hex
   openssl rand -hex 32
   # ENCRYPTION_KEY — random 32-byte hex
   openssl rand -hex 32
   # NEXTAUTH_SECRET — random 32-byte base64
   openssl rand -base64 32
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

   - cert-manager + clickhouse-operator pods
   - `KeeperCluster` and `ClickHouseCluster` pods
   - PostgreSQL StatefulSet
   - Valkey primary
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

## Files

### `secret.yaml`

Contains the three Langfuse application secrets (`salt`, `encryption-key`, `nextauth-secret`). **Apply before installing the chart.** Replace placeholders with secure random values.

### `values.yaml`

Wires the Langfuse application to read its three secrets from `secret.yaml`. Sub-component credentials (Postgres/ClickHouse/Valkey/SeaweedFS) are not configured here — the chart auto-generates them on first install. To pin specific passwords, set `<component>.auth.password` or `<component>.auth.existingSecret`.

### `with-ingress.yaml` (optional)

Adds an ingress on top of the base values. Edit the host before applying.
