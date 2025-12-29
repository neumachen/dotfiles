# syntax=docker/dockerfile:1.7

# hadolint ignore=DL3008
FROM debian:12-slim AS base

LABEL org.opencontainers.image.title="Brownie"
LABEL org.opencontainers.image.description="Brownie base (mise + secure defaults) for AI tooling containers"
LABEL org.opencontainers.image.licenses="MIT"

ARG DEBIAN_FRONTEND=noninteractive

# Optional: pin mise version (leave empty to accept installer default)
ARG MISE_VERSION=""

# Fingerprint from mise install docs
ARG MISE_GPG_FINGERPRINT="24853EC9F655CE80B48E6C3A8B81C9D17413A06D"

# CI-friendly defaults; runtime can override with --user
ARG UID="1000"
ARG GID="1000"

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Base packages (minimal, plus GPG tools for verifying mise installer)
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        openssh-client \
        tini \
        less \
        gnupg \
        dirmngr \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user/group robustly (handles macOS GID collisions like 20).
# User is always named "brownie" (no username arg).
RUN set -eux; \
  if ! getent group "${GID}" >/dev/null; then \
    groupadd --gid "${GID}" brownie; \
  fi; \
  \
  if id -u brownie >/dev/null 2>&1; then \
    existing_uid="$(id -u brownie)"; \
    if [ "${existing_uid}" != "${UID}" ]; then \
      echo "ERROR: user 'brownie' exists with UID ${existing_uid}, expected ${UID}" >&2; \
      exit 1; \
    fi; \
  elif getent passwd "${UID}" >/dev/null; then \
    pw_entry="$(getent passwd "${UID}")"; \
    existing_user="${pw_entry%%:*}"; \
    echo "ERROR: UID ${UID} already exists in image as '${existing_user}'. Choose a different UID or omit UID/GID build args." >&2; \
    exit 1; \
  else \
    useradd --uid "${UID}" --gid "${GID}" --create-home --shell /bin/bash brownie; \
  fi; \
  \
  install -d -m 0755 -o "${UID}" -g "${GID}" /workspace /data /mise; \
  install -d -m 0755 -o "${UID}" -g "${GID}" /home/brownie/.config

# Standard mount point for all tool variants (each uses its own subdir)
VOLUME ["/data"]

# Install mise with GPG verification; enforce signer via VALIDSIG fingerprint check
ENV MISE_INSTALL_PATH="/usr/local/bin/mise"
RUN set -eux; \
  gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "${MISE_GPG_FINGERPRINT}"; \
  curl -fsSL "https://mise.jdx.dev/install.sh.sig" -o /tmp/install.sh.sig; \
  gpg --batch --status-fd=2 --decrypt /tmp/install.sh.sig > /tmp/install.sh 2> /tmp/mise.gpg.status; \
  grep -q "^\[GNUPG:\] VALIDSIG ${MISE_GPG_FINGERPRINT}" /tmp/mise.gpg.status; \
  chmod 0755 /tmp/install.sh; \
  if [[ -n "${MISE_VERSION}" ]]; then \
    MISE_VERSION="${MISE_VERSION}" MISE_INSTALL_PATH="${MISE_INSTALL_PATH}" bash /tmp/install.sh; \
  else \
    MISE_INSTALL_PATH="${MISE_INSTALL_PATH}" bash /tmp/install.sh; \
  fi; \
  rm -f /tmp/install.sh /tmp/install.sh.sig /tmp/mise.gpg.status; \
  \
  # Remove GPG tooling used only for install verification
  apt-get update; \
  apt-get purge -y --auto-remove gnupg dirmngr; \
  rm -rf /var/lib/apt/lists/*; \
  \
  mise --version;

# mise runtime dirs and PATH
ENV MISE_DATA_DIR="/mise"
ENV MISE_CONFIG_DIR="/mise"
ENV MISE_CACHE_DIR="/mise/cache"
ENV PATH="/mise/shims:/home/brownie/.local/bin:${PATH}"

ENV LANG="C.UTF-8"
ENV LC_ALL="C.UTF-8"

# Copy entrypoint from repo-root build context
COPY --chown=brownie:brownie devcontainer/brownie-container.entrypoint.sh /usr/local/bin/brownie-container.entrypoint.sh
RUN chmod 0755 /usr/local/bin/brownie-container.entrypoint.sh;

USER brownie
WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/brownie-container.entrypoint.sh"]
CMD ["bash"]

# -------------------------
# AIDER TARGET
# -------------------------
FROM base AS aider

ARG PYTHON_VERSION="3.12.12"
ARG UV_VERSION="0.9.18"
ARG PIPX_VERSION="1.8.0"
ARG AIDER_VERSION="0.86.1"

# Tool-specific data location under the shared /data mount
ENV AIDER_INPUT_HISTORY_FILE="/data/aider/.aider.input.history"
ENV AIDER_CHAT_HISTORY_FILE="/data/aider/.aider.chat.history.md"
ENV AIDER_LLM_HISTORY_FILE="/data/aider/.aider.llm.history"
ENV TOOL_DATA_SUBDIR="aider"

# Install toolchain with mise.
# GitHub token secret is REQUIRED and mounted readable by brownie (uid/gid/mode).
RUN --mount=type=secret,id=github_token,required=true,uid=${UID},gid=${GID},mode=0400 \
  set -eu; \
  test -s /run/secrets/github_token || { echo "GitHub token secret is required."; exit 2; }; \
  token="$(cat /run/secrets/github_token)"; \
  export GITHUB_TOKEN="$token" GH_TOKEN="$token"; \
  \
  mkdir -p /data/aider; \
  mise use -g "python@${PYTHON_VERSION}" \
  && mise use -g "uv@${UV_VERSION}" \
  && python -m pip install --no-cache-dir --user "pipx==${PIPX_VERSION}" \
  && mise use -g "pipx:aider-chat@${AIDER_VERSION}" \
  && mise reshim \
  && aider --version

CMD ["aider"]

# -------------------------
# FUTURE TARGET PLACEHOLDERS
# -------------------------
FROM base AS codex
ENV TOOL_DATA_SUBDIR="codex"
CMD ["bash"]

FROM base AS cloud
ENV TOOL_DATA_SUBDIR="cloud"
CMD ["bash"]
