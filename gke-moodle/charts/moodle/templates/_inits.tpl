{{- define "moodle.cloudSqlProxy" -}}
- name: cloud-sql-proxy
  image: {{ .Values.cloudSql.proxyImage }}
  restartPolicy: Always
  args:
    - "--structured-logs"
    - "--private-ip"
    - "--health-check"
    - "--http-address=0.0.0.0"
    - "--http-port=9801"
    - "--port={{ .Values.cloudSql.port }}"
    - {{ .Values.cloudSql.instanceConnectionName | quote }}
  startupProbe:
    httpGet:
      path: /readiness
      port: 9801
    periodSeconds: 2
    timeoutSeconds: 2
    failureThreshold: 60
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 256Mi
{{- end }}

{{/*
Init chain. Pass (dict "root" . "waitOnly" true) for the cron worker so it
never takes the NFS install lock — only web pods copy source + install.
*/}}
{{- define "moodle.initContainers" -}}
{{- $root := .root | default . -}}
{{- $waitOnly := .waitOnly | default false -}}
{{- if $root.Values.cloudSql.enabled }}
{{ include "moodle.cloudSqlProxy" $root }}
{{- end }}
- name: init-filesystem
  image: "{{ $root.Values.image.repository }}:{{ $root.Values.image.tag }}"
  imagePullPolicy: {{ $root.Values.image.pullPolicy }}
  command: ["/bin/bash", "/scripts-bootstrap/prepare-fs.sh"]
  # Filestore roots are owned by root; app runs as 1000. PSS baseline allows this.
  securityContext:
    runAsUser: 0
    runAsGroup: 0
    runAsNonRoot: false
    allowPrivilegeEscalation: false
    capabilities:
      drop: ["ALL"]
      add: ["CHOWN", "FOWNER", "DAC_OVERRIDE"]
  volumeMounts:
    - name: nfs
      mountPath: /nfs
    - name: bootstrap
      mountPath: /scripts-bootstrap
      readOnly: true
{{- if $root.Values.cloudSql.enabled }}
- name: init-wait-sql
  image: "{{ $root.Values.image.repository }}:{{ $root.Values.image.tag }}"
  imagePullPolicy: {{ $root.Values.image.pullPolicy }}
  command: ["/bin/bash", "/scripts-bootstrap/wait-sql.sh"]
  env:
    - name: MOODLE_DATABASE_HOST
      value: {{ $root.Values.moodle.database.host | quote }}
    - name: MOODLE_DATABASE_PORT_NUMBER
      value: {{ $root.Values.moodle.database.port | quote }}
    - name: MOODLE_DATABASE_NAME
      value: {{ $root.Values.moodle.database.name | quote }}
    - name: MOODLE_DATABASE_USER
      value: {{ $root.Values.moodle.database.user | quote }}
    - name: MOODLE_DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ $root.Values.existingSecret }}
          key: {{ $root.Values.existingSecretKeys.databasePassword }}
  securityContext:
    {{- toYaml $root.Values.securityContext | nindent 4 }}
  volumeMounts:
    - name: bootstrap
      mountPath: /scripts-bootstrap
      readOnly: true
{{- end }}
- name: init-install-gate
  image: "{{ $root.Values.image.repository }}:{{ $root.Values.image.tag }}"
  imagePullPolicy: {{ $root.Values.image.pullPolicy }}
  command: ["/bin/bash", "/scripts-bootstrap/wait-install.sh"]
  env:
    - name: WAIT_ONLY
      value: {{ $waitOnly | ternary "1" "0" | quote }}
  securityContext:
    {{- toYaml $root.Values.securityContext | nindent 4 }}
  volumeMounts:
    - name: nfs
      mountPath: /nfs
    - name: bootstrap
      mountPath: /scripts-bootstrap
      readOnly: true
{{- end }}
