![GitHub Banner](https://github.com/langfuse/langfuse-k8s/assets/2834609/2982b65d-d0bc-4954-82ff-af8da3a4fac8)

# langfuse-k8s

This is a community-maintained repository that contains resources for deploying Langfuse on Kubernetes.

## Helm Chart

We provide a Helm chart that helps you deploy Langfuse on Kubernetes.
Note that the Helm installation must be named `langfuse` for the chart to work correctly with the default values.yaml.

The following environment variables must be provided via `langfuse.additionalEnv` to configure Redis/Valkey, S3, and ClickHouse.
See the values.yaml file for more information and an example.
Replace `langfuse` in the values with your installation name in case you changed it.

```yaml
# REDIS
- name: "REDIS_CONNECTION_STRING"
  value: "redis://default:changeme@langfuse-valkey-master:6379/0"
# CLICKHOUSE
- name: "CLICKHOUSE_MIGRATION_URL"
  value: "clickhouse://langfuse-clickhouse:9000"
- name: "CLICKHOUSE_URL"
  value: "http://langfuse-clickhouse:8123"
- name: "CLICKHOUSE_USER"
  value: "default"
- name: "CLICKHOUSE_PASSWORD"
  value: "changeme"
# S3 / MinIO
- name: "LANGFUSE_S3_EVENT_UPLOAD_ENABLED"
  value: "true"
- name: "LANGFUSE_S3_EVENT_UPLOAD_BUCKET"
  value: "langfuse"
- name: "LANGFUSE_S3_EVENT_UPLOAD_REGION"
  value: "auto"
- name: "LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID"
  value: "minio"
- name: "LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY"
  value: "miniosecret"
- name: "LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT"
  value: "http://langfuse-minio:9000"
- name: "LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE"
  value: "true"
```

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

| Parameter                                               | Description                                                                                                                                                                                                                                                                                                                                  | Default                         |
|---------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------|
| `langfuse.licenseKey`                                   | Langfuse EE license key.                                                                                                                                                                                                                                                                                                                     | `""`                            |
| `langfuse.nextauth.url`                                 | When deploying to production, set the `nextauth.url` value to the canonical URL of your site.                                                                                                                                                                                                                                                | `http://localhost:3000`         |
| `langfuse.nextauth.secret`                              | Used to encrypt the NextAuth.js JWT, and to hash email verification tokens. In case the value is set to `null`, then the default `NEXTAUTH_SECRET` environment variable will not be set.                                                                                                                                                     | `changeme`                      |
| `langfuse.next.healthcheckBasePath`                     | Base path for the liveness/readiness probes. Should not include trailing slash.                                                                                                                                                                                                                                                              | `""`                            |
| `langfuse.port`                                         | Port to run Langfuse on                                                                                                                                                                                                                                                                                                                      | `3000`                          |
| `langfuse.salt`                                         | Salt for API key hashing. In case the value is set to `null`, then the default `SALT` environment variable will not be set.                                                                                                                                                                                                                  | `changeme`                      |
| `langfuse.telemetryEnabled`                             | Weither or not to enable telemetry (reports basic usage statistics of self-hosted instances to a centralized server).                                                                                                                                                                                                                        | `true`                          |
| `langfuse.extraContainers`                              | Dict that allow addition of additional containers                                                                                                                                                                                                                                                                                            | `[]`                            |
| `langfuse.extraInitContainers`                          | Dict that allow addition of init containers                                                                                                                                                                                                                                                                                                  | `[]`                            |
| `langfuse.extraVolumes`                                 | Dict that allow addition of volumes that can be mounted to the containers                                                                                                                                                                                                                                                                    | `[]`                            |
| `langfuse.extraVolumeMounts`                            | Dict that mounts extra volumes to the langfuse container                                                                                                                                                                                                                                                                                     | `[]`                            |
| `langfuse.web.replicas`                                 | Number of replicas to start for the web container. Defaults to global `replicaCount`.                                                                                                                                                                                                                                                        | `replicaCount`                  |
| `langfuse.web.livenessProbe.initialDelaySeconds`        | Initial delay seconds for livenessProbe.                                                                                                                                                                                                                                                                                                     | `20`                            |
| `langfuse.web.livenessProbe.periodSeconds`              | Period seconds for livenessProbe.                                                                                                                                                                                                                                                                                                            | `10`                            |
| `langfuse.web.livenessProbe.timeoutSeconds`             | Timeout seconds for livenessProbe.                                                                                                                                                                                                                                                                                                           | `5`                             |
| `langfuse.web.livenessProbe.failureThreshold`           | Failure threshold for livenessProbe.                                                                                                                                                                                                                                                                                                         | `5`                             |
| `langfuse.web.livenessProbe.successThreshold`           | Success threshold for livenessProbe.                                                                                                                                                                                                                                                                                                         | `1`                             |
| `langfuse.web.readinessProbe.initialDelaySeconds`       | Initial delay seconds for readinessProbe.                                                                                                                                                                                                                                                                                                    | `20`                            |
| `langfuse.web.readinessProbe.periodSeconds`             | Period seconds for readinessProbe.                                                                                                                                                                                                                                                                                                           | `10`                            |
| `langfuse.web.readinessProbe.timeoutSeconds`            | Timeout seconds for readinessProbe.                                                                                                                                                                                                                                                                                                          | `5`                             |
| `langfuse.web.readinessProbe.failureThreshold`          | Failure threshold for readinessProbe.                                                                                                                                                                                                                                                                                                        | `5`                             |
| `langfuse.web.readinessProbe.successThreshold`          | Success threshold for readinessProbe.                                                                                                                                                                                                                                                                                                        | `1`                             |
| `langfuse.web.resources`                                | Set container requests and limits for CPU and memory.                                                                                                                                                                                                                                                                                        | `{}`                            |
| `langfuse.web.hpa.enabled`                              | Enable Horizontal Pod Autoscaler (HPA) for the web component.                                                                                                                                                                                                                                                                                | `false`                         |
| `langfuse.web.hpa.minReplicas`                          | Minimum number of replicas for HPA for the web component.                                                                                                                                                                                                                                                                                    | `1`                             |
| `langfuse.web.hpa.maxReplicas`                          | Maximum number of replicas for HPA for the web component.                                                                                                                                                                                                                                                                                    | `2`                             |
| `langfuse.web.hpa.targetCPUUtilizationPercentage`       | Target CPU utilization percentage for HPA for the web component.                                                                                                                                                                                                                                                                             | `50`                            |
| `langfuse.web.hpa.targetMemoryUtilizationPercentage`    | Target memory utilization percentage for HPA for the web component.                                                                                                                                                                                                                                                                          | `null`                          |
| `langfuse.web.vpa.enabled`                              | Enable Vertical Pod Autoscaler (VPA) for the web component.                                                                                                                                                                                                                                                                                  | `false`                         |
| `langfuse.web.vpa.controlledResources`                  | Resources controlled by VPA for the web component.                                                                                                                                                                                                                                                                                           | `[]`                            |
| `langfuse.web.vpa.maxAllowed`                           | Maximum resource limits allowed by VPA for the web component.                                                                                                                                                                                                                                                                                | `{}`                            |
| `langfuse.web.vpa.minAllowed`                           | Minimum resource limits allowed by VPA for the web component.                                                                                                                                                                                                                                                                                | `{}`                            |
| `langfuse.web.vpa.updatePolicy.updateMode`              | Update mode for VPA (e.g., `Auto`).                                                                                                                                                                                                                                                                                                          | `Auto`                          |
| `langfuse.worker.replicas`                              | Number of replicas to start for the worker container. Defaults to global `replicaCount`.                                                                                                                                                                                                                                                     | `replicaCount`                  |
| `langfuse.worker.livenessProbe.initialDelaySeconds`     | Initial delay seconds for livenessProbe.                                                                                                                                                                                                                                                                                                     | `20`                            |
| `langfuse.worker.livenessProbe.periodSeconds`           | Period seconds for livenessProbe.                                                                                                                                                                                                                                                                                                            | `10`                            |
| `langfuse.worker.livenessProbe.timeoutSeconds`          | Timeout seconds for livenessProbe.                                                                                                                                                                                                                                                                                                           | `5`                             |
| `langfuse.worker.livenessProbe.failureThreshold`        | Failure threshold for livenessProbe.                                                                                                                                                                                                                                                                                                         | `5`                             |
| `langfuse.worker.livenessProbe.successThreshold`        | Success threshold for livenessProbe.                                                                                                                                                                                                                                                                                                         | `1`                             |
| `langfuse.worker.resources`                             | Set container requests and limits for CPU and memory.                                                                                                                                                                                                                                                                                        | `{}`                            |
| `langfuse.worker.hpa.enabled`                           | Enable Horizontal Pod Autoscaler (HPA) for the worker component.                                                                                                                                                                                                                                                                             | `false`                         |
| `langfuse.worker.hpa.minReplicas`                       | Minimum number of replicas for HPA for the worker component.                                                                                                                                                                                                                                                                                 | `1`                             |
| `langfuse.worker.hpa.maxReplicas`                       | Maximum number of replicas for HPA for the worker component.                                                                                                                                                                                                                                                                                 | `2`                             |
| `langfuse.worker.hpa.targetCPUUtilizationPercentage`    | Target CPU utilization percentage for HPA for the worker component.                                                                                                                                                                                                                                                                          | `50`                            |
| `langfuse.worker.hpa.targetMemoryUtilizationPercentage` | Target memory utilization percentage for HPA for the worker component.                                                                                                                                                                                                                                                                       | `null`                          |
| `langfuse.worker.vpa.enabled`                           | Enable Vertical Pod Autoscaler (VPA) for the worker component.                                                                                                                                                                                                                                                                               | `false`                         |
| `langfuse.worker.vpa.controlledResources`               | Resources controlled by VPA for the worker component.                                                                                                                                                                                                                                                                                        | `[]`                            |
| `langfuse.worker.vpa.maxAllowed`                        | Maximum resource limits allowed by VPA for the worker component.                                                                                                                                                                                                                                                                             | `{}`                            |
| `langfuse.worker.vpa.minAllowed`                        | Minimum resource limits allowed by VPA for the worker component.                                                                                                                                                                                                                                                                             | `{}`                            |
| `langfuse.worker.vpa.updatePolicy.updateMode`           | Update mode for VPA (e.g., `Auto`).                                                                                                                                                                                                                                                                                                          | `Auto`                          |
| `langfuse.additionalEnv`                                | Dict that allow addition of additional env variables, see [documentation](https://langfuse.com/docs/deployment/self-host#configuring-environment-variables) for details.                                                                                                                                                                     | `{}`                            |
| `service.type`                                          | Change the default k8s service type deployed with the application                                                                                                                                                                                                                                                                            | `ClusterIP`                     |
| `service.port`                                          | Change the default k8s service port deployed with the application                                                                                                                                                                                                                                                                            | `3000`                          |
| `service.additionalLabels`                              | Add additional annotations to the service deployed with the application                                                                                                                                                                                                                                                                      | `[]`                            |
| `ingress.enabled`                                       | Enable ingress for the application                                                                                                                                                                                                                                                                                                           | `false`                         |
| `ingress.annotations`                                   | Annotation to add to the deployed ingress                                                                                                                                                                                                                                                                                                    | `[]`                            |
| `resources`                                             | Set shared container requests and limits for web and worker components (not recommended).                                                                                                                                                                                                                                                    | `{}`                            |
| `ingress.hosts`                                         | Hosts to define for the deployed ingress. Effective only if `ingress.enabled` is set to true                                                                                                                                                                                                                                                 | `[]`                            |
| `postgresql.deploy`                                     | Enable postgres deployment (via Bitnami Helm Chart). If you want to use a postgres server already deployed (or a managed one), set this to false                                                                                                                                                                                             | `true`                          |
| `postgresql.auth.username`                              | Username to use to connect to the postgres database deployed with Langfuse. In case `postgresql.deploy` is set to `true`, the user will be created automatically.                                                                                                                                                                            | `postgres`                      |
| `postgresql.auth.password`                              | Password to use to connect to the postgres database deployed with Langfuse. In case `postgresql.deploy` is set to `true`, the password will be set automatically.                                                                                                                                                                            | `postgres`                      |
| `postgresql.auth.database`                              | Database name to use for Langfuse.                                                                                                                                                                                                                                                                                                           | `langfuse`                      |
| `postgresql.host`                                       | If `postgresql.deploy` is set to false, hostname of the external postgres server to use (mandatory)                                                                                                                                                                                                                                          | `nil`                           |
| `postgresql.directUrl`                                  | If `postgresql.deploy` is set to false, Connection string of your Postgres database used for database migrations. Use this if you want to use a different user for migrations or use connection pooling on DATABASE_URL. For large deployments, configure the database user with long timeouts as migrations might need a while to complete. | `nil`                           |
| `postgresql.shadowDatabaseUrl`                          | If your database user lacks the CREATE DATABASE permission, you must create a shadow database and configure the "SHADOW_DATABASE_URL". This is often the case if you use a Cloud database. Refer to the Prisma docs for detailed instructions.                                                                                               | `nil`                           |
| `postgresql.primary.persistence.size`                   | Disk request for the postgres database deployed with Langfuse. Effective only if `postgresql.deploy` is set to true                                                                                                                                                                                                                          | `8Gi`                           |
| `postgresql.primary.persistence.storageClass`           | Disk PVC Storage Class for the postgres database deployed with Langfuse. Effective only if `postgresql.deploy` is set to true                                                                                                                                                                                                                | ``                              |
| `clickhouse.deploy`                                     | Enable ClickHouse deployment (via Bitnami Helm Chart). If you want to use an external Clickhouse server (or a managed one), set this to false                                                                                                                                                                                                | `true`                          |
| `clickhouse.shards`                                     | Number of shards to use for the ClickHouse cluster. Must be set to 1.                                                                                                                                                                                                                                                                        | `1`                             |
| `clickhouse.replicaCount`                               | Number of replicas to use for the ClickHouse cluster. 1 corresponds to a single, non-HA deployment.                                                                                                                                                                                                                                          | `3`                             |
| `clickhouse.resourcesPreset`                            | Resource preset for Bitnami Helm chart.                                                                                                                                                                                                                                                                                                      | `large`                         |
| `clickhouse.auth.username`                              | Username for the ClickHouse user.                                                                                                                                                                                                                                                                                                            | `default`                       |
| `clickhouse.auth.password`                              | Password for the ClickHouse user.                                                                                                                                                                                                                                                                                                            | `changeme`                      |
| `valkey.deploy`                                         | Enable valkey deployment (via Bitnami Helm Chart). If you want to use a Redis or Valkey server already deployed, set to false.                                                                                                                                                                                                               | `true`                          |
| `valkey.architecture`                                   | Architecture for the valkey deployment. Should be `standalone`.                                                                                                                                                                                                                                                                              | `standalone`                    |
| `valkey.primary.extraFlags`                             | Extra flags for the valkey deployment. Must include `--maxmemory-policy noeviction`.                                                                                                                                                                                                                                                         | `--maxmemory-policy noeviction` |
| `valkey.auth.password`                                  | Password for the valkey cluster.                                                                                                                                                                                                                                                                                                             | `changeme`                      |
| `minio.deploy`                                          | Enable MinIO deployment (via Bitnami Helm Chart). If you want to use a custom BlobStorage, e.g. S3, set to false.                                                                                                                                                                                                                            | `true`                          |
| `minio.defaultBuckets`                                  | Default buckets to create with the MinIO deployment.                                                                                                                                                                                                                                                                                         | `langfuse`                      |
| `minio.auth.rootUser`                                   | Name of the MinIO root user.                                                                                                                                                                                                                                                                                                                 | `minio`                         |
| `minio.auth.rootPassword`                               | Password for the MinIO root user.                                                                                                                                                                                                                                                                                                            | `miniosecret`                   |
| `extraManifests`                                        | Dict that allow addition of additional k8s resources                                                                                                                                                                                                                                                                                         | `[]`                            |

#### Examples:

##### With an external Postgres server

```yaml
langfuse:
  nextauth:
    url: http://localhost:3000
    secret: changeme
  salt: changeme
  telemetryEnabled: true
service:
  type: ClusterIP
  additionalLabels: []
ingress:
  enabled: false
  annotations: []
postgresql:
  deploy: false
  auth:
    username: postgres
    password: changeme
    database: langfuse
  host: my-external-postgres-server.com
  directUrl: postgres://user:password@my-external-postgres-server.com
  shadowDatabaseUrl: postgres://user:password@my-external-postgres-server.com
```

##### Deploy a Postgres server at the same time

```yaml
langfuse:
  nextauth:
    url: http://localhost:3000
    secret: changeme
  salt: changeme
  telemetryEnabled: true
service:
  type: ClusterIP
ingress:
  enabled: false
postgresql:
  deploy: true
  auth:
    password: changeme
```

##### Enable ingress

```yaml
langfuse:
  [...]
service:
  [...]
ingress:
  enabled: true
  hosts:
    - host: langfuse.your-host.com
      paths:
      - path: /
        pathType: Prefix
  annotations: []
postgresql:
  [...]
```

##### With an external Postgres server with client certificates using own secrets and additionalEnv for mappings

```yaml
langfuse:
  salt: null
  nextauth: 
    secret: null
  extraVolumes:
    - name: db-keystore   # referencing an existing secret to mount server/client certs for postgres
      secret:
        secretName: langfuse-postgres  # contain the following files (server-ca.pem, sslidentity.pk12)
  extraVolumeMounts:
    - name: db-keystore
      mountPath: /secrets/db-keystore  # mounting the db-keystore store certs in the pod under the given path
      readOnly: true
  additionalEnv:
    - name: DATABASE_URL  # Using the certs in the url eg. postgresql://the-db-user:the-password@postgres-host:5432/langfuse?ssl=true&sslmode=require&sslcert=/secrets/db-keystore/server-ca.pem&sslidentity=/secrets/db-keystore/sslidentity.pk12&sslpassword=the-ssl-identity-pw
      valueFrom:
        secretKeyRef:
          name: langfuse-postgres  # referencing an existing secret
          key: database-url
    - name: NEXTAUTH_SECRET
      valueFrom:
        secretKeyRef:
          name: langfuse-general # referencing an existing secret
          key: nextauth-secret
    - name: SALT
      valueFrom:
        secretKeyRef:
          name: langfuse-general
          key: salt
service:
  [...]
ingress:
  [...]
postgresql:
  deploy: false
  auth:
    password: null
    username: null
```

## Repository Structure

- `examples` directory contains example `yaml` configurations
- `charts/langfuse` directory contains Helm chart for deploying Langfuse with an associated database

Please feel free to contribute any improvements or suggestions.

Langfuse deployment docs: https://langfuse.com/docs/deployment/self-host
