#!/bin/bash

set -euo pipefail

# Update package list and upgrade existing packages
echo "Updating package list and upgrading system..."
apt update && apt upgrade -y

# Install essential tools
echo "Installing essential tools..."
apt install -y curl wget build-essential git vim nano lynis fail2ban sysstat auditd rkhunter acct aide libssl-dev libreadline-dev zlib1g-dev unzip

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

# Run Lynis audit
echo "Running Lynis system audit..."
lynis audit system --quiet --logfile /var/log/lynis.log --report-file /var/log/lynis-report.dat

# Configure Fail2Ban
echo "Configuring Fail2Ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
if [ -z "$(ip -6 addr show scope global)" ]; then
    echo "IPv6 not detected. Disabling in Fail2Ban..."
    sed -i '/\[DEFAULT\]/a allowipv6 = no' /etc/fail2ban/jail.local
fi
systemctl enable fail2ban
systemctl start fail2ban

# Enable auditd with custom rules
echo "Configuring auditd..."
tee /etc/audit/rules.d/passwd_changes.rules <<EOF
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
EOF
augenrules --load
systemctl enable auditd
systemctl start auditd

# Configure RKHunter
echo "Configuring RKHunter..."
sed -i 's|WEB_CMD="/bin/true"|WEB_CMD=""|' /etc/rkhunter.conf
rkhunter --update
rkhunter --propupd

# Configure AIDE
echo "Setting up AIDE for file integrity monitoring..."
aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Harden system configuration
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
sysctl --system

# Restrict compiler access to root only
echo "Restricting compiler access to root only..."
chmod o-rx /usr/bin/gcc /usr/bin/cc

# Install NVM for Node.js and Bun
echo "Installing Node.js via NVM and Bun..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
source ~/.bashrc
nvm install --lts
curl -fsSL https://bun.sh/install | bash

# Install Rust
echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Ruby via rbenv
echo "Installing Ruby via rbenv..."
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

RUBY_VERSION="3.3.6" # Latest Ruby version
echo "Installing Ruby $RUBY_VERSION..."
rbenv install "$RUBY_VERSION"
rbenv global "$RUBY_VERSION"

# Verify Ruby installation
echo "Ruby installation complete. Verifying..."
ruby -v

# Install Go
echo "Installing Go..."
wget https://go.dev/dl/go1.23.4.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.23.4.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
source ~/.profile

# Cleanup
echo "Cleaning up unused packages..."
apt autoremove -y

# Final message
echo "Setup complete. Review system changes and logs for any necessary manual interventions."
