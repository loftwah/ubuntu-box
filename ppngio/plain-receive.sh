#!/bin/bash
# plain-receive.sh
# Usage: ./plain-receive.sh <output-filepath> <transfer-path>
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <output-filepath> <transfer-path>"
    echo "Example: $0 received.txt my-secret-path"
    exit 1
fi

OUTPUT="$1"
PATH="$2"
SERVER="https://ppng.io"

echo "Receiving from $SERVER/$PATH to $OUTPUT"
curl "$SERVER/$PATH" > "$OUTPUT"