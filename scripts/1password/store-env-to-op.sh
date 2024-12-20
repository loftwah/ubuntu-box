#!/bin/bash
# store-env-to-op.sh - Store .env in 1Password as a secure note

# Utility functions
check_op_auth() {
    if ! op account list >/dev/null 2>&1; then
        echo "Error: Not signed in to 1Password CLI. Please sign in first using 'eval \$(op signin)'."
        exit 1
    fi
}

select_vault() {
    local default_vault="$1"
    
    echo "Available vaults:"
    op vault list --format=json | jq -r '.[] | .name'
    
    read -p "Select vault (press Enter for default '$default_vault'): " selected_vault
    echo ${selected_vault:-$default_vault}
}

validate_env_file() {
    local env_file="$1"
    if [[ ! -f "$env_file" ]]; then
        echo "Error: $env_file does not exist."
        return 1
    fi
    return 0
}

# Main script
VAULT_NAME="Personal"
ENV_FILE=".env"
PREFIX="env"
PROJECT_NAME=""
ENV_TYPE="development"

show_help() {
    echo "Usage: $0 [-f ENV_FILE] [-v VAULT_NAME] [-p PROJECT_NAME] [-t ENV_TYPE] [-x PREFIX]"
    echo
    echo "Options:"
    echo " -f ENV_FILE      Specify the .env file to process (default: .env)"
    echo " -v VAULT_NAME    Specify the 1Password vault (default: Personal)"
    echo " -p PROJECT_NAME  Project identifier (default: current directory name)"
    echo " -t ENV_TYPE     Environment type (default: development)"
    echo "                 Valid types: development, staging, production, testing"
    echo " -x PREFIX       Custom prefix for the 1Password item (default: env)"
    echo " -i             Interactive mode - select vault from list"
    echo " -h             Show this help message"
    exit 0
}

while getopts "f:v:p:t:x:ih" opt; do
    case ${opt} in
        f) ENV_FILE="$OPTARG" ;;
        v) VAULT_NAME="$OPTARG" ;;
        p) PROJECT_NAME="$OPTARG" ;;
        t) ENV_TYPE="$OPTARG" ;;
        x) PREFIX="$OPTARG" ;;
        i) VAULT_NAME=$(select_vault "$VAULT_NAME") ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

check_op_auth
validate_env_file "$ENV_FILE" || exit 1

# If no project name specified, use current directory name
if [[ -z "$PROJECT_NAME" ]]; then
    PROJECT_NAME=$(basename "$(pwd)")
fi

# Validate environment type
case "$ENV_TYPE" in
    development|staging|production|testing) ;;
    *)
        echo "Error: Invalid environment type. Must be one of: development, staging, production, testing"
        exit 1
        ;;
esac

# Create a unique, organized title
timestamp=$(date +%Y%m%d_%H%M%S)
note_title="${PREFIX}.${PROJECT_NAME}.${ENV_TYPE}.${timestamp}"

# Build note content with metadata
note_content="# Environment Variables for ${PROJECT_NAME}\n"
note_content+="# Environment: ${ENV_TYPE}\n"
note_content+="# Created: $(date -u '+%Y-%m-%d %H:%M:%S UTC')\n"
note_content+="# Project: ${PROJECT_NAME}\n\n"
note_content+="$(cat "$ENV_FILE")"

# Store as secure note
if op item create --category "Secure Note" --vault "$VAULT_NAME" --title "$note_title" \
   --tags "env,secrets,${PROJECT_NAME},${ENV_TYPE}" --notes-plain "$note_content"; then
    echo "✅ Environment variables stored in 1Password as '$note_title'"
    echo "Tags added: env, secrets, ${PROJECT_NAME}, ${ENV_TYPE}"
else
    echo "❌ Failed to store environment variables"
    exit 1
fi