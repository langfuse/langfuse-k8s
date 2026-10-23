# AI Gateway Example

This example enables the Langfuse AI gateway on top of the [minimal installation](../minimal-installation/). See the [AI gateway section](../../README.md#ai-gateway) of the chart README for release requirements and all settings.

## Installation

1. Follow the [minimal installation](../minimal-installation/) and apply its `secret.yaml`.

2. Set the gateway keys in `secret.yaml` and apply it:
```bash
# Edit secret.yaml and set secure values before applying
kubectl apply -f secret.yaml -n langfuse
```

3. Install the chart with the minimal values, this example's values, and optional ingress configuration:
```bash
# Basic installation
helm install langfuse oci://ghcr.io/langfuse/langfuse-k8s/charts/langfuse \
  --namespace langfuse \
  -f ../minimal-installation/values.yaml -f values.yaml

# Or with ingress enabled
helm install langfuse oci://ghcr.io/langfuse/langfuse-k8s/charts/langfuse \
  --namespace langfuse \
  -f ../minimal-installation/values.yaml -f values.yaml -f with-ingress.yaml
```

## Configuration

### `secret.yaml`
The gateway keys. The service key is shared by web and the gateway; the JWT private key is used only by web, which derives the public key from it.

### `values.yaml`
Enables the gateway and points it at the keys in `secret.yaml`:
```yaml
langfuse:
  gateway:
    enabled: true
    serviceKey:
      secretKeyRef:
        name: langfuse-ai-gateway
        key: service-key
    jwt:
      privateKey:
        secretKeyRef:
          name: langfuse-ai-gateway
          key: jwt-private-key
```

The gateway calls web through web's in-cluster Service, so it works without an ingress for web.

### `with-ingress.yaml` (Optional)
Ingresses for web and for the gateway on its own host. The gateway Ingress raises the nginx timeouts and body size and turns off buffering, so streamed responses work. Its first host is also the gateway URL web shows users.

Make sure to adjust the hostnames to match your environment and add a DNS record for the gateway host.
