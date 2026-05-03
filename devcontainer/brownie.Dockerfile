ARG AIDER_DESK_IMAGE=ghcr.io/hotovo/aider-desk:local
FROM ${AIDER_DESK_IMAGE}

ARG AIDER_DESK_EXTENSIONS_DEFAULT="bmad,\
    chunkhound-search,\
    context-autocompletion-words,\
    fff,\
    generate-tests,\
    lsp,\
    multi-model-run,\
    permission-gate,\
    plannotator,\
    programmatic-tool-calls,\
    protected-paths,\
    plan-mode,\
    questions,\
    redact-secrets,\
    rtk,\
    sandbox,\
    seek,\
    sound-notification,\
    theme,\
    tps-counter,\
    tree-sitter-repo-map,\
    ultrathink,\
    wakatime,\
    https://github.com/wladimiiir/aider-desk-codex-auth-extension"
ARG AIDER_DESK_EXTENSIONS_APPEND=""
ARG AIDER_DESK_EXTENSIONS_OVERRIDE=""

# ── 1) XDG_CONFIG_HOME wiring ──────────────────────────────────────────
#    Entrypoint generates git config here from env vars at runtime.
ENV XDG_CONFIG_HOME=/etc/xdg

# Move safe.directory to system-level config so it doesn't conflict
# with the generated XDG config.  Remove upstream's user-level gitconfig.
RUN git config --system --add safe.directory "*" \
    && rm -f /root/.gitconfig /root/.config/git/config \
    && mkdir -p /etc/xdg/git

# ── 2) Use bash + pipefail for safer RUN steps ────────────────────────
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ── 3) Install SSH client + mise bootstrap dependencies ───────────────
#    openssh-client provides ssh-keygen (git SSH signing) and ssh-add
#    (agent check). curl/ca-certificates/xz-utils/unzip are needed for
#    the official mise installer and common tool archives.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-client \
        curl \
        ca-certificates \
        xz-utils \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# ── 4) Install mise ───────────────────────────────────────────────────
ENV MISE_INSTALL_PATH=/usr/local/bin/mise
ENV MISE_CONFIG_DIR=/root/.config/mise
ENV MISE_DATA_DIR=/root/.local/share/mise
ENV MISE_CACHE_DIR=/root/.cache/mise
ENV PATH=/usr/local/share/mise/shims:/root/.local/share/mise/shims:${PATH}

RUN mkdir -p "${MISE_CONFIG_DIR}" "${MISE_DATA_DIR}" "${MISE_CACHE_DIR}" \
    && curl -fsSL https://mise.run | sh \
    && mise --version

# ── 5) Preinstall AiderDesk extensions into the image ─────────────────
#    Default extensions are baked into the image. At build time you can
#    either append more via AIDER_DESK_EXTENSIONS_APPEND or fully replace
#    the defaults via AIDER_DESK_EXTENSIONS_OVERRIDE.
#    Extensions are installed into the runtime global directory and also
#    copied into an image-owned seed directory for maintenance refreshes.
COPY install-aiderdesk-extensions.sh /usr/local/bin/install-aiderdesk-extensions.sh
RUN chmod +x /usr/local/bin/install-aiderdesk-extensions.sh \
    && /usr/local/bin/install-aiderdesk-extensions.sh \
        /root/.aider-desk/extensions \
        /usr/local/share/aider-desk/extensions-seed \
        "${AIDER_DESK_EXTENSIONS_DEFAULT}" \
        "${AIDER_DESK_EXTENSIONS_APPEND}" \
        "${AIDER_DESK_EXTENSIONS_OVERRIDE}"

# ── 6) Upstream env / volumes / port / healthcheck ────────────────────
#    Re-declared for clarity; inherited from upstream.
ENV NODE_ENV=production
ENV AIDER_DESK_HEADLESS=true
ENV AIDER_DESK_DATA_DIR=/app/data
ENV AIDER_DESK_PORT=24337

VOLUME ["/app/data"]
# Override the data directory to a path without a VOLUME declaration.
# The upstream VOLUME ["/app/data"] causes Docker to auto-create
# anonymous volumes; using /app/state avoids that entirely.
ENV AIDER_DESK_DATA_DIR=/app/state

EXPOSE ${AIDER_DESK_PORT}

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD node -e "require('http').get('http://localhost:${AIDER_DESK_PORT}/', (r) => {process.exit(r.statusCode === 200 || r.statusCode === 404 ? 0 : 1)}).on('error', () => process.exit(1))"

# ── 7) Entrypoint ────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["node", "out/server/runner.js"]
