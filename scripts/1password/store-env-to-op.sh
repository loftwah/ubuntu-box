#!/bin/bash
# store-env-to-op.sh - Store .env file in 1Password

check_op_auth() {
    if ! op account list >/dev/null 2>&1; then
        echo "❌ Not signed in to 1Password CLI. Run: eval \$(op signin)"
        exit 1
    fi
}

env_to_json() {
    local env_file="$1"
    local json_content="{}"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        local key="${line%%=*}"
        local value="${line#*=}"
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        json_content=$(echo "$json_content" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
    done < "$env_file"
    echo "$json_content" | jq '.'
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

check_op_auth

if [[ ! -f "$ENV_FILE" ]]; then
    echo "❌ Error: $ENV_FILE not found"
    exit 1
fi

note_title="env.${PROJECT_NAME}.${ENV_TYPE}"
existing_ids=$(op item list --vault "$VAULT_NAME" --format=json | \
              jq -r --arg title "$note_title" '.[] | select(.title == $title) | .id')
if [[ -n "$existing_ids" ]]; then
    while read -r id; do
        op item delete "$id" --vault "$VAULT_NAME"
    done <<< "$existing_ids"
fi

ENV_JSON=$(env_to_json "$ENV_FILE")
if op item create --category "Secure Note" --title "$note_title" --vault "$VAULT_NAME" \
   --tags "env,${PROJECT_NAME},${ENV_TYPE}" "notesPlain=$ENV_JSON"; then
    echo "✅ Stored as: $note_title"
else
    echo "❌ Failed to store"
    exit 1
fi
