#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Ubuntu Box 2025 Docker Environment Verification ==="
echo "Starting verification at $(date)"
echo

# Track overall status
ERRORS=0

# Function to check package installation through dpkg
check_package() {
    local pkg="$1"
    if dpkg -l "$pkg" 2>/dev/null | grep -q ^ii; then
        echo -e "${GREEN}✓ $pkg installed${NC}"
        return 0
    else
        echo -e "${RED}✗ $pkg not installed${NC}"
        return 1
    fi
}

# Function to check command existence
check_command() {
    local cmd="$1"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ $cmd installed${NC}"
        return 0
    else
        echo -e "${RED}✗ $cmd not found${NC}"
        return 1
    fi
}

# Required Packages
echo "=== Required Packages ==="
check_package "curl" || ((ERRORS++))
check_package "wget" || ((ERRORS++))
check_package "git" || ((ERRORS++))
check_package "vim" || ((ERRORS++))
check_package "nano" || ((ERRORS++))
check_package "build-essential" || ((ERRORS++))
check_package "gcc" || ((ERRORS++))
check_package "g++" || ((ERRORS++))
echo

# Development Tools
echo "=== Development Tools ==="
check_command "python3" || ((ERRORS++))
check_command "uv" || ((ERRORS++))
check_command "node" || ((ERRORS++))
check_command "bun" || ((ERRORS++))
check_command "go" || ((ERRORS++))
check_command "rustc" || ((ERRORS++))
check_command "cargo" || ((ERRORS++))
check_command "ruby" || ((ERRORS++))
check_command "aws" || ((ERRORS++))
check_command "fdfind" || ((ERRORS++))
check_command "rg" || ((ERRORS++))
check_command "fzf" || ((ERRORS++))
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
