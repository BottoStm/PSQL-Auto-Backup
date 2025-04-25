#!/bin/bash
# Integrated Installer: PostgreSQL 17 + gcloud + gcsfuse + pgBackRest + WAL Archiving
# Version 1.8 - Fixed pgBackRest config directory creation

# Configuration
POSTGRES_VERSION="17"
PG_DATA="/var/lib/postgresql/$POSTGRES_VERSION/main"
PG_CONFIG="/etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf"
PGBACKREST_CONFIG="/etc/pgbackrest/pgbackrest.conf"
REPO_TYPE="local"  # Change to "gcs" for Google Cloud Storage
GCS_BUCKET=""      # Set your GCS bucket name if REPO_TYPE="gcs"
REPO_PATH="/var/lib/pgbackrest"  # Local path or GCS path (/pgbackrest for GCS)

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

# Function to check if a package is installed
check_package() {
    dpkg -l "$1" >/dev/null 2>&1
    return $?
}

# Function to check if PostgreSQL is installed and running
check_postgresql() {
    if check_package "postgresql-$POSTGRES_VERSION"; then
        echo "PostgreSQL $POSTGRES_VERSION is already installed."
        if systemctl is-active --quiet postgresql; then
            echo "PostgreSQL is running."
            return 0
        else
            echo "PostgreSQL is installed but not running."
            return 1
        fi
    else
        echo "PostgreSQL $POSTGRES_VERSION is not installed."
        return 1
    fi
}

# Update package lists
echo "Updating package lists..."
sudo apt-get update
check_status "Package list update"

# Install PostgreSQL 17 if not already installed
if ! check_postgresql; then
    echo "Installing PostgreSQL $POSTGRES_VERSION..."
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /usr/share/keyrings/postgresql.gpg
    sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    sudo apt-get update
    sudo apt-get install -y postgresql-$POSTGRES_VERSION postgresql-client-$POSTGRES_VERSION
    check_status "PostgreSQL $POSTGRES_VERSION installation"
else
    echo "Skipping PostgreSQL installation."
fi

# Install Google Cloud CLI if not already installed
if ! command -v gcloud >/dev/null 2>&1; then
    echo "Installing Google Cloud CLI..."
    sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/google-cloud.gpg
    echo "deb [signed-by=/usr/share/keyrings/google-cloud.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
    sudo apt-get update && sudo apt-get install -y google-cloud-cli
    check_status "Google Cloud CLI installation"
else
    echo "Google Cloud CLI is already installed."
fi

# Install GCSFuse if not already installed
if ! command -v gcsfuse >/dev/null 2>&1; then
    echo "Installing GCSFuse..."
    # Set GCSFuse repository
    export GCSFUSE_REPO=gcsfuse-$(lsb_release -c -s)
    # Import Google Cloud GPG key with retries
    for i in {1..3}; do
        curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && break
        echo "Retry $i: Failed to fetch Google Cloud GPG key. Retrying..."
        sleep 2
    done
    if [ ! -f /usr/share/keyrings/cloud.google.gpg ]; then
        echo "ERROR: Failed to import Google Cloud GPG key after retries."
        exit 1
    fi
    # Add GCSFuse repository
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
    sudo apt-get update || {
        echo "ERROR: Failed to update apt after adding GCSFuse repository. Check /etc/apt/sources.list.d/gcsfuse.list."
        exit 1
    }
    sudo apt-get install -y fuse gcsfuse
    check_status "GCSFuse installation"
else
    echo "GCSFuse is already installed."
fi

# Install pgBackRest if not already installed
if ! check_package "pgbackrest"; then
    echo "Installing pgBackRest..."
    sudo apt-get install -y pgbackrest
    check_status "pgBackRest installation"
else
    echo "pgBackRest is already installed."
fi

# Stop PostgreSQL safely if running
if systemctl is-active --quiet postgresql; then
    echo "Stopping PostgreSQL..."
    systemctl stop postgresql
    check_status "Stopping PostgreSQL"
fi

# Configure pgBackRest
echo "Configuring pgBackRest..."
if [ "$REPO_TYPE" = "gcs" ] && [ -z "$GCS_BUCKET" ]; then
    echo "ERROR: GCS_BUCKET must be set for REPO_TYPE=gcs"
    exit 1
fi

# Create pgBackRest configuration directory
sudo mkdir -p /etc/pgbackrest
check_status "pgBackRest configuration directory creation"

# Write pgBackRest configuration
cat > "$PGBACKREST_CONFIG" << EOF
[global]
repo1-path = ${REPO_PATH}
repo1-retention-full = 2
compress-type = lz4
start-fast = y
process-max = 2
$( [ "$REPO_TYPE" = "gcs" ] && echo "repo1-type = gcs" )
$( [ "$REPO_TYPE" = "gcs" ] && echo "repo1-gcs-bucket = $GCS_BUCKET" )

[main]
pg1-path = $PG_DATA
EOF
check_status "pgBackRest configuration"

# Set permissions for pgBackRest
chown postgres:postgres "$PGBACKREST_CONFIG"
chmod 640 "$PGBACKREST_CONFIG"
mkdir -p "$REPO_PATH"
chown postgres:postgres "$REPO_PATH"
chmod 750 "$REPO_PATH"

# Configure PostgreSQL WAL settings
echo "Configuring PostgreSQL WAL..."
sed -i "s/^#*wal_level = .*/wal_level = replica/" "$PG_CONFIG"
sed -i "s/^#*archive_mode = .*/archive_mode = on/" "$PG_CONFIG"
sed -i "s|^#*archive_command = .*|archive_command = 'pgbackrest --stanza=main archive-push %p'|" "$PG_CONFIG"
check_status "PostgreSQL WAL configuration"

# Start PostgreSQL
echo "Starting PostgreSQL..."
systemctl start postgresql
check_status "Starting PostgreSQL"

# Create pgBackRest stanza
echo "Creating pgBackRest stanza..."
sudo -u postgres pgbackrest --stanza=main stanza-create
check_status "pgBackRest stanza creation"

# Verify setup
echo "Verification:"
echo "PostgreSQL WAL Settings:"
sudo -u postgres psql -c "SELECT name, setting FROM pg_settings WHERE name IN ('wal_level', 'archive_mode', 'archive_command');"

echo "pgBackRest Configuration:"
sudo -u postgres pgbackrest --stanza=main check
check_status "pgBackRest configuration check"

# Display versions
echo "Installation and configuration complete:"
echo "- PostgreSQL $(psql --version)"
echo "- Google Cloud CLI $(gcloud --version | head -1 2>/dev/null || echo 'Not installed')"
echo "- GCSFuse $(gcsfuse --version 2>/dev/null || echo 'Not installed')"
echo "- pgBackRest $(pgbackrest version | head -1)"
echo ""
echo "WAL archiving and pgBackRest setup completed successfully!"
echo "Note: For GCS, ensure gcloud is authenticated (run 'gcloud auth login') and the bucket exists."
