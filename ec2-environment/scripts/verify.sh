#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Ubuntu Box 2025 System Verification ==="
echo "Starting verification at $(date)"
echo

# Function to check command existence and version
check_command() {
    local cmd="$1"
    local version_arg="${2:---version}"
    local expected_version="$3"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        version_output=$($cmd $version_arg 2>&1 | head -n1)
        if [ -n "$expected_version" ]; then
            if echo "$version_output" | grep -q "$expected_version"; then
                echo -e "${GREEN}✓ $cmd installed ($version_output)${NC}"
                return 0
            else
                echo -e "${YELLOW}! $cmd installed but version mismatch ($version_output)${NC}"
                return 1
            fi
        else
            echo -e "${GREEN}✓ $cmd installed ($version_output)${NC}"
            return 0
        fi
    else
        echo -e "${RED}✗ $cmd not found${NC}"
        return 1
    fi
}

# Function to check system service
check_service() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo -e "${GREEN}✓ $service is running${NC}"
        return 0
    else
        echo -e "${RED}✗ $service is not running${NC}"
        return 1
    fi
}

# Track overall status
ERRORS=0

# System Information
echo "=== System Information ==="
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo

# System Services
echo "=== Core Services ==="
services=(
    "ssh"
    "docker"
    "fail2ban"
    "amazon-cloudwatch-agent"
    "auditd"
    "unattended-upgrades"
)

for service in "${services[@]}"; do
    check_service "$service" || ((ERRORS++))
done
echo

# Required Packages
echo "=== Required Packages ==="
packages=(
    "curl"
    "wget"
    "git"
    "vim"
    "nano"
    "build-essential"
    "python3"
    "jq"
    "docker"
)

for pkg in "${packages[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg"; then
        echo -e "${GREEN}✓ $pkg installed${NC}"
    else
        echo -e "${RED}✗ $pkg not installed${NC}"
        ((ERRORS++))
    fi
done
echo

# Development Tools
echo "=== Development Tools ==="
tools=(
    "mise"
    "uv"
    "fd"
    "rg"
    "fzf"
    "bun"
    "docker"
)

for tool in "${tools[@]}"; do
    check_command "$tool" || ((ERRORS++))
done
echo

# Runtime Versions
echo "=== Runtime Versions ==="
check_command "node" "--version" "v20" || ((ERRORS++))
check_command "go" "version" "go1.22" || ((ERRORS++))
check_command "rustc" "--version" || ((ERRORS++))
check_command "ruby" "--version" "3.3" || ((ERRORS++))
check_command "python3" "--version" "3.12" || ((ERRORS++))
echo

# Security Configuration
echo "=== Security Configuration ==="
# Check SSH configuration
if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config.d/hardening.conf; then
    echo -e "${GREEN}✓ SSH root login disabled${NC}"
else
    echo -e "${RED}✗ SSH root login not properly configured${NC}"
    ((ERRORS++))
fi

# Check fail2ban
if fail2ban-client status sshd >/dev/null 2>&1; then
    echo -e "${GREEN}✓ fail2ban configured for SSH${NC}"
else
    echo -e "${RED}✗ fail2ban not configured for SSH${NC}"
    ((ERRORS++))
fi

# Check AIDE database
if [ -f /var/lib/aide/aide.db ]; then
    echo -e "${GREEN}✓ AIDE database exists${NC}"
else
    echo -e "${RED}✗ AIDE database not found${NC}"
    ((ERRORS++))
fi
echo

# AWS Integration
echo "=== AWS Integration ==="
# Check instance identity
if curl -s http://169.254.169.254/latest/meta-data/instance-id >/dev/null; then
    echo -e "${GREEN}✓ EC2 metadata accessible${NC}"
else
    echo -e "${RED}✗ EC2 metadata not accessible${NC}"
    ((ERRORS++))
fi

# Check CloudWatch agent
if [ -f /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json ]; then
    echo -e "${GREEN}✓ CloudWatch agent configured${NC}"
else
    echo -e "${RED}✗ CloudWatch agent configuration missing${NC}"
    ((ERRORS++))
fi

# Check EFS utils
if command -v mount.efs >/dev/null 2>&1; then
    echo -e "${GREEN}✓ EFS utilities installed${NC}"
else
    echo -e "${RED}✗ EFS utilities not installed${NC}"
    ((ERRORS++))
fi
echo

# Docker Configuration
echo "=== Docker Configuration ==="
if groups ubuntu | grep -q docker; then
    echo -e "${GREEN}✓ Ubuntu user in docker group${NC}"
else
    echo -e "${RED}✗ Ubuntu user not in docker group${NC}"
    ((ERRORS++))
fi

if docker info >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker daemon running${NC}"
else
    echo -e "${RED}✗ Docker daemon not running${NC}"
    ((ERRORS++))
fi
echo

# Final Status
echo "=== Verification Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed successfully${NC}"
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s) during verification${NC}"
    exit 1
fi