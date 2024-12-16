#!/bin/bash

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function to check command existence
check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed$(command -v "$1")"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is not installed"
        return 1
    fi
}

# Function to run test command
test_command() {
    local cmd="$1"
    local name="${2:-$1}"
    if eval "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name test passed"
        return 0
    else
        echo -e "${RED}✗${NC} $name test failed"
        return 1
    }
}

echo -e "${BOLD}Verifying installed tools...${NC}"

# System tools
echo -e "\n${BOLD}Checking system tools:${NC}"
check_command "curl"
check_command "wget"
check_command "git"
check_command "vim"
check_command "nano"

# Security tools
echo -e "\n${BOLD}Checking security tools:${NC}"
check_command "lynis"
check_command "fail2ban-client"
check_command "rkhunter"
check_command "aide"

# AWS CLI
echo -e "\n${BOLD}Checking AWS CLI:${NC}"
check_command "aws"
test_command "aws --version" "AWS CLI"

# Node.js ecosystem
echo -e "\n${BOLD}Checking Node.js ecosystem:${NC}"
check_command "node"
check_command "npm"
check_command "bun"
test_command "bun --version" "Bun"
test_command "node --version" "Node.js"

# TypeScript
echo -e "\n${BOLD}Checking TypeScript:${NC}"
test_command "bun run tsc --version" "TypeScript"
test_command "bun run ts-node --version" "ts-node"

# Rust
echo -e "\n${BOLD}Checking Rust:${NC}"
check_command "rustc"
check_command "cargo"
test_command "rustc --version" "Rust"

# Ruby
echo -e "\n${BOLD}Checking Ruby:${NC}"
check_command "ruby"
check_command "rbenv"
test_command "ruby --version" "Ruby"
test_command "rbenv --version" "rbenv"

# Go
echo -e "\n${BOLD}Checking Go:${NC}"
check_command "go"
test_command "go version" "Go"

# Python ecosystem
echo -e "\n${BOLD}Checking Python ecosystem:${NC}"
check_command "python3"
check_command "pip3"
check_command "poetry"
check_command "pipenv"
check_command "uv"

# Test uv with pycowsay
echo -e "\n${BOLD}Testing uv with pycowsay:${NC}"
uv pip install pycowsay
echo -e "${GREEN}Testing pycowsay:${NC}"
uvx pycowsay 'suck my balls!'

# Environment variables
echo -e "\n${BOLD}Checking environment variables:${NC}"
test_command "echo \$PATH | grep -q '/usr/local/go/bin'" "Go PATH"
test_command "echo \$PATH | grep -q '/.rbenv/bin'" "rbenv PATH"
test_command "echo \$PATH | grep -q '/.bun/bin'" "Bun PATH"
test_command "echo \$PATH | grep -q '/.cargo/bin'" "Cargo PATH"

echo -e "\n${BOLD}Verification complete!${NC}"

# Quick benchmark (optional)
echo -e "\n${BOLD}Running quick performance test:${NC}"
echo "Testing bun performance..."
echo 'console.log("Hello World!")' > test.js
time bun run test.js
rm test.js

echo "Testing go performance..."
echo 'package main; import "fmt"; func main() { fmt.Println("Hello World!") }' > test.go
go build test.go
time ./test
rm test.go test

echo -e "\n${BOLD}All tests completed!${NC}"