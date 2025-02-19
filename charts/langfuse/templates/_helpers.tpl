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
{{- if .Values.serviceAccount.create }}
{{- default (include "langfuse.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret for nextauth
*/}}
{{- define "langfuse.nextauthSecretName" -}}
{{- printf "%s-nextauth" (include "langfuse.fullname" .) -}}
{{- end }}

{{/*
Create the name of the secret for postgresql if we use an external database
*/}}
{{- define "langfuse.postgresqlSecretName" -}}
{{- printf "%s-postgresql" (include "langfuse.fullname" .) -}}
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
Create the name of the secret for clickhouse if we use an external database
*/}}
{{- define "langfuse.clickhouseSecretName" -}}
{{- printf "%s-clickhouse" (include "langfuse.fullname" .) -}}
{{- end }}

{{/*
Return clickhouse fullname
*/}}
{{- define "langfuse.clickhouse.fullname" -}}
{{- if .Values.clickhouse.deploy }}
{{- include "common.names.dependency.fullname" (dict "chartName" "clickhouse" "chartValues" .Values.clickhouse "context" $) -}}
{{- else }}
{{- printf "%s-clickhouse" (include "langfuse.fullname" .) -}}
{{- end }}
{{- end }}

{{/*
Clickhouse host
*/}}
{{- define "langfuse.clickhouse.host" -}}
{{- if .Values.clickhouse.deploy }}
{{- (include "langfuse.clickhouse.fullname" .) -}}
{{- else }}
{{- .Values.clickhouse.host -}}
{{- end }}
{{- end }}

{{/*
Return Valkey fullname
*/}}
{{- define "langfuse.valkey.fullname" -}}
{{- if .Values.valkey.deploy }}
{{- include "common.names.dependency.fullname" (dict "chartName" "valkey" "chartValues" .Values.clickhouse "context" $) -}}
{{- else }}
{{- printf "%s-valkey" (include "langfuse.fullname" .) -}}
{{- end }}
{{- end }}

{{/*
Valkey host
*/}}
{{- define "langfuse.valkey.host" -}}
{{- if .Values.valkey.deploy }}
{{- printf "%s-primary" (include "langfuse.valkey.fullname" .) -}}
{{- else }}
{{- .Values.valkey.host -}}
{{- end }}
{{- end }}

{{/*
Create the name of the secret for minio if we use an external deployment
*/}}
{{- define "langfuse.minioSecretName" -}}
{{- printf "%s-minio" (include "langfuse.fullname" .) -}}
{{- end }}

{{/*
Return minio fullname
*/}}
{{- define "langfuse.minio.fullname" -}}
{{- if .Values.minio.deploy }}
{{- include "common.names.dependency.fullname" (dict "chartName" "minio" "chartValues" .Values.minio "context" $) -}}
{{- else }}
{{- printf "%s-minio" (include "langfuse.fullname" .) -}}
{{- end }}
{{- end }}

{{/*
Minio host
*/}}
{{- define "langfuse.minio.host" -}}
{{- if .Values.minio.deploy }}
{{- (include "langfuse.minio.fullname" .) -}}
{{- else }}
{{- .Values.minio.host -}}
{{- end }}
{{- end }}