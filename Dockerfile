# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Set non-interactive mode for APT
ENV DEBIAN_FRONTEND=noninteractive

# Update packages and install base tools
RUN apt update && apt install -y \
    curl wget build-essential git vim nano unzip && \
    apt clean && rm -rf /var/lib/apt/lists/*

# Add the setup script
ADD https://raw.githubusercontent.com/loftwah/ubuntu-box/refs/heads/main/ubuntu_setup.sh /tmp/ubuntu_setup.sh

# Make the script executable
RUN chmod +x /tmp/ubuntu_setup.sh

# Run the setup script
RUN /tmp/ubuntu_setup.sh

# Set the default shell to bash
CMD ["/bin/bash"]
