#!/bin/bash
# WAL-Enable: Complete PostgreSQL WAL + pgBackRest Setup
# Version 2.0

# Configuration
POSTGRES_VERSION="17"
PG_DATA="/var/lib/postgresql/$POSTGRES_VERSION/main"
PG_CONFIG="/etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf"
PGBACKREST_CONFIG="/etc/pgbackrest.conf"

# Verify root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run as root"
  exit 1
fi

# Stop PostgreSQL safely
echo "Stopping PostgreSQL..."
systemctl stop postgresql || {
  echo "ERROR: Failed to stop PostgreSQL"
  exit 1
}

# Configure pgBackRest
echo "Configuring pgBackRest..."
cat > "$PGBACKREST_CONFIG" << EOF
[global]
repo1-path = /var/lib/pgbackrest
repo1-retention-full = 2
compress-type = lz4
start-fast = y
process-max = 2

[main]
pg1-path = $PG_DATA
EOF

# Set permissions
chown postgres:postgres "$PGBACKREST_CONFIG"
chmod 640 "$PGBACKREST_CONFIG"

# Create repository directory
mkdir -p /var/lib/pgbackrest
chown postgres:postgres /var/lib/pgbackrest
chmod 750 /var/lib/pgbackrest

# Configure PostgreSQL WAL settings
echo "Configuring PostgreSQL WAL..."
sed -i "s/^#*wal_level = .*/wal_level = replica/" "$PG_CONFIG"
sed -i "s/^#*archive_mode = .*/archive_mode = on/" "$PG_CONFIG"
sed -i "s|^#*archive_command = .*|archive_command = 'pgbackrest --stanza=main archive-push %p'|" "$PG_CONFIG"

# Start PostgreSQL
echo "Starting PostgreSQL..."
systemctl start postgresql || {
  echo "ERROR: Failed to start PostgreSQL"
  exit 1
}

# Create pgBackRest stanza
echo "Creating pgBackRest stanza..."
sudo -u postgres pgbackrest --stanza=main stanza-create || {
  echo "ERROR: Failed to create stanza"
  exit 1
}

# Verify setup
echo "Verification:"
echo "PostgreSQL WAL Settings:"
sudo -u postgres psql -c "SELECT name, setting FROM pg_settings WHERE name IN ('wal_level', 'archive_mode', 'archive_command');"

echo "pgBackRest Configuration:"
sudo -u postgres pgbackrest --stanza=main check

echo "WAL archiving and pgBackRest setup completed successfully!"
