ARG AIDER_DESK_IMAGE=aider-desk:local
FROM ${AIDER_DESK_IMAGE}

# The set of AiderDesk extensions to install and which of them are
# disabled by default is declared in aider-desk-extensions.yaml — the
# single source of truth. Parsed at build time by the AiderDesk
# runtime's bundled `yaml` package; no extra build dependencies.

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
        # ── Erlang/OTP build deps (required by asdf/mise erlang plugin) ──
        # build-essential/autoconf/m4: C toolchain + autotools
        # libncurses5-dev: terminal support (erl REPL)
        # libssl-dev: crypto/TLS (OTP ssl app)
        # libwxgtk3.2-dev + libgl1-mesa-dev + libglu1-mesa-dev: wx GUI (observer)
        # libpng-dev: wx dependency
        # libssh-dev: OTP ssh app
        # unixodbc-dev: OTP odbc app
        # xsltproc + fop + libxml2-utils: OTP documentation build
        # inotify-tools: Phoenix live-reload (fs watcher)
        build-essential \
        autoconf \
        m4 \
        libncurses5-dev \
        libssl-dev \
        libwxgtk3.2-dev \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        libpng-dev \
        libssh-dev \
        unixodbc-dev \
        xsltproc \
        fop \
        libxml2-utils \
        inotify-tools \
        cmake \
        pkg-config \
        # ── General build utilities ───────────────────────────────────────
        # wget: fallback downloader used by many mise plugins and install scripts
        # file: magic-byte detection used by build scripts and mise plugin checks
        # patch: source patching during OTP/Erlang compilation
        wget \
        file \
        patch \
        # ── C/C++ runtime and dev libraries ──────────────────────────────
        # libreadline-dev: erl REPL line editing; also needed by Ruby/Python builds
        # zlib1g-dev: required by Erlang, Ruby, Python, and many C extensions
        # libffi-dev: required by Python ctypes, Ruby FFI, and Elixir NIFs
        # libyaml-dev: required by Ruby psych gem and some Elixir YAML libs
        # libgmp-dev: required by Erlang crypto and some NIF builds
        libreadline-dev \
        zlib1g-dev \
        libffi-dev \
        libyaml-dev \
        libgmp-dev \
        # ── Locale and timezone ───────────────────────────────────────────
        # locales: required to generate en_US.UTF-8; Elixir/mix fail without UTF-8
        # tzdata: required by Elixir DateTime/Timex and Phoenix apps
        locales \
        tzdata \
        # ── Database clients ──────────────────────────────────────────────
        # postgresql-client: psql for mix ecto.create/migrate and DB inspection
        postgresql-client \
        # ── Interactive / debugging utilities ─────────────────────────────
        # tree: directory structure inspection
        # bash-completion: tab completion in interactive bash sessions
        # lsof: debug port conflicts (Phoenix default 4000)
        # strace: low-level debugging of NIF/port/syscall issues
        tree \
        bash-completion \
        lsof \
        strace \
        # ── Git extended tooling ──────────────────────────────────────────
        # git-lfs: large file storage; required for Hugging Face model repos
        # git-filter-repo: fast, safe history rewriting (replaces git filter-branch)
        git-lfs \
        git-filter-repo \
    # Debian 12 ships /etc/locale.gen empty; `locale-gen en_US.UTF-8` as an
    # argument is a no-op without an entry in that file, leaving only the
    # precompiled C.utf8 in `locale -a`. update-locale's sanity check then
    # invokes `locale charmap` with LANG/LC_ALL=en_US.UTF-8, glibc replies
    # "Cannot set ... default locale", and update-locale exits 255 with
    # "invalid locale settings". Seed /etc/locale.gen first, then run
    # locale-gen with no args so it compiles the listed entries.
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Claude SDK invokes `check-ignore` as a bare command (not `git check-ignore`),
# so provide a PATH shim that forwards to the git subcommand.
RUN printf '#!/bin/sh\nexec git check-ignore "$@"\n' >/usr/local/bin/check-ignore \
    && chmod +x /usr/local/bin/check-ignore

# ── 3a) Docker CLI + compose plugin (Docker-out-of-Docker client) ─────
#    Installs only the Docker CLI and the compose plugin — NO dockerd.
#    The container drives the *host* engine via a bind-mounted UNIX socket
#    when the user opts in with `shiki --docker-host` (see
#    compose.docker-sock.template.yaml). Without that flag the binaries
#    are dormant and there is no socket to talk to, so this layer is a
#    pure image-size cost (~30 MB) with zero runtime effect.
#
#    Choice of source: Docker's official apt repo (`docker-ce-cli` +
#    `docker-compose-plugin`) is preferred over Debian's `docker.io`
#    because:
#      • `docker.io` pulls ~80 MB of dockerd binaries this image will
#        never run (DooD, not DinD).
#      • Debian's `docker-compose-plugin` lags upstream by months and
#        has shipped a broken `docker compose` subcommand on slim bases.
#      • `docker-ce-cli` puts the compose plugin at
#        /usr/libexec/docker/cli-plugins/docker-compose, which `docker
#        compose <subcmd>` (modern compose, the one we test) finds
#        automatically.
#
#    Security: the CLI is harmless without a socket. The socket bind is
#    opt-in, per-session, at the compose layer — never baked into the
#    image. See compose.docker-sock.template.yaml for the full security
#    note.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && . /etc/os-release \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
        >/etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        docker-ce-cli \
        docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/* \
    && docker --version \
    && docker compose version

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

# ── 4) Locale ─────────────────────────────────────────────────────────
#    Elixir, mix, and Phoenix require a UTF-8 locale. Without it, mix
#    can emit encoding errors and some string operations misbehave.
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ── 6) Install mise ───────────────────────────────────────────────────
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

# ── 7) Preinstall AiderDesk extensions into the image ─────────────────
#    The set of extensions and which of them are disabled by default is
#    declared in aider-desk-extensions.yaml (single source of truth).
#    The YAML is copied into the image and parsed here with the
#    AiderDesk runtime's bundled `yaml` package (no extra build deps).
#    Both enabled and disabled IDs are installed; the disabled list is
#    rendered to a CSV that entrypoint.sh reads on container start to
#    seed settings.extensions.disabled in config.json.
COPY aider-desk-extensions.yaml /usr/local/share/aider-desk/extensions.yaml
COPY render-aiderdesk-extensions.js /usr/local/lib/aider-desk/render-extensions.js
COPY install-aiderdesk-extensions.sh /usr/local/bin/install-aiderdesk-extensions.sh
RUN chmod +x /usr/local/bin/install-aiderdesk-extensions.sh \
    && node /usr/local/lib/aider-desk/render-extensions.js \
        /usr/local/share/aider-desk/extensions.yaml \
        /usr/local/share/aider-desk/extensions-install.csv \
        /usr/local/share/aider-desk/extensions-disabled.csv \
    && /usr/local/bin/install-aiderdesk-extensions.sh \
        /root/.aider-desk/extensions \
        /usr/local/share/aider-desk/extensions-seed \
        "$(cat /usr/local/share/aider-desk/extensions-install.csv)" \
        "" \
        ""

# ── 8) Upstream env / volumes / port / healthcheck ────────────────────
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

# ── 9) Entrypoint ────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["node", "out/server/runner.js"]
