ARG AIDER_DESK_IMAGE=aider-desk:local
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
    seek,\
    sound-notification,\
    theme,\
    tps-counter,\
    tree-sitter-repo-map,\
    ultrathink,\
    wakatime,\
    https://github.com/neumachen/aiderdesk-codex-extension"
ARG AIDER_DESK_EXTENSIONS_APPEND=""
ARG AIDER_DESK_EXTENSIONS_OVERRIDE=""

# ── 1) XDG_CONFIG_HOME wiring ──────────────────────────────────────────
#    The container ships a baked-in /etc/xdg/git/config holding only
#    container-wide defaults (pager, editor, push/pull/rebase behavior,
#    excludesfile pointer, safe.directory). Identity, signing key, and
#    per-project routing are layered in at runtime by mounting a host
#    file at /etc/xdg/git/identity (see compose.template.yaml,
#    SHIKI_GIT_IDENTITY). The baked config ends with
#    `[include] path = /etc/xdg/git/identity` so the mount takes effect.
ENV XDG_CONFIG_HOME=/etc/xdg

# Defensively keep safe.directory at --system level too. Harmless if also
# present in /etc/xdg/git/config; survives if the XDG config ever fails to
# parse. Remove upstream's user-level gitconfig so it can't shadow
# /etc/xdg/git/config.
RUN git config --system --add safe.directory "*" \
    && rm -f /root/.gitconfig /root/.config/git/config \
    && mkdir -p /etc/xdg/git

# Bake the container-default git config and the global ignore file.
# - `config` is hand-authored next to this Dockerfile and contains no
#   identity. It ends with `[include] path = /etc/xdg/git/identity`,
#   which compose mounts read-only from the host.
# - `ignore` is chezmoi-rendered from private_dot_config/exact_git/private_ignore
#   so the host and the container share one source of truth for ignore patterns.
COPY config /etc/xdg/git/config
COPY ignore /etc/xdg/git/ignore

# ── 2) Use bash + pipefail for safer RUN steps ────────────────────────
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ── 3) Install SSH client + mise bootstrap + Claude SDK runtime deps ──
#    openssh-client provides ssh-keygen (git SSH signing) and ssh-add
#    (agent check). curl/ca-certificates/xz-utils/unzip are needed for
#    the official mise installer and common tool archives. ripgrep
#    (rg), bubblewrap (bwrap), and socat are required by Claude Code's
#    sandbox. The remaining packages mirror Anthropic's claude-code
#    devcontainer Dockerfile so the agent has the same operational
#    surface (shell utilities, optional outbound-firewall tooling). Tools
#    that are better managed by mise — gh, jq, fzf, vim, delta — are
#    omitted here and shipped via shiki-mise.toml below.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openssh-client \
        curl \
        ca-certificates \
        xz-utils \
        unzip \
        ripgrep \
        bubblewrap \
        socat \
        less \
        procps \
        sudo \
        zsh \
        man-db \
        gnupg2 \
        iptables \
        ipset \
        iproute2 \
        dnsutils \
        aggregate \
        nano \
    && rm -rf /var/lib/apt/lists/*

# Claude SDK invokes `check-ignore` as a bare command (not `git check-ignore`),
# so provide a PATH shim that forwards to the git subcommand.
RUN printf '#!/bin/sh\nexec git check-ignore "$@"\n' >/usr/local/bin/check-ignore \
    && chmod +x /usr/local/bin/check-ignore

# Enterprise-managed Claude Code settings. The compose template bind-mounts
# the host's user-level ~/.claude/settings.json (permissions, model, env)
# into the container, but the sandbox toggle MUST live here so it only
# applies inside shiki containers — never on the host. Managed settings
# have higher precedence than user settings, so this enforces the strong
# nested bwrap sandbox without leaking sandbox=true into the host's
# chezmoi-managed settings.json (which would break Claude Code on macOS
# where Seatbelt init has different requirements).
RUN mkdir -p /etc/claude-code \
    && printf '%s\n' '{"sandbox":{"enabled":true}}' \
        >/etc/claude-code/managed-settings.json

# ── 4) Install mise ───────────────────────────────────────────────────
ENV MISE_INSTALL_PATH=/usr/local/bin/mise
ENV MISE_CONFIG_DIR=/root/.config/mise
ENV MISE_DATA_DIR=/root/.local/share/mise
ENV MISE_CACHE_DIR=/root/.cache/mise
ENV PATH=/usr/local/share/mise/shims:/root/.local/share/mise/shims:${PATH}

RUN mkdir -p "${MISE_CONFIG_DIR}" "${MISE_DATA_DIR}" "${MISE_CACHE_DIR}" /etc/mise \
    && curl -fsSL https://mise.run | sh \
    && mise --version \
    && echo 'eval "$(mise activate bash)"' >>/root/.bashrc

# System-wide mise config: the baseline tools every shiki session gets
# (gh, jq, fzf, vim, delta). Installed on first container start by
# entrypoint.sh into the per-session MISE_DATA_DIR bind mount.
COPY shiki-mise.toml /etc/mise/config.toml

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
