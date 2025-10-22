# Upgrading from Langfuse Helm Chart v0.13 to v1.0

This guide outlines the changes needed when upgrading from Langfuse Helm Chart v0.13 to v1.0. For an example of a migration for a minimal example, see the [upgrade example](./examples/upgrade-v0.13-to-v1.0/).

## Breaking Changes

### Configuration Structure Changes

1. **Langfuse Configuration**
  - Most core configurations are now handled under the `langfuse` section:
    ```yaml
      # Old
      serviceAccount: [...]
      podAnnotations: {}
      podSecurityContext: {}
      securityContext: {}
      service: [...]
      resources: {}
      nodeSelector: {}
      tolerations: []
      affinity: {}

      # New
      langfuse:
        serviceAccount: [...]
        pod:
          annotations: {}
        podSecurityContext: {}
        securityContext: {}
        resources: {}
        nodeSelector: {}
        tolerations: []
        affinity: {}
        web:
          service: [...]
    ```

  - The replicaCount parameter got renamed to replicas, and can be overridden per component:
    ```yaml
      # Old
      replicaCount: 1

      # New
      langfuse:
        replicas: 1
    ```
    
    Alternatively, you can set the replicas directly for each component:
    ```yaml
      langfuse:
        web:
          replicas: 2
        worker:
          replicas: 3
    ```

2. **Authentication and Security**
  - The `langfuse.salt` is now structured differently:
    ```yaml
      # Old
      langfuse:
        salt: changeme

      # New
      langfuse:
        salt:
          value: ""  # Direct value
          secretKeyRef:  # Or use an existing secret
            name: ""
            key: ""
    ```

  - `encryptionKey` configuration instead of `ENCRYPTION_KEY` environment variable
    
    ```yaml
      # Old
      langfuse:
        additionalEnv:
          - name: "ENCRYPTION_KEY"
            value: "<encryption-key>"

      # New
      langfuse:
        encryptionKey:
          value: "<encryption-key>"
    ```

    Alternatively, you can use an existing secret for the encryption key:
    ```yaml
      langfuse:
        encryptionKey:
          existingSecret: <secret-name>
          existingSecretKey: <secret-key>
    ```

2. **Redis Configuration**
  - The `valkey` section has been renamed to `redis`. To keep the same name, you can set the `nameOverride` to `valkey`.
  - Previously configured environment variables in `additionalEnv` have been integrated into the chart structure:

    ```yaml
      # Old Redis Configuration
      langfuse:
        additionalEnv:
          - name: "REDIS_CONNECTION_STRING"
            value: "redis://<username>:<password>@<host>:<port>/<database>"

      # New Redis Configuration
      redis:
        nameOverride: valkey
        host: <host>
        port: <port>
        auth:
          username: <username>
          password: <password>
          database: <database>
    ```

    You can also use an existing secret for the password, instead of setting the password directly:
    ```yaml
      redis:
        auth:
          existingSecret: <secret-name>
          existingSecretPasswordKey: <password-key>
    ```

3. **Clickhouse Configuration**
  - Previously configured environment variables in `additionalEnv` have been integrated into the chart structure:

    ```yaml
      # Old Clickhouse Configuration (in additionalEnv)
      langfuse:
        additionalEnv:
          - name: "CLICKHOUSE_MIGRATION_URL"
            value: "clickhouse://<host>:<native-port>"
          - name: "CLICKHOUSE_URL"
            value: "http://<host>:<http-port>"
          - name: "CLICKHOUSE_USER"
            value: "<username>"
          - name: "CLICKHOUSE_PASSWORD"
            value: "<password>"

      # New Clickhouse Configuration
      clickhouse:
        host: <host>
        httpPort: <http-port>
        nativePort: <native-port>
        auth:
          username: "<username>"
          password: "<password>"
        migration:
          url: "clickhouse://<host>:<native-port>"
    ```

    You can also use an existing secret for the password, instead of setting the password directly:
    ```yaml
      clickhouse:
        auth:
          existingSecret: <secret-name>
          existingSecretPasswordKey: <password-key>
    ```
    
    **⚠️ Important:** The new `clickhouse` configuration structure and `langfuse.additionalEnv` with ClickHouse environment variables are mutually exclusive.
    You cannot use both approaches simultaneously. If you have ClickHouse configuration in `langfuse.additionalEnv` (e.g., `CLICKHOUSE_URL`, `CLICKHOUSE_USER`, `CLICKHOUSE_PASSWORD`, `CLICKHOUSE_MIGRATION_URL`), you must remove these entries when migrating to the new `clickhouse` configuration structure, or continue using only `langfuse.additionalEnv` for all ClickHouse settings.

