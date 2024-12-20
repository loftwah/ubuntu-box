#!/bin/bash
# verify-store-and-retrieve.sh - Verify 1Password ENV storage/retrieval

check_dependencies() {
    for script in store-env-to-op.sh retrieve-env-from-op.sh; do
        if [[ ! -f "$script" ]]; then
            echo "❌ Missing $script"
            exit 1
        fi
        chmod +x "$script"
    done
}

compare_files() {
    local original="$1"
    local retrieved="$2"
    
    # Create temp files with normalized content
    local temp_orig=$(mktemp)
    local temp_retr=$(mktemp)
    
    # Normalize and sort both files
    grep -v '^#' "$original" | sort | sed 's/[[:space:]]*=[[:space:]]*/=/' > "$temp_orig"
    grep -v '^#' "$retrieved" | sort | sed 's/[[:space:]]*=[[:space:]]*/=/' > "$temp_retr"
    
    echo "📄 Original content (normalized):"
    cat "$temp_orig"
    echo "📄 Retrieved content (normalized):"
    cat "$temp_retr"
    
    if diff "$temp_orig" "$temp_retr" >/dev/null; then
        echo "✅ Files match perfectly"
        rm "$temp_orig" "$temp_retr"
        return 0
    else
        echo "❌ Files differ:"
        diff "$temp_orig" "$temp_retr"
        rm "$temp_orig" "$temp_retr"
        return 1
    fi
}

VAULT_NAME="Personal"
ENV_FILE=".env"
PROJECT_NAME=$(basename "$(pwd)")
ENV_TYPE="development"

while getopts "f:v:p:t:h" opt; do
    case ${opt} in
        f) ENV_FILE="$OPTARG" ;;
        v) VAULT_NAME="$OPTARG" ;;
        p) PROJECT_NAME="$OPTARG" ;;
        t) ENV_TYPE="$OPTARG" ;;
        h)
           echo "Usage: $0 [-f env_file] [-v vault] [-p project] [-t type]"
           exit 0
           ;;
    esac
done

check_dependencies

if [[ ! -f "$ENV_FILE" ]]; then
    echo "❌ Error: $ENV_FILE not found"
    exit 1
fi

echo "🔄 Starting verification..."
echo "📂 Project: $PROJECT_NAME"
echo "🔐 Vault: $VAULT_NAME"
echo "📄 File: $ENV_FILE"

# Store the env file
if ! ./store-env-to-op.sh -f "$ENV_FILE" -p "$PROJECT_NAME" -t "$ENV_TYPE" -v "$VAULT_NAME"; then
    echo "❌ Store failed"
    exit 1
fi

# Get the title of the note we just stored
if [[ ! -f /tmp/last_stored_note ]]; then
    echo "❌ Couldn't find stored note title"
    exit 1
fi
NOTE_TITLE=$(cat /tmp/last_stored_note)
rm /tmp/last_stored_note

# Retrieve to a temp file
TEMP_FILE=$(mktemp)
if ! ./retrieve-env-from-op.sh -t "$NOTE_TITLE" -o "$TEMP_FILE" -v "$VAULT_NAME"; then
    echo "❌ Retrieve failed"
    rm "$TEMP_FILE"
    exit 1
fi

# Compare the files
if compare_files "$ENV_FILE" "$TEMP_FILE"; then
    echo "✅ Verification successful!"
    rm "$TEMP_FILE"
    exit 0
else
    echo "❌ Verification failed"
    rm "$TEMP_FILE"
    exit 1
fi