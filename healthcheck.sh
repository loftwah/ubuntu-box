#!/bin/bash
set -e

# Check for sufficient free memory
if [ "$(free | awk '/^Mem:/ {print $4}')" -lt 102400 ]; then
    echo "Insufficient memory"
    exit 1
fi

# Check basic commands
for cmd in go node python3; do
    if ! command -v $cmd > /dev/null 2>&1; then
        echo "$cmd not found"
        exit 1
    fi
done

# Health check passed
echo "Health check passed"
exit 0
