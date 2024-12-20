#!/bin/bash
# db-backup-send.sh
# Usage: ./db-backup-send.sh <dbname> <transfer-path> [password]
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <dbname> <transfer-path> [password]"
    echo "Example: $0 mydb my-db-backup mypassword"
    echo "If password is not provided, a random one will be generated"
    exit 1
fi

DB="$1"
PATH="$2"
SERVER="https://ppng.io"

if [ "$#" -eq 3 ]; then
    PASSWORD="$3"
else
    PASSWORD=$(openssl rand -base64 32)
    echo "Generated password: $PASSWORD"
    echo "Share this password securely with the recipient!"
fi

echo "Backing up, encrypting and sending database $DB to $SERVER/$PATH"
pg_dump -Fc "$DB" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" | curl -T - "$SERVER/$PATH"
echo "Transfer initiated. Share these details securely with the recipient:"
echo "Path: $PATH"
echo "Password: $PASSWORD"