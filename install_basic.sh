#!/bin/bash
# Minimal Installer: PostgreSQL + gcloud + gcsfuse + pgBackRest
# Version 1.2 - No Configuration

# Update package lists
sudo apt-get update

# Install PostgreSQL
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y postgresql postgresql-client

# Install Google Cloud CLI
sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update && sudo apt-get install -y google-cloud-cli

# Install GCSFuse
export GCSFUSE_REPO=gcsfuse-$(lsb_release -c -s)
echo "deb https://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y fuse gcsfuse

# Install pgBackRest
sudo apt-get install -y pgbackrest

echo "Installation complete:"
echo "- PostgreSQL $(psql --version)"
echo "- Google Cloud CLI $(gcloud --version | head -1)"
echo "- GCSFuse $(gcsfuse --version)"
echo "- pgBackRest $(pgbackrest version | head -1)"
echo ""
echo "Note: No configuration has been applied"
