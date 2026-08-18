# Minimal Installation Example

This example demonstrates a minimal installation of Langfuse in a Kubernetes cluster. It includes a basic configuration with ingress support.

## Prerequisites

The chart renders `ClickHouseCluster` / `KeeperCluster` CRs. Install these once per cluster (skip if already present), in order:

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

To install Langfuse using this example:

1. Create the namespace and required secret:
```bash
kubectl create namespace langfuse

# Edit secret.yaml and set secure values before applying
kubectl apply -f secret.yaml -n langfuse
```

2. Install the chart using the base values file and optional ingress configuration:
```bash
# Basic installation
helm install langfuse oci://ghcr.io/langfuse/langfuse-k8s/charts/langfuse \
  --version 2.0.0 \
  --namespace langfuse \
  -f values.yaml

# Or with ingress enabled
helm install langfuse oci://ghcr.io/langfuse/langfuse-k8s/charts/langfuse \
  --version 2.0.0 \
  --namespace langfuse \
  -f values.yaml -f with-ingress.yaml
```

Alternatively, via the Helm repository:

```bash
helm repo add langfuse https://langfuse.github.io/langfuse-k8s
helm repo update
helm install langfuse langfuse/langfuse -n langfuse -f values.yaml
```

## Configuration

The example contains three configuration files:

### `secret.yaml`
Contains all required secrets for the Langfuse installation. **Must be applied before installing the Helm chart**. Make sure to replace all placeholder values with secure values before applying.

### `values.yaml`
The core values file that configures Langfuse to use the pre-created secret for all required credentials:
```yaml
langfuse:
  salt:
    secretKeyRef:
      name: langfuse
      key: salt

  encryptionKey:
    secretKeyRef:
      name: langfuse
      key: encryption-key

  nextauth:
    secret:
      secretKeyRef:
        name: langfuse
        key: nextauth-secret

postgresql:
  auth:
    existingSecret: langfuse
    secretKeys:
      userPasswordKey: postgresql-password

clickhouse:
  auth:
    existingSecret: langfuse
    existingSecretKey: clickhouse-password

redis:
  auth:
    existingSecret: langfuse
    existingSecretPasswordKey: redis-password

s3:
  auth:
    existingSecret: langfuse
    rootUserSecretKey: s3-user
    rootPasswordSecretKey: s3-password
```

### `with-ingress.yaml` (Optional)
Additional configuration to enable ingress:
```yaml
langfuse:
  nextauth:
    url: http://langfuse.example.com
  ingress:
    enabled: true
    className: nginx
    hosts:
    - host: langfuse.example.com
      paths:
      - path: /
        pathType: Prefix
```

Make sure to adjust the hostname in the values file to match your environment before installing.
