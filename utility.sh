#!/bin/bash
# Utility Script: pgBackRest Full/Incremental Backup and Restore with rsync
# Version 1.0 - Manages local backups and restores with /pgbackup sync

# Configuration
POSTGRES_VERSION="17"
PG_DATA="/var/lib/postgresql/$POSTGRES_VERSION/main"
PGBACKREST_CONFIG="/etc/pgbackrest/pgbackrest.conf"
REPO_PATH="/var/lib/pgbackrest"  # pgBackRest local repository
BACKUP_PATH="/pgbackup"          # Mounted directory for rsync

# Verify root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

# Function to check command success
check_status() {
    if [ $? -ne 0 ]; then
        echo "ERROR: $1 failed. Exiting."
        exit 1
    fi
}

# Function to verify pgBackRest configuration
verify_pgbackrest_config() {
    if [ ! -f "$PGBACKREST_CONFIG" ]; then
        echo "ERROR: pgBackRest configuration file $PGBACKREST_CONFIG not found."
        echo "Ensure prepare.sh has been run to set up pgBackRest."
        exit 1
    fi
    if [ ! -d "$REPO_PATH" ]; then
        echo "ERROR: pgBackRest repository $REPO_PATH not found."
        exit 1
    fi
}

# Function to verify /pgbackup directory
verify_backup_path() {
    if [ ! -d "$BACKUP_PATH" ]; then
        echo "ERROR: Backup directory $BACKUP_PATH not found or not mounted."
        exit 1
    fi
}

# Function to sync repository to /pgbackup
sync_to_backup() {
    echo "Syncing $REPO_PATH to $BACKUP_PATH..."
    rsync -av --delete "$REPO_PATH/" "$BACKUP_PATH/" --chown=postgres:postgres
    check_status "rsync to $BACKUP_PATH"
    chmod 750 "$BACKUP_PATH"
    chown postgres:postgres "$BACKUP_PATH"
}

# Function to sync from /pgbackup to repository
sync_from_backup() {
    echo "Syncing $BACKUP_PATH to $REPO_PATH..."
    rsync -av --delete "$BACKUP_PATH/" "$REPO_PATH/" --chown=postgres:postgres
    check_status "rsync from $BACKUP_PATH"
    chmod 750 "$REPO_PATH"
    chown postgres:postgres "$REPO_PATH"
}

# Function to stop PostgreSQL
stop_postgresql() {
    if systemctl is-active --quiet postgresql; then
        echo "Stopping PostgreSQL..."
        systemctl stop postgresql
        check_status "Stopping PostgreSQL"
    fi
}

# Function to start PostgreSQL
start_postgresql() {
    echo "Starting PostgreSQL..."
    systemctl start postgresql
    check_status "Starting PostgreSQL"
}

# Function to prepare data directory for restore
prepare_data_directory() {
    echo "Preparing data directory $PG_DATA..."
    if [ -d "$PG_DATA" ]; then
        mv "$PG_DATA" "$PG_DATA.bak"
        check_status "Backing up existing data directory"
    fi
    mkdir -p "$PG_DATA"
    chown postgres:postgres "$PG_DATA"
    chmod 700 "$PG_DATA"
}

# Usage information
usage() {
    echo "Usage: $0 {fullbackup|incrbackup|restorefull|restoreincr [target_time]}"
    echo "Options:"
    echo "  fullbackup       Create a full backup and sync to /pgbackup"
    echo "  incrbackup       Create an incremental backup and sync to /pgbackup"
    echo "  restorefull      Restore the latest full backup from /pgbackup"
    echo "  restoreincr      Restore full + incremental backups from /pgbackup (optionally to target_time, e.g., '2025-04-25 11:59:00')"
    exit 1
}

# Check for valid option
if [ $# -lt 1 ]; then
    usage
fi

# Verify pgBackRest and /pgbackup
verify_pgbackrest_config
verify_backup_path

case "$1" in
    fullbackup)
        echo "Performing full backup..."
        sudo -u postgres pgbackrest --stanza=main backup --type=full
        check_status "Full backup"
        sync_to_backup
        echo "Full backup completed and synced to $BACKUP_PATH."
        sudo -u postgres pgbackrest --stanza=main info
        ;;
    incrbackup)
        echo "Performing incremental backup..."
        sudo -u postgres pgbackrest --stanza=main backup --type=incr
        check_status "Incremental backup"
        sync_to_backup
        echo "Incremental backup completed and synced to $BACKUP_PATH."
        sudo -u postgres pgbackrest --stanza=main info
        ;;
    restorefull)
        echo "Restoring full backup..."
        stop_postgresql
        sync_from_backup
        prepare_data_directory
        sudo -u postgres pgbackrest --stanza=main restore
        check_status "Full backup restore"
        start_postgresql
        echo "Full backup restored successfully."
        sudo -u postgres psql -c "SELECT now();"
        ;;
    restoreincr)
        echo "Restoring full + incremental backup..."
        stop_postgresql
        sync_from_backup
        prepare_data_directory
        if [ -n "$2" ]; then
            echo "Restoring to target time: $2"
            sudo -u postgres pgbackrest --stanza=main --type=time --target="$2" restore
        else
            sudo -u postgres pgbackrest --stanza=main restore
        fi
        check_status "Incremental backup restore"
        start_postgresql
        echo "Full + incremental backup restored successfully."
        sudo -u postgres psql -c "SELECT now();"
        ;;
    *)
        usage
        ;;
esac

echo "Operation completed successfully."
