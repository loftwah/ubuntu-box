#!/bin/bash

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/ubuntu_setup.log"
CHECKSUM_FILE="${SCRIPT_DIR}/checksums.txt"

# Version definitions
RUBY_VERSION="3.3.6"
GO_VERSION="1.23.4"
NODE_VERSION="20.11.0"

# Logging functions
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

error() {
    log "ERROR" "$*"
    return 1
}

# Error handling
handle_error() {
    local line_no=$1
    local exit_code=$2
    log "ERROR" "Error occurred in script at line: ${line_no}"
    log "ERROR" "Exit code: ${exit_code}"
}

trap 'handle_error ${LINENO} $?' ERR

# Function to verify checksums
verify_checksum() {
    local file=$1
    local expected=$2
    local actual
    actual=$(sha256sum "$file" | cut -d' ' -f1)
    if [ "$actual" != "$expected" ]; then
        error "Checksum verification failed for $file"
        return 1
    fi
    log "INFO" "Checksum verified for $file"
}

# Function to check if running in Docker
in_docker() {
    [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup
}

# Function to check command existence
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "Command not found: $1"
        return 1
    fi
}

# Function to check version compatibility
check_version() {
    local current=$1
    local required=$2
    if [ "$(printf '%s\n' "$required" "$current" | sort -V | head -n1)" != "$required" ]; then
        error "Version $current is less than required version $required"
        return 1
    fi
}

# Backup function
backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log "INFO" "Backup created for $file"
    fi
}

# Initialize logging
mkdir -p "$(dirname "${LOG_FILE}")"
touch "${LOG_FILE}"
log "INFO" "Starting Ubuntu setup script"

# Update and upgrade
log "INFO" "Updating package list and upgrading system..."
apt update && apt upgrade -y || error "Failed to update/upgrade system"

# Install essential tools with parallel installation
log "INFO" "Installing essential tools..."
apt install -y --no-install-recommends \
    curl wget build-essential git vim nano lynis fail2ban \
    sysstat auditd rkhunter acct aide libssl-dev \
    libreadline-dev zlib1g-dev unzip ca-certificates \
    gnupg lsb-release software-properties-common \
    || error "Failed to install essential tools"

# AWS CLI Installation with checksum verification
log "INFO" "Installing AWS CLI v2..."
AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
AWS_CLI_CHECKSUM="expected-checksum-here" # Replace with actual checksum

curl -fsSL "$AWS_CLI_URL" -o awscliv2.zip
verify_checksum awscliv2.zip "$AWS_CLI_CHECKSUM"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

# Security tools configuration
if ! in_docker; then
    # Lynis audit
    log "INFO" "Running Lynis system audit..."
    lynis audit system --quiet --logfile /var/log/lynis.log --report-file /var/log/lynis-report.dat

    # Fail2Ban configuration
    log "INFO" "Configuring Fail2Ban..."
    backup_file "/etc/fail2ban/jail.local"
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    
    if [ -z "$(ip -6 addr show scope global 2>/dev/null)" ]; then
        log "INFO" "IPv6 not detected. Disabling in Fail2Ban..."
        sed -i '/\[DEFAULT\]/a allowipv6 = no' /etc/fail2ban/jail.local
    fi
    
    systemctl enable fail2ban
    systemctl start fail2ban

    # Auditd configuration
    log "INFO" "Configuring auditd..."
    backup_file "/etc/audit/rules.d/passwd_changes.rules"
    cat > /etc/audit/rules.d/passwd_changes.rules <<EOF
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers_changes
EOF
    augenrules --load
    systemctl enable auditd
    systemctl start auditd
fi

# RKHunter configuration
log "INFO" "Configuring RKHunter..."
backup_file "/etc/rkhunter.conf"
sed -i 's|WEB_CMD="/bin/true"|WEB_CMD=""|' /etc/rkhunter.conf
rkhunter --update
rkhunter --propupd

# AIDE configuration
log "INFO" "Setting up AIDE..."
aideinit
mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || true

# System hardening
log "INFO" "Applying system hardening configurations..."
backup_file "/etc/sysctl.d/99-hardening.conf"
cat > /etc/sysctl.d/99-hardening.conf <<EOF
# Network security
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0

# Additional hardening
kernel.randomize_va_space=2
kernel.dmesg_restrict=1
kernel.sysrq=0
fs.suid_dumpable=0
EOF

if ! in_docker; then
    sysctl --system
fi

# Development tools installation
if ! in_docker; then
    # NVM and Node.js
    log "INFO" "Installing Node.js via NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"

    # Bun
    log "INFO" "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash

    # Rust
    log "INFO" "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # Ruby via rbenv
    log "INFO" "Installing Ruby via rbenv..."
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    cd ~/.rbenv && src/configure && make -C src
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    rbenv install "$RUBY_VERSION"
    rbenv global "$RUBY_VERSION"

    # Go
    log "INFO" "Installing Go..."
    GO_FILENAME="go${GO_VERSION}.linux-amd64.tar.gz"
    wget "https://go.dev/dl/${GO_FILENAME}"
    tar -C /usr/local -xzf "${GO_FILENAME}"
    rm "${GO_FILENAME}"
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
    source ~/.profile
fi

# Set up automatic security updates
log "INFO" "Configuring automatic security updates..."
apt install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

# Cleanup
log "INFO" "Cleaning up..."
apt autoremove -y
apt clean
rm -rf /var/lib/apt/lists/*

# Final security checks
log "INFO" "Running final security checks..."
if ! in_docker; then
    lynis audit system --quick
    rkhunter --check --skip-keypress
fi

log "INFO" "Setup complete. Please review logs at ${LOG_FILE}"

# Create health check endpoint
if [ -n "${HEALTH_CHECK_PORT:-}" ]; then
    mkdir -p /usr/local/bin
    cat > /usr/local/bin/health_check.sh <<EOF
#!/bin/bash
echo "HTTP/1.1 200 OK"
echo "Content-Type: application/json"
echo ""
echo '{"status": "healthy", "timestamp": "'"\$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"}'
EOF
    chmod +x /usr/local/bin/health_check.sh
    nohup nc -l -p "${HEALTH_CHECK_PORT}" -e /usr/local/bin/health_check.sh &
fi

exit 0