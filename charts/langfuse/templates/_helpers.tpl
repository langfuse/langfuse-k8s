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
Return PostgreSQL fullname
*/}}
{{- define "langfuse.postgresql.fullname" -}}
{{- if .Values.postgresql.deploy }}
{{- include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" $) -}}
{{- else }}
{{- printf "%s-postgresql" (include "langfuse.fullname" .) -}}
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
    Database related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.databaseEnv" -}}
{{- if .Values.postgresql.host }}
- name: DATABASE_HOST
  value: {{ .Values.postgresql.deploy | ternary (include "langfuse.postgresql.fullname" . | quote) (.Values.postgresql.host | quote) }}
{{- end }}
{{- if .Values.postgresql.auth.username }}
- name: DATABASE_USERNAME
  value: {{ .Values.postgresql.auth.username | quote }}
{{- end }}
- name: DATABASE_PASSWORD
  value: {{ required "postgresql.auth.password is required" .Values.postgresql.auth.password | quote }}
{{- if .Values.postgresql.auth.database }}
- name: DATABASE_NAME
  value: {{ .Values.postgresql.auth.database | quote }}
{{- end }}
{{- if .Values.postgresql.directUrl }}
- name: DIRECT_URL
  value: {{ .Values.postgresql.directUrl | quote }}
{{- end -}}
{{- if .Values.postgresql.shadowDatabaseUrl }}
- name: SHADOW_DATABASE_URL
  value: {{ .Values.postgresql.shadowDatabaseUrl | quote }}
{{- end -}}
- name: LANGFUSE_AUTO_POSTGRES_MIGRATION_DISABLED
  value: {{ not .Values.postgresql.migration.autoMigrate | quote }}
- name: DB_EXPORT_PAGE_SIZE
  value: {{ .Values.postgresql.exportPageSize | quote }}
{{- end -}}

{{/*
    Langfuse Server related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.serverEnv" -}}
- name: NODE_ENV
  value: {{ .Values.langfuse.nodeEnv | quote }}
- name: LANGFUSE_CSP_ENFORCE_HTTPS
  value: {{ .Values.langfuse.cspEnforceHttps | quote }}
- name: LANGFUSE_LOG_LEVEL
  value: {{ .Values.langfuse.logging.level | quote }}
- name: LANGFUSE_LOG_FORMAT
  value: {{ .Values.langfuse.logging.format | quote }}
{{- with (include "langfuse.getValueOrSecret" (dict "key" "langfuse.salt" "value" .Values.langfuse.salt) ) }}
- name: SALT
  {{- . | nindent 2 }}
{{- end }}
{{- with (include "langfuse.getRequiredValueOrSecret" (dict "key" "langfuse.encryptionKey" "value" .Values.langfuse.encryptionKey) ) }}
- name: ENCRYPTION_KEY
  {{- . | nindent 2 }}
{{- end }}
- name: HOSTNAME
  value: "0.0.0.0"
{{- with (include "langfuse.getValueOrSecret" (dict "key" "langfuse.licenseKey" "value" .Values.langfuse.licenseKey)) }}
- name: LANGFUSE_EE_LICENSE_KEY
  {{- . | nindent 2 }}
{{- end }}
- name: TELEMETRY_ENABLED
  value: {{ .Values.langfuse.features.telemetryEnabled | quote }}
- name: NEXT_PUBLIC_SIGN_UP_DISABLED
  value: {{ .Values.langfuse.features.signUpDisabled | quote }}
- name: ENABLE_EXPERIMENTAL_FEATURES
  value: {{ .Values.langfuse.features.experimentalFeaturesEnabled | quote }}
{{- end -}}

{{/*
    NextAuth related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.nextauthEnv" -}}
- name: NEXTAUTH_URL
  value: {{ .Values.nextauth.url | quote }}
- name: NEXTAUTH_SECRET
  {{- include "langfuse.getRequiredValueOrSecret" (dict "key" "nextauth.secret" "value" .Values.nextauth.secret) | nindent 2 }}
{{- end -}}

{{/*
    Redis related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.redisEnv" -}}
- name: REDIS_PASSWORD
  value: {{ required "redis.auth.password is required" .Values.redis.auth.password | quote }}
- name: REDIS_CONNECTION_STRING
  value: "redis://{{ .Values.redis.auth.username | default "default" }}:$(REDIS_PASSWORD)@{{ .Values.redis.host }}:{{ .Values.redis.port }}/{{ .Values.redis.auth.database }}"
{{- end -}}


{{/*
    Clickhouse related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.clickhouseEnv" -}}
- name: CLICKHOUSE_MIGRATION_URL
  value: "clickhouse://{{ .Values.clickhouse.host }}:{{ .Values.clickhouse.nativePort }}"
- name: CLICKHOUSE_URL
  value: "http://{{ .Values.clickhouse.host }}:{{ .Values.clickhouse.httpPort }}"
- name: CLICKHOUSE_USER
  value: {{ required "clickhouse.auth.username is required" .Values.clickhouse.auth.username | quote }}
- name: CLICKHOUSE_PASSWORD
  value: {{ required "clickhouse.auth.password is required" .Values.clickhouse.auth.password | quote }}
{{- if $.Values.clickhouse.replicaCount | int | eq 1 -}}
- name: CLICKHOUSE_CLUSTER_ENABLED
  value: "false"
{{- end -}}
{{- end -}}

{{/*
    Get a s3 related config by value or secret. Lookup the bucket value, if not found lookup the shared config.
*/}}
{{- define "langfuse.getS3ValueOrSecret" -}}
{{- with (include "langfuse.getValueOrSecret" (dict "key" (printf ".Values.s3.%s.%s" .bucket .key) "value" (index .values .bucket .key)) ) -}}
{{- . | nindent 2 }}
{{- else with (include "langfuse.getValueOrSecret" (dict "key" (printf ".Values.s3.%s" .key) "value" (index .values .key)) ) -}}
{{- . | nindent 2 }}
{{- else -}}
{{- fail (printf "no valid value or secretKeyRef provided for .Values.s3.[%s].%s" .bucket .key) }}
{{- end -}}
{{- end -}}

{{/*
    S3/MinIO related configurations by environment variables
    Compare with https://langfuse.com/self-hosting/configuration#environment-variables
*/}}
{{- define "langfuse.s3Env" -}}
- name: LANGFUSE_S3_EVENT_UPLOAD_ENABLED
  value: "true"
- name: LANGFUSE_S3_EVENT_UPLOAD_BUCKET
{{- if $.Values.s3.deploy -}}
  value: {{ coalesce .Values.s3.eventUpload.bucket .Values.s3.bucket .Values.s3.defaultBuckets | quote }}
{{- else -}}
    value: {{ required "s3.[eventUpload].bucket is required" (.Values.s3.eventUpload.bucket | default .Values.s3.bucket) | quote }}
{{- end -}}
{{- if or .Values.s3.eventUpload.prefix .Values.s3.prefix }}
- name: LANGFUSE_S3_EVENT_UPLOAD_PREFIX
  value: {{ .Values.s3.eventUpload.prefix | default .Values.s3.prefix | quote }}
{{- end }}
{{- if or .Values.s3.eventUpload.region .Values.s3.region }}
- name: LANGFUSE_S3_EVENT_UPLOAD_REGION
  value: {{ .Values.s3.eventUpload.region | default .Values.s3.region | quote }}
{{- end }}
{{- if or .Values.s3.eventUpload.endpoint .Values.s3.endpoint }}
- name: LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT
  value: {{ .Values.s3.eventUpload.endpoint | default .Values.s3.endpoint | quote }}
{{- end }}
{{- if or .Values.s3.eventUpload.accessKeyId .Values.s3.accessKeyId }}
- name: LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID
  {{- include "langfuse.getS3ValueOrSecret" (dict "key" "accessKeyId" "bucket" "eventUpload" "values" .Values.s3) | nindent 2 }}
{{- end }}
{{- if or .Values.s3.eventUpload.secretAccessKey .Values.s3.secretAccessKey }}
- name: LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY
  {{- include "langfuse.getS3ValueOrSecret" (dict "key" "secretAccessKey" "bucket" "eventUpload" "values" .Values.s3) | nindent 2 }}
{{- end }}
{{- if or .Values.s3.eventUpload.forcePathStyle .Values.s3.forcePathStyle }}
- name: LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE
  value: {{ .Values.s3.eventUpload.forcePathStyle | default .Values.s3.forcePathStyle | quote }}
{{- end }}

- name: LANGFUSE_S3_BATCH_EXPORT_ENABLED
  value: {{ .Values.s3.batchExport.enabled | quote }}
{{- if $.Values.s3.batchExport.enabled -}}
- name: LANGFUSE_S3_BATCH_EXPORT_BUCKET
{{- if $.Values.s3.deploy -}}
  value: {{ coalesce .Values.s3.batchExport.bucket .Values.s3.bucket .Values.s3.defaultBuckets | quote }}
{{- else -}}
  value: {{ required "s3.[batchExport].bucket is required" (.Values.s3.batchExport.bucket | default .Values.s3.bucket) | quote }}
{{- end -}}
{{- if or .Values.s3.batchExport.prefix .Values.s3.prefix }}
- name: LANGFUSE_S3_BATCH_EXPORT_PREFIX
  value: {{ .Values.s3.batchExport.prefix | default .Values.s3.prefix | quote }}
{{- end }}
{{- if or .Values.s3.batchExport.region .Values.s3.region }}
- name: LANGFUSE_S3_BATCH_EXPORT_REGION
  value: {{ .Values.s3.batchExport.region | default .Values.s3.region | quote }}
{{- end }}
{{- if or .Values.s3.batchExport.endpoint .Values.s3.endpoint }}
- name: LANGFUSE_S3_BATCH_EXPORT_ENDPOINT
  value: {{ .Values.s3.batchExport.endpoint | default .Values.s3.endpoint | quote }}
{{- end }}
{{- if or .Values.s3.batchExport.accessKeyId .Values.s3.accessKeyId }}
- name: LANGFUSE_S3_BATCH_EXPORT_ACCESS_KEY_ID
  {{- include "langfuse.getS3ValueOrSecret" (dict "key" "accessKeyId" "bucket" "batchExport" "values" .Values.s3) | nindent 2 }}
{{- end }}
{{- if or .Values.s3.batchExport.secretAccessKey .Values.s3.secretAccessKey }}
- name: LANGFUSE_S3_BATCH_EXPORT_SECRET_ACCESS_KEY
  {{- include "langfuse.getS3ValueOrSecret" (dict "key" "secretAccessKey" "bucket" "batchExport" "values" .Values.s3) | nindent 2 }}
{{- end }}
{{- if or .Values.s3.batchExport.forcePathStyle .Values.s3.forcePathStyle }}
- name: LANGFUSE_S3_BATCH_EXPORT_FORCE_PATH_STYLE
  value: {{ .Values.s3.batchExport.forcePathStyle | default .Values.s3.forcePathStyle | quote }}
{{- end }}
{{- end -}}
- name: LANGFUSE_S3_MEDIA_UPLOAD_BUCKET
{{- if $.Values.s3.deploy -}}
  value: {{ coalesce .Values.s3.mediaUpload.bucket .Values.s3.bucket .Values.s3.defaultBuckets | quote }}
{{- else -}}
  value: {{ required "s3.[mediaUpload].bucket is required" (.Values.s3.mediaUpload.bucket | default .Values.s3.bucket) | quote }}
{{- end -}}
{{- if or .Values.s3.mediaUpload.prefix .Values.s3.prefix }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_PREFIX
  value: {{ .Values.s3.mediaUpload.prefix | default .Values.s3.prefix | quote }}
{{- end }}
{{- if or .Values.s3.mediaUpload.region .Values.s3.region }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_REGION
  value: {{ .Values.s3.mediaUpload.region | default .Values.s3.region | quote }}
{{- end }}
{{- if or .Values.s3.mediaUpload.endpoint .Values.s3.endpoint }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT
  value: {{ .Values.s3.mediaUpload.endpoint | default .Values.s3.endpoint | quote }}
{{- end }}
{{- if or .Values.s3.mediaUpload.accessKeyId .Values.s3.accessKeyId }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_ACCESS_KEY_ID
  {{- include "langfuse.getS3ValueOrSecret" (dict "key" "accessKeyId" "bucket" "mediaUpload" "values" .Values.s3) | nindent 2 }}
{{- end }}
{{- if or .Values.s3.mediaUpload.secretAccessKey .Values.s3.secretAccessKey }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_SECRET_ACCESS_KEY
  {{- include "langfuse.getS3ValueOrSecret" (dict "key" "secretAccessKey" "bucket" "mediaUpload" "values" .Values.s3) | nindent 2 }}
{{- end }}
{{- if or .Values.s3.mediaUpload.forcePathStyle .Values.s3.forcePathStyle }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_FORCE_PATH_STYLE
  value: {{ .Values.s3.mediaUpload.forcePathStyle | default .Values.s3.forcePathStyle | quote }}
{{- end }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_MAX_CONTENT_LENGTH
  value: {{ .Values.s3.mediaUpload.maxContentLength | quote }}
- name: LANGFUSE_S3_MEDIA_UPLOAD_DOWNLOAD_URL_EXPIRY_SECONDS
  value: {{ .Values.s3.mediaUpload.downloadUrlExpirySeconds | quote }}
{{- end -}}

{{/*
Common environment variables for all deployments
*/}}
{{- define "langfuse.commonEnv" -}}
{{- include "langfuse.serverEnv" . }}
{{- include "langfuse.nextauthEnv" . }}
{{- include "langfuse.databaseEnv" . }}
{{- include "langfuse.redisEnv" . }}
{{- include "langfuse.clickhouseEnv" . }}
{{- include "langfuse.s3Env" . }}
{{- end -}}