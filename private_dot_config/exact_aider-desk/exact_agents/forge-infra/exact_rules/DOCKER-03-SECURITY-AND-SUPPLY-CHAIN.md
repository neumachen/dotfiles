# Docker Rule: Security and Supply Chain

This rule covers the supply chain for built images: what gets baked in, what gets attested, how it's signed, how it's scanned. Image-build mechanics live in `DOCKER-02-IMAGE-CONVENTIONS`; host-engine access discipline in `DOCKER-01-HOST-ACCESS`.

## Threat model

Treat the image as **untrusted input** to whatever runs it. The threats:

1. **Vulnerable dependencies** baked in — known CVEs in OS packages or language runtime libs.
2. **Malicious dependencies** — typosquatted npm/PyPI/Gem packages, compromised upstream.
3. **Image tampering** — registry compromise, MITM, accidental retag.
4. **Build pipeline compromise** — CI logs leaking secrets, build steps fetching `eval`able shell scripts over HTTP.
5. **Excessive privilege at runtime** — capabilities, host filesystem mounts, privileged flag.

This rule addresses 1–4. Runtime privilege (5) is the cluster/orchestrator's job — covered in `KUBERNETES-01-MANIFEST-CONVENTIONS`.

## Pinning

### Pin by digest, not by tag, in production

Tags are mutable. A `:1.4.2` tag yesterday is not guaranteed to be the same bytes today.

```dockerfile
# Good — digest pinned (tag is a comment for humans).
FROM ghcr.io/example/base@sha256:f5e6...  # 1.4.2

# Acceptable for dev — tag pinned.
FROM ghcr.io/example/base:1.4.2

# Never in any committed Dockerfile.
FROM ghcr.io/example/base:latest
```

- Pin base images and any intermediate-stage images by `@sha256:...`.
- Use `docker buildx imagetools inspect <image>` to look up a digest before pinning.
- Refresh digests on a schedule (Renovate, Dependabot, or a weekly chore) — pinned-and-forgotten is also a supply chain risk.

### Pin language deps by checksum lockfile

- Go: `go.sum`.
- Node: `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock` (committed).
- Python: `pip-tools` (`requirements.txt` with hashes), `uv.lock`, `poetry.lock`.
- Ruby: `Gemfile.lock` (committed; verify `BUNDLED WITH` matches CI bundler).
- Rust: `Cargo.lock` (committed; even for libraries, for CI reproducibility).
- Java/Kotlin: lockfile of the chosen build tool (`gradle.lockfile`, Maven `dependencies-lock.json`).

CI installs must fail on lockfile drift: `npm ci`, `pnpm install --frozen-lockfile`, `bundle install --frozen`, `cargo build --locked`, `go mod download` + `go mod verify`.

## Vulnerability scanning

Run **at least one** scanner against the built image; ideally one each from a different provider for triangulation.

### Trivy

```sh
trivy image \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  --format json \
  --output trivy.json \
  ghcr.io/org/myapp:$SHA
```

- `--ignore-unfixed` — focus on what you can act on.
- `--severity HIGH,CRITICAL` — set the gate. Tune to `MEDIUM` as the codebase matures.
- `--exit-code 1` — fail CI when findings exceed the gate.
- `.trivyignore` for documented exceptions: include the CVE ID, the reason, and an expiry date.

### Grype

Equivalent role; pairs naturally with Syft for SBOMs. Useful as a second opinion.

```sh
grype ghcr.io/org/myapp:$SHA \
  --fail-on high \
  --output json
```

### Cadence

- On every CI build: scan and gate.
- On a schedule (daily/weekly): rescan published images. CVEs are disclosed continuously — yesterday's clean image is today's vulnerable one.
- For published images, surface the scan as a registry annotation or signed attestation (see Provenance below).

## SBOMs (Software Bill of Materials)

Every shipped image gets an SBOM. SBOMs let downstream consumers (and your own future self) answer "is this image affected by CVE-X?" without rescanning.

### Generation

BuildKit can emit SBOMs natively:

```sh
docker buildx build \
  --sbom=true \
  --provenance=mode=max \
  --push \
  -t ghcr.io/org/myapp:$VERSION \
  .
```

`--sbom=true` attaches the SBOM as an OCI image attestation (the registry stores it alongside the image manifest). Inspect with:

```sh
docker buildx imagetools inspect ghcr.io/org/myapp:$VERSION --format '{{json .SBOM}}'
```

External generation with Syft (if you need a file artifact for compliance review):

