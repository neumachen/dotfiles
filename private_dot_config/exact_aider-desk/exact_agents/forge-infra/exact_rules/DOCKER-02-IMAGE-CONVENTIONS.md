# Docker Rule: Image Conventions

When authoring or modifying a Dockerfile, follow these conventions. This rule covers the **image build** — host-engine access discipline is in `DOCKER-01-HOST-ACCESS`; supply chain (signing, SBOM, scanning) is in `DOCKER-03-SECURITY-AND-SUPPLY-CHAIN`.

## Builder

- BuildKit only. Either via `DOCKER_BUILDKIT=1`, the `docker buildx` plugin, or a `docker-bake.hcl` file. Legacy builder lacks cache mounts, build secrets, and SBOM/provenance attestations.
- Pin the syntax directive at the top of every Dockerfile so BuildKit semantics are unambiguous:
  ```dockerfile
  # syntax=docker/dockerfile:1.7
  ```
  Bump the version intentionally; do not float on `dockerfile:1`.

## Multi-stage builds

Multi-stage is mandatory for any image that isn't a base/runtime layer published by an upstream. Pattern:

```dockerfile
# syntax=docker/dockerfile:1.7

#############################################
# Stage 1 — build
#############################################
FROM golang:1.23-alpine AS build
WORKDIR /src

# Cache module downloads. Mount the module cache, do not COPY-and-discard.
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=bind,source=go.mod,target=go.mod \
    --mount=type=bind,source=go.sum,target=go.sum \
    go mod download

COPY . .

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -ldflags='-s -w' -o /out/app ./cmd/app

#############################################
# Stage 2 — runtime
#############################################
FROM gcr.io/distroless/static-debian12:nonroot AS runtime

COPY --from=build /out/app /app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
```

Rules:

- Name every stage with `AS <name>`. Use lower-kebab-case: `build`, `test`, `runtime`, `release`.
- The final stage is the published image. Earlier stages may be referenced with `--target` for dev/test builds but should not be the default.
- Order stages by **how often the inputs change**: build tools and base packages first (cache-stable), source code last (cache-volatile).
- Runtime stages contain the runtime binary and its runtime dependencies — nothing else. No compilers, no package managers, no shells unless the entrypoint needs one.

## Base images

- Prefer minimal bases for runtime: `distroless`, `chainguard/static`, `alpine` (with size caveat), or `scratch` for static binaries.
- Pin tags by **digest** in production-bound images: `FROM gcr.io/distroless/static-debian12:nonroot@sha256:abc123...`. Tags can be retagged or vanish; digests cannot.
- Pin by tag at minimum (`debian:12-slim`, `node:22.10-alpine`); never use `:latest` in committed Dockerfiles.
- Match the base across all stages of the same family (e.g., `golang:1.23-alpine` and `alpine:3.20` — same alpine major).

## Layer ordering for cache

Each instruction is a cache layer. BuildKit reuses a layer if its instruction *and* its inputs are unchanged. Order matters:

1. `FROM` and `WORKDIR` (rarely change).
2. System packages via package manager (changes when you add deps).
3. Application dependency manifests (`go.mod`, `package.json`, `Gemfile`, `pyproject.toml`).
4. Application dependencies install (cached separately from the manifest copy).
5. Application source code (changes every commit).
6. Build step.

Worst-cache-bust pattern: `COPY . .` then `RUN go build` — every source change reinstalls dependencies. Split deps from source.

## Cache mounts and bind mounts (BuildKit)

Replace `COPY-then-clean` patterns with mounts:

```dockerfile
# Package manager caches — survive across builds, never enter the image layer.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends curl ca-certificates

# Bind mounts — read the host file at build time without baking it into a layer.
RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
    --mount=type=cache,target=/root/.cache/pip \
    pip install --no-deps -r /tmp/requirements.txt
```

Use `sharing=locked` for caches mutated during a single RUN (most cases). Use `sharing=shared` for read-mostly caches across parallel builds.

## .dockerignore

Every project has a `.dockerignore`. At minimum:

