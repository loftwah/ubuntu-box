#!/bin/bash
# db-backup-receive.sh
# Usage: ./db-backup-receive.sh <newdbname> <transfer-path> <password>
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <newdbname> <transfer-path> <password>"
    echo "Example: $0 restored_db my-db-backup 'the-password'"
    exit 1
fi

NEWDB="$1"
PATH="$2"
PASSWORD="$3"
SERVER="https://ppng.io"

echo "Receiving and restoring database backup from $SERVER/$PATH to database $NEWDB"
curl "$SERVER/$PATH" | openssl enc -d -aes-256-cbc -pbkdf2 -salt -pass pass:"$PASSWORD" | pg_restore -d "$NEWDB"