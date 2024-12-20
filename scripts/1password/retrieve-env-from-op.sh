#!/bin/bash
# retrieve-env-from-op.sh - Get .env from 1Password

check_op_auth() {
    if ! op account list >/dev/null 2>&1; then
        echo "❌ Not signed in to 1Password CLI. Run: eval \$(op signin)"
        exit 1
    fi
}

VAULT_NAME="Personal"
OUTPUT_FILE=".env"
PROJECT_NAME=""
ENV_TYPE="development"

while getopts "o:v:p:t:l:h" opt; do
    case ${opt} in
        o) OUTPUT_FILE="$OPTARG" ;;
        v) VAULT_NAME="$OPTARG" ;;
        p) PROJECT_NAME="$OPTARG" ;;
        t) NOTE_TITLE="$OPTARG" ;;
        l) LIST_MODE=true ;;
        h)
           echo "Usage: $0 [-o output] [-v vault] [-p project] [-t note_title] [-l]"
           exit 0
           ;;
    esac
done

check_op_auth

if [[ "$LIST_MODE" = true ]]; then
    if [[ -n "$PROJECT_NAME" ]]; then
        op item list --vault "$VAULT_NAME" --tags "env,${PROJECT_NAME}" --format=json | \
            jq -r '.[] | .title' | sort -r
    else
        op item list --vault "$VAULT_NAME" --tags "env" --format=json | \
            jq -r '.[] | .title' | sort -r
    fi
    exit 0
fi

# If no explicit title but project name given, construct the title
if [[ -z "$NOTE_TITLE" && -n "$PROJECT_NAME" ]]; then
    NOTE_TITLE="env.${PROJECT_NAME}.${ENV_TYPE}"
fi

if [[ -z "$NOTE_TITLE" ]]; then
    echo "❌ Error: Note title (-t) or project name (-p) required"
    echo "💡 Use -l to list available environment files"
    exit 1
fi

echo "🔍 Retrieving: $NOTE_TITLE"

# Get the newest note ID with this title
NOTE_ID=$(op item list --vault "$VAULT_NAME" --format=json | \
          jq -r --arg title "$NOTE_TITLE" '.[] | select(.title == $title) | .id' | \
          head -n 1)

if [[ -z "$NOTE_ID" ]]; then
    echo "❌ Note not found"
    exit 1
fi

# Get full item JSON and extract notesPlain
json_content=$(op item get "$NOTE_ID" --format=json | jq -r '.fields[] | select(.label == "notesPlain") | .value')
if [[ -z "$json_content" ]]; then
    echo "❌ Failed to retrieve notesPlain content"
    exit 1
fi

# Validate and parse JSON with jq
if ! echo "$json_content" | jq empty 2>/dev/null; then
    echo "❌ Invalid JSON content retrieved"
    echo "🔍 Retrieved content for debugging:"
    echo "$json_content"
    exit 1
fi

# Parse JSON into .env format
parsed_env=$(echo "$json_content" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"')
if [[ -z "$parsed_env" ]]; then
    echo "❌ Error parsing retrieved content"
    echo "🔍 JSON content for debugging:"
    echo "$json_content"
    exit 1
fi

# Write parsed environment variables to the output file
{
    echo "# Retrieved at: $(date)"
    echo "$parsed_env"
} | sort > "$OUTPUT_FILE"

echo "✅ Retrieved to: $OUTPUT_FILE"
echo "📄 Content:"
echo "-------------------"
cat "$OUTPUT_FILE"
echo "-------------------"