```
.git
.github
node_modules
dist
build
coverage
tmp
.env
.env.*
*.log
README.md
docs
```

Excluding `.git` and `node_modules` alone often halves the build context. The build context is uploaded to the BuildKit daemon on every build — keep it small.

## Non-root USER

Containers run as root by default. Override:

```dockerfile
# Create the user in the build stage (or use a base that already provides one):
RUN groupadd --system --gid 10001 app \
 && useradd  --system --uid 10001 --gid 10001 --no-create-home --shell /sbin/nologin app

USER app
```

Or use a base that ships non-root by default: `distroless/static-debian12:nonroot` (UID 65532), `chainguard/static:latest-nonroot`.

- The `USER` directive applies to every subsequent RUN, ENTRYPOINT, and CMD. Place it after all root-required setup.
- Numeric UIDs survive runtime user namespacing better than names. Specify both: `USER 10001:10001`.

## ENTRYPOINT and CMD

- Prefer the **exec form** (JSON array): `ENTRYPOINT ["/app"]`, `CMD ["--config", "/etc/app.toml"]`. Shell form (`ENTRYPOINT /app`) inserts a shell and breaks `SIGTERM` propagation.
- Use `ENTRYPOINT` for the binary, `CMD` for default arguments — users override CMD with `docker run ... arg`.
- A wrapper entrypoint script is fine when boot-time logic is needed (drop privileges, render config, wait-for-dep). Put it in `/usr/local/bin/entrypoint.sh`, mark executable, and use `ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]`.

## HEALTHCHECK

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:8080/healthz >/dev/null || exit 1
```

- Include a healthcheck for long-running services. Omit for one-shot CLIs.
- `--start-period` excludes failures during boot from triggering unhealthy.
- The CMD must be small — `wget`, `curl`, `nc`, or a Go/Node one-liner is typical. Bake one such tool into the image if the runtime doesn't include it.

## EXPOSE

- Document network ports the container listens on: `EXPOSE 8080`. This is metadata only — does not publish ports.
- Multiple ports: separate lines, `EXPOSE 8080 9090`.

## ENV and ARG

- `ARG` is build-time only, gone from the running image. Use for build-time inputs: versions, build flags, vendor URLs.
- `ENV` persists into the runtime image. Use for default runtime config; users override with `-e`.
- Common runtime ENV: `LANG`, `LC_ALL`, `TZ`, `PATH`, `HOME`. Set explicitly rather than relying on inherited defaults.
- Never put secrets in `ARG` or `ENV`. ARGs are visible in `docker history`; ENVs in `docker inspect`.

## Build secrets

For private package registries, signing keys, or build-time tokens:

```dockerfile
RUN --mount=type=secret,id=npm_token,target=/run/secrets/npm_token \
    npm config set //npm.pkg.github.com/:_authToken "$(cat /run/secrets/npm_token)" \
 && npm ci --omit=dev
```

Pass at build time: `docker build --secret id=npm_token,src=$HOME/.npm-token .`. The secret is mounted at build time and never written to a layer.

For SSH-protected git deps:

```dockerfile
RUN --mount=type=ssh \
    git clone git@github.com:org/private-repo.git /opt/private
```

Pass: `docker build --ssh default .`.

## OCI labels

Annotate every image with [OCI image spec labels](https://github.com/opencontainers/image-spec/blob/main/annotations.md). They surface in registries, are required by some security policies, and feed downstream tooling:

```dockerfile
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.opencontainers.image.title="myapp" \
      org.opencontainers.image.description="One-line description of what this image does." \
      org.opencontainers.image.url="https://github.com/org/myapp" \
      org.opencontainers.image.source="https://github.com/org/myapp" \
      org.opencontainers.image.documentation="https://github.com/org/myapp#readme" \
      org.opencontainers.image.vendor="Org Name" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.authors="team@example.com" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="gcr.io/distroless/static-debian12:nonroot"
