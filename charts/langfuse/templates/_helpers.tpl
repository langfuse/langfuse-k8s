{{/*
Expand the name of the chart.
*/}}
{{- define "langfuse.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "langfuse.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "langfuse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "langfuse.labels" -}}
helm.sh/chart: {{ include "langfuse.chart" . }}
{{ include "langfuse.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "langfuse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "langfuse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "langfuse.serviceAccountName" -}}
{{- if .Values.langfuse.serviceAccount.create }}
{{- default (include "langfuse.fullname" .) .Values.langfuse.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.langfuse.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return PostgreSQL hostname
*/}}
{{- define "langfuse.postgresql.hostname" -}}
{{- if .Values.postgresql.host }}
{{- .Values.postgresql.host }}
{{- else if .Values.postgresql.deploy }}
{{- printf "%s-postgresql" (include "langfuse.fullname" .) -}}
{{- end }}
{{- end }}

{{/*
Return Redis hostname
*/}}
{{- define "langfuse.redis.hostname" -}}
{{- if .Values.redis.host }}
{{- .Values.redis.host }}
{{- else if .Values.redis.deploy }}
{{- printf "%s-%s-primary" (include "langfuse.fullname" .) (default "redis" .Values.redis.nameOverride) -}}
{{- end }}
{{- end }}

{{/*
Return ClickHouse hostname (without protocol)
*/}}
{{- define "langfuse.clickhouse.hostname" -}}
{{- if .Values.clickhouse.host }}
{{- if hasPrefix "http://" .Values.clickhouse.host -}}
{{- trimPrefix "http://" .Values.clickhouse.host -}}
{{- else if hasPrefix "https://" .Values.clickhouse.host -}}
{{- trimPrefix "https://" .Values.clickhouse.host -}}
{{- else -}}
{{- .Values.clickhouse.host -}}
{{- end -}}
{{- else if .Values.clickhouse.deploy }}
{{- printf "%s-clickhouse" (include "langfuse.fullname" .) -}}
{{- end }}
{{- end }}

{{/*
Return S3/MinIO endpoint -- if not set uses auto-discovery
*/}}
{{- define "langfuse.s3.endpoint" -}}
{{- if or .Values.s3.eventUpload.endpoint .Values.s3.endpoint }}
{{- .Values.s3.eventUpload.endpoint | default .Values.s3.endpoint }}
{{- else if .Values.s3.deploy }}
{{- printf "http://%s-%s:9000" (include "langfuse.fullname" .) (default "s3" .Values.s3.nameOverride) -}}
{{- else }}
{{- end }}
{{- end }}

{{/*
Get a value from either a direct value or a secret reference, or nothing if neither is provided
*/}}
{{- define "langfuse.getValueOrSecret" -}}
{{- if (and .value.secretKeyRef.name .value.secretKeyRef.key) -}}
{{- if .value.value -}}
{{- fail (printf ".value and .secretKeyRef are mutually exclusive for %s" .key) -}}
{{- end -}}
valueFrom:
  secretKeyRef:
    name: {{ .value.secretKeyRef.name }}
    key: {{ .value.secretKeyRef.key }}
{{- else if .value.value -}}
value: {{ .value.value | quote }}
{{- end -}}
{{- end -}}

{{/*
    Get a required value from either a direct value or a secret reference
*/}}
{{- define "langfuse.getRequiredValueOrSecret" -}}
{{- with (include "langfuse.getValueOrSecret" .) -}}
{{ . }}
{{- else -}}
{{ fail (printf "no valid value or secretKeyRef provided for %s" .key) }}
{{- end -}}
{{- end -}}

{{/*
Get value of a specific environment variable from additionalEnv if it exists
*/}}
{{- define "langfuse.getEnvVar" -}}
{{- $envVarName := .name -}}
{{- range .env -}}
{{- if eq .name $envVarName -}}
{{ .value }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
    Database related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.databaseEnv" -}}
{{- with (include "langfuse.getEnvVar" (dict "env" .Values.langfuse.additionalEnv "name" "DATABASE_URL")) -}}
{{/*
    If DATABASE_URL is set, we do nothing in databaseEnv.
*/}}
{{- else -}}
- name: DATABASE_HOST
  value: {{ include "langfuse.postgresql.hostname" . | quote }}
{{- if .Values.postgresql.port }}
- name: DATABASE_PORT
  value: {{ .Values.postgresql.port | quote }}
{{- end }}
{{- if .Values.postgresql.auth.username }}
- name: DATABASE_USERNAME
  value: {{ .Values.postgresql.auth.username | quote }}
{{- end }}
- name: DATABASE_PASSWORD
{{- if .Values.postgresql.auth.existingSecret }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.postgresql.auth.existingSecret }}
      key: {{ required "postgresql.auth.secretKeys.userPasswordKey is required when using an existing secret" .Values.postgresql.auth.secretKeys.userPasswordKey }}
{{- else }}
  value: {{ required "Using an existing secret or postgresql.auth.password is required" .Values.postgresql.auth.password | quote }}
{{- end }}
{{- end }}
{{- if .Values.postgresql.auth.database }}
- name: DATABASE_NAME
  value: {{ .Values.postgresql.auth.database | quote }}
{{- end }}
{{- if .Values.postgresql.args }}
- name: DATABASE_ARGS
  value: {{ .Values.postgresql.args | quote }}
{{- end }}
{{- if .Values.postgresql.directUrl }}
- name: DIRECT_URL
  value: {{ .Values.postgresql.directUrl | quote }}
{{- end }}
{{- if .Values.postgresql.shadowDatabaseUrl }}
- name: SHADOW_DATABASE_URL
  value: {{ .Values.postgresql.shadowDatabaseUrl | quote }}
{{- end }}
- name: LANGFUSE_AUTO_POSTGRES_MIGRATION_DISABLED
  value: {{ not .Values.postgresql.migration.autoMigrate | quote }}
{{- end -}}

{{/*
    Langfuse Server related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.serverEnv" -}}
- name: NODE_ENV
  value: {{ .Values.langfuse.nodeEnv | quote }}
- name: LANGFUSE_LOG_LEVEL
  value: {{ .Values.langfuse.logging.level | quote }}
- name: LANGFUSE_LOG_FORMAT
  value: {{ .Values.langfuse.logging.format | quote }}
{{- with (include "langfuse.getRequiredValueOrSecret" (dict "key" "langfuse.salt" "value" .Values.langfuse.salt) ) }}
- name: SALT
  {{- . | nindent 2 }}
{{- end }}
{{- with (include "langfuse.getValueOrSecret" (dict "key" "langfuse.encryptionKey" "value" .Values.langfuse.encryptionKey) ) }}
- name: ENCRYPTION_KEY
  {{- . | nindent 2 }}
{{- end }}
{{- with (include "langfuse.getValueOrSecret" (dict "key" "langfuse.licenseKey" "value" .Values.langfuse.licenseKey)) }}
- name: LANGFUSE_EE_LICENSE_KEY
  {{- . | nindent 2 }}
{{- end }}
- name: TELEMETRY_ENABLED
  value: {{ .Values.langfuse.features.telemetryEnabled | quote }}
- name: AUTH_DISABLE_SIGNUP
  value: {{ .Values.langfuse.features.signUpDisabled | quote }}
- name: ENABLE_EXPERIMENTAL_FEATURES
  value: {{ .Values.langfuse.features.experimentalFeaturesEnabled | quote }}
{{- if hasKey .Values.langfuse "smtp" }}
{{- if .Values.langfuse.smtp.connectionUrl }}
- name: SMTP_CONNECTION_URL
  value: {{ .Values.langfuse.smtp.connectionUrl | quote }}
- name: EMAIL_FROM_ADDRESS
  value: {{ required "langfuse.smtp.fromAddress has to be set if langfuse.smtp.connectionUrl is configured" .Values.langfuse.smtp.fromAddress | quote }}
{{- end }}
{{- end }}
{{- if hasKey .Values.langfuse "allowedOrganizationCreators" }}
{{- if .Values.langfuse.allowedOrganizationCreators }}
- name: LANGFUSE_ALLOWED_ORGANIZATION_CREATORS
  value: {{ join "," .Values.langfuse.allowedOrganizationCreators | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
    NextAuth related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.nextauthEnv" -}}
- name: NEXTAUTH_URL
  value: {{ .Values.langfuse.nextauth.url | quote }}
- name: NEXTAUTH_SECRET
  {{- include "langfuse.getRequiredValueOrSecret" (dict "key" "langfuse.nextauth.secret" "value" .Values.langfuse.nextauth.secret) | nindent 2 }}
{{- if and (hasKey .Values.langfuse "auth") (hasKey .Values.langfuse.auth "disableUsernamePassword") }}
- name: AUTH_DISABLE_USERNAME_PASSWORD
  value: {{ .Values.langfuse.auth.disableUsernamePassword | quote }}
{{- end }}
{{- if and (hasKey .Values.langfuse "auth") (hasKey .Values.langfuse.auth "providers") }}
{{- range $providerName, $provider := .Values.langfuse.auth.providers }}
{{- range $optionKey, $optionVal := $provider }}
- name: AUTH_{{ $providerName | snakecase | upper }}_{{ $optionKey | snakecase | upper }}
  value: {{ $optionVal | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
    Redis related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.redisEnv" -}}
{{- if or .Values.redis.auth.existingSecret .Values.redis.auth.password }}
- name: REDIS_PASSWORD
{{- if .Values.redis.auth.existingSecret }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.redis.auth.existingSecret }}
      key: {{ required "redis.auth.existingSecretPasswordKey is required when using an existing secret" .Values.redis.auth.existingSecretPasswordKey }}
{{- else }}
  value: {{ required "Using an existing secret or redis.auth.password is required" .Values.redis.auth.password | quote }}
{{- end }}
{{- end }}
{{- if not (include "langfuse.getEnvVar" (dict "env" $.Values.langfuse.additionalEnv "name" "REDIS_CONNECTION_STRING")) }}
- name: REDIS_TLS_ENABLED
  value: {{ .Values.redis.tls.enabled | quote }}
- name: REDIS_CONNECTION_STRING
  value: "{{ if .Values.redis.tls.enabled }}rediss{{ else }}redis{{ end }}://{{ .Values.redis.auth.username }}:$(REDIS_PASSWORD)@{{ include "langfuse.redis.hostname" . }}:{{ .Values.redis.port }}/{{ .Values.redis.auth.database }}"
{{- end }}
{{- if .Values.redis.tls.enabled }}
{{- if .Values.redis.tls.caPath }}
- name: REDIS_TLS_CA_PATH
  value: {{ .Values.redis.tls.caPath | quote }}
{{- end }}
{{- if .Values.redis.tls.certPath }}
- name: REDIS_TLS_CERT_PATH
  value: {{ .Values.redis.tls.certPath | quote }}
{{- end }}
{{- if .Values.redis.tls.keyPath }}
- name: REDIS_TLS_KEY_PATH
  value: {{ .Values.redis.tls.keyPath | quote }}
{{- end }}
{{- end }}
{{- end -}}


{{/*
Return ClickHouse protocol (http or https)
*/}}
{{- define "langfuse.clickhouse.protocol" -}}
{{- if .Values.clickhouse.host }}
{{- if hasPrefix "https://" .Values.clickhouse.host -}}
{{- print "https" -}}
{{- else -}}
{{- print "http" -}}
{{- end -}}
{{- else -}}
{{- print "http" -}}
{{- end -}}
{{- end }}

{{/*
    Clickhouse related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.clickhouseEnv" -}}
{{- with (include "langfuse.getEnvVar" (dict "env" .Values.langfuse.additionalEnv "name" "CLICKHOUSE_MIGRATION_URL")) -}}
{{/*
  If CLICKHOUSE_MIGRATION_URL is set in additionalEnv, we do nothing for ClickHouse env vars, because we assume everything is configured via additionalEnv.
*/}}
{{- else -}}
{{- if or .Values.clickhouse.migration.url .Values.clickhouse.host .Values.clickhouse.deploy }}
- name: CLICKHOUSE_MIGRATION_URL
  {{- if .Values.clickhouse.migration.url }}
  value: {{ .Values.clickhouse.migration.url | quote }}
  {{- else if .Values.clickhouse.host }}
  value: "clickhouse://{{ .Values.clickhouse.host }}:{{ .Values.clickhouse.nativePort }}"
  {{- else if .Values.clickhouse.deploy }}
  value: "clickhouse://{{ include "langfuse.clickhouse.hostname" . }}:{{ .Values.clickhouse.nativePort }}"
  {{- end }}
{{- end }}
{{- if or (hasKey .Values.clickhouse.migration "ssl") .Values.clickhouse.deploy }}
- name: CLICKHOUSE_MIGRATION_SSL
  value: {{ .Values.clickhouse.migration.ssl | quote }}
{{- end }}
{{- if or .Values.clickhouse.host .Values.clickhouse.deploy }}
- name: CLICKHOUSE_URL
  value: "{{ include "langfuse.clickhouse.protocol" . }}://{{ include "langfuse.clickhouse.hostname" . }}:{{ .Values.clickhouse.httpPort }}"
{{- end }}
{{- if or .Values.clickhouse.auth.username .Values.clickhouse.deploy }}
- name: CLICKHOUSE_USER
  {{- if .Values.clickhouse.deploy }}
  value: {{ required "clickhouse.auth.username is required" .Values.clickhouse.auth.username | quote }}
  {{- else }}
  value: {{ .Values.clickhouse.auth.username | quote }}
  {{- end }}
{{- end }}
{{- if or .Values.clickhouse.auth.existingSecret .Values.clickhouse.auth.password .Values.clickhouse.deploy }}
- name: CLICKHOUSE_PASSWORD
{{- if .Values.clickhouse.auth.existingSecret }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.clickhouse.auth.existingSecret }}
      key: {{ required "clickhouse.auth.existingSecretKey is required when using an existing secret" .Values.clickhouse.auth.existingSecretKey }}
{{- else if .Values.clickhouse.auth.password }}
  value: {{ .Values.clickhouse.auth.password | quote }}
{{- else if .Values.clickhouse.deploy }}
  value: {{ required "Configuring an existing secret or clickhouse.auth.password is required" .Values.clickhouse.auth.password | quote }}
{{- end }}
{{- end }}
{{- if and .Values.clickhouse.deploy ($.Values.clickhouse.replicaCount | int | eq 1) }}
- name: CLICKHOUSE_CLUSTER_ENABLED
  value: "false"
{{- end }}
{{- if or (hasKey .Values.clickhouse.migration "autoMigrate") .Values.clickhouse.deploy }}
- name: LANGFUSE_AUTO_CLICKHOUSE_MIGRATION_DISABLED
  value: {{ not .Values.clickhouse.migration.autoMigrate | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
    Get a s3 related config by value or secret. Lookup the bucket value, if not found lookup the shared config.
    If no value or secret is found, return an empty value (e.g. for role IRSA on AWS)
*/}}
{{- define "langfuse.getS3ValueOrSecret" -}}
{{- with (include "langfuse.getValueOrSecret" (dict "key" (printf ".Values.s3.%s.%s" .bucket .key) "value" (index .values .bucket .key)) ) -}}
{{- . }}
{{- else }}
{{- with (include "langfuse.getValueOrSecret" (dict "key" (printf ".Values.s3.%s" .key) "value" (index .values .key)) ) -}}
{{- . }}
{{- else -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
    S3/MinIO related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.s3Env" -}}
{{/* Storage provider specific environment variables */}}
{{- if eq .Values.s3.storageProvider "azure" }}
- name: LANGFUSE_USE_AZURE_BLOB
  value: "true"
{{- else if eq .Values.s3.storageProvider "gcs" }}
- name: LANGFUSE_USE_GOOGLE_CLOUD_STORAGE
  value: "true"
{{- with (include "langfuse.getValueOrSecret" (dict "key" ".Values.s3.gcs.credentials" "value" .Values.s3.gcs.credentials)) }}
- name: LANGFUSE_GOOGLE_CLOUD_STORAGE_CREDENTIALS
  {{- . | nindent 2 }}
{{- end }}
{{- end }}
- name: LANGFUSE_S3_EVENT_UPLOAD_BUCKET
{{- if $.Values.s3.deploy }}
  value: {{ required "s3.[eventUpload].bucket is required" (coalesce .Values.s3.eventUpload.bucket .Values.s3.bucket .Values.s3.defaultBuckets) | quote }}
{{- else }}
  value: {{ required "s3.[eventUpload].bucket is required" (.Values.s3.eventUpload.bucket | default .Values.s3.bucket) | quote }}
{{- end }}
{{- if .Values.s3.eventUpload.prefix }}
- name: LANGFUSE_S3_EVENT_UPLOAD_PREFIX
  value: {{ .Values.s3.eventUpload.prefix | quote }}
{{- end }}
{{- if or .Values.s3.eventUpload.region .Values.s3.region }}
- name: LANGFUSE_S3_EVENT_UPLOAD_REGION
  value: {{ .Values.s3.eventUpload.region | default .Values.s3.region | quote }}
{{- end }}
{{- if or .Values.s3.eventUpload.endpoint .Values.s3.endpoint .Values.s3.deploy }}
- name: LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT
  value: {{ .Values.s3.eventUpload.endpoint | default .Values.s3.endpoint | default (include "langfuse.s3.endpoint" .) | quote }}
{{- end }}
{{- with (include "langfuse.getS3ValueOrSecret" (dict "key" "accessKeyId" "bucket" "eventUpload" "values" .Values.s3) ) }}
- name: LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID
  {{- . | nindent 2 }}
{{- else }}
{{- if .Values.s3.deploy }}
- name: LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID
  {{- if and .Values.s3.auth.existingSecret .Values.s3.auth.rootUserSecretKey }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.auth.existingSecret }}
      key: {{ .Values.s3.auth.rootUserSecretKey }}
  {{- else }}
  value: {{ .Values.s3.auth.rootUser | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- with (include "langfuse.getS3ValueOrSecret" (dict "key" "secretAccessKey" "bucket" "eventUpload" "values" .Values.s3) ) }}
- name: LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY
  {{- . | nindent 2 }}
{{- else }}
{{- if .Values.s3.deploy }}
- name: LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY
  {{- if and .Values.s3.auth.existingSecret .Values.s3.auth.rootPasswordSecretKey }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.auth.existingSecret }}
      key: {{ .Values.s3.auth.rootPasswordSecretKey }}
  {{- else }}
  value: {{ .Values.s3.auth.rootPassword | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- if or (hasKey .Values.s3.eventUpload "forcePathStyle") (hasKey .Values.s3 "forcePathStyle") }}
- name: LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE
  value: {{ .Values.s3.eventUpload.forcePathStyle | default .Values.s3.forcePathStyle | quote }}
{{- end }}
- name: LANGFUSE_S3_BATCH_EXPORT_ENABLED
  value: {{ .Values.s3.batchExport.enabled | quote }}
{{- if $.Values.s3.batchExport.enabled }}
- name: LANGFUSE_S3_BATCH_EXPORT_BUCKET
{{- if $.Values.s3.deploy }}
  value: {{ required "s3.[batchExport].bucket is required" (coalesce .Values.s3.batchExport.bucket .Values.s3.bucket .Values.s3.defaultBuckets) | quote }}
{{- else }}
  value: {{ required "s3.[batchExport].bucket is required" (.Values.s3.batchExport.bucket | default .Values.s3.bucket) | quote }}
{{- end }}
{{- if or .Values.s3.batchExport.prefix .Values.s3.prefix }}
- name: LANGFUSE_S3_BATCH_EXPORT_PREFIX
  value: {{ .Values.s3.batchExport.prefix | default .Values.s3.prefix | quote }}
{{- end }}
{{- if or .Values.s3.batchExport.region .Values.s3.region }}
- name: LANGFUSE_S3_BATCH_EXPORT_REGION
  value: {{ .Values.s3.batchExport.region | default .Values.s3.region | quote }}
{{- end }}
{{- if or .Values.s3.batchExport.endpoint .Values.s3.endpoint .Values.s3.deploy }}
- name: LANGFUSE_S3_BATCH_EXPORT_ENDPOINT
  value: {{ .Values.s3.batchExport.endpoint | default .Values.s3.endpoint | default (include "langfuse.s3.endpoint" .) | quote }}
{{- end }}
{{- with (include "langfuse.getS3ValueOrSecret" (dict "key" "accessKeyId" "bucket" "batchExport" "values" .Values.s3) ) }}
- name: LANGFUSE_S3_BATCH_EXPORT_ACCESS_KEY_ID
  {{- . | nindent 2 }}
{{- else }}
{{- if .Values.s3.deploy }}
- name: LANGFUSE_S3_BATCH_EXPORT_ACCESS_KEY_ID
  {{- if and .Values.s3.auth.existingSecret .Values.s3.auth.rootUserSecretKey }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.auth.existingSecret }}
      key: {{ .Values.s3.auth.rootUserSecretKey }}
  {{- else }}
  value: {{ .Values.s3.auth.rootUser | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- with (include "langfuse.getS3ValueOrSecret" (dict "key" "secretAccessKey" "bucket" "batchExport" "values" .Values.s3) ) }}
- name: LANGFUSE_S3_BATCH_EXPORT_SECRET_ACCESS_KEY
  {{- . | nindent 2 }}
{{- else }}
{{- if .Values.s3.deploy }}
- name: LANGFUSE_S3_BATCH_EXPORT_SECRET_ACCESS_KEY
  {{- if and .Values.s3.auth.existingSecret .Values.s3.auth.rootPasswordSecretKey }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.auth.existingSecret }}
      key: {{ .Values.s3.auth.rootPasswordSecretKey }}
  {{- else }}
  value: {{ .Values.s3.auth.rootPassword | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- if or (hasKey .Values.s3.batchExport "forcePathStyle") (hasKey .Values.s3 "forcePathStyle") }}
- name: LANGFUSE_S3_BATCH_EXPORT_FORCE_PATH_STYLE
  value: {{ .Values.s3.batchExport.forcePathStyle | default .Values.s3.forcePathStyle | quote }}
{{- end }}
{{- end }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_BUCKET
{{- if $.Values.s3.deploy }}
  value: {{ required "s3.[mediaUpload].bucket is required" (coalesce .Values.s3.mediaUpload.bucket .Values.s3.bucket .Values.s3.defaultBuckets) | quote }}
{{- else }}
  value: {{ required "s3.[mediaUpload].bucket is required" (.Values.s3.mediaUpload.bucket | default .Values.s3.bucket) | quote }}
{{- end }}
{{- if or .Values.s3.mediaUpload.prefix .Values.s3.prefix }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_PREFIX
  value: {{ .Values.s3.mediaUpload.prefix | default .Values.s3.prefix | quote }}
{{- end }}
{{- if or .Values.s3.mediaUpload.region .Values.s3.region }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_REGION
  value: {{ .Values.s3.mediaUpload.region | default .Values.s3.region | quote }}
{{- end }}
{{- if or .Values.s3.mediaUpload.endpoint .Values.s3.endpoint .Values.s3.deploy }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT
  value: {{ .Values.s3.mediaUpload.endpoint | default .Values.s3.endpoint | default (include "langfuse.s3.endpoint" .) | quote }}
{{- end }}
{{- with (include "langfuse.getS3ValueOrSecret" (dict "key" "accessKeyId" "bucket" "mediaUpload" "values" .Values.s3) ) }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_ACCESS_KEY_ID
  {{- . | nindent 2 }}
{{- else }}
{{- if .Values.s3.deploy }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_ACCESS_KEY_ID
  {{- if and .Values.s3.auth.existingSecret .Values.s3.auth.rootUserSecretKey }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.auth.existingSecret }}
      key: {{ .Values.s3.auth.rootUserSecretKey }}
  {{- else }}
  value: {{ .Values.s3.auth.rootUser | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- with (include "langfuse.getS3ValueOrSecret" (dict "key" "secretAccessKey" "bucket" "mediaUpload" "values" .Values.s3) ) }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_SECRET_ACCESS_KEY
  {{- . | nindent 2 }}
{{- else }}
{{- if .Values.s3.deploy }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_SECRET_ACCESS_KEY
  {{- if and .Values.s3.auth.existingSecret .Values.s3.auth.rootPasswordSecretKey }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.auth.existingSecret }}
      key: {{ .Values.s3.auth.rootPasswordSecretKey }}
  {{- else }}
  value: {{ .Values.s3.auth.rootPassword | quote }}
  {{- end }}
{{- end }}
{{- end }}
{{- if or (hasKey .Values.s3.mediaUpload "forcePathStyle") (hasKey .Values.s3 "forcePathStyle") }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_FORCE_PATH_STYLE
  value: {{ .Values.s3.mediaUpload.forcePathStyle | default .Values.s3.forcePathStyle | quote }}
{{- end }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_MAX_CONTENT_LENGTH
  value: {{ .Values.s3.mediaUpload.maxContentLength | quote }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_DOWNLOAD_URL_EXPIRY_SECONDS
  value: {{ .Values.s3.mediaUpload.downloadUrlExpirySeconds | quote }}
{{- if hasKey .Values.s3 "concurrency" }}
{{- if hasKey .Values.s3.concurrency "reads" }}
- name: LANGFUSE_S3_CONCURRENT_READS
  value: {{ .Values.s3.concurrency.reads | quote }}
{{- end }}
{{- if hasKey .Values.s3.concurrency "writes" }}
- name: LANGFUSE_S3_CONCURRENT_WRITES
  value: {{ .Values.s3.concurrency.writes | quote }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Common environment variables for all deployments
*/}}
{{- define "langfuse.commonEnv" -}}
{{ include "langfuse.serverEnv" . }}
{{ include "langfuse.nextauthEnv" . }}
{{ include "langfuse.databaseEnv" . }}
{{ include "langfuse.redisEnv" . }}
{{ include "langfuse.clickhouseEnv" . }}
{{ include "langfuse.s3Env" . }}
{{- end -}}
