#!/bin/bash
# encrypted-send.sh
# Usage: ./encrypted-send.sh <filepath> <transfer-path> [password]
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <filepath> <transfer-path> [password]"
    echo "Example: $0 secret.pdf my-secure-path mypassword"
    echo "If password is not provided, a random one will be generated"
    exit 1
fi

FILE="$1"
PATH="$2"
SERVER="https://ppng.io"

if [ ! -f "$FILE" ]; then
    echo "Error: File $FILE does not exist"
    exit 1
fi

if [ "$#" -eq 3 ]; then
    PASSWORD="$3"
else
    PASSWORD=$(openssl rand -base64 32)
    echo "Generated password: $PASSWORD"
    echo "Share this password securely with the recipient!"
fi

echo "Encrypting and sending $FILE to $SERVER/$PATH"
cat "$FILE" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" | curl -T - "$SERVER/$PATH"
echo "Transfer initiated. Share these details securely with the recipient:"
echo "Path: $PATH"
echo "Password: $PASSWORD"