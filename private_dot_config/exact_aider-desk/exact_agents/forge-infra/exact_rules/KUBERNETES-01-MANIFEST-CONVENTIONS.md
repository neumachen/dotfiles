# Kubernetes Rule: Manifest Conventions

When writing or modifying raw Kubernetes manifests (or Kustomize overlays), follow these conventions.

If the project uses **Helm**, prefer the Helm rule. If it uses both Helm and Kustomize, the Helm rule applies inside the chart; this rule applies to anything outside it.

## API versions

- Pin to **stable** API versions:
  - `apps/v1` for `Deployment`, `StatefulSet`, `DaemonSet`, `ReplicaSet`.
  - `batch/v1` for `Job`, `CronJob`.
  - `v1` for `Service`, `ConfigMap`, `Secret`, `Pod`, `PersistentVolumeClaim`, `Namespace`, `ServiceAccount`.
  - `networking.k8s.io/v1` for `Ingress`, `NetworkPolicy`.
  - `policy/v1` for `PodDisruptionBudget`.
  - `rbac.authorization.k8s.io/v1` for `Role`, `RoleBinding`, `ClusterRole`, `ClusterRoleBinding`.
- Do not use `extensions/v1beta1`, `apps/v1beta*`, `policy/v1beta1` — long deprecated.

## Labels (recommended set)

Every workload and its selectors should carry the standard labels:

```yaml
metadata:
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/version: "1.4.2"
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: payments-platform
    app.kubernetes.io/managed-by: kustomize
```

A `Deployment` and its `Service` must agree on `app.kubernetes.io/name` and `app.kubernetes.io/instance`; that pair is the selector.

## Selectors and immutability

- `spec.selector.matchLabels` is **immutable** on `Deployment`/`StatefulSet`. Plan it before the first apply; changing it later requires delete-and-recreate.
- Make selectors specific enough that no unrelated pod could match. `{ app: web }` alone is too broad.

## Containers

- `image:` always has an explicit tag or digest. Never `:latest` in production manifests.
- `imagePullPolicy: IfNotPresent`. Override to `Always` only for mutable tags during development.
- Set both `resources.requests` and `resources.limits` for CPU and memory. Missing requests breaks the scheduler; missing limits breaks the node.
- Liveness, readiness, and startup probes:
  - **Readiness** decides whether a pod receives traffic.
  - **Liveness** decides whether a pod gets killed.
  - **Startup** delays the first liveness check (for slow-starting containers).
  - Do not use the same endpoint for all three.
- Set `terminationGracePeriodSeconds` matching the application's actual shutdown time. Default 30s is too short for many JVM/Node services.

## Security

- `securityContext.runAsNonRoot: true` at the pod level.
- `containers[].securityContext`:
  - `allowPrivilegeEscalation: false`
  - `readOnlyRootFilesystem: true` (mount writable `emptyDir` if needed)
  - `capabilities.drop: ["ALL"]`, add only what's needed.
  - `seccompProfile.type: RuntimeDefault`.
- Use `automountServiceAccountToken: false` on the pod unless the workload actually calls the Kubernetes API.
- Avoid `hostNetwork: true`, `hostPID: true`, `hostIPC: true`. They escape the pod boundary.

## Secrets

- Never commit a `Secret` with `data:` populated. Use a secret manager (Sealed Secrets, External Secrets, SOPS, Vault) and commit the *encrypted* or *placeholder* form.
- Mount secrets as files (`volumeMounts`) rather than env vars when the consuming code supports it — files don't leak through `kubectl describe pod`.

## Networking

- `Service` `type: ClusterIP` is the default. Avoid `NodePort` and `LoadBalancer` unless the project's traffic model requires them; prefer `Ingress` + ingress controller.
- `NetworkPolicy` denies all ingress + egress by default, then allow specifically.

## Workload reliability

- `replicas:` should be ≥ 2 for anything serving traffic.
- `PodDisruptionBudget` with `minAvailable: 1` for stateful or single-replica workloads.
- `topologySpreadConstraints` with `whenUnsatisfiable: ScheduleAnyway` for anti-affinity across zones.

## ConfigMaps

- Mutable — but a change to a `ConfigMap` does **not** restart pods that mount it. Either:
  - Use a hash-suffixed name (`mychart-config-<hash>`) and update the Deployment `env`/`volumes` reference, or
  - Use a tool like `reloader` that watches for config changes.

## Kustomize specifics

- `kustomization.yaml` at every overlay level.
- `commonLabels:` and `commonAnnotations:` go in the base, not the overlay.
- `patchesStrategicMerge` is deprecated in favor of `patches:` with `target:` selectors.
- Each overlay should be its own directory; do not parameterize via env vars at apply time.

## Validation

- `kubectl apply --dry-run=client -f .` for client-side validation.
- `kubeconform` or `kubeval` in CI.
- `kustomize build overlays/<env> | kubectl apply --dry-run=server -f -` for server-side validation against a real cluster.

## Examples

### Good — Deployment + Service pair

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    app.kubernetes.io/name: api
    app.kubernetes.io/component: api
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: api
      app.kubernetes.io/component: api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: api
        app.kubernetes.io/component: api
    spec:
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: api
          image: ghcr.io/example/api:1.4.2
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
          readinessProbe:
            httpGet: { path: /readyz, port: http }
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz, port: http }
            periodSeconds: 30
            failureThreshold: 3
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
---
apiVersion: v1
kind: Service
metadata:
  name: api
  labels:
    app.kubernetes.io/name: api
    app.kubernetes.io/component: api
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: api
    app.kubernetes.io/component: api
  ports:
    - name: http
      port: 80
      targetPort: http
```

### Bad

```yaml
# :latest, no probes, no resources, no security context, root container:
apiVersion: extensions/v1beta1     # deprecated
kind: Deployment
metadata:
  name: api
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: api
          image: ghcr.io/example/api:latest
```
