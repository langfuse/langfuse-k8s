# langfuse

![Version: 2.0.0](https://img.shields.io/badge/Version-2.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 4.4.0](https://img.shields.io/badge/AppVersion-4.4.0-informational?style=flat-square)

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
| https://groundhog2k.github.io/helm-charts/ | postgresql(postgres) | 1.6.3 |
| https://seaweedfs.github.io/seaweedfs/helm | s3(seaweedfs) | 4.23.0 |
| https://valkey-io.github.io/valkey-helm | redis(valkey) | 0.9.4 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| clickhouse.auth.existingSecret | string | `""` | Existing Secret holding the ClickHouse password. When set, auth.password is ignored. |
| clickhouse.auth.existingSecretKey | string | `""` | Key within existingSecret that contains the ClickHouse password. |
| clickhouse.auth.password | string | `""` | Password Langfuse uses to authenticate to ClickHouse. Leave empty to have the chart generate one. |
| clickhouse.auth.username | string | `"default"` | Username Langfuse uses to authenticate to ClickHouse. |
| clickhouse.cluster.affinity | object | `{}` | Affinity rules for ClickHouse pods. |
| clickhouse.cluster.enabled | bool | `true` | Enable ON CLUSTER DDL in Langfuse (CLICKHOUSE_CLUSTER_ENABLED). Disable only for an external non-clustered ClickHouse. |
| clickhouse.cluster.image.repository | string | `"clickhouse/clickhouse-server"` | ClickHouse server image repository. |
| clickhouse.cluster.image.tag | string | `"26.4"` | ClickHouse server image tag. Keep aligned with the version recommended for Langfuse v4. |
| clickhouse.cluster.nodeSelector | object | `{}` | Node selector for ClickHouse pods. |
| clickhouse.cluster.profileSettings | object | `{}` | Extra ClickHouse user profile settings mounted into users.xml. |
| clickhouse.cluster.replicas | int | `1` | Number of ClickHouse replicas. 1 is a valid single-pod cluster; 2+ requires Keeper enabled. |
| clickhouse.cluster.resources | object | `{"limits":{"memory":"4Gi"},"requests":{"cpu":"1","memory":"2Gi"}}` | CPU/memory for ClickHouse pods. Non-empty defaults avoid the operator's ~1Gi fallback that OOMs under load. |
| clickhouse.cluster.settings | object | `{}` | Extra ClickHouse server settings applied under the `<clickhouse>` config section. |
| clickhouse.cluster.storage.accessModes[0] | string | `"ReadWriteOnce"` |  |
| clickhouse.cluster.storage.className | string | `""` | StorageClass for ClickHouse PVCs. Leave empty to use the cluster default. |
| clickhouse.cluster.storage.size | string | `"100Gi"` | Persistent volume size for each ClickHouse pod. |
| clickhouse.cluster.tolerations | list | `[]` | Tolerations for ClickHouse pods. |
| clickhouse.crdCheck | bool | `true` | Require ClickHouse operator CRDs when deploy is true. Disable for offline helm template/GitOps diffs (or pass `--api-versions clickhouse.com/v1alpha1/ClickHouseCluster`). |
| clickhouse.database | string | `"default"` | ClickHouse database name Langfuse connects to. |
| clickhouse.deploy | bool | `true` | Deploy ClickHouse (ClickHouseCluster + KeeperCluster CRs) via the operator. Disable to use an external or self-managed ClickHouse. |
| clickhouse.host | string | `""` | ClickHouse hostname Langfuse connects to. Auto-set from the cluster Service when deploy is true; set explicitly for external ClickHouse. |
| clickhouse.httpPort | int | `8123` | HTTP port Langfuse uses to talk to ClickHouse. |
| clickhouse.keeper.affinity | object | `{}` | Affinity rules for Keeper pods. |
| clickhouse.keeper.enabled | bool | `true` | Deploy a KeeperCluster alongside ClickHouse. Must stay enabled while clickhouse.deploy is true — the ClickHouseCluster CRD requires a keeperClusterRef even for a single replica. Run ClickHouse externally (clickhouse.deploy=false + clickhouse.host) to avoid Keeper. |
| clickhouse.keeper.image.repository | string | `"clickhouse/clickhouse-keeper"` | ClickHouse Keeper image repository. |
| clickhouse.keeper.image.tag | string | `"26.4"` | ClickHouse Keeper image tag. Keep aligned with the ClickHouse server tag. |
| clickhouse.keeper.nodeSelector | object | `{}` | Node selector for Keeper pods. |
| clickhouse.keeper.replicas | int | `3` | Keeper replica count (must be odd: 1, 3, or 5). Use 3 for production HA. |
| clickhouse.keeper.resources | object | `{"limits":{"memory":"1Gi"},"requests":{"cpu":"250m","memory":"256Mi"}}` | CPU/memory requests and limits for Keeper pods. |
| clickhouse.keeper.storage.accessModes[0] | string | `"ReadWriteOnce"` |  |
| clickhouse.keeper.storage.className | string | `""` | StorageClass for Keeper PVCs. Leave empty to use the cluster default. |
| clickhouse.keeper.storage.size | string | `"20Gi"` | Persistent volume size for each Keeper pod. |
| clickhouse.keeper.tolerations | list | `[]` | Tolerations for Keeper pods. |
| clickhouse.migration.autoMigrate | bool | `true` | Run ClickHouse schema migrations automatically when Langfuse starts. |
| clickhouse.migration.ssl | bool | `false` | Use SSL for ClickHouse schema migrations. |
| clickhouse.migration.url | string | `""` | ClickHouse migration URL (native TCP). Leave empty to derive from host/port when deploy is true. |
| clickhouse.nativePort | int | `9000` | Native TCP port Langfuse uses to talk to ClickHouse. |
| extraManifests | list | `[]` |  |
| fullnameOverride | string | `""` | Override the full name of the deployed resources, defaults to a combination of the release name and the name for the selector labels |
| langfuse.additionalEnv | list | `[]` | List of additional environment variables to be added to all langfuse deployments. See [documentation](https://langfuse.com/docs/deployment/self-host#configuring-environment-variables) for details. |
| langfuse.additionalEnvFrom | list | `[]` | Secrets or ConfigMap of additional environment variables to be added to all langfuse deployments. See [documentation](https://langfuse.com/docs/deployment/self-host#configuring-environment-variables) for details. |
| langfuse.affinity | object | `{}` | Affinity for all langfuse deployments |
| langfuse.allowV1Upgrade | bool | `false` | Allow helm upgrade that would replace leftover v1 Bitnami stores (CH STS, PG PVC, MinIO Deploy) with empty v2 volumes. Default false. The supported path is examples/upgrade-v1-to-v2 (in-place only when stores are external; otherwise a sibling v2 release). |
| langfuse.allowedOrganizationCreators | list | `[]` | EE: Langfuse allowed organization creators. See [documentation](https://langfuse.com/self-hosting/organization-creators) |
| langfuse.deployment.annotations | object | `{}` | Annotations for all langfuse deployments |
| langfuse.deployment.strategy | object | `{}` | Deployment strategy for all langfuse deployments (can be overridden by individual deployments) |
| langfuse.dnsConfig | object | `{}` | DNS configuration for all langfuse deployments |
| langfuse.encryptionKey | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | Encryption key for sensitive data (256 bits / 64 hex chars). Leave empty to auto-generate on first install (persisted in `<release>-app`); override with value/secretKeyRef to pin. Generate via `openssl rand -hex 32`. |
| langfuse.extraContainers | list | `[]` | Allows additional containers to be added to all langfuse deployments |
| langfuse.extraInitContainers | list | `[]` | Allows additional init containers to be added to all langfuse deployments |
| langfuse.extraLifecycle | object | `{}` | Allows additional lifecycle hooks to be added to all langfuse deployments |
| langfuse.extraVolumeMounts | list | `[]` | Allows additional volume mounts to be added to all langfuse deployments |
| langfuse.extraVolumes | list | `[]` | Allows additional volumes to be added to all langfuse deployments |
| langfuse.features.experimentalFeaturesEnabled | bool | `false` | Enable experimental features |
| langfuse.features.signUpDisabled | bool | `false` | Disable public sign up |
| langfuse.features.telemetryEnabled | bool | `true` | Whether or not to report basic usage statistics to a centralized server. |
| langfuse.image.pullPolicy | string | `"Always"` | The pull policy to use for all langfuse deployments. Can be overridden by the individual deployments. |
| langfuse.image.pullSecrets | list | `[]` | The pull secrets to use for all langfuse deployments. Can be overridden by the individual deployments. |
| langfuse.image.tag | string | `nil` | The image tag to use for all langfuse deployments. Can be overridden by the individual deployments. Falls back to appVersion if not set. |
| langfuse.ingress.additionalLabels | object | `{}` | Additional labels for the ingress resource |
| langfuse.ingress.annotations | object | `{}` | Annotations for the ingress resource |
| langfuse.ingress.className | string | `""` | The class name for the ingress resource |
| langfuse.ingress.enabled | bool | `false` | Set to `true` to enable the ingress resource |
| langfuse.ingress.hosts | list | `[]` | The hosts for the ingress resource |
| langfuse.ingress.tls.enabled | bool | `false` | Set to `true` to enable use HTTPS on the ingress |
| langfuse.ingress.tls.secretName | string | `""` | The name of the secret to use for TLS Key |
| langfuse.licenseKey | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | Langfuse EE license key. |
| langfuse.logging.format | string | `"text"` | Set the log format for the application (text or json) |
| langfuse.logging.level | string | `"info"` | Set the log level for the application (trace, debug, info, warn, error, fatal) |
| langfuse.nextauth.secret | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | NextAuth secret for JWT encryption and email token hashing. Leave empty to auto-generate on first install (persisted in `<release>-app`); override with value/secretKeyRef to pin. |
| langfuse.nextauth.url | string | `"http://localhost:3000"` | When deploying to production, set the `nextauth.url` value to the canonical URL of your site. |
| langfuse.nodeEnv | string | `"production"` | Node.js environment to use for all langfuse deployments |
| langfuse.nodeSelector | object | `{}` | Node selector for all langfuse deployments |
| langfuse.pod.annotations | object | `{}` | Annotations for all langfuse pods |
| langfuse.pod.labels | object | `{}` | Labels for all langfuse pods |
| langfuse.pod.topologySpreadConstraints | list | `[]` | Topology spread constraints for all langfuse pods |
| langfuse.podSecurityContext | object | `{}` | Pod security context for all langfuse deployments |
| langfuse.replicas | int | `1` | Number of replicas to use for all langfuse deployments. Can be overridden by the individual deployments |
| langfuse.resources | object | `{}` | Resources for all langfuse deployments. Can be overridden by the individual deployments |
| langfuse.revisionHistoryLimit | int | `10` | Number of old ReplicaSets to retain to allow rollback. Can be overridden by the individual deployments |
| langfuse.salt | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | Salt used to hash API keys. Leave empty to auto-generate on first install (persisted in `<release>-app`); override with value/secretKeyRef to pin. Generate via `openssl rand -base64 32`. |
| langfuse.securityContext | object | `{}` | Security context for all langfuse deployments |
| langfuse.serviceAccount.annotations | object | `{}` | Annotations for the service account |
| langfuse.serviceAccount.automountServiceAccountToken | bool | `true` | Whether to automount service account token in pods. Set to false to disable automatic mounting of the service account token. |
| langfuse.serviceAccount.create | bool | `true` | Whether to create a service account for all langfuse deployments |
| langfuse.serviceAccount.name | string | `""` | Override the name of the service account to use, discovered automatically if not set |
| langfuse.smtp.connectionUrl | string | `""` | SMTP connection URL. See [documentation](https://langfuse.com/self-hosting/transactional-emails) |
| langfuse.smtp.fromAddress | string | `""` | From address for emails. Required if connectionUrl is set. |
| langfuse.tolerations | list | `[]` | Tolerations for all langfuse deployments |
| langfuse.web.deployment.additionalLabels | object | `{}` | Additional labels for the langfuse web deployment |
| langfuse.web.deployment.annotations | object | `{}` | Annotations for the web deployment |
| langfuse.web.deployment.strategy | object | `{}` | Deployment strategy for the web deployment. Overrides the global deployment strategy |
| langfuse.web.hostAliases | list | `[]` | Adding records to /etc/hosts in the pod's network. |
| langfuse.web.hpa.annotations | object | `{}` | Annotations for the langfuse web HPA |
| langfuse.web.hpa.enabled | bool | `false` | Set to `true` to enable HPA for the langfuse web pods Note: When both KEDA and HPA are enabled, the deployment will fail. |
| langfuse.web.hpa.maxReplicas | int | `2` | The maximum number of replicas to use for the langfuse web pods |
| langfuse.web.hpa.minReplicas | int | `1` | The minimum number of replicas to use for the langfuse web pods |
| langfuse.web.hpa.targetCPUUtilizationPercentage | int | `50` | The target CPU utilization percentage for the langfuse web pods |
| langfuse.web.image.pullPolicy | string | `nil` | The pull policy to use for the langfuse web pods. Using `langfuse.image.pullPolicy` if not set. |
| langfuse.web.image.pullSecrets | string | `nil` | The pull secrets to use for the langfuse web pods. Using `langfuse.image.pullSecrets` if not set. |
| langfuse.web.image.repository | string | `"docker.langfuse.com/langfuse/langfuse"` | The image repository to use for the langfuse web pods. |
| langfuse.web.image.tag | string | `nil` | The tag to use for the langfuse web pods. Using `langfuse.image.tag` if not set. |
| langfuse.web.keda.containerName | string | `""` | Optional container name to target for metrics (leave empty to target all containers) |
| langfuse.web.keda.enabled | bool | `false` | Set to `true` to enable KEDA for the langfuse web pods Note: When both KEDA and HPA are enabled, the deployment will fail. |
| langfuse.web.keda.maxReplicas | int | `2` | The maximum number of replicas to use for the langfuse web pods |
| langfuse.web.keda.metricType | string | `"Utilization"` | The metric type for scaling (Utilization or AverageValue) |
| langfuse.web.keda.minReplicas | int | `1` | The minimum number of replicas to use for the langfuse web pods |
| langfuse.web.keda.pollingInterval | int | `30` | The polling interval in seconds for checking metrics |
| langfuse.web.keda.triggerType | string | `"cpu"` | The trigger type for scaling (cpu or memory) |
| langfuse.web.keda.value | string | `"50"` | The target utilization percentage for the langfuse web pods |
| langfuse.web.livenessProbe.failureThreshold | int | `3` | Failure threshold for livenessProbe. |
| langfuse.web.livenessProbe.initialDelaySeconds | int | `20` | Initial delay seconds for livenessProbe. |
| langfuse.web.livenessProbe.path | string | `"/api/public/health"` | Path to check for liveness. |
| langfuse.web.livenessProbe.periodSeconds | int | `10` | Period seconds for livenessProbe. |
| langfuse.web.livenessProbe.successThreshold | int | `1` | Success threshold for livenessProbe. |
| langfuse.web.livenessProbe.timeoutSeconds | int | `5` | Timeout seconds for livenessProbe. |
| langfuse.web.pdb.create | bool | `true` | Set to `true` to create a Pod Disruption Budget for the langfuse web pods |
| langfuse.web.pdb.maxUnavailable | string | `""` | Maximum number of unavailable pods during disruptions. Cannot be set simultaneously with minAvailable. Defaults to 1 if neither is set. |
| langfuse.web.pdb.minAvailable | string | `""` | Minimum number of available pods during disruptions. Cannot be set simultaneously with maxUnavailable. |
| langfuse.web.pod.additionalEnv | list | `[]` | List of additional environment variables to be added to all langfuse web pods. See [documentation](https://langfuse.com/docs/deployment/self-host#configuring-environment-variables) for details. |
| langfuse.web.pod.additionalEnvFrom | list | `[]` | Secrets or ConfigMap of additional environment variables to be added to all langfuse web pods. See [documentation](https://langfuse.com/docs/deployment/self-host#configuring-environment-variables) for details. |
| langfuse.web.pod.affinity | string | `nil` | Affinity for the web pods. Overrides the global affinity |
| langfuse.web.pod.annotations | object | `{}` | Annotations for the web pods |
| langfuse.web.pod.extraContainers | list | `[]` | Allows additional containers to be added to all langfuse web pods |
| langfuse.web.pod.labels | object | `{}` | Labels for the web pods |
| langfuse.web.pod.nodeSelector | string | `nil` | Node selector for the web pods. Overrides the global nodeSelector |
| langfuse.web.pod.tolerations | string | `nil` | Tolerations for the web pods. Overrides the global tolerations |
| langfuse.web.pod.topologySpreadConstraints | string | `nil` | Topology spread constraints for the web pods. Overrides the global topologySpreadConstraints |
| langfuse.web.readinessProbe.failureThreshold | int | `3` | Failure threshold for readinessProbe. |
| langfuse.web.readinessProbe.initialDelaySeconds | int | `20` | Initial delay seconds for readinessProbe. |
| langfuse.web.readinessProbe.path | string | `"/api/public/ready"` | Path to check for readiness. |
| langfuse.web.readinessProbe.periodSeconds | int | `10` | Period seconds for readinessProbe. |
| langfuse.web.readinessProbe.successThreshold | int | `1` | Success threshold for readinessProbe. |
| langfuse.web.readinessProbe.timeoutSeconds | int | `5` | Timeout seconds for readinessProbe. |
| langfuse.web.replicas | string | `nil` | Number of replicas to use if HPA is not enabled. Defaults to the global replicas |
| langfuse.web.resources | object | `{}` | Resources for the langfuse web pods. Defaults to the global resources |
| langfuse.web.revisionHistoryLimit | string | `nil` | Number of old ReplicaSets to retain to allow rollback. |
| langfuse.web.service.additionalLabels | object | `{}` | Additional labels for the langfuse web application service |
| langfuse.web.service.annotations | object | `{}` | Annotations for the langfuse web application service |
| langfuse.web.service.externalPort | string | `nil` | The external port that will be exposed by the service. Falls back to `port` if not set. |
| langfuse.web.service.nodePort | string | `nil` | The node port to use for the langfuse web application |
| langfuse.web.service.port | int | `3000` | The port to use for the langfuse web application |
| langfuse.web.service.type | string | `"ClusterIP"` | The type of service to use for the langfuse web application |
| langfuse.web.vpa.controlledResources | list | `[]` | The resources to control for the langfuse web pods |
| langfuse.web.vpa.enabled | bool | `false` | Set to `true` to enable VPA for the langfuse web pods |
| langfuse.web.vpa.maxAllowed | object | `{}` | The maximum allowed resources for the langfuse web pods |
| langfuse.web.vpa.minAllowed | object | `{}` | The minimum allowed resources for the langfuse web pods |
| langfuse.web.vpa.updatePolicy.updateMode | string | `"Auto"` | The update policy mode for the langfuse web pods |
| langfuse.worker.deployment.additionalLabels | object | `{}` | Additional labels for the worker deployment |
| langfuse.worker.deployment.annotations | object | `{}` | Annotations for the worker deployment |
| langfuse.worker.deployment.strategy | object | `{}` | Deployment strategy for the worker deployment. Overrides the global deployment strategy |
| langfuse.worker.hostAliases | list | `[]` | Adding records to /etc/hosts in the worker pod's network. |
| langfuse.worker.hpa.annotations | object | `{}` | Annotations for the langfuse worker HPA |
| langfuse.worker.hpa.enabled | bool | `false` | Set to `true` to enable HPA for the langfuse worker pods Note: When both KEDA and HPA are enabled, the deployment will fail. |
| langfuse.worker.hpa.maxReplicas | int | `2` | The maximum number of replicas to use for the langfuse worker pods |
| langfuse.worker.hpa.minReplicas | int | `1` | The minimum number of replicas to use for the langfuse worker pods |
| langfuse.worker.hpa.targetCPUUtilizationPercentage | int | `50` | The target CPU utilization percentage for the langfuse worker pods |
| langfuse.worker.image.pullPolicy | string | `nil` | The pull policy to use for the langfuse worker pods. Using `langfuse.image.pullPolicy` if not set. |
| langfuse.worker.image.pullSecrets | string | `nil` | The pull secrets to use for the langfuse worker pods. Using `langfuse.image.pullSecrets` if not set. |
| langfuse.worker.image.repository | string | `"docker.langfuse.com/langfuse/langfuse-worker"` | The image repository to use for the langfuse worker pods |
| langfuse.worker.image.tag | string | `nil` | The tag to use for the langfuse worker pods. Using `langfuse.image.tag` if not set. |
| langfuse.worker.keda.containerName | string | `""` | Optional container name to target for metrics (leave empty to target all containers) |
| langfuse.worker.keda.enabled | bool | `false` | Set to `true` to enable KEDA for the langfuse worker pods Note: When both KEDA and HPA are enabled, the deployment will fail. |
| langfuse.worker.keda.maxReplicas | int | `2` | The maximum number of replicas to use for the langfuse worker pods |
| langfuse.worker.keda.metricType | string | `"Utilization"` | The metric type for scaling (Utilization or AverageValue) |
| langfuse.worker.keda.minReplicas | int | `1` | The minimum number of replicas to use for the langfuse worker pods |
| langfuse.worker.keda.pollingInterval | int | `30` | The polling interval in seconds for checking metrics |
| langfuse.worker.keda.triggerType | string | `"cpu"` | The trigger type for scaling (cpu or memory) |
| langfuse.worker.keda.value | string | `"50"` | The target utilization percentage for the langfuse worker pods |
| langfuse.worker.livenessProbe.failureThreshold | int | `3` | Failure threshold for livenessProbe. |
| langfuse.worker.livenessProbe.initialDelaySeconds | int | `20` | Initial delay seconds for livenessProbe. |
| langfuse.worker.livenessProbe.periodSeconds | int | `10` | Period seconds for livenessProbe. |
| langfuse.worker.livenessProbe.successThreshold | int | `1` | Success threshold for livenessProbe. |
| langfuse.worker.livenessProbe.timeoutSeconds | int | `5` | Timeout seconds for livenessProbe. |
| langfuse.worker.pdb.create | bool | `true` | Set to `true` to create a Pod Disruption Budget for the worker deployment |
| langfuse.worker.pdb.maxUnavailable | string | `""` | Maximum number of unavailable pods during disruptions. Cannot be set simultaneously with minAvailable. Defaults to 1 if neither is set. |
| langfuse.worker.pdb.minAvailable | string | `""` | Minimum number of available pods during disruptions. Cannot be set simultaneously with maxUnavailable. |
| langfuse.worker.pod.additionalEnv | list | `[]` | List of additional environment variables to be added to all langfuse worker pods. See [documentation](https://langfuse.com/docs/deployment/self-host#configuring-environment-variables) for details. |
| langfuse.worker.pod.additionalEnvFrom | list | `[]` | Secrets or ConfigMap of additional environment variables to be added to all langfuse worker pods. See [documentation](https://langfuse.com/docs/deployment/self-host#configuring-environment-variables) for details. |
| langfuse.worker.pod.affinity | string | `nil` | Affinity for the worker pods. Overrides the global affinity |
| langfuse.worker.pod.annotations | object | `{}` | Annotations for the worker pods |
| langfuse.worker.pod.extraContainers | list | `[]` | Allows additional containers to be added to all langfuse worker pods |
| langfuse.worker.pod.labels | object | `{}` | Labels for the worker pods |
| langfuse.worker.pod.nodeSelector | string | `nil` | Node selector for the worker pods. Overrides the global nodeSelector |
| langfuse.worker.pod.tolerations | string | `nil` | Tolerations for the worker pods. Overrides the global tolerations |
| langfuse.worker.pod.topologySpreadConstraints | string | `nil` | Topology spread constraints for the worker pods. Overrides the global topologySpreadConstraints |
| langfuse.worker.replicas | string | `nil` | Number of replicas to use if HPA is not enabled. Defaults to the global replicas |
| langfuse.worker.resources | object | `{}` | Resources for the langfuse worker pods. Defaults to the global resources |
| langfuse.worker.revisionHistoryLimit | string | `nil` | Number of old ReplicaSets to retain to allow rollback. |
| langfuse.worker.vpa.controlledResources | list | `[]` | The resources to control for the langfuse worker pods |
| langfuse.worker.vpa.enabled | bool | `false` | Set to `true` to enable VPA for the langfuse worker pods |
| langfuse.worker.vpa.maxAllowed | object | `{}` | The maximum allowed resources for the langfuse worker pods |
| langfuse.worker.vpa.minAllowed | object | `{}` | The minimum allowed resources for the langfuse worker pods |
| langfuse.worker.vpa.updatePolicy.updateMode | string | `"Auto"` | The update policy mode for the langfuse worker pods |
| nameOverride | string | `""` | Override the name for the selector labels, defaults to the chart name |
| postgresql.affinity | object | `{}` |  |
| postgresql.args | string | `""` | Additional database connection arguments |
| postgresql.auth.args | string | `""` | Additional database connection arguments |
| postgresql.auth.database | string | `"langfuse"` | Database name Langfuse uses. Created automatically by the sub-chart when deploy is true. |
| postgresql.auth.existingSecret | string | `""` | If you want to use an existing secret for the postgres password, set the name of the secret here. (`postgresql.auth.password` will be ignored and picked up from this secret). |
| postgresql.auth.password | string | `""` | Password Langfuse uses to connect to PostgreSQL. Leave empty to have the chart generate one (stored in a release-managed Secret). |
| postgresql.auth.secretKeys | object | `{"adminPasswordKey":"postgres-password","userPasswordKey":"password"}` | Keys in existingSecret: userPasswordKey for Langfuse; adminPasswordKey for the Postgres superuser when deploy is true. |
| postgresql.auth.username | string | `"langfuse"` | Username Langfuse uses to connect to PostgreSQL. Created automatically by the sub-chart when deploy is true. |
| postgresql.deploy | bool | `true` | Deploy PostgreSQL via the bundled groundhog2k/postgres sub-chart. Disable to use an external or managed Postgres. |
| postgresql.directUrl | string | `""` | If `postgresql.deploy` is set to false, Connection string of your Postgres database used for database migrations. Use this if you want to use a different user for migrations or use connection pooling on DATABASE_URL. For large deployments, configure the database user with long timeouts as migrations might need a while to complete. |
| postgresql.host | string | `""` | PostgreSQL host to connect to. If postgresql.deploy is true, this will be set automatically based on the release name. |
| postgresql.image.pullPolicy | string | `"IfNotPresent"` |  |
| postgresql.image.repository | string | `"postgres"` | Postgres image. Defaults to the upstream Docker Hub image (Apache 2.0 / PostgreSQL license). |
| postgresql.image.tag | string | `"18"` |  |
| postgresql.livenessProbe | object | `{}` | Liveness / readiness probe customisations (see groundhog2k/postgres docs). |
| postgresql.migration.autoMigrate | bool | `true` | Whether to run automatic migrations on startup |
| postgresql.nodeSelector | object | `{}` | Node selector / tolerations / affinity for the Postgres pod. |
| postgresql.podSecurityContext | object | `{"fsGroup":999}` | Pod security context. |
| postgresql.port | string | `nil` | Port of the postgres server to use. Defaults to 5432. |
| postgresql.readinessProbe | object | `{}` |  |
| postgresql.replicaCount | int | `1` | Number of replicas for the Postgres StatefulSet. Single-instance only — set to 0 to suspend. |
| postgresql.resources | object | `{}` | Resource limits/requests for the Postgres pod. Tune for your workload. |
| postgresql.securityContext | object | `{"runAsGroup":999,"runAsUser":999}` | Container security context. |
| postgresql.service.port | int | `5432` | Port the Postgres Service exposes. Must match `postgresql.port` (or the langfuse default 5432). |
| postgresql.service.type | string | `"ClusterIP"` |  |
| postgresql.settings | object | `{"existingSecret":"langfuse-postgresql-auth","superuserPassword":{}}` | Pass-through Postgres settings for the groundhog2k sub-chart. Usually left alone; helpers wire the chart-managed Secret automatically. |
| postgresql.settings.existingSecret | string | `"langfuse-postgresql-auth"` | Existing Secret for the superuser password (keys: POSTGRES_USER, POSTGRES_PASSWORD). Single source of truth for the chart-managed Secret's name — the chart creates the Secret under this exact name, so any release name works. Override it (together with userDatabase.existingSecret) when running two releases in one namespace. |
| postgresql.settings.superuserPassword | object | `{}` | Postgres superuser password. Auto-derived from the chart-managed Secret unless existingSecret is set. |
| postgresql.shadowDatabaseUrl | string | `""` | If your database user lacks the CREATE DATABASE permission, you must create a shadow database and configure the "SHADOW_DATABASE_URL". This is often the case if you use a Cloud database. Refer to the Prisma docs for detailed instructions. |
| postgresql.startupProbe | object | `{}` |  |
| postgresql.storage | object | `{"className":"","persistentVolumeClaimRetentionPolicy":{"whenDeleted":"Retain","whenScaled":"Retain"},"requestedSize":"20Gi"}` | PVC settings for the Postgres data volume. |
| postgresql.storage.className | string | `""` | StorageClass name. Leave empty to use the cluster's default. |
| postgresql.storage.persistentVolumeClaimRetentionPolicy | object | `{"whenDeleted":"Retain","whenScaled":"Retain"}` | Keep the PVC after the release is uninstalled. |
| postgresql.tolerations | list | `[]` |  |
| postgresql.userDatabase | object | `{"existingSecret":"langfuse-postgresql-auth","name":{},"password":{},"user":{}}` | Bootstrap the Langfuse database/user on first start. Empty name/user/password maps use defaults from auth.* via the chart-managed Secret. |
| postgresql.userDatabase.existingSecret | string | `"langfuse-postgresql-auth"` | Existing Secret for userDatabase credentials (keys: USERDB_USER, USERDB_PASSWORD, POSTGRES_DB). Must match settings.existingSecret when the chart manages the Secret (validated at render time). |
| redis.auth.aclConfig | string | `""` | Pass-through to valkey-helm: extra inline ACL config appended after `aclUsers`. |
| redis.auth.aclUsers | object | `{"default":{"permissions":"~* &* +@all"}}` | Valkey ACL users to create. Must include "default" when auth.enabled is true; `~* &* +@all` grants full access. |
| redis.auth.database | int | `0` |  |
| redis.auth.enabled | bool | `true` | Enable ACL-based authentication on the bundled Valkey sub-chart. |
| redis.auth.existingSecret | string | `""` | Existing Secret holding the Redis password. When set, auth.password is ignored and the chart-managed Secret is not created. |
| redis.auth.existingSecretPasswordKey | string | `""` | The key in the existing secret that contains the password. |
| redis.auth.password | string | `""` | Redis password Langfuse authenticates with. Leave empty to auto-generate; set null to disable auth. URL-encode special characters. |
| redis.auth.username | string | `"default"` | Redis username Langfuse authenticates with. Set null to omit from the connection string; created as an ACL user when deploy is true. |
| redis.auth.usersExistingSecret | string | `"langfuse-redis-auth"` | Valkey ACL users Secret (one key per username). Single source of truth for the chart-managed Secret's name — the chart creates the Secret under this exact name, so any release name works. Override when running two releases in one namespace. |
| redis.cluster.enabled | bool | `false` | Set to `true` to enable Redis Cluster mode. When enabled, you must set `redis.deploy` to `false` and provide cluster nodes. |
| redis.cluster.nodes | list | `[]` | List of Redis cluster nodes in the format "host:port". Example: ["redis-1:6379", "redis-2:6379", "redis-3:6379"] |
| redis.dataStorage | object | `{"accessModes":["ReadWriteOnce"],"className":"","enabled":true,"keepPvc":false,"requestedSize":"8Gi"}` | Persistence for the primary node. |
| redis.deploy | bool | `true` | Deploy Valkey via the bundled valkey-io/valkey sub-chart. Disable to use an external Redis or Valkey. |
| redis.extraFlags | list | `["--maxmemory-policy","noeviction"]` | Set the maxmemory eviction policy. Langfuse requires `noeviction` to avoid losing job data. |
| redis.host | string | `""` | Redis host to connect to. If redis.deploy is true, this will be set automatically based on the release name. |
| redis.image.pullPolicy | string | `"IfNotPresent"` |  |
| redis.image.registry | string | `"docker.io"` |  |
| redis.image.repository | string | `"valkey/valkey"` |  |
| redis.image.tag | string | `"8.0"` |  |
| redis.metrics.enabled | bool | `false` | Enable the bundled Valkey Prometheus exporter sidecar. |
| redis.podSecurityContext.fsGroup | int | `1000` |  |
| redis.podSecurityContext.runAsGroup | int | `1000` |  |
| redis.podSecurityContext.runAsUser | int | `1000` |  |
| redis.podSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| redis.port | int | `6379` | Redis port to connect to. |
| redis.replica | object | `{"enabled":false,"persistence":{"accessModes":["ReadWriteOnce"],"size":"8Gi","storageClass":""},"replicas":0,"service":{"enabled":true,"port":6379,"type":"ClusterIP"}}` | Valkey replication. Default standalone; set enabled and replicas for primary/replica (Langfuse always targets the primary). |
| redis.resources | object | `{}` | Resource limits/requests for the Valkey pods. |
| redis.sentinel.enabled | bool | `false` | Set to `true` to enable Redis Sentinel mode. Cannot be enabled simultaneously with cluster mode. When enabled, you must set `redis.deploy` to `false`. |
| redis.sentinel.existingSecret | string | `""` | If you want to use an existing secret for the sentinel password, set the name of the secret here. (`redis.sentinel.password` will be ignored and picked up from this secret). |
| redis.sentinel.existingSecretPasswordKey | string | `""` | The key in the existing secret that contains the sentinel password. |
| redis.sentinel.masterName | string | `""` | Name of the Redis Sentinel master. Required when `redis.sentinel.enabled` is `true`. |
| redis.sentinel.nodes | string | `""` | Comma-separated list of Redis Sentinel nodes in the format "host:port". Example: "sentinel-1:26379,sentinel-2:26379,sentinel-3:26379". Required when `redis.sentinel.enabled` is `true`. |
| redis.sentinel.password | string | `""` | Password for Redis Sentinel authentication (optional). |
| redis.sentinel.username | string | `""` | Username for Redis Sentinel authentication (optional). |
| redis.service.port | int | `6379` | Port the primary Valkey Service exposes. |
| redis.service.type | string | `"ClusterIP"` |  |
| redis.tls.caPath | string | `""` | Path to the CA certificate file for TLS verification (mounted into Langfuse pods). |
| redis.tls.certPath | string | `""` | Path to the client certificate file for mutual TLS authentication. |
| redis.tls.enabled | bool | `false` | Enable TLS for Langfuse↔Redis. When deploy is true, also enables TLS on the Valkey sub-chart. |
| redis.tls.keyPath | string | `""` | Path to the client private key file for mutual TLS authentication. |
| s3.accessKeyId | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 accessKeyId to use for all uploads. Can be overridden per upload type. |
| s3.allInOne.data.accessModes[0] | string | `"ReadWriteOnce"` |  |
| s3.allInOne.data.size | string | `"50Gi"` |  |
| s3.allInOne.data.storageClass | string | `""` |  |
| s3.allInOne.data.type | string | `"persistentVolumeClaim"` | Persistence for the SeaweedFS data directory. |
| s3.allInOne.enabled | bool | `true` |  |
| s3.allInOne.image.pullPolicy | string | `"IfNotPresent"` |  |
| s3.allInOne.image.registry | string | `"docker.io"` |  |
| s3.allInOne.image.repository | string | `"chrislusf/seaweedfs"` |  |
| s3.allInOne.image.tag | string | `"3.95"` |  |
| s3.allInOne.resources.limits.cpu | int | `2` |  |
| s3.allInOne.resources.limits.memory | string | `"2Gi"` |  |
| s3.allInOne.resources.requests.cpu | string | `"500m"` |  |
| s3.allInOne.resources.requests.memory | string | `"1Gi"` |  |
| s3.allInOne.s3.createBuckets | list | `[{"name":"langfuse"}]` | Buckets to create by the SeaweedFS post-install/post-upgrade hook. Must include every bucket Langfuse uses (`s3.bucket` and any per-upload-type overrides) — validated at render time. |
| s3.allInOne.s3.createBucketsHook.resources | object | `{}` |  |
| s3.allInOne.s3.enableAuth | bool | `true` |  |
| s3.allInOne.s3.enabled | bool | `true` |  |
| s3.allInOne.s3.existingConfigSecret | string | `"langfuse-s3-auth"` | SeaweedFS IAM config Secret. Single source of truth for the chart-managed Secret's name — the chart creates the Secret (from s3.auth) under this exact name, so any release name works. Override when running two releases in one namespace. |
| s3.allInOne.s3.port | int | `8333` |  |
| s3.allInOne.service.internalTrafficPolicy | string | `"Cluster"` |  |
| s3.allInOne.service.type | string | `"ClusterIP"` |  |
| s3.auth.existingSecret | string | `""` | Existing Secret for S3 access/secret keys (via rootUserSecretKey / rootPasswordSecretKey). |
| s3.auth.rootPassword | string | `""` | S3 secret access key Langfuse uses against the SeaweedFS gateway. Leave empty to have the chart generate one. |
| s3.auth.rootPasswordSecretKey | string | `""` | Key in the existing secret that contains the S3 secret access key. |
| s3.auth.rootUser | string | `"langfuse"` | Access key ID Langfuse uses to authenticate against the SeaweedFS S3 gateway. |
| s3.auth.rootUserSecretKey | string | `""` | Key in the existing secret that contains the S3 access key ID. |
| s3.batchExport.accessKeyId | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 accessKeyId to use for batch exports. |
| s3.batchExport.bucket | string | `""` | S3 bucket to use for batch exports. |
| s3.batchExport.enabled | bool | `true` | Enable batch export. |
| s3.batchExport.endpoint | string | `""` | S3 endpoint to use for batch exports. |
| s3.batchExport.forcePathStyle | string | `nil` | Whether to force path style on requests. Required for SeaweedFS / MinIO. |
| s3.batchExport.prefix | string | `""` | Prefix to use for batch exports within the bucket. |
| s3.batchExport.region | string | `""` | S3 region to use for batch exports. |
| s3.batchExport.secretAccessKey | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 secretAccessKey to use for batch exports. |
| s3.bucket | string | `"langfuse"` | Default S3 bucket for uploads (overridable per upload type). Auto-created on SeaweedFS when deploy is true. |
| s3.concurrency.reads | int | `50` | Maximum number of concurrent read operations to S3. Defaults to 50. |
| s3.concurrency.writes | int | `50` | Maximum number of concurrent write operations to S3. Defaults to 50. |
| s3.defaultBuckets | string | `"langfuse"` | Legacy default bucket list; first entry is used when neither s3.bucket nor a per-upload bucket is set. |
| s3.deploy | bool | `true` | Deploy SeaweedFS via the bundled seaweedfs sub-chart. Disable to use external S3-compatible storage. |
| s3.endpoint | string | `""` | S3 endpoint for uploads (overridable per upload type). Auto-set to the SeaweedFS Service when deploy is true. |
| s3.eventUpload.accessKeyId | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 accessKeyId to use for event uploads. |
| s3.eventUpload.bucket | string | `""` | S3 bucket to use for event uploads. |
| s3.eventUpload.endpoint | string | `""` | S3 endpoint to use for event uploads. |
| s3.eventUpload.forcePathStyle | string | `nil` | Whether to force path style on requests. Required for SeaweedFS / MinIO. |
| s3.eventUpload.prefix | string | `""` | Prefix to use for event uploads within the bucket. |
| s3.eventUpload.region | string | `""` | S3 region to use for event uploads. |
| s3.eventUpload.secretAccessKey | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 secretAccessKey to use for event uploads. |
| s3.filer.enabled | bool | `false` |  |
| s3.forcePathStyle | bool | `true` | Whether to force path style on requests. Required for SeaweedFS / MinIO. Can be overridden per upload type. |
| s3.gcs.credentials | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | GCS credentials JSON (or secretKeyRef). Falls back to the pod's environment/service account credentials if unset. |
| s3.master.enabled | bool | `false` |  |
| s3.mediaUpload.accessKeyId | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 accessKeyId to use for media uploads. |
| s3.mediaUpload.bucket | string | `""` | S3 bucket to use for media uploads. |
| s3.mediaUpload.downloadUrlExpirySeconds | int | `3600` | Expiry time for download URLs. Defaults to 1 hour. |
| s3.mediaUpload.enabled | bool | `true` | Enable media uploads. |
| s3.mediaUpload.endpoint | string | `""` | S3 endpoint to use for media uploads. |
| s3.mediaUpload.forcePathStyle | string | `nil` | Whether to force path style on requests. Required for SeaweedFS / MinIO. |
| s3.mediaUpload.maxContentLength | int | `1000000000` | Maximum content length for media uploads. Defaults to 1GB. |
| s3.mediaUpload.prefix | string | `""` | Prefix to use for media uploads within the bucket. |
| s3.mediaUpload.region | string | `""` | S3 region to use for media uploads. |
| s3.mediaUpload.secretAccessKey | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 secretAccessKey to use for media uploads. |
| s3.region | string | `"auto"` | S3 region for uploads (overridable per upload type). |
| s3.s3.enabled | bool | `false` |  |
| s3.secretAccessKey | object | `{"secretKeyRef":{"key":"","name":""},"value":""}` | S3 secretAccessKey to use for all uploads. Can be overridden per upload type. |
| s3.storageProvider | string | `"s3"` | Object storage provider for Langfuse uploads: s3 (default), azure, or gcs. |
| s3.volume.enabled | bool | `false` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
