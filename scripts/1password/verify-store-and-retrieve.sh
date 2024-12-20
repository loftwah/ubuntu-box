#!/bin/bash
# verify-store-and-retrieve.sh - Verify 1Password ENV storage and retrieval

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

compare_env_files() {
    local original="$1"
    local retrieved="$2"
    
    # Create temporary files with sorted, normalized content
    local temp_orig=$(mktemp)
    local temp_retr=$(mktemp)
    
    # Process files: remove comments, sort, and normalize whitespace
    grep -v '^#' "$original" | sort | sed 's/[[:space:]]*=[[:space:]]*/=/' > "$temp_orig"
    grep -v '^#' "$retrieved" | sort | sed 's/[[:space:]]*=[[:space:]]*/=/' > "$temp_retr"
    
    # Compare and show differences
    if diff -u "$temp_orig" "$temp_retr" > /dev/null; then
        echo "✅ Verification successful: Original and retrieved files match"
        local result=0
    else
        echo "❌ Verification failed: Files differ"
        echo "Differences found:"
        diff -u "$temp_orig" "$temp_retr" | grep -E '^\+|\-' | grep -v '^\+\+\+|\-\-\-'
        local result=1
    fi
    
    # Cleanup
    rm "$temp_orig" "$temp_retr"
    return $result
}

# Main script
VAULT_NAME="Personal"
ENV_FILE=".env"
PREFIX="env"
PROJECT_NAME=""
ENV_TYPE="development"
TEMP_RETRIEVE_FILE=$(mktemp)

show_help() {
    echo "Usage: $0 [-f ENV_FILE] [-v VAULT_NAME] [-p PROJECT_NAME] [-t ENV_TYPE] [-x PREFIX]"
    echo
    echo "Options:"
    echo " -f ENV_FILE      Specify the .env file to verify (default: .env)"
    echo " -v VAULT_NAME    Specify the 1Password vault (default: Personal)"
    echo " -p PROJECT_NAME  Project name for organization (default: current directory name)"
    echo " -t ENV_TYPE     Environment type (default: development)"
    echo " -x PREFIX       Custom prefix for the 1Password item (default: env)"
    echo " -i             Interactive mode - select vault from list"
    echo " -k             Keep temporary files for inspection"
    echo " -h             Show this help message"
    exit 0
}

cleanup() {
    if [[ "$KEEP_TEMPS" != "true" ]]; then
        rm -f "$TEMP_RETRIEVE_FILE"
    else
        echo "Temporary files kept for inspection:"
        echo "Retrieved file: $TEMP_RETRIEVE_FILE"
    fi
}
trap cleanup EXIT

while getopts "f:v:p:t:x:ikh" opt; do
    case ${opt} in
        f) ENV_FILE="$OPTARG" ;;
        v) VAULT_NAME="$OPTARG" ;;
        p) PROJECT_NAME="$OPTARG" ;;
        t) ENV_TYPE="$OPTARG" ;;
        x) PREFIX="$OPTARG" ;;
        i) VAULT_NAME=$(select_vault "$VAULT_NAME") ;;
        k) KEEP_TEMPS="true" ;;
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

echo "🔄 Starting verification process..."
echo "Project: $PROJECT_NAME"
echo "Environment: $ENV_TYPE"

# Step 1: Store the environment file
echo "📤 Storing environment file..."
timestamp=$(date +%Y%m%d_%H%M%S)
note_title="${PREFIX}.${PROJECT_NAME}.${ENV_TYPE}.${timestamp}"

# Build the note content with metadata
note_content="# Environment Variables for ${PROJECT_NAME}\n"
note_content+="# Environment: ${ENV_TYPE}\n"
note_content+="# Created: $(date -u '+%Y-%m-%d %H:%M:%S UTC')\n"
note_content+="# Project: ${PROJECT_NAME}\n\n"

while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    note_content+="$key=$value\n"
done < "$ENV_FILE"

if ! op document create - \
    --title "$note_title" \
    --vault "$VAULT_NAME" \
    --tags "env,secrets,${PROJECT_NAME},${ENV_TYPE}" \
    <<< "$note_content"; then
    echo "❌ Failed to store environment file"
    exit 1
fi

echo "✅ Stored as: $note_title"

# Step 2: Retrieve the environment file
echo "📥 Retrieving environment file..."
if ! op document get "$note_title" --vault "$VAULT_NAME" > "$TEMP_RETRIEVE_FILE"; then
    echo "❌ Failed to retrieve environment file"
    exit 1
fi

# Step 3: Compare files
echo "🔍 Comparing original and retrieved files..."
if compare_env_files "$ENV_FILE" "$TEMP_RETRIEVE_FILE"; then
    echo "✅ Verification complete: All tests passed"
    exit 0
else
    echo "❌ Verification failed"
    exit 1
fi