```sh
syft ghcr.io/org/myapp:$VERSION \
  --output spdx-json=sbom.spdx.json \
  --output cyclonedx-json=sbom.cdx.json
```

### Formats

- **SPDX 2.3** (`.spdx.json`) — the de facto compliance format. Linux Foundation standard.
- **CycloneDX 1.5** (`.cdx.json`) — OWASP standard, slightly richer dependency graph.

Emit both. They cost almost nothing to generate; consumers may want either.

### Attach SBOMs to releases

Publish SBOMs as GitHub release assets next to the image tag:

```sh
gh release upload "$VERSION" sbom.spdx.json sbom.cdx.json
```

## Provenance and attestations (SLSA)

Provenance documents *how* the image was built — which commit, which workflow, which inputs, which builder.

```sh
docker buildx build \
  --provenance=mode=max \
  --push \
  -t ghcr.io/org/myapp:$VERSION \
  .
```

`mode=max` includes build args, base images, frontend metadata. `mode=min` (the default) is significantly less useful.

The output is an [in-toto attestation](https://in-toto.io/) stored as an OCI artifact alongside the image. Verify with:

```sh
docker buildx imagetools inspect ghcr.io/org/myapp:$VERSION --format '{{json .Provenance}}'
```

For GitHub Actions, the matrix is straightforward:

- `docker/build-push-action@v5` with `provenance: mode=max` and `sbom: true`.
- The action's `id-token: write` permission + GitHub's OIDC issuer signs the attestation with a keyless cosign flow (no long-lived private key to manage).

## Signing with cosign

### Keyless (recommended for CI)

```sh
# In CI with OIDC token available:
cosign sign --yes ghcr.io/org/myapp@sha256:...
```

The signature is bound to the OIDC identity (GitHub Actions workflow, GitLab runner, AWS role) at the time of signing. Verification re-checks the identity:

```sh
cosign verify ghcr.io/org/myapp:$VERSION \
  --certificate-identity-regexp 'https://github.com/org/myapp/.github/workflows/.+' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Use keyless for CI/CD. There is no long-lived key for an attacker to steal.

### Keyed (for offline or air-gapped flows)

```sh
cosign generate-key-pair       # produces cosign.key, cosign.pub
cosign sign --key cosign.key ghcr.io/org/myapp@sha256:...
cosign verify --key cosign.pub ghcr.io/org/myapp:$VERSION
```

- Store `cosign.key` in a hardware security module or KMS. Never commit it.
- Distribute `cosign.pub` widely (commit it; embed it in deployment tooling).
- Rotate keys on a schedule; track the rotation in the public key's commit history.

### Verify on pull

Integrate `cosign verify` into the deploy step. Kubernetes admission controllers like [Sigstore Policy Controller](https://docs.sigstore.dev/policy-controller/overview/) or [Connaisseur](https://sse-secure-systems.github.io/connaisseur/) can refuse pods whose images lack a verifiable signature from an allow-listed identity.

## Build-time secrets

Never:

- `ARG SECRET=...` (visible in `docker history`).
- `ENV SECRET=...` (visible in `docker inspect`).
- `COPY .env .` followed by `RUN something-that-reads-it` (baked into the layer).
- Echo a secret to stdout during the build (CI logs).

Always use BuildKit secrets:

```dockerfile
# syntax=docker/dockerfile:1.7
RUN --mount=type=secret,id=npm_token,target=/run/secrets/npm_token \
    npm config set //npm.pkg.github.com/:_authToken "$(cat /run/secrets/npm_token)" \
 && npm ci --omit=dev \
 && npm config delete //npm.pkg.github.com/:_authToken
```

Pass at build time:

```sh
docker build --secret id=npm_token,env=NPM_TOKEN .
```

For GitHub deploy keys / cloned private repos, use `--mount=type=ssh` (forwards your SSH agent into the build).

## Secret-leak scanning

Run pre-commit or pre-push hooks against the repo:

- **gitleaks** — most popular, scriptable, easy CI integration.
- **trufflehog** — entropy- + pattern-based, more findings, more false positives.
- **detect-secrets** (Yelp) — pre-commit framework integration.

Add `gitleaks` to CI as a separate job, not as part of the image build. The image build is too late to catch a secret that already landed in git history.

## Distroless and minimal base images

Prefer images that contain the runtime and nothing else:

- `gcr.io/distroless/static-debian12:nonroot` — for static Go/Rust binaries. No shell, no package manager.
- `gcr.io/distroless/cc-debian12:nonroot` — for binaries needing glibc + libssl (most C/C++ binaries).
- `gcr.io/distroless/nodejs22-debian12:nonroot` — Node runtime, nothing else.
- `gcr.io/distroless/python3-debian12:nonroot` — Python 3 runtime.
- `gcr.io/distroless/java21-debian12:nonroot` — JRE 21.
- `chainguard.dev/static`, `chainguard.dev/cc`, language-specific Chainguard images — daily CVE patching, smaller attack surface, free for most use.
- `scratch` — empty base. Use for fully-static binaries (Go with CGO_ENABLED=0).

Why:

- No shell to spawn (`exec` is harder for an attacker).
- No `apt`, `apk`, `yum` for an attacker to abuse.
- Fewer CVE-affected packages by definition.

Tradeoffs:

- Debugging requires `kubectl debug` with an ephemeral container or `docker exec ... --image=busybox`. Worth it.
- Slightly more rigorous about which native dependencies your binary actually needs.

## Registry hygiene

- Push to a single canonical registry. Mirror downstream from there.
- Use immutable tags (the registry should refuse retag): `:1.4.2` is the same image forever; `:latest` and `:1.4` are aliases that may move.
- Enforce signed-image-only via registry policy (Harbor, ECR, Artifactory, GHCR + Sigstore Policy Controller).
- Limit who can `push --force`. Audit log every overwrite.
- Garbage-collect unsigned, unscanned, or stale images. Storage is cheap; sprawl is a security problem.

## CI matrix

The opinionated minimum for a production image:

| Step | Tool | Gate |
|---|---|---|
| Lockfile verification | `npm ci` / `bundle install --frozen` / `cargo build --locked` / `go mod verify` | fail on drift |
| Secret scan | `gitleaks` | fail on finding |
| Build | `docker buildx build --sbom=true --provenance=mode=max` | — |
| SBOM extraction | `docker buildx imagetools inspect` or `syft` | publish artifact |
| Vulnerability scan | `trivy image` and/or `grype` | fail on HIGH/CRITICAL |
| Sign | `cosign sign --yes` (keyless via OIDC) | required |
| Push | `docker push` (handled by build-push-action) | — |
| Verify (on deploy) | `cosign verify` + admission controller | required |

## Documented exceptions

For any CVE you accept the risk on, record it as `.trivyignore` (or `.grype.yaml`'s `ignore:` block) with:

```
# CVE-2024-XXXXX — golang stdlib regex DoS
# Mitigation: regex inputs are operator-controlled, not user-supplied.
# Re-evaluate by: 2026-03-01
CVE-2024-XXXXX
```

Three rules:

1. Always cite the mitigation, not just "false positive."
2. Always set a re-evaluation date.
3. Review the file quarterly. Expired exceptions are reverted to gating.

## Anti-patterns

- Scanning a base image once and trusting it forever. Rescan on every build; CVEs are disclosed continuously.
- Signing the tag but pulling by tag. Pull by digest after verifying the signature.
- Stripping debug symbols and calling it "obfuscation security." It isn't; strip for size.
- Embedding a private key, then `RUN rm /key`. The layer history still contains it. Use build secrets.
- `RUN curl https://... | sh` for installing tools. Vendor the script and review it. Better: install from a distro package or pinned binary release.
- Permissive image pull policies in production (`pullPolicy: Always` on a mutable tag). Pull by digest.
- "Just use root, it's behind a firewall." Set `USER`.
- One image per team rather than per service. Per-service images are smaller, scoped, and faster to scan.

## Examples

### Good — CI snippet (GitHub Actions, abridged)

```yaml
permissions:
  contents: read
  id-token: write          # for keyless cosign signing
  packages: write          # for pushing to GHCR

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Verify lockfiles
        run: npm ci

      - name: Scan for secrets
        uses: gitleaks/gitleaks-action@v2

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build, sign, push, attest
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
          sbom: true
          provenance: mode=max
          build-args: |
            BUILD_DATE=${{ github.event.head_commit.timestamp }}
            VCS_REF=${{ github.sha }}
            VERSION=${{ github.ref_name }}

      - name: Vulnerability scan
        uses: aquasecurity/trivy-action@v0
        with:
          image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
          severity: HIGH,CRITICAL
          ignore-unfixed: true
          exit-code: 1

      - name: Sign image
        env:
          IMAGE: ghcr.io/${{ github.repository }}:${{ github.sha }}
        run: |
          cosign sign --yes "$IMAGE"
```

### Bad

```yaml
# no scanning, no SBOM, no signing, latest tag, mutable digest:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myimage:latest .
      - run: docker push myimage:latest
```
