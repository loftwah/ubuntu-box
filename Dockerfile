# Start with Ubuntu 24.04 (Noble Numbat)
FROM ubuntu:24.04 as base

# Prevent interactive prompts
ARG DEBIAN_FRONTEND=noninteractive

# Install base system packages (matching EC2 environment)
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    build-essential \
    gcc \
    g++ \
    make \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    pkg-config \
    libssl-dev \
    zlib1g-dev \
    jq \
    yq \
    htop \
    ncdu \
    zip \
    unzip \
    tree \
    tmux \
    imagemagick \
    fd-find \
    fzf \
    ripgrep \
    libffi-dev \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

# Get official Python+UV
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS python
WORKDIR /python-build
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

# Get official Bun
FROM oven/bun:1.0.21 AS bun

# Get official Node.js
FROM node:20 AS node

# Get official Go
FROM golang:1.22-bookworm AS golang

# Back to our Ubuntu base for final image
FROM base AS final

# Copy from Python+UV
COPY --from=python /usr/local/bin/python* /usr/local/bin/
COPY --from=python /usr/local/bin/uv /usr/local/bin/
ENV PATH="/app/.venv/bin:$PATH"

# Copy from Bun
COPY --from=bun /usr/local/bin/bun /usr/local/bin/
COPY --from=bun /usr/local/bin/bunx /usr/local/bin/

# Copy from Node.js
COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/bin/npm /usr/local/bin/
COPY --from=node /usr/local/bin/npx /usr/local/bin/

# Copy from Go
COPY --from=golang /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

# Create working directory
WORKDIR /app

# Create and set up verify script
COPY verify.sh /usr/local/bin/verify
RUN chmod +x /usr/local/bin/verify

# Default command
CMD ["bash"]