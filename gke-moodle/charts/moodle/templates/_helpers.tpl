{{- define "moodle.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "moodle.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s" (include "moodle.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "moodle.labels" -}}
app.kubernetes.io/name: {{ include "moodle.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "moodle.selectorLabels" -}}
app.kubernetes.io/name: {{ include "moodle.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "moodle.pvcName" -}}
{{- if .Values.persistence.existingClaim }}
{{- .Values.persistence.existingClaim }}
{{- else }}
{{- printf "%s-moodledata" (include "moodle.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Must be set explicitly. Omitting dnsPolicy does not clear a previous
Helm revision that used None + 169.254.20.10 (3-way merge keeps the field).
ClusterFirst: kube-dns first; NodeLocal is still used when the node has it.
*/}}
{{- define "moodle.dns" -}}
dnsPolicy: ClusterFirst
{{- end }}

{{- define "moodle.hubOverlayMounts" -}}
- name: bootstrap
  mountPath: /scripts/entrypoint.sh
  subPath: entrypoint.sh
- name: bootstrap
  mountPath: /scripts/setup/moodle.sh
  subPath: moodle.sh
- name: bootstrap
  mountPath: /scripts/setup/mariadb.sh
  subPath: mariadb.sh
- name: bootstrap
  mountPath: /scripts/lib/mariadb.sh
  subPath: mariadb-lib.sh
- name: bootstrap
  mountPath: /scripts/moodle-run.sh
  subPath: moodle-run.sh
{{- end }}

{{- define "moodle.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "moodle.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
