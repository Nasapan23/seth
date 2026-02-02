# Seth - Secure OpenClaw Assistant
# Multi-platform: works on ARM64 (Apple Silicon, Oracle ARM, Raspberry Pi) and x86_64
# Ubuntu 24.04 with Node.js 22, OpenClaw, and Playwright
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
# System dependencies + Chromium deps for Playwright
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
    # Playwright/Chromium dependencies (Ubuntu 24.04 naming)
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
# Install Playwright browsers (Chromium only for ARM64 compatibility)
# =============================================================================
USER seth
WORKDIR /home/seth

# Set Playwright to use system chromium path
ENV PLAYWRIGHT_BROWSERS_PATH=/home/seth/.cache/ms-playwright
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=0

# Install only Chromium (Firefox/WebKit have ARM64 issues)
RUN npx playwright install chromium --with-deps || true

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
# Copy scripts
# =============================================================================
COPY --chown=seth:seth scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=seth:seth scripts/healthcheck.sh /usr/local/bin/healthcheck.sh

USER root
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

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
