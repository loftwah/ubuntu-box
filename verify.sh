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

# Function to check command existence and version
check_command() {
    local cmd="$1"
    local version_arg="${2:---version}"
    local expected_version="${3:-}"
    
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
check_command "python" "--version" "3.12" || ((ERRORS++))
check_command "uv" "--version" || ((ERRORS++))
check_command "node" "--version" "20" || ((ERRORS++))
check_command "bun" "--version" "1.0.21" || ((ERRORS++))
check_command "go" "version" "1.22" || ((ERRORS++))
check_command "rustc" "--version" "1.83" || ((ERRORS++))
check_command "cargo" "--version" || ((ERRORS++))
check_command "ruby" "--version" "3.3" || ((ERRORS++))
check_command "aws" "--version" "2.22.19" || ((ERRORS++))
check_command "fdfind" "--version" || ((ERRORS++))
check_command "rg" "--version" || ((ERRORS++))
check_command "fzf" "--version" || ((ERRORS++))
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