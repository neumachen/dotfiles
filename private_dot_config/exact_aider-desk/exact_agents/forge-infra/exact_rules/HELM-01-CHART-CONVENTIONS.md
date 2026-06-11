# Helm Rule: Chart Conventions

When writing or modifying Helm charts, follow these conventions.

## Chart metadata

- `Chart.yaml` requires `apiVersion: v2`, `name`, `version`, `appVersion`.
- `version` is the chart's own SemVer — bump it on **every** chart change, even if `appVersion` is unchanged. Helm uses it for `helm install --version` and rollback.
- `appVersion` quoted: `appVersion: "1.2.3"`. Some tools mis-parse unquoted versions like `1.2.30` (as a float).
- Pin dependencies in `Chart.yaml`:
  ```yaml
  dependencies:
    - name: postgresql
      version: "12.5.6"
      repository: "https://charts.bitnami.com/bitnami"
  ```
  Run `helm dependency update` after changes; commit `Chart.lock` alongside.

## File layout

A typical chart:

```
mychart/
├── Chart.yaml
├── Chart.lock
├── values.yaml
├── values.schema.json
├── templates/
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   └── NOTES.txt
└── README.md
```

- `_helpers.tpl` for template-only helpers (no top-level `apiVersion`).
- `NOTES.txt` for post-install user-facing instructions. Keep it brief.
- One top-level resource per template file. Don't mix `Deployment` and `Service` in `deployment.yaml`.

## values.yaml

- Every value the chart consumes is declared in `values.yaml` with a sensible default and an inline comment.
- Group values by component, not alphabetically. Indentation tells the story.
- Boolean defaults: prefer `false` for opt-in features (so a user with no overrides gets minimal behaviour).
- Add a `values.schema.json` for non-trivial charts so `helm install` rejects malformed values:
  ```json
  {
    "$schema": "https://json-schema.org/draft-07/schema",
    "properties": {
      "replicaCount": { "type": "integer", "minimum": 1 }
    },
    "required": ["replicaCount"]
  }
  ```

## Templates

- Use `{{ .Values.foo }}` for chart inputs. Don't fall back to env vars or files.
- Use `{{ include "mychart.fullname" . }}` for resource names. Define `mychart.fullname`, `mychart.name`, `mychart.labels` in `_helpers.tpl` per the Helm scaffold convention.
- Always set standard labels:
  ```yaml
  metadata:
    labels:
      {{- include "mychart.labels" . | nindent 4 }}
  ```
- Use `{{- ... -}}` whitespace trimming consistently. Mixed trim/non-trim hurts diff review.
- Don't generate manifests conditionally inside the middle of a YAML block — wrap the whole resource in `{{- if .Values.feature.enabled }} ... {{- end }}`.

## Resources

- `Deployment` over `ReplicaSet` (always go through Deployment unless you have a real reason).
- `StatefulSet` for ordered/named workloads with stable storage. Use a `volumeClaimTemplates` block.
- Set `resources.requests` and `resources.limits` on every container; missing limits is a noisy-neighbor bug waiting to happen.
- Set `securityContext.runAsNonRoot: true` and `readOnlyRootFilesystem: true` by default; allow per-container overrides if necessary.
- Set `imagePullPolicy: IfNotPresent`. Override to `Always` only for `:latest`-style tags.

## Hooks

- Use `helm.sh/hook` annotations sparingly: pre-install/post-install, pre-upgrade/post-upgrade, pre-delete/post-delete.
- Hook resources are not deleted by `helm uninstall` unless they have `helm.sh/hook-delete-policy: hook-succeeded`. Set the policy.

## Testing

- `helm lint .` and `helm template . --debug | kubectl apply --dry-run=client -f -` before commit.
- `helm install --dry-run --debug` for end-to-end validation against a live cluster API.
- Use `helm test` with `templates/tests/*.yaml` for actual post-install assertions.

## Examples

### Good

```yaml
# Chart.yaml
apiVersion: v2
name: mychart
version: 0.3.7
appVersion: "1.4.2"
description: A small focused chart for X.
```

```yaml
# templates/deployment.yaml — only the important parts
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "mychart.selectorLabels" . | nindent 8 }}
    spec:
      securityContext:
        runAsNonRoot: true
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

### Bad

```yaml
# Unversioned dependency, no values schema, no resource limits, root container:
apiVersion: v2
name: mychart
version: 0.0.1                # never bumped
dependencies:
  - name: postgresql
    repository: "https://example.com/charts"   # unpinned version

# templates/deployment.yaml — `latest` tag, no labels, no limits:
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mychart
spec:
  template:
    spec:
      containers:
        - name: app
          image: myapp:latest
```
