#!/bin/bash
# encrypted-receive.sh
# Usage: ./encrypted-receive.sh <output-filepath> <transfer-path> <password>
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <output-filepath> <transfer-path> <password>"
    echo "Example: $0 decrypted.pdf my-secure-path 'the-password'"
    exit 1
fi

OUTPUT="$1"
PATH="$2"
PASSWORD="$3"
SERVER="https://ppng.io"

echo "Receiving and decrypting from $SERVER/$PATH to $OUTPUT"
curl "$SERVER/$PATH" | openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" > "$OUTPUT"