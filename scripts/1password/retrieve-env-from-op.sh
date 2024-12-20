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

while getopts "o:v:t:l:p:h" opt; do
    case ${opt} in
        o) OUTPUT_FILE="$OPTARG" ;;
        v) VAULT_NAME="$OPTARG" ;;
        t) NOTE_TITLE="$OPTARG" ;;
        p) PROJECT_NAME="$OPTARG" ;;
        l) LIST_MODE=true ;;
        h)
           echo "Usage: $0 [-o output] [-v vault] [-t title] [-l] [-p project]"
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

if [[ -z "$NOTE_TITLE" ]]; then
    echo "❌ Error: Note title (-t) required"
    exit 1
fi

echo "🔍 Retrieving: $NOTE_TITLE"

# Get all fields except internal ones
if ! op item get "$NOTE_TITLE" --vault "$VAULT_NAME" --format=json | \
     jq -r '.fields[] | select(.id | test("^[^notesPlain]")) | "\(.label)=\(.value)"' | sort > "$OUTPUT_FILE"; then
    echo "❌ Failed to retrieve"
    exit 1
fi

echo "✅ Retrieved to: $OUTPUT_FILE"
echo "📄 Content:"
echo "-------------------"
cat "$OUTPUT_FILE"
echo "-------------------"