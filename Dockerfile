# Seth - Secure OpenClaw Assistant
# Multi-platform: works on ARM64 (Apple Silicon, Oracle ARM, Raspberry Pi) and x86_64
# Ubuntu 24.04 with Node.js 22, OpenClaw, and Chrome/Chromium browser
#
# Build: docker compose build
# Run:   docker compose up -d

FROM ubuntu:24.04

# Build arguments
ARG OPENCLAW_VERSION=latest
ARG NODE_MAJOR=22
ARG SETH_UID=1000
ARG SETH_GID=1000
ARG TARGETARCH

# Labels
LABEL maintainer="nisipeanu"
LABEL description="Seth - Secure, Progressive OpenClaw Assistant"
LABEL org.opencontainers.image.source="https://github.com/noxt-repo/seth"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set locale
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# =============================================================================
# System dependencies + Chrome/Chromium browser dependencies
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    ca-certificates \
    curl \
    wget \
    gnupg \
    git \
    # Build essentials (for native modules)
    build-essential \
    python3 \
    # Chrome/Chromium browser dependencies (Ubuntu 24.04 naming)
    libasound2t64 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libexpat1 \
    libgbm1 \
    libglib2.0-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxshmfence1 \
    # Fonts
    fonts-liberation \
    fonts-noto-color-emoji \
    # Process management
    tini \
    # Health checks
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Node.js 22 LTS
# =============================================================================
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Create non-root user (use fixed UID/GID to avoid base image conflicts)
# Runtime uses SETH_UID:SETH_GID via compose user: directive for host permissions
# =============================================================================
RUN groupadd --gid 10000 seth \
    && useradd --uid 10000 --gid seth --shell /bin/bash --create-home seth

# =============================================================================
# Install OpenClaw globally
# =============================================================================
RUN npm install -g openclaw@${OPENCLAW_VERSION}

# =============================================================================
# Create directory structure
# =============================================================================
RUN mkdir -p \
    /home/seth/.openclaw \
    /home/seth/workspace \
    /home/seth/.cache \
    /opt/seth/skills \
    /opt/seth/prompts \
    && chown -R seth:seth /home/seth /opt/seth

# =============================================================================
# Install Browser (Google Chrome for amd64, Chromium for arm64)
# =============================================================================
# Must run as root to install packages
USER root

# Install browser based on architecture
# - amd64: Google Chrome (best compatibility, not available on ARM)
# - arm64: Chromium from Ubuntu repos
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        apt-get update \
        && wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        && dpkg -i google-chrome-stable_current_amd64.deb; \
        apt-get install -f -y \
        && rm -f google-chrome-stable_current_amd64.deb \
        && rm -rf /var/lib/apt/lists/* \
        && google-chrome-stable --version \
        && echo "Google Chrome installed for amd64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends chromium-browser \
        && rm -rf /var/lib/apt/lists/* \
        && echo "Chromium installed for arm64"; \
    else \
        echo "Unknown architecture: $TARGETARCH - skipping browser install"; \
    fi

# Set browser executable path based on architecture
ENV BROWSER_EXECUTABLE_PATH=${TARGETARCH:+/usr/bin/google-chrome-stable}
# Note: entrypoint.sh will detect the correct path at runtime

USER seth
WORKDIR /home/seth

# =============================================================================
# Environment configuration
# =============================================================================
ENV NODE_ENV=production
ENV HOME=/home/seth
ENV OPENCLAW_STATE_DIR=/home/seth/.openclaw
ENV OPENCLAW_CONFIG_PATH=/home/seth/.openclaw/openclaw.json

# OpenClaw paths
ENV OPENCLAW_WORKSPACE=/home/seth/workspace

# =============================================================================
# Copy scripts, skills, and prompts into the image
# =============================================================================
# Scripts
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

# Skills (baked into image for Swarm/Portainer compatibility)
COPY skills/local /opt/seth/skills
COPY skills/allowlist.yml /opt/seth/allowlist.yml

# Prompts (baked into image for Swarm/Portainer compatibility)
COPY prompts /opt/seth/prompts

USER root
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh \
    && chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh \
    && chown -R seth:seth /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh /opt/seth

# =============================================================================
# Runtime configuration
# =============================================================================
USER seth
WORKDIR /home/seth

# Ports: Gateway (18789), Browser CDP (18800)
EXPOSE 18789 18800

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Use tini as init
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

# Default command: run gateway
CMD ["gateway"]
