#!/bin/bash
# lock-verify.sh - Test script for lock.sh
#
# Purpose: Verifies that the lock.sh script properly prevents multiple instances
#
# Setup:
#   1. Place lock.sh and lock-verify.sh in the same directory
#   2. Make both executable: chmod +x lock.sh lock-verify.sh
#
# Usage:
#   1. Run in first terminal:
#      ./lock-verify.sh
#
#   2. While countdown is running, try in second terminal:
#      ./lock-verify.sh
#
#   3. Second attempt should fail with "Lock failed" message
#
# Expected Results:
#   - First run: Shows countdown from 10 to 1
#   - Second run (during countdown): Shows "Lock failed" message
#   - After countdown: Lock is released, script can run again

source "$(dirname "$0")/lock.sh"

echo "Trying to get lock..."

if ! exlock_now; then
    echo "Lock failed - another instance is running!"
    exit 1
fi

echo "Got lock! Starting 10 second countdown..."
echo "Try running this script in another terminal now!"

# Countdown from 10
for i in {10..1}; do
    echo "$i..."
    sleep 1
done

echo "Done! Lock will be released."