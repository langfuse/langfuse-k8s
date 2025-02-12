![GitHub Banner](https://github.com/langfuse/langfuse-k8s/assets/2834609/2982b65d-d0bc-4954-82ff-af8da3a4fac8)

# langfuse-k8s

This is a community-maintained repository that contains resources for deploying Langfuse on Kubernetes.

## Helm Chart

We provide a Helm chart that helps you deploy Langfuse on Kubernetes.

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

The required configuration options to set are:

```yaml
  langfuse:
    encryptionKey:
      value: ""

  nextauth:
    secret:
      value: ""

  postgresql:
    auth:
      password: ""

  clickhouse:
    auth:
      password: ""

  redis:
    auth:
      password: ""
```

They can alternatively set via secret references (the secrets must exits):

```yaml
  langfuse:
    encryptionKey:
      secretKeyRef:
        name: langfuse-encryption-key
        key: encryption-key

  nextauth:
    secret:
      secretKeyRef:
        name: langfuse-nextauth-secret
        key: nextauth-secret

  postgresql:
    auth:
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

##### With an external Postgres server with client certificates using own secrets and additionalEnv for mappings

TODO(cb):

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

## Repository Structure

- `examples` directory contains example `yaml` configurations
- `charts/langfuse` directory contains Helm chart for deploying Langfuse with an associated database

Please feel free to contribute any improvements or suggestions.

Langfuse deployment docs: https://langfuse.com/docs/deployment/self-host
