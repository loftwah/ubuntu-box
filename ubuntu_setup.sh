#!/bin/bash

set -euo pipefail

# Update package list and upgrade existing packages
echo "Updating package list and upgrading system..."
apt update && apt upgrade -y

# Install essential tools
echo "Installing essential tools..."
apt install -y --no-install-recommends \
    curl wget build-essential git vim nano lynis fail2ban \
    sysstat auditd rkhunter acct aide libssl-dev \
    libreadline-dev zlib1g-dev unzip ca-certificates \
    gnupg lsb-release software-properties-common \
    python3-pip python3-dev libffi-dev libyaml-dev python3.12-venv

# AWS CLI Installation
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

# Remind about Piping Server usage
echo "---------------------------------------------------"
echo "Tip: Use Piping Server for quick file transfers!"
echo "Send: echo 'hello, world' | curl -T - https://ppng.io/hello"
echo "Get:  curl https://ppng.io/hello > hello.txt"
echo "More info: https://piping-ui.org"
echo "---------------------------------------------------"

# Configure RKHunter (with error handling)
echo "Configuring RKHunter..."
if [ -f /etc/rkhunter.conf ]; then
    sed -i 's|^WEB_CMD=.*|WEB_CMD=""|' /etc/rkhunter.conf || true
    rkhunter --update || true
    rkhunter --propupd || true
fi

# Configure AIDE
echo "Setting up AIDE..."
aideinit || true
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || true

# System hardening (keep the essential parts that work in Docker)
echo "Applying system hardening configurations..."
tee /etc/sysctl.d/99-hardening.conf <<EOF
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
EOF

# Install NVM for Node.js and Bun
echo "Installing Node.js via NVM and Bun..."
su - appuser -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash'
su - appuser -c '. ~/.nvm/nvm.sh && nvm install --lts && nvm use --lts'

# Install Bun
echo "Installing Bun..."
su - appuser -c 'curl -fsSL https://bun.sh/install | bash'

# Install Rust
echo "Installing Rust..."
su - appuser -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
su - appuser -c 'source "$HOME/.cargo/env"'

# Install Ruby via rbenv
echo "Installing Ruby via rbenv..."
su - appuser -c 'git clone https://github.com/rbenv/rbenv.git ~/.rbenv'
su - appuser -c 'cd ~/.rbenv && src/configure && make -C src'
su - appuser -c 'export PATH="$HOME/.rbenv/bin:$PATH" && eval "$(~/.rbenv/bin/rbenv init -)" && \
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build && \
    rbenv install 3.3.6 && rbenv global 3.3.6'

# Install Go
echo "Installing Go..."
wget https://go.dev/dl/go1.23.4.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.23.4.linux-amd64.tar.gz
rm go1.23.4.linux-amd64.tar.gz

# Install Python tools
echo "Installing Python tools..."
python3 -m venv /usr/local/venv
. /usr/local/venv/bin/activate
pip3 install --no-cache-dir poetry pipenv virtualenv

# Install uv
echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

# Add TypeScript globally via Bun
echo "Installing TypeScript..."
su - appuser -c '. ~/.bashrc && PATH=$PATH:$HOME/.bun/bin bun add -g typescript ts-node'

# Cleanup
echo "Cleaning up..."
apt autoremove -y
apt clean
rm -rf /var/lib/apt/lists/*

# Set environment variables for appuser
cat << 'EOF' >> /home/appuser/.bashrc
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
export PATH="$PATH:/usr/local/go/bin"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
source "$HOME/.cargo/env"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF

chown -R appuser:appuser /home/appuser

echo "Setup complete. Review system changes and logs for any necessary manual interventions."