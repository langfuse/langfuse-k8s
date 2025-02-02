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
Common environment variables
*/}}
{{- define "langfuse.commonEnv" -}}
{{- with (include "langfuse.getValueOrSecret" (dict "key" "langfuse.auth.licenseKey" "value" .Values.langfuse.auth.licenseKey)) }}
- name: LANGFUSE_EE_LICENSE_KEY
  {{- . | nindent 2 }}
{{- end }}
- name: NODE_ENV
  value: {{ .Values.langfuse.nodeEnv | quote }}
- name: HOSTNAME
  value: "0.0.0.0"
- name: PORT
  value: {{ .Values.langfuse.web.service.port | quote }}
{{- if .Values.postgresql.auth.username }}
- name: DATABASE_USERNAME
  value: {{ .Values.postgresql.auth.username | quote }}
{{- end }}
- name: DATABASE_PASSWORD
  value: {{ required "postgresql.auth.password is required" .Values.postgresql.auth.password | quote }}
{{- if .Values.postgresql.host }}
- name: DATABASE_HOST
  value: {{ .Values.postgresql.deploy | ternary (include "langfuse.postgresql.fullname" . | quote) (.Values.postgresql.host | quote) }}
{{- end }}
{{- if .Values.postgresql.auth.database }}
- name: DATABASE_NAME
  value: {{ .Values.postgresql.auth.database | quote }}
{{- end }}
- name: NEXTAUTH_URL
  value: {{ .Values.langfuse.auth.nextauth.url | quote }}
- name: NEXTAUTH_SECRET
  {{- include "langfuse.getRequiredValueOrSecret" (dict "key" "langfuse.auth.nextauth.secret" "value" .Values.langfuse.auth.nextauth.secret) | nindent 2 }}
{{- with (include "langfuse.getValueOrSecret" (dict "key" "langfuse.auth.salt" "value" .Values.langfuse.auth.salt) ) }}
- name: SALT
  {{- . | nindent 2 }}
{{- end }}
- name: TELEMETRY_ENABLED
  value: {{ .Values.langfuse.features.telemetryEnabled | quote }}
- name: NEXT_PUBLIC_SIGN_UP_DISABLED
  value: {{ .Values.langfuse.features.signUpDisabled | quote }}
- name: ENABLE_EXPERIMENTAL_FEATURES
  value: {{ .Values.langfuse.features.experimentalFeaturesEnabled | quote }}
# Redis configuration
- name: REDIS_PASSWORD
  value: {{ required "redis.auth.password is required" .Values.redis.auth.password | quote }}
- name: REDIS_CONNECTION_STRING
  value: "redis://{{ .Values.redis.auth.username | default "default" }}:$(REDIS_PASSWORD)@{{ .Values.redis.host }}:{{ .Values.redis.port }}/{{ .Values.redis.auth.database }}"
# Clickhouse configuration
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
# S3/MinIO configuration
- name: LANGFUSE_S3_EVENT_UPLOAD_ENABLED
  value: "true"
- name: LANGFUSE_S3_EVENT_UPLOAD_BUCKET
  value: {{ .Values.objectStorage.bucket | quote }}
- name: LANGFUSE_S3_EVENT_UPLOAD_REGION
  value: {{ .Values.objectStorage.region | quote }}
- name: LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID
  {{- include "langfuse.getRequiredValueOrSecret" (dict "key" "objectStorage.auth.accessKeyId" "value" .Values.objectStorage.auth.accessKeyId) | nindent 2 }}
- name: LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY
  {{- include "langfuse.getRequiredValueOrSecret" (dict "key" "objectStorage.auth.secretAccessKey" "value" .Values.objectStorage.auth.secretAccessKey) | nindent 2 }}
- name: LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT
  value: {{ .Values.objectStorage.endpoint | quote }}
- name: LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE
  value: {{ .Values.objectStorage.forcePathStyle | quote }}
{{- end -}}