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
    local temp_orig=$(mktemp)
    local temp_retr=$(mktemp)
    grep -v '^#' "$original" | sort | sed 's/[[:space:]]*=[[:space:]]*/=/' > "$temp_orig"
    grep -v '^#' "$retrieved" | sort | sed 's/[[:space:]]*=[[:space:]]*/=/' > "$temp_retr"

    if diff "$temp_orig" "$temp_retr" >/dev/null; then
        echo "✅ Files match"
        rm "$temp_orig" "$temp_retr"
        return 0
    else
        echo "❌ Files differ"
        diff "$temp_orig" "$temp_retr"
        rm "$temp_orig" "$temp_retr"
        return 1
    fi
}

VAULT_NAME="Personal"
ENV_FILE=".env"
PROJECT_NAME=$(basename "$(pwd)")
ENV_TYPE="development"

check_dependencies

./store-env-to-op.sh -f "$ENV_FILE" -v "$VAULT_NAME" -p "$PROJECT_NAME" -t "$ENV_TYPE"
TEMP_FILE=$(mktemp)
./retrieve-env-from-op.sh -t "env.${PROJECT_NAME}.${ENV_TYPE}" -o "$TEMP_FILE" -v "$VAULT_NAME"

compare_files "$ENV_FILE" "$TEMP_FILE"
