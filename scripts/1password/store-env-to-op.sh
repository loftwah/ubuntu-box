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
        # Skip empty lines and comments
        if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Split on first = only and trim whitespace
        local key="${line%%=*}"
        local value="${line#*=}"
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        json_content=$(echo "$json_content" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
    done < "$env_file"
    
    echo "$json_content"
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

timestamp=$(date +%Y%m%d_%H%M%S)
note_title="env.${PROJECT_NAME}.${ENV_TYPE}.${timestamp}"

echo "📝 Creating note: $note_title"
ENV_JSON=$(env_to_json "$ENV_FILE")
echo "📄 JSON content:"
echo "$ENV_JSON" | jq .

# Store in both fields for maximum compatibility
if op item create --category "Secure Note" --title "$note_title" --vault "$VAULT_NAME" \
   --tags "env,${PROJECT_NAME},${ENV_TYPE}" \
   "env[text]=$ENV_JSON" "notesPlain=$ENV_JSON"; then
    echo "✅ Stored as: $note_title"
    echo "$note_title" > /tmp/last_stored_note
else
    echo "❌ Failed to store"
    exit 1
fi