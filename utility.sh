#!/bin/bash
# Utility Script: pgBackRest Full/Incremental Backup and Restore with lftp
# Version 1.18 - Fixed lftp local sync with file:// URLs, added debug

# Configuration
POSTGRES_VERSION="17"
PG_DATA="/var/lib/postgresql/$POSTGRES_VERSION/main"
PGBACKREST_CONFIG="/etc/pgbackrest/pgbackrest.conf"
REPO_PATH="/var/lib/pgbackrest"  # pgBackRest local repository
BACKUP_PATH="/pgbackup"          # Mounted directory for sync
LFTP_PARALLEL=2                  # Number of parallel lftp transfers

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

# Function to verify lftp is installed
ensure_tools() {
    if ! command -v lftp >/dev/null 2>&1; then
        echo "Installing lftp..."
        apt-get update
        apt-get install -y lftp
        check_status "lftp installation"
    else
        echo "lftp is already installed."
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

# Function to check and create stanza
ensure_stanza() {
    if [ ! -f "$REPO_PATH/backup/main/backup.info" ]; then
        echo "Stanza 'main' not initialized. Creating stanza..."
        sudo -u postgres pgbackrest --stanza=main stanza-create
        check_status "Stanza creation"
    else
        echo "Stanza 'main' already initialized."
    fi
}

# Function to validate target time format for PITR
validate_target_time() {
    local target_time="$1"
    # Check if the time matches YYYY-MM-DD HH:MM:SS format
    if [[ ! "$target_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        echo "ERROR: Invalid target time format. Use 'YYYY-MM-DD HH:MM:SS' (e.g., '2025-04-25 11:59:00')."
        exit 1
    fi
}

# Function to list available backups
list_backups() {
    echo "Available backups:"
    sudo -u postgres pgbackrest --stanza=main info
    check_status "Listing backups"
}

# Function to verify and set permissions
verify_permissions() {
    echo "Setting permissions for $REPO_PATH and $BACKUP_PATH..."
    find "$REPO_PATH" -exec chown postgres:postgres {} \;
    find "$REPO_PATH" -type d -exec chmod 750 {} \;
    find "$REPO_PATH" -type f -exec chmod 640 {} \;
    find "$BACKUP_PATH" -exec chown postgres:postgres {} \;
    find "$BACKUP_PATH" -type d -exec chmod 750 {} \;
    find "$BACKUP_PATH" -type f -exec chmod 640 {} \;
}

# Function to sync repository to /pgbackup
sync_to_backup() {
    echo "Syncing $REPO_PATH to $BACKUP_PATH..."
    # Ensure destination subdirectories exist
    for subdir in archive backup; do
        mkdir -p "$BACKUP_PATH/$subdir"
        chown postgres:postgres "$BACKUP_PATH/$subdir"
        chmod 750 "$BACKUP_PATH/$subdir"
    done
    # Verify permissions
    verify_permissions
    # Sync using lftp mirror with file:// for local paths
    echo "Mirroring files from $REPO_PATH to $BACKUP_PATH..."
    sudo lftp -e "mirror --delete --parallel=$LFTP_PARALLEL --verbose file://$REPO_PATH $BACKUP_PATH; exit"
    check_status "lftp sync to $BACKUP_PATH"
    # Set final permissions
    verify_permissions
}

# Function to sync from /pgbackup to repository
sync_from_backup() {
    echo "Syncing $BACKUP_PATH to $REPO_PATH..."
    # Ensure destination subdirectories exist
    for subdir in archive backup; do
        mkdir -p "$REPO_PATH/$subdir"
        chown postgres:postgres "$REPO_PATH/$subdir"
        chmod 750 "$REPO_PATH/$subdir"
    done
    # Verify permissions
    verify_permissions
    # Sync using lftp mirror with file:// for local paths
    echo "Mirroring files from $BACKUP_PATH to $REPO_PATH..."
    sudo lftp -e "mirror --delete --parallel=$LFTP_PARALLEL --verbose file://$BACKUP_PATH $REPO_PATH; exit"
    check_status "lftp sync from $BACKUP_PATH"
    # Set final permissions
    verify_permissions
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

# Verify prerequisites
ensure_tools
verify_pgbackrest_config
verify_backup_path
ensure_stanza

case "$1" in
    fullbackup)
        echo "Performing full backup..."
        sudo -u postgres pgbackrest --stanza=main backup --type=full
        check_status "Full backup"
        sync_to_backup
        echo "Full backup completed and synced to $BACKUP_PATH."
        list_backups
        ;;
    incrbackup)
        echo "Performing incremental backup..."
        sudo -u postgres pgbackrest --stanza=main backup --type=incr
        check_status "Incremental backup"
        sync_to_backup
        echo "Incremental backup completed and synced to $BACKUP_PATH."
        list_backups
        ;;
    restorefull)
        echo "Restoring full backup..."
        list_backups
        echo "The latest full backup will be restored."
        read -p "Proceed with restore? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            echo "Restore cancelled."
            exit 0
        fi
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
        list_backups
        echo "Options:"
        echo "1. Restore to the latest available point (full + incremental + WAL)"
        echo "2. Restore to a specific point in time (PITR)"
        echo "3. Cancel"
        read -p "Enter choice (1/2/3): " choice
        case "$choice" in
            1)
                echo "Restoring to latest available point..."
                stop_postgresql
                sync_from_backup
                prepare_data_directory
                sudo -u postgres pgbackrest --stanza=main restore
                check_status "Incremental backup restore"
                ;;
            2)
                read -p "Enter target time (YYYY-MM-DD HH:MM:SS, e.g., '2025-04-25 11:59:00): " target_time
                validate_target_time "$target_time"
                echo "Restoring to target time: $target_time"
                stop_postgresql
                sync_from_backup
                prepare_data_directory
                sudo -u postgres pgbackrest --stanza=main --type=time --target="$target_time" restore
                check_status "Incremental backup restore (PITR)"
                ;;
            3)
                echo "Restore cancelled."
                exit 0
                ;;
            *)
                echo "ERROR: Invalid choice. Use 1, 2, or 3."
                exit 1
                ;;
        esac
        start_postgresql
        echo "Full + incremental backup restored successfully."
        sudo -u postgres psql -c "SELECT now();"
        ;;
    *)
        usage
        ;;
esac

# PITR Usage Example (Commented)
echo "PITR Example for restoreincr:"
cat << 'EOF'
# To restore to a specific point in time (e.g., '2025-04-25 11:59:00'):
sudo ./utility.sh restoreincr
# Choose option 2 and enter: 2025-04-25 11:59:00
# This will:
# 1. Sync /pgbackup to /var/lib/pgbackrest
# 2. Restore the full backup
# 3. Apply incremental backups
# 4. Replay WAL segments up to 2025-04-25 11:59:00
EOF

echo "Operation completed successfully."
