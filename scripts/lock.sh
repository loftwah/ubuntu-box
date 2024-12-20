#!/bin/bash
# lock.sh - Script locking mechanism
# Save this in your scripts directory

LOCKFILE="${LOCK_DIR:-/var/lock}/`basename $0`"
LOCKFD=99

_lock()             { flock -$1 $LOCKFD; }
_no_more_locking()  { _lock u; _lock xn && rm -f $LOCKFILE; }
_prepare_locking()  { eval "exec $LOCKFD>\"$LOCKFILE\""; trap _no_more_locking EXIT; }

# Public functions
exlock_now()        { _lock xn; }  # obtain exclusive lock immediately or fail
exlock()            { _lock x; }   # obtain exclusive lock
unlock()            { _lock u; }   # drop a lock

_prepare_locking