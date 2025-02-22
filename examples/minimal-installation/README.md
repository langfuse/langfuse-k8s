# Minimal Installation Example

This example demonstrates a minimal installation of Langfuse in a Kubernetes cluster. It includes a basic configuration with ingress support.

## Installation

To install Langfuse using this example:

1. First, create the required secret:
```bash
# Edit secret.yaml and set secure values before applying
kubectl apply -f secret.yaml
```

2. Add the Helm repository:
```bash
helm repo add langfuse https://cbeneke.github.io/langfuse-k8s
helm repo update
```

3. Install the chart using the base values file and optional ingress configuration:
```bash
# Basic installation
helm install langfuse langfuse/langfuse -f values.yaml

# Or with ingress enabled
helm install langfuse langfuse/langfuse -f values.yaml -f with-ingress.yaml
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
  resourcesPreset: medium

redis:
  auth:
    existingSecret: langfuse
    existingSecretPasswordKey: redis-password
```

### `with-ingress.yaml` (Optional)
Additional configuration to enable ingress:
```yaml
nextauth:
  url: https://langfuse.example.com
langfuse:
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
