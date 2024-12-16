# Build stage
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Add build-time metadata
LABEL org.opencontainers.image.authors="dean@deanlofts.xyz"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.description="Secure Ubuntu development environment"
LABEL org.opencontainers.image.source="https://github.com/loftwah/ubuntu-box"

# Final stage
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC

# Install essential tools first
RUN apt update && apt install -y --no-install-recommends \
    curl wget build-essential git vim nano lynis fail2ban \
    sysstat auditd rkhunter acct aide libssl-dev \
    libreadline-dev zlib1g-dev unzip ca-certificates \
    gnupg lsb-release software-properties-common \
    python3-pip python3-dev libffi-dev libyaml-dev python3.12-venv \
    && apt clean && rm -rf /var/lib/apt/lists/*

# Get tools from official images
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY --from=node:20 /usr/local/bin/node /usr/local/bin/
COPY --from=node:20 /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=oven/bun:latest /usr/local/bin/bun /usr/local/bin/
COPY --from=golang:1.23 /usr/local/go /usr/local/go
COPY --from=rust:latest /usr/local/cargo /usr/local/cargo
COPY --from=rust:latest /usr/local/rustup /usr/local/rustup
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
COPY --from=ruby:3.3 /usr/local/bin/ruby /usr/local/bin/
COPY --from=ruby:3.3 /usr/local/lib/ruby /usr/local/lib/ruby
COPY --from=ruby:3.3 /usr/local/bundle /usr/local/bundle
ENV GEM_HOME=/usr/local/bundle \
    BUNDLE_APP_CONFIG=/usr/local/bundle \
    PATH=/usr/local/bundle/bin:/usr/local/lib/ruby/gems/3.3.0/bin:$PATH

# Create non-root user and setup directories
RUN useradd -m -s /bin/bash appuser \
    && mkdir -p /home/appuser/.config \
    && mkdir -p /home/appuser/bin \
    && chown -R appuser:appuser /home/appuser

# Copy verification script and set permissions (while still root)
COPY verify.sh /home/appuser/bin/
RUN chmod +x /home/appuser/bin/verify.sh \
    && chown appuser:appuser /home/appuser/bin/verify.sh

# Install AWS CLI
COPY --from=amazon/aws-cli:latest /usr/local/aws-cli /usr/local/aws-cli
RUN ln -s /usr/local/aws-cli/v2/current/bin/aws /usr/local/bin/aws

# Switch to appuser for remaining setup
USER appuser
WORKDIR /home/appuser

# Install TypeScript via Bun and ensure it's in PATH
RUN bun install -g typescript ts-node && \
    echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.bashrc

# Set up Python environment
RUN python3 -m venv ~/.venv \
    && . ~/.venv/bin/activate

# Configure environment
RUN echo 'export PATH="/usr/local/go/bin:$PATH"' >> ~/.bashrc && \
    echo 'export PATH="/usr/local/cargo/bin:$PATH"' >> ~/.bashrc && \
    echo 'source ~/.venv/bin/activate' >> ~/.bashrc

# Source bashrc on login
CMD ["/bin/bash", "-l"]