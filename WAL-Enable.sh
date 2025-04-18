#!/bin/bash
# WAL-Enable: Configure PostgreSQL for WAL Archiving
# Version 1.0

POSTGRES_VERSION="17"  # Change to your PostgreSQL version
CONFIG_FILE="/etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf"

# Verify running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root"
  exit 1
fi

# Stop PostgreSQL safely
echo "Stopping PostgreSQL..."
systemctl stop postgresql || {
  echo "ERROR: Failed to stop PostgreSQL"
  exit 1
}

# Configure WAL settings
echo "Modifying $CONFIG_FILE..."
sed -i "s/^#*wal_level = .*/wal_level = replica/" "$CONFIG_FILE"
sed -i "s/^#*archive_mode = .*/archive_mode = on/" "$CONFIG_FILE"
sed -i "s|^#*archive_command = .*|archive_command = 'pgbackrest --stanza=main archive-push %p'|" "$CONFIG_FILE"

# Verify changes
echo "Configuration changes:"
grep -E "wal_level|archive_mode|archive_command" "$CONFIG_FILE"

# Start PostgreSQL
echo "Starting PostgreSQL..."
systemctl start postgresql || {
  echo "ERROR: Failed to start PostgreSQL"
  exit 1
}

# Verify WAL archiving
echo "Verifying WAL archiving..."
sudo -u postgres psql -c "SELECT name, setting FROM pg_settings WHERE name IN ('wal_level', 'archive_mode', 'archive_command');"
sudo -u postgres psql -c "SELECT pg_switch_wal();"  # Force WAL rotation to test

echo "WAL archiving successfully configured!"
