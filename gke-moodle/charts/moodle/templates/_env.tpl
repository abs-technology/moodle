{{- define "moodle.env.common" -}}
- name: MOODLE_WWWROOT
  value: {{ .Values.moodle.wwwroot | quote }}
- name: MOODLE_SSLPROXY
  value: {{ .Values.moodle.sslProxy | quote }}
- name: MOODLE_REVERSEPROXY
  value: {{ .Values.moodle.reverseProxy | quote }}
- name: MOODLE_CLUSTER
  value: {{ .Values.moodle.cluster | quote }}
- name: MOODLE_SITE_NAME
  value: {{ .Values.moodle.siteName | quote }}
- name: MOODLE_SITE_FULLNAME
  value: {{ .Values.moodle.siteFullname | quote }}
- name: MOODLE_SITE_SHORTNAME
  value: {{ .Values.moodle.siteShortname | quote }}
- name: MOODLE_USERNAME
  value: {{ .Values.moodle.adminUser | quote }}
- name: MOODLE_EMAIL
  value: {{ .Values.moodle.adminEmail | quote }}
- name: MOODLE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.existingSecret }}
      key: {{ .Values.existingSecretKeys.adminPassword }}
- name: MOODLE_DATABASE_TYPE
  value: {{ .Values.moodle.database.type | quote }}
- name: MOODLE_DATABASE_HOST
  value: {{ .Values.moodle.database.host | quote }}
- name: MOODLE_DATABASE_PORT_NUMBER
  value: {{ .Values.moodle.database.port | quote }}
- name: MOODLE_DATABASE_NAME
  value: {{ .Values.moodle.database.name | quote }}
- name: MOODLE_DATABASE_USER
  value: {{ .Values.moodle.database.user | quote }}
- name: MARIADB_USER
  value: {{ .Values.moodle.database.user | quote }}
- name: MARIADB_DATABASE
  value: {{ .Values.moodle.database.name | quote }}
- name: MOODLE_DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.existingSecret }}
      key: {{ .Values.existingSecretKeys.databasePassword }}
- name: MARIADB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.existingSecret }}
      key: {{ .Values.existingSecretKeys.databasePassword }}
- name: MOODLE_LOCALCACHE_DIR
  value: /var/www/moodlelocalcache
- name: MOODLE_FIX_DATA_PERMS
  value: "no"
{{- end }}

{{- define "moodle.env.web" -}}
{{- include "moodle.env.common" . }}
- name: MOODLE_CRON_ENABLED
  value: {{ .Values.moodle.cronEnabled | quote }}
- name: MOODLE_CRON_MINUTES
  value: {{ .Values.moodle.cronMinutes | quote }}
- name: PHP_MEMORY_LIMIT
  value: {{ .Values.moodle.php.memoryLimit | quote }}
- name: PHP_MAX_INPUT_VARS
  value: {{ .Values.moodle.php.maxInputVars | quote }}
- name: PHP_MAX_FILE_UPLOADS
  value: {{ .Values.moodle.php.maxFileUploads | quote }}
- name: PHP_POST_MAX_SIZE
  value: {{ .Values.moodle.php.postMaxSize | quote }}
- name: PHP_UPLOAD_MAX_FILESIZE
  value: {{ .Values.moodle.php.uploadMaxFilesize | quote }}
- name: PHP_MAX_EXECUTION_TIME
  value: {{ .Values.moodle.php.maxExecutionTime | quote }}
- name: MOODLE_BOOTSTRAP_H5P
  value: "background"
- name: MOODLE_OPTIMIZE_COMPOSER
  value: "auto"
{{- end }}

{{- define "moodle.scheduling" -}}
{{- with .Values.image.pullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
