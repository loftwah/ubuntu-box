#!/bin/bash
# retrieve-env-from-op.sh - Retrieve .env from 1Password secure note

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

list_env_files() {
    local vault="$1"
    local project="$2"
    local prefix="$3"
    
    echo "Available environment files:"
    if [[ -n "$project" ]]; then
        op item list --vault "$vault" --tags "env,${project}" --format=json | \
            jq -r '.[] | select(.title | startswith("'"${prefix}."'")) | .title'
    else
        op item list --vault "$vault" --tags "env" --format=json | \
            jq -r '.[] | select(.title | startswith("'"${prefix}."'")) | .title'
    fi
}

# Main script
VAULT_NAME="Personal"
OUTPUT_FILE=".env"
PREFIX="env"
PROJECT_NAME=""

show_help() {
    echo "Usage: $0 [-o OUTPUT_FILE] [-v VAULT_NAME] [-p PROJECT_NAME] [-x PREFIX] -t NOTE_TITLE"
    echo
    echo "Options:"
    echo " -o OUTPUT_FILE   Specify output file (default: .env)"
    echo " -v VAULT_NAME    Specify the 1Password vault (default: Personal)"
    echo " -p PROJECT_NAME  Filter by project name"
    echo " -x PREFIX       Item prefix to search for (default: env)"
    echo " -t NOTE_TITLE    Title of the secure note to retrieve"
    echo " -i              Interactive mode - select vault and note"
    echo " -l              List available environment files"
    echo " -h              Show this help message"
    exit 0
}

while getopts "o:v:p:t:x:ilh" opt; do
    case ${opt} in
        o) OUTPUT_FILE="$OPTARG" ;;
        v) VAULT_NAME="$OPTARG" ;;
        p) PROJECT_NAME="$OPTARG" ;;
        t) NOTE_TITLE="$OPTARG" ;;
        x) PREFIX="$OPTARG" ;;
        i) VAULT_NAME=$(select_vault "$VAULT_NAME") ;;
        l) LIST_MODE=true ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

check_op_auth

# List mode - show available env files and exit
if [[ "$LIST_MODE" = true ]]; then
    list_env_files "$VAULT_NAME" "$PROJECT_NAME" "$PREFIX"
    exit 0
fi

if [[ -z "$NOTE_TITLE" ]]; then
    echo "Error: Note title (-t) is required"
    echo "Use -l to list available environment files"
    show_help
fi

# Check if output file already exists
if [[ -f "$OUTPUT_FILE" ]]; then
    read -p "Output file $OUTPUT_FILE already exists. Overwrite? (y/N) " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo "Operation cancelled"
        exit 1
    fi
fi

# Retrieve the secure note
if op item get "$NOTE_TITLE" --vault "$VAULT_NAME" --fields notesPlain > "$OUTPUT_FILE"; then
    echo "✅ Environment variables retrieved to $OUTPUT_FILE"
else
    echo "❌ Failed to retrieve environment variables"
    exit 1
fi