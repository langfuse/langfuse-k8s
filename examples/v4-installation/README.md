# Langfuse v4 Installation Example

This example demonstrates a complete [Langfuse v4](https://langfuse.com/docs/v4) installation in a Kubernetes cluster.
ClickHouse runs outside of the Helm chart and is managed by the official [ClickHouse Kubernetes Operator](https://github.com/ClickHouse/clickhouse-operator), as the ClickHouse version bundled with the chart is not compatible with Langfuse v4.
All other components (PostgreSQL, Redis, MinIO) are deployed by the chart as usual.

See the [Recommended Setup](../../README.md#recommended-setup) section in the repository README for background on this architecture.

## Installation

To install Langfuse v4 using this example:

1. Install [cert-manager](https://cert-manager.io/), which the ClickHouse operator requires for its webhook certificates (skip if it is already installed in your cluster):

   ```bash
   helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
     --version v1.20.2 \
     --namespace cert-manager --create-namespace \
     --set crds.enabled=true
   ```

2. Install the ClickHouse operator (once per Kubernetes cluster):

   ```bash
   helm install clickhouse-operator oci://ghcr.io/clickhouse/clickhouse-operator-helm \
     --version 0.0.5 \
     --namespace clickhouse-operator --create-namespace
   ```

3. Create the namespace and the required secrets:

   ```bash
   kubectl create namespace langfuse

   # Edit secret.yaml and set secure values before applying
   kubectl apply --namespace langfuse -f secret.yaml

   # The ClickHouse password lives in a separate secret that is shared between
   # the operator-managed ClickHouse cluster and the Langfuse chart
   kubectl create secret generic langfuse-clickhouse-auth \
     --namespace langfuse \
     --from-literal=password="$(openssl rand -hex 32)"
   ```

4. Create the ClickHouse and ClickHouse Keeper clusters and wait until both report `Ready`:

   ```bash
   kubectl apply --namespace langfuse -f clickhouse-cluster.yaml
   kubectl wait --for=condition=Ready --timeout=600s \
     keepercluster/langfuse clickhousecluster/langfuse \
     --namespace langfuse
   ```

5. Install the chart into the same namespace using the values file:

   ```bash
   helm repo add langfuse https://langfuse.github.io/langfuse-k8s
   helm repo update
   helm install langfuse langfuse/langfuse --namespace langfuse -f values.yaml
   ```

## Configuration

The example contains three configuration files:

### `secret.yaml`

Contains the application secrets for the Langfuse installation. **Must be applied before installing the Helm chart**. Make sure to replace all placeholder values with secure values before applying.

The ClickHouse password is intentionally not part of this secret: it is stored in the separate `langfuse-clickhouse-auth` secret created in step 3, because it is shared between the operator-managed ClickHouse cluster and the Langfuse chart.

### `clickhouse-cluster.yaml`

Defines the `KeeperCluster` and `ClickHouseCluster` resources that the ClickHouse operator turns into a running, replicated ClickHouse cluster. The `defaultUserPassword` setting references the `langfuse-clickhouse-auth` secret, so the `default` user is created with the same password that the chart uses to connect.

Adjust `replicas`, the ClickHouse image `tag`, and the requested `storage` to your environment before applying. For TLS, pod scheduling, monitoring, and other options, see the [operator documentation](https://clickhouse.com/docs/clickhouse-operator/overview).

### `values.yaml`

The core values file. It pins the Langfuse image to a v4 release, configures the chart to read all required credentials from the pre-created secrets, and connects Langfuse to the operator-managed ClickHouse cluster instead of deploying the bundled ClickHouse sub-chart.

The operator exposes the ClickHouse cluster through a headless service named `<name>-clickhouse-headless` and configures the ClickHouse cluster name as `default`, which matches the chart's defaults, so no further ClickHouse-related changes are required.

## Ingress

This example does not expose Langfuse outside of the cluster. To enable an ingress, see the [ingress examples](../../README.md#enable-ingress) in the repository README.
