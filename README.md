![GitHub Banner](https://github.com/langfuse/langfuse-k8s/assets/2834609/2982b65d-d0bc-4954-82ff-af8da3a4fac8)

# langfuse-k8s

This is a community-maintained repository that contains resources for deploying Langfuse on Kubernetes.

## Helm Chart
We provide an Helm chart that helps you deploy Langfuse on Kubernetes. This Helm chart could use an external Postgres server or deploy one for you, thanks to [Bitnami Postgres Helm chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql).

### Installation
```bash
helm repo add langfuse https://langfuse.github.io/langfuse-k8s
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
| `langfuse.telemetryEnabled` | Weither or not to enable telemetry (reports basic usage statistics of self-hosted instances to a centralized server). | `true` |
| `service.type` | Change the default k8s service type deployed with the application | `ClusterIP` |
| `service.additionalLabels` | Add additional annotations to the service deployed with the application | `[]` |
| `ingress.enabled` | Enable ingress for the application | `false` |
| `ingress.annotations` | Annotation to add the the deployed ingress | `[]` |
| `postgresql.deploy` | Enable postgres deployment (via Bitnami Helm Chart). If you want to use a postgres server already deployed (or a managed one), set this to false | `true` |
| `postgresql.auth.username` | Username to use to connect to the postgres database deployed with Langfuse. In case `postgresql.deploy` is set to `true`, the user will be created automatically. | `postgres` |
| `postgresql.auth.password` | Password to use to connect to the postgres database deployed with Langfuse. In case `postgresql.deploy` is set to `true`, the password will be set automatically. | `postgres` |
| `postgresql.auth.database` | Database name to use for Langfuse. | `langfuse` |
| `postgresql.host` | If `postgresql.deploy` is set to false, hostname of the external postgres server to use (mandatory) | `nil` |
| `postgresql.primary.persistence.size` | Disk request for the postgres database deployed with Langfuse. Effective only if `postgresql.deploy` is set to true | `8Gi` |

#### Example (external Postgres server):
```yaml
langfuse:
    nextauth:
        url: "localhost:3000"
        secret: "changeme"
    salt: "changeme"
    telemetryEnabled: true
service:
    type: "ClusterIP"
    additionalLabels: []
ingress:
    enabled: false
    annotations: []
postgresql:
    deploy: false
    host: "my-external-postgres-server.com"
```


## Repository Structure
- `examples` directory contains example `yaml` configurations
- `charts/langfuse` directory contains Helm chart for deploying Langfuse with an associated database


Please feel free to contribute any improvements or suggestions.

Langfuse deployment docs: https://langfuse.com/docs/deployment/self-host
