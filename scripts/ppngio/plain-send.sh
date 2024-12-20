#!/bin/bash
# plain-send.sh
# Usage: ./plain-send.sh <filepath> <transfer-path>
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <filepath> <transfer-path>"
    echo "Example: $0 myfile.txt my-secret-path"
    exit 1
fi

FILE="$1"
PATH="$2"
SERVER="https://ppng.io"

if [ ! -f "$FILE" ]; then
    echo "Error: File $FILE does not exist"
    exit 1
fi

echo "Sending $FILE to $SERVER/$PATH"
curl -T "$FILE" "$SERVER/$PATH"