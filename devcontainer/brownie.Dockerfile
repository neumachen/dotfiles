ARG UPSTREAM_IMAGE=ghcr.io/hotovo/aider-desk:latest
FROM ${UPSTREAM_IMAGE}

# ── 1) XDG_CONFIG_HOME wiring ──────────────────────────────────────────
#    Entrypoint generates git config here from env vars at runtime.
ENV XDG_CONFIG_HOME=/etc/xdg

# Move safe.directory to system-level config so it doesn't conflict
# with the generated XDG config.  Remove upstream's user-level gitconfig.
RUN git config --system --add safe.directory "*" \
    && rm -f /root/.gitconfig /root/.config/git/config \
    && mkdir -p /etc/xdg/git

# ── 2) Install openssh-client ─────────────────────────────────────────
#    Provides ssh-keygen (git SSH signing) and ssh-add (agent check).
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-client \
    && rm -rf /var/lib/apt/lists/*

# ── 3) Upstream env / volumes / port / healthcheck ────────────────────
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

# ── 4) Entrypoint ────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["node", "out/server/runner.js"]
