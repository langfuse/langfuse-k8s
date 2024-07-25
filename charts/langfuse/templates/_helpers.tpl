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
Create the name of the configmap for nextauth
*/}}
{{- define "langfuse.nextauthConfigMapName" -}}
{{- printf "%s-nextauth" (include "langfuse.fullname" .) -}}
{{- end }}

{{/*
Create the name of the secret for salt
*/}}
{{- define "langfuse.saltSecretName" -}}
{{- printf "%s-salt" (include "langfuse.fullname" .) -}}
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
Create the postgresqlConfigMapName
*/}}
{{- define "langfuse.postgresqlConfigMapName" -}}
{{- printf "%s-postgresql" (include "langfuse.fullname" .) -}}
{{- end }}

{{/*
Create the valueFrom json for DATABASE_HOST
*/}}
{{- define "langfuse.postgresql.databaseHost.valueFrom" -}}
{{- if .Values.postgresql.deploy -}}
configMapRef:
  name: {{ include "langfuse.postgresqlConfigMapName" . }}
  key: postgres-database
{{- else if .Values.langfuse.postgresql.host.valueFrom -}}
{{- toYaml .Values.langfuse.postgresql.host.valueFrom }}
{{- else -}}
configMapRef:
  name: {{ include "langfuse.postgresqlConfigMapName" . }}
  key: postgres-database
{{- end }}
{{- end }}

{{/*
Create the valueFrom json for DATABASE_USERNAME
*/}}
{{- define "langfuse.postgresql.auth.username.valueFrom" -}}
{{- if .Values.postgresql.deploy -}}
configMapRef:
  name: {{ include "langfuse.postgresqlConfigMapName" . }}
  key: postgres-username
{{- else if .Values.langfuse.postgresql.auth.username.valueFrom -}}
{{- toYaml .Values.langfuse.postgresql.auth.username.valueFrom }}
{{- else -}}
configMapRef:
  name: {{ include "langfuse.postgresqlConfigMapName" . }}
  key: postgres-username
{{- end }}
{{- end }}

{{/*
Create the valueFrom json for DATABASE_PASSWORD
*/}}
{{- define "langfuse.postgresql.auth.password.valueFrom" -}}
{{- if .Values.postgresql.deploy -}}
secretKeyRef:
  name: {{ include "langfuse.postgresqlSecretName" . }}
  key: postgres-password
{{- else if .Values.langfuse.postgresql.auth.password.valueFrom }}
{{- toYaml .Values.langfuse.postgresql.auth.password.valueFrom }}
{{- else -}}
configMapRef:
  name: {{ include "langfuse.postgresqlSecretName" . }}
  key: postgres-password
{{- end }}
{{- end }}

{{/*
Create the valueFrom json for DATABASE_NAME
*/}}
{{- define "langfuse.postgresql.auth.database.valueFrom" -}}
{{- if .Values.postgresql.deploy -}}
configMapRef:
  name: {{ include "langfuse.postgresqlConfigMapName" . }}
  key: postgres-database
{{- else if .Values.langfuse.postgresql.auth.database.valueFrom }}
{{- toYaml .Values.langfuse.postgresql.auth.database.valueFrom }}
{{- else -}}
configMapRef:
  name: {{ include "langfuse.postgresqlConfigMapName" . }}
  key: postgres-database
{{- end }}
{{- end }}

{{/*
Create the valueFrom json for SALT
*/}}
{{- define "langfuse.salt.valueFrom" -}}
{{- if .Values.langfuse.salt.valueFrom }}
{{- toYaml .Values.langfuse.salt.valueFrom }}
{{- else -}}
secretKeyRef:
  name: {{ include "langfuse.saltSecretName" . }}
  key: salt
{{- end }}
{{- end }}

{{/*
Create the valueFrom json for DIRECT_URL
*/}}
{{- define "langfuse.postgresql.directURL.valueFrom" -}}
{{- if .Values.langfuse.postgresql.directURL.valueFrom }}
{{- toYaml .Values.langfuse.postgresql.directURL.valueFrom }}
{{- else -}}
secretKeyRef:
  name: {{ include "langfuse.postgresqlSecretName" . }}
  key: postgres-direct-url
{{- end }}
{{- end }}

{{/*
Create the valueFrom json for SHADOW_DATABASE_URL
*/}}
{{- define "langfuse.postgresql.shadowDatabaseURL.valueFrom" -}}
{{- if .Values.langfuse.postgresql.shadowDatabaseURL.valueFrom }}
{{- toYaml .Values.langfuse.postgresql.shadowDatabaseURL.valueFrom }}
{{- else -}}
secretKeyRef:
  name: {{ include "langfuse.postgresqlSecretName" . }}
  key: postgres-shadow-database-url
{{- end }}
{{- end }}

{{/*
Create the valueFrom json for NEXTAUTH_URL
*/}}
{{- define "langfuse.nextauth.url.valueFrom" -}}
{{- if .Values.langfuse.nextauth.url.valueFrom }}
{{- toYaml .Values.langfuse.nextauth.url.valueFrom }}
{{- else -}}
configMapRef:
  name: {{ include "langfuse.nextauthConfigMapName" . }}
  key: nextauth-url
{{- end }}
{{- end }}

{{/*
Create the valueFrom json for NEXTAUTH_SECRET
*/}}
{{- define "langfuse.nextauth.secret.valueFrom" -}}
{{- if .Values.langfuse.nextauth.secret.valueFrom }}
{{- toYaml .Values.langfuse.nextauth.secret.valueFrom }}
{{- else -}}
secretKeyRef:
  name: {{ include "langfuse.nextauthSecretName" . }}
  key: secret
{{- end }}
{{- end }}
