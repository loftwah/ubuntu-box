# Build stage
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Add build-time metadata
LABEL org.opencontainers.image.authors="dean@deanlofts.xyz"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.description="Secure Ubuntu development environment"
LABEL org.opencontainers.image.source="https://github.com/loftwah/ubuntu-box"

# Install build dependencies
RUN apt update && apt install -y --no-install-recommends \
    curl wget build-essential git vim nano unzip \
    && apt clean && rm -rf /var/lib/apt/lists/*

# Final stage
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC

# Copy build artifacts from builder
COPY --from=builder /usr/local/bin /usr/local/bin

# Create non-root user
RUN useradd -m -s /bin/bash appuser \
    && mkdir -p /home/appuser/.config \
    && chown -R appuser:appuser /home/appuser

# Copy setup script from local context
COPY ubuntu_setup.sh /tmp/ubuntu_setup.sh
RUN chmod +x /tmp/ubuntu_setup.sh

# Run setup script as root (needed for system setup)
RUN /tmp/ubuntu_setup.sh

# Switch to non-root user
USER appuser
WORKDIR /home/appuser

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["/bin/bash"]