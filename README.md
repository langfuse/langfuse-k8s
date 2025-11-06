![GitHub Banner](https://github.com/langfuse/langfuse-k8s/assets/2834609/2982b65d-d0bc-4954-82ff-af8da3a4fac8)

# langfuse-k8s

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/langfuse-k8s)](https://artifacthub.io/packages/search?repo=langfuse-k8s)

This is a community-maintained repository that contains resources for deploying Langfuse on Kubernetes.
Please feel free to contribute any improvements or suggestions.

Langfuse self-hosting documentation: https://langfuse.com/self-hosting

## Repository Structure

- `examples` directory contains example `yaml` configurations
- `charts/langfuse` directory contains Helm chart for deploying Langfuse with an associated database

## ⚠️ Important: Bitnami Registry Changes

**Effective August 28, 2025**, Bitnami will restructure its container registry. This chart now uses `bitnamilegacy/*` images by default to prevent deployment failures.

**What changed:**
- Bitnami moved most container images to a paid "Secure Images" tier
- Free images are now limited to a small community subset
- Older/versioned images moved to the "Bitnami Legacy" repository

**Next steps:**
- For existing deployments: Ensure that you update your mirrors to clone from bitnamilegacy if applicable.
- We will investigate alternative image sources that are compliant with the Helm chart and roll them out over time.
- You _may_ upgrade to Bitnami Secure Images if desired in the meantime. In this case, set `global.security.allowInsecureImages: false` and configure image repositories to use `bitnami/*` instead of `bitnamilegacy/*`

See [Bitnami's announcement](https://github.com/bitnami/charts/issues/35164) for more details.

## Helm Chart

We provide a Helm chart that helps you deploy Langfuse on Kubernetes.

### Installation

Configure the required secrets and parameters as defined below in a new `values.yaml` file.
Then install the helm chart using the commands below:

```bash
helm repo add langfuse https://langfuse.github.io/langfuse-k8s
helm repo update
helm install langfuse langfuse/langfuse -f values.yaml
```

### Upgrading

```bash
helm repo update
helm upgrade langfuse langfuse/langfuse
```

Please validate whether the helm sub-charts in the Chart.yaml were updated between versions.
If yes, follow the guide for the respective sub-chart to upgrade it.

### Sizing

By default, the chart will run with the minimum resources to provide a stable experience.
For production environments, we recommend to adjust the following parameters in the values.yaml.
See [Langfuse documentation](https://langfuse.com/self-hosting/scaling) for our full sizing guide.

```yaml
langfuse:
  resources:
    limits:
      cpu: "2"
      memory: "4Gi"
    requests:
      cpu: "2"
      memory: "4Gi"

clickhouse:
  resources:
    limits:
      cpu: "2"
      memory: "8Gi"
    requests:
      cpu: "2"
      memory: "8Gi"
      
  zookeeper:
    resources:
      limits:
        cpu: "2"
        memory: "4Gi"
      requests:
        cpu: "2"
        memory: "4Gi"

redis:
  primary:
    resources:
      limits:
        cpu: "1"
        memory: "1.5Gi"
      requests:
        cpu: "1"
        memory: "1.5Gi"

s3:
  resources:
    limits:
      cpu: "2"
      memory: "4Gi"
    requests:
      cpu: "2"
      memory: "4Gi"
```

### Configuration

The required configuration options to set are:

```yaml
# Optional, but highly recommended. Generate via `openssl rand -hex 32`.
#  langfuse:
#    encryptionKey:
#      value: ""
langfuse: 
  salt:
    value: secureSalt
  nextauth:
    secret:
      value: ""

postgresql:
  auth:
    # If you want to use `postgres` as the username, you need to provide postgresPassword instead of password.
    username: langfuse
    password: ""

clickhouse:
  auth:
    password: ""

redis:
  auth:
    password: ""

s3:
  auth:
    rootPassword: ""
```

They can alternatively set via secret references (the secrets must exist):

```yaml
# Optional, but highly recommended. Generate via `openssl rand -hex 32`.
#  langfuse:
#    encryptionKey:
#      secretKeyRef:
#        name: langfuse-encryption-key-secret
#        key: encryptionKey
langfuse: 
  salt:
    secretKeyRef:
      name: langfuse-general
      key: salt
  nextauth:
    secret:
      secretKeyRef:
        name: langfuse-nextauth-secret
        key: nextauth-secret

postgresql:
  auth:
    # If you want to use `postgres` as the username, you need to provide a adminPasswordKey in secretKeys.
    username: langfuse
    existingSecret: langfuse-postgresql-auth
    secretKeys:
      userPasswordKey: password

clickhouse:
  auth:
    existingSecret: langfuse-clickhouse-auth
    existingSecretKey: password

redis:
  auth:
    existingSecret: langfuse-redis-auth
    existingSecretPasswordKey: password

s3:
  auth:
    # If existingSecret is set, both root user and root password must be supplied via the secret
    existingSecret: langfuse-s3-auth
    rootUserSecretKey: rootUser
    rootPasswordSecretKey: rootPassword
```
      
See the [Helm README](https://github.com/langfuse/langfuse-k8s/blob/main/charts/langfuse/README.md) for a full list of all configuration options.

#### Storage Provider Options

Langfuse supports multiple blob storage providers through the `s3.storageProvider` configuration:

- **`s3`** (default): Uses S3-compatible interface. Works with AWS S3, MinIO, Cloudflare R2, and other S3-compatible services.
- **`azure`**: Uses Azure Blob Storage native integration. Requires Azure Storage Account credentials.
- **`gcs`**: Uses Google Cloud Storage native integration. Requires GCS service account credentials.

By default, the system uses the S3-compatible method.
When Azure or GCS is selected, the respective native storage integration is enabled with the appropriate environment variables.
See our [self-hosting docs](https://langfuse.com/self-hosting/infrastructure/blobstorage) for more details on Blob Storage configurations.

#### Examples

##### With an external Postgres server

```yaml
[...]
postgresql:
  deploy: false
  auth:
    username: my-username
    password: my-password
    database: my-database
  host: my-external-postgres-server.com
  directUrl: postgres://my-username:my-password@my-external-postgres-server.com
  shadowDatabaseUrl: postgres://my-username:my-password@my-external-postgres-server.com
```

##### With an external S3 bucket

```yaml
[...]
s3:
  deploy: false
  bucket: "langfuse-bucket"
  region: "eu-west-1"
  endpoint: "https://s3.eu-west-1.amazonaws.com"
  forcePathStyle: false
  accessKeyId:
    value: "mykey"
  secretAccessKey:
    value: "mysecret"
  eventUpload:
    prefix: "events/"
  batchExport:
    prefix: "exports/"
  mediaUpload:
    prefix: "media/"
```

##### With Azure Blob Storage

```yaml
[...]
s3:
  deploy: false
  storageProvider: "azure"
  bucket: "langfuse"  # Container name - If it does not exist, Langfuse will attempt to create it
  accessKeyId:
    value: "devstoreaccount1"  # Azure Storage Account name
  secretAccessKey:
    value: "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="  # Azure Storage Account key
  endpoint: "https://yourstorageaccount.blob.core.windows.net"
  eventUpload:
    prefix: "events/"
  batchExport:
    prefix: "exports/"
  mediaUpload:
    prefix: "media/"
```

##### With Google Cloud Storage

```yaml
[...]
s3:
  deploy: false
  storageProvider: "gcs"
  bucket: "langfuse"  # GCS bucket name
  gcs:
    credentials:
      value: |
        {
          "type": "service_account",
          "project_id": "your-project-id",
          "private_key_id": "your-private-key-id",
          "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
          "client_email": "your-service-account@your-project-id.iam.gserviceaccount.com",
          "client_id": "your-client-id",
          "auth_uri": "https://accounts.google.com/o/oauth2/auth",
          "token_uri": "https://oauth2.googleapis.com/token",
          "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
          "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/your-service-account%40your-project-id.iam.gserviceaccount.com"
        }
  eventUpload:
    prefix: "events/"
  batchExport:
    prefix: "exports/"
  mediaUpload:
    prefix: "media/"
```

Alternatively, you can reference the credentials from a secret:

```yaml
[...]
s3:
  deploy: false
  storageProvider: "gcs"
  bucket: "langfuse"
  gcs:
    credentials:
      secretKeyRef:
        name: "gcs-credentials"
        key: "credentials.json"
  eventUpload:
    prefix: "events/"
  batchExport:
    prefix: "exports/"
  mediaUpload:
    prefix: "media/"
```

##### With Redis Cluster

Langfuse supports Redis Cluster mode for high-availability and scalability. Configure Redis in one of two ways:

**Standalone Mode (Default):**

```yaml
redis:
  deploy: false  # Set to false for external Redis
  host: "my-redis.example.com"
  port: 6379
  auth:
    password: "your-password"
```

**Cluster Mode:**

```yaml
redis:
  deploy: false  # Must be false - deployed Redis doesn't support cluster mode
  cluster:
    enabled: true
    nodes:
      - "redis-node-1:6379"
      - "redis-node-2:6379"
      - "redis-node-3:6379"
      - "redis-node-4:6379"
      - "redis-node-5:6379"
      - "redis-node-6:6379"
  auth:
    password: "your-cluster-password"
```

**Redis Cluster with TLS:**

```yaml
redis:
  deploy: false
  cluster:
    enabled: true
    nodes:
      - "redis-node-1:6379"
      - "redis-node-2:6379"
      - "redis-node-3:6379"
  auth:
    password: "your-cluster-password"
  tls:
    enabled: true
    caPath: "/certs/ca.crt"
    certPath: "/certs/client.crt"
    keyPath: "/certs/client.key"
```

**AWS ElastiCache Example:**

For AWS ElastiCache Redis Cluster, use the configuration endpoint that automatically discovers all cluster nodes:

```yaml
redis:
  deploy: false
  cluster:
    enabled: true
    nodes:
      - "clustercfg.my-redis-cluster.abc123.cache.amazonaws.com:6379"
  auth:
    password: "your-auth-token"
  tls:
    enabled: true
```

#### Use custom deployment strategy

```yaml
[...]
langfuse:
  deployment:
    strategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 50%
        maxUnavailable: 50%
```

##### Enable ingress

```yaml
[...]
langfuse:
  ingress:
    enabled: true
    hosts:
    - host: langfuse.your-host.com
      paths:
      - path: /
        pathType: Prefix
    annotations: []
```

##### Ingress with custom backend (AWS Load Balancer Controller redirect)

Use custom backends to configure AWS Load Balancer Controller redirects or other advanced routing:

```yaml
[...]
langfuse:
  ingress:
    enabled: true
    className: "alb"
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      # Redirect action annotation
      alb.ingress.kubernetes.io/actions.redirect-to-langfuse: |
        {
          "type": "redirect",
          "redirectConfig": {
            "protocol": "HTTPS",
            "port": "443",
            "host": "langfuse.example.com",
            "statusCode": "HTTP_301"
          }
        }
    hosts:
      # Main service host - uses default backend
      - host: langfuse.example.com
        paths:
        - path: /
          pathType: Prefix
      # Redirect host - uses custom backend for redirect
      - host: langfuse-v3.example.com
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: redirect-to-langfuse
              port:
                name: use-annotation
```

##### Ingress with mixed backends

Configure different backends for different paths within the same host:

```yaml
[...]
langfuse:
  ingress:
    enabled: true
    hosts:
    - host: langfuse.example.com
      paths:
      # Default backend for main application
      - path: /
        pathType: Prefix
      # Custom backend for specific path
      - path: /api/webhook
        pathType: Prefix
        backend:
          service:
            name: webhook-service
            port:
              number: 8080
```

#### Custom Storage Class Definition

The Langfuse chart supports configuring storage classes for all persistent volumes in the deployment. You can configure storage classes in two ways:

1. **Global Storage Class**: Set a global storage class that will be used for all persistent volumes unless overridden.
```yaml
global:
  defaultStorageClass: "your-storage-class"
```

2. **Component-specific Storage Classes**: Override the storage class for specific components.
```yaml
postgresql:
  primary:
    persistence:
      storageClass: "postgres-storage-class"
   
redis:
  primary:
    persistence:
      storageClass: "redis-storage-class"

clickhouse:
  persistence:
    storageClass: "clickhouse-storage-class"

s3:
  persistence:
    storageClass: "minio-storage-class"
```

If no storage class is specified, the cluster's default storage class will be used.

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

##### With SSO provider configuration using secrets and additionalEnv

This example shows how to configure Okta SSO by setting the required environment variables from secrets using the `additionalEnv` pattern:

```yaml
langfuse:
  additionalEnv:
    - name: AUTH_OKTA_CLIENT_ID
      valueFrom:
        secretKeyRef:
          name: okta-secrets
          key: AUTH_OKTA_CLIENT_ID
    - name: AUTH_OKTA_CLIENT_SECRET
      valueFrom:
        secretKeyRef:
          name: okta-secrets
          key: AUTH_OKTA_CLIENT_SECRET
    - name: AUTH_OKTA_ISSUER
      valueFrom:
        secretKeyRef:
          name: okta-secrets
          key: AUTH_OKTA_ISSUER
```

You would need to create the corresponding secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: okta-secrets
type: Opaque
stringData:
  AUTH_OKTA_CLIENT_ID: "your-okta-client-id"
  AUTH_OKTA_CLIENT_SECRET: "your-okta-client-secret"
  AUTH_OKTA_ISSUER: "https://your-domain.okta.com"
```

This pattern works for any SSO provider supported by Langfuse. See the [Authentication and SSO documentation](https://langfuse.com/self-hosting/authentication-and-sso#sso) for other providers and their required environment variables.

##### With overrides for hostAliases

This is going to add a record to the /etc/hosts file of all containers
under the langfuse-web pod in such a way that every traffic towards "oauth.id.jumpcloud.com" is going to be forwarded to the localhost network.

```yaml
langfuse:
  web:
    hostAliases:
      - ip: 127.0.0.1
        hostnames:
          - "oauth.id.jumpcloud.com"
```

##### With topology spread constraints

Distribute pods evenly across different zones to improve high availability:

```yaml
langfuse:
  # Global topology spread constraints applied to all langfuse pods
  pod:
    topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app.kubernetes.io/instance: langfuse
  
  # Component-specific topology spread constraints
  web:
    pod:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web
  
  worker:
    pod:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: worker
```

## Testing

This repository includes testing to ensure the Helm chart works correctly across different configurations.

### Setup

Install the helm unittest plugin using
```shell
helm plugin install https://github.com/helm-unittest/helm-unittest.git
```

### Running Tests Locally

```bash
helm unittest charts/langfuse --color
```
