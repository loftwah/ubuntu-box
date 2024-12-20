# Complete Guide to Linux Lock Files

A practical guide to using lock files in Linux/Ubuntu to prevent scripts from running simultaneously.

## The Main Lock Script (lock.sh)

This is your reusable locking mechanism:

```bash
#!/bin/bash
# lock.sh - Script locking mechanism
# Save this as /scripts/lock.sh

LOCKFILE="${LOCK_DIR:-/var/lock}/`basename $0`"
LOCKFD=99

_lock()             { flock -$1 $LOCKFD; }
_no_more_locking()  { _lock u; _lock xn && rm -f $LOCKFILE; }
_prepare_locking()  { eval "exec $LOCKFD>\"$LOCKFILE\""; trap _no_more_locking EXIT; }

exlock_now()        { _lock xn; }  # obtain exclusive lock immediately or fail
exlock()            { _lock x; }   # obtain exclusive lock
unlock()            { _lock u; }   # drop a lock

_prepare_locking
```

## Common Use Cases

### 1. Basic Script Lock

Prevents a script from running twice:

```bash
#!/bin/bash
# check_server.sh - Basic system check script

source /scripts/lock.sh

if ! exlock_now; then
    echo "Already running!"
    exit 1
fi

echo "Checking server..."
sleep 30  # your actual work here
echo "Done!"
```

### 2. Cron Job

For scheduled tasks:

```bash
#!/bin/bash
# backup.sh - Daily backup script
# Crontab: 0 1 * * * /scripts/backup.sh

source /scripts/lock.sh

if ! exlock_now; then
    echo "Backup already in progress!"
    exit 1
fi

echo "Starting backup..."
# your backup commands here
echo "Backup complete!"
```

### 3. PostgreSQL Backup Example

Real-world example combining everything:

```bash
#!/bin/bash
# pg_backup.sh - PostgreSQL backup with locking
# Usage: PGDATABASE=mydb ./pg_backup.sh

source /scripts/lock.sh

# Config
BACKUP_DIR=${BACKUP_DIR:-"/var/backups/postgres"}
KEEP_DAYS=${KEEP_DAYS:-7}
DATE=$(date +%Y%m%d_%H%M%S)

# Check requirements
if [ -z "$PGDATABASE" ]; then
    echo "Error: PGDATABASE not set"
    exit 1
fi

# Try to get lock
if ! exlock_now; then
    echo "Another backup is already running!"
    exit 1
fi

# Do backup
echo "Starting backup of $PGDATABASE..."
mkdir -p "$BACKUP_DIR"
pg_dump "$PGDATABASE" | gzip > "$BACKUP_DIR/$PGDATABASE-$DATE.sql.gz"

# Cleanup old backups
find "$BACKUP_DIR" -name "$PGDATABASE-*.sql.gz" -mtime +$KEEP_DAYS -delete
echo "Backup complete!"
```

## How To Use

1. Save the lock script:

```bash
sudo mkdir -p /scripts
sudo nano /scripts/lock.sh  # paste lock.sh content
sudo chmod +x /scripts/lock.sh
```

2. Create your script (example):

```bash
sudo nano /scripts/check_server.sh  # paste script content
sudo chmod +x /scripts/check_server.sh
```

3. Run your script:

```bash
./check_server.sh
```

## Testing Locks

1. Run in first terminal:

```bash
./check_server.sh
```

2. While first is running, try in second terminal:

```bash
./check_server.sh  # Should fail with "Already running!"
```

## Common Commands

Check if script is running:

```bash
# List locks
ls -l /var/lock/

# Check specific lock
fuser /var/lock/scriptname.lock

# Remove stale lock (be careful!)
rm /var/lock/scriptname.lock
```

## Best Practices

1. Always source the lock script first
2. Always check the lock status immediately
3. Put lock files in /var/lock
4. Use descriptive lock file names
5. Let the trap handle cleanup

## Debugging

If your script isn't locking properly:

1. Check lock file permissions
2. Make sure /var/lock is writable
3. Verify the lock file path
4. Check if script has execute permissions

## Full Example For Production

Here's a production-ready example combining everything:

```bash
#!/bin/bash
# production_script.sh - Template for production scripts

# Source the locking script
source /scripts/lock.sh

# Configuration
LOG_FILE="/var/log/production_script.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Check lock
if ! exlock_now; then
    log "Script already running!"
    exit 1
fi

# Your script logic here
log "Starting script..."
# Do your work here
log "Script complete!"
```
