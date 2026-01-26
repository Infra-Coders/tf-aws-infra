{{- define "edge-app.name" -}}
edge-app
{{- end }}

{{- define "edge-app.fullname" -}}
{{ include "edge-app.name" . }}-{{ .Release.Name }}
{{- end }}
