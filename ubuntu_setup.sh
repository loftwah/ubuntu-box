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
    python3-pip python3-dev

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

# Configure RKHunter
echo "Configuring RKHunter..."
sed -i 's|WEB_CMD="/bin/true"|WEB_CMD=""|' /etc/rkhunter.conf
rkhunter --update
rkhunter --propupd

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
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

# Install Bun
curl -fsSL https://bun.sh/install | bash

# Install Rust
echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# Install Ruby via rbenv
echo "Installing Ruby via rbenv..."
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
cd ~/.rbenv && src/configure && make -C src
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
RUBY_VERSION="3.3.6"
rbenv install "$RUBY_VERSION"
rbenv global "$RUBY_VERSION"

# Install Go
echo "Installing Go..."
wget https://go.dev/dl/go1.23.4.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.23.4.linux-amd64.tar.gz
rm go1.23.4.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc

# Install Python tools
echo "Installing Python tools..."
pip3 install --no-cache-dir poetry pipenv virtualenv

# Add TypeScript globally via Bun
echo "Installing TypeScript..."
bun add -g typescript ts-node

# Cleanup
echo "Cleaning up..."
apt autoremove -y
apt clean
rm -rf /var/lib/apt/lists/*

# Set environment variables
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
echo 'export PATH="$PATH:/usr/local/go/bin"' >> ~/.bashrc
echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc
echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc
echo 'source $HOME/.cargo/env' >> ~/.bashrc
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc

echo "Setup complete. Review system changes and logs for any necessary manual interventions."