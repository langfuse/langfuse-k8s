![GitHub Banner](https://github.com/langfuse/langfuse-k8s/assets/2834609/2982b65d-d0bc-4954-82ff-af8da3a4fac8)

# langfuse-k8s

This is a community-maintained repository that contains resources for deploying Langfuse on Kubernetes.

## Helm Chart

We provide a Helm chart that helps you deploy Langfuse on Kubernetes.

### 1.0.0 Release Candidate

This Chart is a release candidate for the 1.0.0 version of the Langfuse Helm Chart.
Please provide all thoughts and feedbacks on the interface and the upgrade path via our [GitHub Discussion](https://github.com/orgs/langfuse/discussions/5734).

For details on how to migrate from 0.13.x to 1.0.0, refer to our [migration guide](./UPGRADE.md).

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
    secretKeys:
      userPasswordKey: password

redis:
  auth:
    existingSecret: langfuse-redis-auth
    secretKeys:
      userPasswordKey: password

s3:
  auth:
    # If existingSecret is set, both root user and root password must be supplied via the secret
    existingSecret: langfuse-s3-auth
    rootUserSecretKey: rootUser
    rootPasswordSecretKey: rootPassword
```
      
See the [Helm README](./charts/langfuse/README.md) for a full list of all configuration options.

#### Examples:

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

#### With an external S3 bucket

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

## Repository Structure

- `examples` directory contains example `yaml` configurations
- `charts/langfuse` directory contains Helm chart for deploying Langfuse with an associated database

Please feel free to contribute any improvements or suggestions.

Langfuse deployment docs: https://langfuse.com/docs/deployment/self-host
