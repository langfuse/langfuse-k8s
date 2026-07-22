# Installation with Self-Built ClickHouse and ZooKeeper Images

This example is a copy of the [minimal installation example](../minimal-installation)
that runs the ClickHouse and ZooKeeper dependencies on self-built, Bitnami-compatible
images instead of the frozen `bitnamilegacy` ones. See
[poc-images/README.md](../../poc-images/README.md) for what these images are and how to
build them.

## Installation

1. Build and push the images to a registry your cluster can pull from:
```bash
docker build -t registry.example.com/langfuse/clickhouse:26.2.19.43 poc-images/poc-clickhouse
```
```bash
docker build -t registry.example.com/langfuse/zookeeper:3.9.3 poc-images/poc-zookeeper
```
```bash
docker push registry.example.com/langfuse/clickhouse:26.2.19.43 && docker push registry.example.com/langfuse/zookeeper:3.9.3
```

2. Adjust `values.yaml`: replace `registry.example.com` and the repository names with
   the coordinates you pushed to. Keep the tags in sync with what you built.

3. Create the required secret:
```bash
# Edit secret.yaml and set secure values before applying
kubectl apply -f secret.yaml
```

4. Add the Helm repository:
```bash
helm repo add langfuse https://langfuse.github.io/langfuse-k8s
helm repo update
```

5. Install the chart using the base values file and optional ingress configuration:
```bash
# Basic installation
helm install langfuse langfuse/langfuse -f values.yaml

# Or with ingress enabled
helm install langfuse langfuse/langfuse -f values.yaml -f with-ingress.yaml
```

## How the image override works

The Bitnami ClickHouse chart (and its ZooKeeper subchart) resolve images from
`registry`/`repository`/`tag` values. This chart's defaults only override the
*repository* (to `bitnamilegacy/*`), so the **tag must be set explicitly** — otherwise
the chart default tag is used, which will not exist under your repository:

```yaml
clickhouse:
  image:
    registry: registry.example.com
    repository: langfuse/clickhouse
    tag: "26.2.19.43"
  zookeeper:
    image:
      registry: registry.example.com
      repository: langfuse/zookeeper
      tag: "3.9.3"
```

Non-Bitnami repositories additionally require `global.security.allowInsecureImages:
true`, which is already the default of this chart.

The remaining files are unchanged from the minimal installation example:

- `secret.yaml` — all required credentials; **apply before installing** and replace all
  placeholder values.
- `with-ingress.yaml` — optional ingress configuration; adjust the hostname to your
  environment.
