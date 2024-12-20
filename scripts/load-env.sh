#!/bin/bash

# Detect if script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not run directly"
    echo "Usage: source $(basename "$0")"
    echo "Try: source $0"
    exit 1
fi

# Print usage example if --help is passed
if [ "$1" = "--help" ]; then
    echo "Usage: source $(basename "$0")"
    echo ""
    echo "This script loads environment variables from .env in the current directory."
    echo ""
    echo "Examples:"
    echo "  # Must be run from directory containing .env file:"
    echo "  $ source ./load-env.sh"
    echo "  $ . ./load-env.sh"
    echo ""
    echo "Note: Must be sourced to affect current shell environment"
    exit 0
fi

# Check if .env file exists in current directory
if [ ! -f .env ]; then
    echo "Error: No .env file found in current directory ($(pwd))"
    exit 1
fi

# Load environment variables
echo "Loading environment from: $(pwd)/.env"
set -a
source .env
set +a