```

Populate via build args from CI:

```yaml
- name: Build
  uses: docker/build-push-action@v5
  with:
    build-args: |
      BUILD_DATE=${{ github.event.head_commit.timestamp }}
      VCS_REF=${{ github.sha }}
      VERSION=${{ github.ref_name }}
```

Key labels:

- `org.opencontainers.image.title` — short human name.
- `org.opencontainers.image.description` — one sentence.
- `org.opencontainers.image.source` — URL of the source repo (links image → code in many registries).
- `org.opencontainers.image.revision` — commit SHA.
- `org.opencontainers.image.version` — semver tag or release name.
- `org.opencontainers.image.licenses` — SPDX expression.
- `org.opencontainers.image.base.name` — exact base image tag with digest if pinned.

For BuildKit `docker buildx build`, use `--annotation`:

```sh
docker buildx build \
  --annotation "index:org.opencontainers.image.title=myapp" \
  --annotation "manifest:org.opencontainers.image.source=https://github.com/org/myapp" \
  ...
```

Annotations target either the multi-platform `index` or each per-arch `manifest` — choose deliberately.

## Multi-platform images

For images shipped to multiple architectures:

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push \
  -t ghcr.io/org/myapp:$VERSION \
  .
```

- BuildKit emits a manifest list. Pulling clients select the right arch transparently.
- Use `--platform=$TARGETPLATFORM` inside `FROM` to inherit the per-arch target:
  ```dockerfile
  FROM --platform=$BUILDPLATFORM golang:1.23 AS build
  ARG TARGETPLATFORM TARGETOS TARGETARCH
  RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build ...
  ```
- Cross-compile when possible; emulation (`qemu`) for non-trivial native builds is slow and fragile.

## Image size

- One process per container — the unix-philosophy version of "one concept per container."
- Strip debug info from compiled binaries: `-ldflags='-s -w'` (Go), `--release` (Rust), `:without-debug` (Elixir/OTP releases).
- Don't `apt-get upgrade` in Dockerfiles — pins shift and the layer balloons. Pin the base and let the upstream maintainer rebuild.
- Combine related RUN steps with `&& \` to share a single layer when correctness allows. Don't combine unrelated steps just to "save a layer."
- Audit with `dive ghcr.io/org/myapp:$VERSION` to see what's actually in each layer.

## Anti-patterns

- `RUN apt-get update` without `apt-get install` in the same RUN. Cached `update` paired with fresh `install` installs stale packages.
- `RUN cd /app && command`. Use `WORKDIR /app` then `RUN command`. `cd` doesn't persist across RUN.
- `ADD` for general file copies. `ADD` has untarring and URL-fetching behaviour you usually don't want. Use `COPY`.
- `COPY . /app` without a `.dockerignore`. Uploads the world; busts cache.
- Running services as root. Even if "it's behind a firewall." Even "for now." Set `USER`.
- `ENTRYPOINT bash -c "..."` — breaks signal handling. Use the exec form.
- `RUN curl https://... | sh`. Vendor the script and review it.
- Hardcoding architecture in `FROM amd64/...`. Use multi-platform builds.

## Examples

### Good — Go runtime

See the multi-stage template at the top.

### Good — Node runtime

```dockerfile
# syntax=docker/dockerfile:1.7

#############################################
# Stage 1 — deps (cached on lockfile change)
#############################################
FROM node:22-alpine AS deps
WORKDIR /app

RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

#############################################
# Stage 2 — build
#############################################
FROM node:22-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

#############################################
# Stage 3 — runtime
#############################################
FROM gcr.io/distroless/nodejs22-debian12:nonroot AS runtime

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.opencontainers.image.title="myapp" \
      org.opencontainers.image.source="https://github.com/org/myapp" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=deps /app/node_modules ./node_modules

USER nonroot:nonroot
EXPOSE 3000
ENV NODE_ENV=production
CMD ["dist/server.js"]
```

### Bad

```dockerfile
# no syntax pin, no multi-stage, latest tag, root user, no labels, COPY . then deps install:
FROM node:latest

WORKDIR /app
COPY . .
RUN npm install
EXPOSE 3000
CMD npm start
```
