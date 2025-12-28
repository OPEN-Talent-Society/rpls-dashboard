# Custom GitHub Runner for AI Enablement Projects
# Pre-installed: Node 20 LTS, Bun, Playwright, Lighthouse CI, pnpm
# Base image: myoung34/github-runner (Ubuntu-based)

FROM myoung34/github-runner:latest

LABEL maintainer="AI Enablement Academy"
LABEL description="Optimized self-hosted GitHub runner for Next.js/Bun/Playwright projects"

# Set environment variables
ENV NODE_VERSION=20
ENV BUN_INSTALL=/root/.bun
ENV PATH="${BUN_INSTALL}/bin:${PATH}"
ENV PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright
ENV PNPM_HOME=/root/.local/share/pnpm
ENV PATH="${PNPM_HOME}:${PATH}"

# Install system dependencies for Playwright and building
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    gnupg \
    # Playwright dependencies
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    libatspi2.0-0 \
    # Additional useful tools
    jq \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 LTS via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm globally
RUN npm install -g pnpm@latest

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash

# Install Lighthouse CI globally
RUN npm install -g @lhci/cli@latest

# Install Playwright with Chromium only (saves ~1GB disk space)
# Add firefox webkit to the install command if you need other browsers
RUN mkdir -p /tmp/playwright-setup \
    && cd /tmp/playwright-setup \
    && npm init -y \
    && npm install playwright@latest \
    && npx playwright install --with-deps chromium \
    && cd / \
    && rm -rf /tmp/playwright-setup

# Verify installations
RUN echo "=== Verifying installations ===" \
    && node --version \
    && npm --version \
    && pnpm --version \
    && bun --version \
    && lhci --version \
    && npx playwright --version

# Pre-create cache directories with proper permissions
RUN mkdir -p /root/.bun/install/cache \
    && mkdir -p /root/.npm \
    && mkdir -p ${PNPM_HOME} \
    && mkdir -p ${PLAYWRIGHT_BROWSERS_PATH}

# NOTE: Do NOT set WORKDIR - the base image requires its default working directory
# for config.sh and bin/Runner.Listener to function properly

# Default command (inherited from base image)
# The base image handles GitHub runner registration and execution
