{{- define "passthrough-app.name" -}}
passthrough-app
{{- end }}

{{- define "passthrough-app.fullname" -}}
{{ include "passthrough-app.name" . }}-{{ .Release.Name }}
{{- end }}
