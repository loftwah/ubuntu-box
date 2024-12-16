#!/bin/bash

set -euo pipefail

# Update package list and upgrade existing packages
echo "Updating package list and upgrading system..."
sudo apt update && sudo apt upgrade -y

# Install essential tools
echo "Installing essential tools..."
sudo apt install -y curl wget build-essential git vim nano lynis fail2ban sysstat auditd rkhunter acct aide libssl-dev libreadline-dev zlib1g-dev

# Run Lynis audit
echo "Running Lynis system audit..."
sudo lynis audit system --quiet --logfile /var/log/lynis.log --report-file /var/log/lynis-report.dat

# Configure Fail2Ban
echo "Configuring Fail2Ban..."
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
if [ -z "$(ip -6 addr show scope global)" ]; then
    echo "IPv6 not detected. Disabling in Fail2Ban..."
    sudo sed -i '/\[DEFAULT\]/a allowipv6 = no' /etc/fail2ban/jail.local
fi
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Enable auditd with custom rules
echo "Configuring auditd..."
sudo tee /etc/audit/rules.d/passwd_changes.rules <<EOF
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
EOF
sudo augenrules --load
sudo systemctl enable auditd
sudo systemctl start auditd

# Configure RKHunter
echo "Configuring RKHunter..."
sudo sed -i 's|WEB_CMD="/bin/true"|WEB_CMD=""|' /etc/rkhunter.conf
sudo rkhunter --update
sudo rkhunter --propupd

# Configure AIDE
echo "Setting up AIDE for file integrity monitoring..."
sudo aideinit
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Harden system configuration
echo "Applying system hardening configurations..."
sudo tee /etc/sysctl.d/99-hardening.conf <<EOF
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
sudo sysctl --system

# Restrict compiler access to root only
echo "Restricting compiler access to root only..."
sudo chmod o-rx /usr/bin/gcc /usr/bin/cc

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
sudo tar -C /usr/local -xzf go1.23.4.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
source ~/.profile

# Cleanup
echo "Cleaning up unused packages..."
sudo apt autoremove -y

# Final message
echo "Setup complete. Review system changes and logs for any necessary manual interventions."
