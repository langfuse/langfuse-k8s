# langfuse

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3](https://img.shields.io/badge/AppVersion-3-informational?style=flat-square)

Open source LLM engineering platform - LLM observability, metrics, evaluations, prompt management.

**Homepage:** <https://langfuse.com/>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| langfuse | <contact@langfuse.com> | <https://langfuse.com/> |

## Source Code

* <https://github.com/langfuse/langfuse>
* <https://github.com/langfuse/langfuse-k8s>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| oci://registry-1.docker.io/bitnamicharts | clickhouse | 7.x.x |
| oci://registry-1.docker.io/bitnamicharts | common | 2.x.x |
| oci://registry-1.docker.io/bitnamicharts | s3(minio) | 14.x.x |
| oci://registry-1.docker.io/bitnamicharts | postgresql | 16.x.x |
| oci://registry-1.docker.io/bitnamicharts | redis(valkey) | 2.x.x |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| clickhouse.auth | object | `{"password":"","username":"default"}` | Authentication configuration |
| clickhouse.auth.password | string | `""` | Password for the ClickHouse user. |
| clickhouse.auth.username | string | `"default"` | Username for the ClickHouse user. |
| clickhouse.clusterEnabled | bool | `true` | Whether to run ClickHouse commands ON CLUSTER |
| clickhouse.database | string | `"default"` | Database name to use |
| clickhouse.deploy | bool | `true` | Enable ClickHouse deployment (via Bitnami Helm Chart). If you want to use an external Clickhouse server (or a managed one), set this to false |
| clickhouse.host | string | `""` | ClickHouse host to connect to. If clickhouse.deploy is true, this will be set automatically based on the release name. |
| clickhouse.httpPort | int | `8123` | ClickHouse HTTP port to connect to. |
| clickhouse.migration | object | `{"autoMigrate":true,"ssl":false,"url":""}` | Migration configuration |
| clickhouse.migration.autoMigrate | bool | `true` | Whether to run automatic ClickHouse migrations on startup |
| clickhouse.migration.ssl | bool | `false` | Set to true to establish SSL connection for migration |
| clickhouse.migration.url | string | `""` | Migration URL (TCP protocol) for clickhouse |
| clickhouse.nativePort | int | `9000` | ClickHouse native port to connect to. |
| clickhouse.replicaCount | int | `3` | Number of replicas to use for the ClickHouse cluster. 1 corresponds to a single, non-HA deployment. |
| clickhouse.resourcesPreset | string | `"2xlarge"` |  |
| clickhouse.shards | int | `1` | Subchart specific settings |
| extraManifests | list | `[]` |  |
| fullnameOverride | string | `""` | Override the full name of the deployed resources, defaults to a combination of the release name and the name for the selector labels |
| langfuse | object | `{"additionalEnv":[],"affinity":{},"encryptionKey":{"key":{"secretKeyRef":{"key":"","name":""},"value":""}},"extraContainers":[],"extraInitContainers":[],"extraVolumeMounts":[],"extraVolumes":[],"features":{"experimentalFeaturesEnabled":false,"signUpDisabled":false,"telemetryEnabled":true},"ingress":{"additionalLabels":{},"annotations":{},"className":"","enabled":false,"hosts":[],"tls":{"enabled":false,"secretName":""}},"licenseKey":{"secretKeyRef":{"key":"","name":""},"value":""},"logging":{"format":"text","level":"info"},"nodeEnv":"production","nodeSelector":{},"podAnnotations":{},"podSecurityContext":{},"replicas":1,"resources":{},"salt":{"secretKeyRef":{"key":"","name":""},"value":""},"securityContext":{},"serviceAccount":{"annotations":{},"create":true,"name":""},"tolerations":[],"web":{"hostAliases":[],"hpa":{"enabled":false,"maxReplicas":2,"minReplicas":1,"targetCPUUtilizationPercentage":50},"image":{"pullPolicy":"Always","pullSecrets":[],"repository":"langfuse/langfuse","tag":3},"livenessProbe":{"failureThreshold":3,"initialDelaySeconds":20,"path":"/api/public/health","periodSeconds":10,"successThreshold":1,"timeoutSeconds":5},"readinessProbe":{"failureThreshold":3,"initialDelaySeconds":20,"path":"/api/public/ready","periodSeconds":10,"successThreshold":1,"timeoutSeconds":5},"replicas":null,"resources":{},"service":{"additionalLabels":{},"annotations":{},"nodePort":null,"port":3000,"type":"ClusterIP"},"vpa":{"controlledResources":[],"enabled":false,"maxAllowed":{},"minAllowed":{},"updatePolicy":{"updateMode":"Auto"}}},"worker":{"hpa":{"enabled":false,"maxReplicas":2,"minReplicas":1,"targetCPUUtilizationPercentage":50},"image":{"pullPolicy":"Always","pullSecrets":[],"repository":"langfuse/langfuse-worker","tag":3},"livenessProbe":{"failureThreshold":3,"initialDelaySeconds":20,"periodSeconds":10,"successThreshold":1,"timeoutSeconds":5},"replicas":null,"resources":{},"vpa":{"controlledResources":[],"enabled":false,"maxAllowed":{},"minAllowed":{},"updatePolicy":{"updateMode":"Auto"}}}}` | Core Langfuse Configuration |
| langfuse.additionalEnv | list | `[]` | List of additional environment variables to be added to all langfuse deployments. See [documentation](https://langfuse.com/docs/deployment/self-host#configuring-environment-variables) for details. |
| langfuse.affinity | object | `{}` | Affinity for all langfuse deployments |
| langfuse.encryptionKey | object | `{"key":{"secretKeyRef":{"key":"","name":""},"value":""}}` | Used to encrypt sensitive data. Must be 256 bits (64 string characters in hex format). Generate via `openssl rand -hex 32`. |
| langfuse.extraContainers | list | `[]` | Allows additional containers to be added to all langfuse deployments |
| langfuse.extraInitContainers | list | `[]` | Allows additional init containers to be added to all langfuse deployments |
| langfuse.extraVolumeMounts | list | `[]` | Allows additional volume mounts to be added to all langfuse deployments |
| langfuse.extraVolumes | list | `[]` | Allows additional volumes to be added to all langfuse deployments |
| langfuse.features | object | `{"experimentalFeaturesEnabled":false,"signUpDisabled":false,"telemetryEnabled":true}` | Feature flags |
| langfuse.features.experimentalFeaturesEnabled | bool | `false` | Enable experimental features |
| langfuse.features.signUpDisabled | bool | `false` | Disable public sign up |
| langfuse.features.telemetryEnabled | bool | `true` | Whether or not to report basic usage statistics to a centralized server. |
| langfuse.licenseKey | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | Langfuse EE license key. |
| langfuse.logging | object | `{"format":"text","level":"info"}` | Logging configuration |
| langfuse.logging.format | string | `"text"` | Set the log format for the application (text or json) |
| langfuse.logging.level | string | `"info"` | Set the log level for the application (trace, debug, info, warn, error, fatal) |
| langfuse.nodeEnv | string | `"production"` | Node.js environment to use for all langfuse deployments |
| langfuse.nodeSelector | object | `{}` | Node selector for all langfuse deployments |
| langfuse.podAnnotations | object | `{}` | Pod annotations for all langfuse deployments |
| langfuse.podSecurityContext | object | `{}` | Pod security context for all langfuse deployments |
| langfuse.replicas | int | `1` | Number of replicas to use for all langfuse deployments, can be overridden by the individual deployments |
| langfuse.resources | object | `{}` | Resources for all langfuse deployments, can be overridden by the individual deployments |
| langfuse.salt | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | Used to hash API keys. Can be configured by value or existing secret reference. If neither value nor secretKeyRef is provided, no salt will be used. |
| langfuse.securityContext | object | `{}` | Security context for all langfuse deployments |
| langfuse.serviceAccount.name | string | `""` | Override the name of the service account to use, discovered automatically if not set |
| langfuse.tolerations | list | `[]` | Tolerations for all langfuse deployments |
| langfuse.web.hostAliases | list | `[]` | Adding records to /etc/hosts in the pod's network. |
| langfuse.web.hpa | object | `{"enabled":false,"maxReplicas":2,"minReplicas":1,"targetCPUUtilizationPercentage":50}` | Horizontal Pod Autoscaler configuration |
| langfuse.web.image | object | `{"pullPolicy":"Always","pullSecrets":[],"repository":"langfuse/langfuse","tag":3}` | Image to use for the langfuse web application |
| langfuse.web.livenessProbe.failureThreshold | int | `3` | Failure threshold for livenessProbe. |
| langfuse.web.livenessProbe.initialDelaySeconds | int | `20` | Initial delay seconds for livenessProbe. |
| langfuse.web.livenessProbe.path | string | `"/api/public/health"` | Path to check for liveness. |
| langfuse.web.livenessProbe.periodSeconds | int | `10` | Period seconds for livenessProbe. |
| langfuse.web.livenessProbe.successThreshold | int | `1` | Success threshold for livenessProbe. |
| langfuse.web.livenessProbe.timeoutSeconds | int | `5` | Timeout seconds for livenessProbe. |
| langfuse.web.readinessProbe.failureThreshold | int | `3` | Failure threshold for readinessProbe. |
| langfuse.web.readinessProbe.initialDelaySeconds | int | `20` | Initial delay seconds for readinessProbe. |
| langfuse.web.readinessProbe.path | string | `"/api/public/ready"` | Path to check for readiness. |
| langfuse.web.readinessProbe.periodSeconds | int | `10` | Period seconds for readinessProbe. |
| langfuse.web.readinessProbe.successThreshold | int | `1` | Success threshold for readinessProbe. |
| langfuse.web.readinessProbe.timeoutSeconds | int | `5` | Timeout seconds for readinessProbe. |
| langfuse.web.replicas | string | `nil` | Number of replicas to use if HPA is not enabled. Defaults to the global replicas |
| langfuse.web.resources | object | `{}` | Resources for the langfuse web application. Defaults to the global resources |
| langfuse.web.service | object | `{"additionalLabels":{},"annotations":{},"nodePort":null,"port":3000,"type":"ClusterIP"}` | Service configuration for the langfuse web application |
| langfuse.web.vpa | object | `{"controlledResources":[],"enabled":false,"maxAllowed":{},"minAllowed":{},"updatePolicy":{"updateMode":"Auto"}}` | Vertical Pod Autoscaler configuration |
| langfuse.worker.hpa | object | `{"enabled":false,"maxReplicas":2,"minReplicas":1,"targetCPUUtilizationPercentage":50}` | Horizontal Pod Autoscaler configuration |
| langfuse.worker.image | object | `{"pullPolicy":"Always","pullSecrets":[],"repository":"langfuse/langfuse-worker","tag":3}` | Image to use for the langfuse worker application |
| langfuse.worker.livenessProbe.failureThreshold | int | `3` | Failure threshold for livenessProbe. |
| langfuse.worker.livenessProbe.initialDelaySeconds | int | `20` | Initial delay seconds for livenessProbe. |
| langfuse.worker.livenessProbe.periodSeconds | int | `10` | Period seconds for livenessProbe. |
| langfuse.worker.livenessProbe.successThreshold | int | `1` | Success threshold for livenessProbe. |
| langfuse.worker.livenessProbe.timeoutSeconds | int | `5` | Timeout seconds for livenessProbe. |
| langfuse.worker.replicas | string | `nil` | Number of replicas to use if HPA is not enabled. Defaults to the global replicas |
| langfuse.worker.resources | object | `{}` | Resources for the langfuse worker application. Defaults to the global resources |
| langfuse.worker.vpa | object | `{"controlledResources":[],"enabled":false,"maxAllowed":{},"minAllowed":{},"updatePolicy":{"updateMode":"Auto"}}` | Vertical Pod Autoscaler configuration |
| nameOverride | string | `""` | Override the name for the selector labels, defaults to the chart name |
| nextauth | object | `{"secret":{"secretKeyRef":{"key":"","name":""},"value":""},"url":"http://localhost:3000"}` | NextAuth configuration |
| nextauth.secret | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | Used to encrypt the NextAuth.js JWT, and to hash email verification tokens. Can be configured by value or existing secret reference. |
| nextauth.url | string | `"http://localhost:3000"` | When deploying to production, set the `nextauth.url` value to the canonical URL of your site. |
| postgresql | object | `{"architecture":"standalone","auth":{"args":"","database":"postgres_langfuse","existingSecret":"","password":"","secretKeys":{"userPasswordKey":"password"},"username":"postgres"},"deploy":true,"directUrl":"","exportPageSize":1000,"host":"","migration":{"autoMigrate":false},"port":5432,"primary":{"service":{"ports":{"postgresql":5432}}},"shadowDatabaseUrl":""}` | PostgreSQL Configuration |
| postgresql.auth | object | `{"args":"","database":"postgres_langfuse","existingSecret":"","password":"","secretKeys":{"userPasswordKey":"password"},"username":"postgres"}` | Authentication configuration |
| postgresql.auth.args | string | `""` | Additional database connection arguments |
| postgresql.auth.database | string | `"postgres_langfuse"` | Database name to use for Langfuse. |
| postgresql.auth.existingSecret | string | `""` | If you want to use an existing secret for the postgres password, set the name of the secret here. |
| postgresql.auth.password | string | `""` | Password to use to connect to the postgres database deployed with Langfuse. In case `postgresql.deploy` is set to `true`, the password will be set automatically. |
| postgresql.auth.username | string | `"postgres"` | Username to use to connect to the postgres database deployed with Langfuse. In case `postgresql.deploy` is set to `true`, the user will be created automatically. |
| postgresql.deploy | bool | `true` | Deploy subchart or use external database |
| postgresql.directUrl | string | `""` | If `postgresql.deploy` is set to false, Connection string of your Postgres database used for database migrations. Use this if you want to use a different user for migrations or use connection pooling on DATABASE_URL. For large deployments, configure the database user with long timeouts as migrations might need a while to complete. |
| postgresql.exportPageSize | int | `1000` | Optional page size for streaming exports to S3 to avoid memory issues. The page size can be adjusted if needed to optimize performance. |
| postgresql.host | string | `""` | Hostname of the postgres server to use. If `postgresql.deploy` is true, this will be set automatically based on the release name. |
| postgresql.migration | object | `{"autoMigrate":false}` | Migration configuration |
| postgresql.migration.autoMigrate | bool | `false` | Whether to run automatic migrations on startup |
| postgresql.port | int | `5432` | Port of the postgres server to use. |
| postgresql.shadowDatabaseUrl | string | `""` | If your database user lacks the CREATE DATABASE permission, you must create a shadow database and configure the "SHADOW_DATABASE_URL". This is often the case if you use a Cloud database. Refer to the Prisma docs for detailed instructions. |
| redis.architecture | string | `"standalone"` |  |
| redis.auth | object | `{"database":0,"existingSecret":"","existingSecretPasswordKey":"","password":""}` | Authentication configuration |
| redis.auth.existingSecret | string | `""` | If you want to use an existing secret for the redis password, set the name of the secret here. |
| redis.auth.existingSecretPasswordKey | string | `""` | The key in the existing secret that contains the password. |
| redis.auth.password | string | `""` | Configure the password by value or existing secret reference |
| redis.deploy | bool | `true` | Enable valkey deployment (via Bitnami Helm Chart). If you want to use a Redis or Valkey server already deployed, set to false. |
| redis.host | string | `""` | Redis host to connect to. If redis.deploy is true, this will be set automatically based on the release name. |
| redis.port | int | `6379` | Redis port to connect to. |
| redis.primary.extraFlags | list | `["--maxmemory-policy noeviction"]` | Extra flags for the valkey deployment. Must include `--maxmemory-policy noeviction`. |
| s3.accessKeyId | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 accessKeyId to use for all uploads. Can be overridden per upload type. |
| s3.auth.rootPassword | string | `""` |  |
| s3.auth.rootUser | string | `""` |  |
| s3.batchExport.accessKeyId | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 accessKeyId to use for batch exports. |
| s3.batchExport.bucket | string | `""` | S3 bucket to use for batch exports. |
| s3.batchExport.enabled | bool | `true` | Enable batch export. |
| s3.batchExport.endpoint | string | `""` | S3 endpoint to use for batch exports. |
| s3.batchExport.forcePathStyle | bool | `true` | Whether to force path style on requests. Required for MinIO. |
| s3.batchExport.prefix | string | `""` | Prefix to use for batch exports within the bucket. |
| s3.batchExport.region | string | `""` | S3 region to use for batch exports. |
| s3.batchExport.secretAccessKey | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 secretAccessKey to use for batch exports. |
| s3.bucket | string | `""` | S3 bucket to use for all uploads. Can be overridden per upload type. |
| s3.defaultBuckets | string | `"langfuse"` |  |
| s3.deploy | bool | `true` | Enable MinIO deployment (via Bitnami Helm Chart). If you want to use a custom BlobStorage, e.g. S3, set to false. |
| s3.endpoint | string | `""` | S3 endpoint to use for all uploads. Can be overridden per upload type. |
| s3.eventUpload.accessKeyId | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 accessKeyId to use for event uploads. |
| s3.eventUpload.bucket | string | `""` | S3 bucket to use for event uploads. |
| s3.eventUpload.endpoint | string | `""` | S3 endpoint to use for event uploads. |
| s3.eventUpload.forcePathStyle | bool | `true` | Whether to force path style on requests. Required for MinIO. |
| s3.eventUpload.prefix | string | `""` | Prefix to use for event uploads within the bucket. |
| s3.eventUpload.region | string | `"auto"` | S3 region to use for event uploads. |
| s3.eventUpload.secretAccessKey | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 secretAccessKey to use for event uploads. |
| s3.forcePathStyle | bool | `true` | Whether to force path style on requests. Required for MinIO. Can be overridden per upload type. |
| s3.mediaUpload.accessKeyId | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 accessKeyId to use for media uploads. |
| s3.mediaUpload.bucket | string | `""` | S3 bucket to use for media uploads. |
| s3.mediaUpload.downloadUrlExpirySeconds | int | `3600` | Expiry time for download URLs. Defaults to 1 hour. |
| s3.mediaUpload.enabled | bool | `true` | Enable batch export. |
| s3.mediaUpload.endpoint | string | `""` | S3 endpoint to use for media uploads. |
| s3.mediaUpload.forcePathStyle | bool | `true` | Whether to force path style on requests. Required for MinIO. |
| s3.mediaUpload.maxContentLength | int | `1000000000` | Maximum content length for media uploads. Defaults to 1GB. |
| s3.mediaUpload.prefix | string | `""` | Prefix to use for media uploads within the bucket. |
| s3.mediaUpload.region | string | `""` | S3 region to use for media uploads. |
| s3.mediaUpload.secretAccessKey | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 secretAccessKey to use for media uploads. |
| s3.region | string | `"auto"` | S3 region to use for all uploads. Can be overridden per upload type. |
| s3.secretAccessKey | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 secretAccessKey to use for all uploads. Can be overridden per upload type. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