4. **S3/MinIO Configuration**
  - The `minio` section has been renamed to `s3`. To keep the same name, you can set the `nameOverride` to `minio`.
  - Previously configured environment variables in `additionalEnv` have been integrated into the chart structure:

    ```yaml
      # Old S3/MinIO Configuration (in additionalEnv)
      langfuse:
        additionalEnv:
          - name: "LANGFUSE_S3_EVENT_UPLOAD_ENABLED"
            value: "true"
          - name: "LANGFUSE_S3_EVENT_UPLOAD_BUCKET"
            value: "<bucket>"
          - name: "LANGFUSE_S3_EVENT_UPLOAD_REGION"
            value: "<region>"
          - name: "LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID"
            value: "<access-key-id>"
          - name: "LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY"
            value: "<secret-access-key>"
          - name: "LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT"
            value: "<endpoint>"
          - name: "LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE"
            value: "true"

      # New S3/MinIO Configuration - global settings
      s3:
        nameOverride: minio
        bucket: <bucket>
        region: <region>
        endpoint: <endpoint>
        forcePathStyle: true
        accessKeyId:
          value: "<access-key-id>"
        secretAccessKey:
          value: "<secret-access-key>"
        eventUpload:
          prefix: "events/"
        batchExport:
          prefix: "exports/"
        mediaUpload:
          prefix: "media/"
    ```

    Alternatively, you can configure the buckets, endpoints, etc. per upload type:
    ```yaml
      s3:
        nameOverride: minio
        eventUpload:
          bucket: <bucket>
          [...]
        batchExport:
          bucket: <bucket>
          [...]
        mediaUpload:
          bucket: <bucket>
          [...]
    ```

5. **Feature Flags**
  - Feature flags have been restructured under `langfuse.features`:
    ```yaml
      # Old
      langfuse:
        telemetryEnabled: true
        nextPublicSignUpDisabled: false
        enableExperimentalFeatures: false

      # New
      langfuse:
        features:
          telemetryEnabled: true
          signUpDisabled: false
          experimentalFeaturesEnabled: false
    ```

7. **Image Configuration**
  - Image configuration has been restructured and can now be overridden per component:
    ```yaml
      # Old
      image:
        repository: langfuse/langfuse
        pullPolicy: Always
        tag: 3

      # New
      langfuse:
        image:
          tag: 3
          pullPolicy: Always
          pullSecrets: []
        
        web:
          image:
            repository: langfuse/langfuse
            tag: null  # Inherits from langfuse.image.tag if not set
            pullPolicy: null  # Inherits from langfuse.image.pullPolicy if not set
        
        worker:
          image:
            repository: langfuse/langfuse-worker
            tag: null  # Inherits from langfuse.image.tag if not set
            pullPolicy: null  # Inherits from langfuse.image.pullPolicy if not set
    ```

7. **Logging Configuration**
  - New logging configuration section:
    ```yaml
      langfuse:
        logging:
          level: info  # trace, debug, info, warn, error, fatal
          format: text # text or json
    ```

8. **Health Checks**
  - New health check configurations for web and worker components:
    ```yaml
      langfuse:
        web:
          livenessProbe:
            path: "/api/public/health"
            initialDelaySeconds: 20
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
            successThreshold: 1
          readinessProbe:
            path: "/api/public/ready"
            initialDelaySeconds: 20
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
            successThreshold: 1
    ```

### Removed Configurations

The following configurations have been removed or replaced:
  - `langfuse.port` - Now handled internally
  - `langfuse.next.healthcheckBasePath` - Replaced by new health check configurations
  - `langfuse.additionalEnv` still available, but mostly moved to the new integrated structure

## Migration Steps

1. **Required Actions**
  - Move your global configurations to the new structure under `langfuse`
  - Update your image configuration to use the new structure
  - Update relevant secret values or references for the salt, encryption key, license key and nextauth secret to the new structure:
    - If you are referencing by value, use `langfuse.salt.value`, `langfuse.encryptionKey.value` and `langfuse.licenseKey.value`
    - If you are referencing by secret, use `langfuse.salt.secretKeyRef`, `langfuse.encryptionKey.secretKeyRef` and `langfuse.licenseKey.secretKeyRef`
  - Migrate your environment variables to the new integrated structure:
    - Move Redis configuration from `valkey` and `langfuse.additionalEnv` to `redis`, add the `nameOverride` to `valkey`
    - Move Clickhouse configuration from `clickhouse` and `langfuse.additionalEnv` to `clickhouse`
    - Move S3/MinIO configuration from `minio` and `langfuse.additionalEnv` to `s3`, add the `nameOverride` to `minio`
    - Move the encryption key to the new structure under `langfuse.encryptionKey`

3. **Optional Configurations**
  - Configure the new logging settings if needed
  - Set up health check parameters if you need custom values
  - Review and configure the new feature flags structure

4. **Dependencies**
  - Review the configuration of dependent services (Redis, PostgreSQL, Clickhouse, MinIO)
  - Check that all required environment variables are properly migrated to the new structure
  - Any remaining custom environment variables can still be set in `langfuse.additionalEnv`

## Troubleshooting

### Migration Errors

If you encounter a migration error like `no migration found for version 18: read down for version 18 .: file does not exist` during upgrade, this typically happens when a pre-release chart deployed a newer Langfuse version than the major release chart.
This occurs because pre-release charts may use floating version tags (like `:3`) which can deploy newer application versions with migrations that are not included in specific versioned releases.

**Solution:** Deploy a specific version of the chart that includes all required migrations or overwrite the appVersion configuration to use the latest Langfuse release.

## Additional Notes

- The chart now supports better separation of concerns between web and worker deployments
- New configurations provide more flexibility for production deployments
- Health checks are more configurable and robust
- Secret management is more secure with the new structure
- Environment variables are now better organized and integrated into the chart structure

For more detailed information, please refer to the [official Langfuse documentation](https://langfuse.com/docs). 
