#!/bin/bash
# secure-encrypted-send.sh
# Performs encryption and transfer entirely in memory using pipes

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
    # Generate password in memory
    PASSWORD=$(openssl rand -base64 32)
    echo "Generated password: $PASSWORD"
    echo "Share this password securely with the recipient!"
fi

echo "Encrypting and sending $FILE to $SERVER/$PATH"
# All operations performed in memory using pipes
cat "$FILE" | pv -pterb | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" -out >(curl -T - "$SERVER/$PATH")

echo -e "\nTransfer completed. Share these details securely with the recipient:"
echo "Path: $PATH"
echo "Password: $PASSWORD"