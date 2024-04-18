![GitHub Banner](https://github.com/langfuse/langfuse-k8s/assets/2834609/2982b65d-d0bc-4954-82ff-af8da3a4fac8)

# langfuse-k8s

This is a community-maintained repository that contains resources for deploying Langfuse on Kubernetes.

## Helm Chart
We provide an Helm chart that helps you deploy Langfuse on Kubernetes. This Helm chart deploy an instance of Langfuse with a Postgres database (as recommended by Langfuse). The database is provided thanks to [Bitnami Postgres Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql).

### Installation
```bash
helm repo add langfuse https://langfuse.github.io/langfuse-helm
helm repo update
helm install langfuse langfuse/langfuse
```

### Upgrading
```bash
helm repo update
helm upgrade langfuse langfuse/langfuse
```

### Configuration
The following table lists the useful configurable parameters of the Langfuse chart and their default values.

| Parameter | Description | Default |
| --- | --- | --- |
| `langfuse.nextauth.url` | When deploying to production, set the `nextauth.url` value to the canonical URL of your site. | `localhost:3000` |
| `langfuse.nextauth.secret` | Used to encrypt the NextAuth.js JWT, and to hash email verification tokens. | `changeme` |
| `langfuse.salt` | Salt for API key hashing | `changeme` |
| `telemetryEnabled` | Weither or not to enable telemetry (reports basic usage statistics of self-hosted instances to a centralized server). | `true` |
| `service.type` | Change the default k8s service type deployed with the application | `ClusterIP` |
| `service.additionalLabels` | Add additional annotations to the service deployed with the application | `[]` |
| `ingress.enabled` | Enable ingress for the application | `false` |
| `ingress.annotations` | Annotation to add the the deployed ingress | `[]` |
| `postgres.primary.persistence.size` | Disk request for the postgres database deployed with Langfuse | `8Gi` |


## Repository Structure
- `examples` directory contains example `yaml` configurations
- `charts/langfuse` directory contains Helm chart for deploying Langfuse with an associated database


Please feel free to contribute any improvements or suggestions.

Langfuse deployment docs: https://langfuse.com/docs/deployment/self-host
