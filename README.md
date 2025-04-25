README for prepare.sh
Overview
The prepare.sh script automates the installation and configuration of PostgreSQL 17 and pgBackRest on Ubuntu 22.04, setting up a robust local backup system with Write-Ahead Logging (WAL) archiving. It supports both full and incremental backups to a local repository (/var/lib/pgbackrest) and provides an optional cron job for automated backups (weekly full, daily incremental). The script is designed to be idempotent, checking for existing installations to avoid redundant operations, and includes error handling for reliability.
This README explains:
What the script does.

How to use it.

The backup process (full and incremental).

The restore process for recovering a crashed database.

Sample commands for backup and restore.

What the Script Does
The prepare.sh script performs the following tasks:
Checks for Existing Installations:
Verifies if PostgreSQL 17 and pgBackRest are already installed.

Skips installation steps for components that are already present.

Installs Dependencies:
Installs PostgreSQL 17 and its client from the official PostgreSQL repository.

Installs pgBackRest for backup and restore operations.

Configures PostgreSQL:
Sets up WAL archiving with:
wal_level = replica

archive_mode = on

archive_command = 'pgbackrest --stanza=main archive-push %p'

Ensures the data directory (/var/lib/postgresql/17/main) is correctly configured.

Configures pgBackRest:
Creates a local backup repository at /var/lib/pgbackrest.

Configures /etc/pgbackrest/pgbackrest.conf with:
Local repository path.

Retention of 2 full backups.

LZ4 compression for efficiency.

Parallel processing (process-max = 2).

Sets appropriate permissions for the repository and configuration files.

Optional Cron Job:
If ENABLE_CRON="yes", sets up a cron job to:
Run full backups every Sunday at 2 AM.

Run incremental backups daily at 2 AM (Monday–Saturday).

Log output to /var/log/pgbackrest_backup.log.

Verifies Setup:
Checks PostgreSQL WAL settings.

Runs a pgBackRest configuration check.

Displays installed versions and backup instructions.

Requirements
Operating System: Ubuntu 22.04 (Jammy).

Root Privileges: The script must be run as root or with sudo.

Disk Space: Ensure sufficient space in:
/var/lib/postgresql/17/main for the database.

/var/lib/pgbackrest for backups and WAL segments.

Internet Access: Required to download packages and keys.

How to Use
Save the Script:
Save the script as prepare.sh.

Make it executable:
bash

chmod +x prepare.sh

Customize (Optional):
Open prepare.sh and set:
bash

ENABLE_CRON="yes"

to enable automated backups (full on Sundays, incremental daily at 2 AM). Default is ENABLE_CRON="no".

Run the Script:
Execute as root:
bash

sudo ./prepare.sh

The script will install, configure, and verify the setup.

Check Output:
Review the script’s output for installation status, WAL settings, and pgBackRest configuration.

Note the restore instructions printed at the end.

Backup Process
pgBackRest supports full and incremental backups:
Full Backup: Captures the entire database cluster.

Incremental Backup: Captures changes since the last full or incremental backup, requiring WAL archiving for point-in-time recovery (PITR).

WAL Archiving: Continuously archives Write-Ahead Logs to /var/lib/pgbackrest/archive/main, enabling recovery to any point between backups.

Sample Backup Commands
Create a Full Backup:
bash

sudo -u postgres pgbackrest --stanza=main backup --type=full

Takes a complete snapshot of the database.

Example: Run after significant changes or weekly.

Create an Incremental Backup:
bash

sudo -u postgres pgbackrest --stanza=main backup --type=incr

Backs up changes since the last backup (full or incremental).

Example: Run daily to minimize backup size and time.

Requires a prior full backup.

Verify Backups:
bash

sudo -u postgres pgbackrest --stanza=main info

Displays available backups (e.g., full backup from 2025-04-24, incremental from 2025-04-25).

Example output:

stanza: main
status: ok
cipher: none

db (current)
  wal archive min/max (17): 000000010000000000000001/000000010000000000000004

  full backup: 20250424-120000F
    timestamp start/stop: 2025-04-24 12:00:00 / 2025-04-24 12:10:00
    wal start/stop: 000000010000000000000001 / 000000010000000000000002
    database size: 100MB, database backup size: 100MB
    repo size: 95MB, repo backup size: 90MB

  incr backup: 20250425-100000F_20250425-100000I
    timestamp start/stop: 2025-04-25 10:00:00 / 2025-04-25 10:05:00
    wal start/stop: 000000010000000000000003 / 000000010000000000000004
    database size: 100MB, database backup size: 10MB
    repo size: 95MB, repo backup size: 9MB

Check Automated Backups (if ENABLE_CRON="yes"):
View logs:
bash

cat /var/log/pgbackrest_backup.log

Verify backups:
bash

sudo -u postgres pgbackrest --stanza=main info

Restore Process
If your PostgreSQL database crashes (e.g., corrupted data directory), you can restore it using pgBackRest. The process involves:
Restoring the most recent full backup.

Applying the incremental backup (if available).

Replaying WAL segments to recover to the latest point or a specific time (PITR).

Scenario Example
Full Backup: Taken on 2025-04-24 at 12:00 PM.

Incremental Backup: Taken on 2025-04-25 at 10:00 AM.

Crash: Occurred on 2025-04-25 at 12:00 PM.

Sample Restore Commands
Stop PostgreSQL:
bash

sudo systemctl stop postgresql

Check Available Backups:
bash

sudo -u postgres pgbackrest --stanza=main info

Confirm the full backup (e.g., 20250424-120000F) and incremental backup (e.g., 20250425-100000F_20250425-100000I) exist.

Prepare the Data Directory:
Back up and clear the corrupted data directory:
bash

sudo mv /var/lib/postgresql/17/main /var/lib/postgresql/17/main.bak
sudo mkdir /var/lib/postgresql/17/main
sudo chown postgres:postgres /var/lib/postgresql/17/main
sudo chmod 700 /var/lib/postgresql/17/main

Restore to the Latest Point:
bash

sudo -u postgres pgbackrest --stanza=main restore

Restores:
Full backup from 2025-04-24.

Incremental backup from 2025-04-25 10:00 AM.

WAL segments up to the latest archived point (e.g., 2025-04-25 12:00 PM).

Optional: Point-in-Time Recovery (PITR):
To recover to a specific time (e.g., just before the crash at 2025-04-25 11:59 AM):
bash

sudo -u postgres pgbackrest --stanza=main --type=time --target="2025-04-25 11:59:00" restore

Start PostgreSQL:
bash

sudo systemctl start postgresql

Verify the Database:
bash

sudo -u postgres psql -c "SELECT now();"
sudo -u postgres psql -c "\dt"  # List tables

Check your application data to ensure recovery.

Clean Up:
If the restore is successful, remove the corrupted data backup:
bash

sudo rm -rf /var/lib/postgresql/17/main.bak

Troubleshooting
Backup Issues:
If pgbackrest info shows no backups, verify the repository:
bash

ls -l /var/lib/pgbackrest

Check permissions:
bash

ls -ld /var/lib/pgbackrest

Ensure WAL archiving is working:
bash

sudo -u postgres psql -c "SELECT name, setting FROM pg_settings WHERE name IN ('wal_level', 'archive_mode', 'archive_command');"

Restore Issues:
If restore fails, check logs:
bash

sudo -u postgres pgbackrest --stanza=main --log-level-console=detail restore

Ensure the data directory is empty or cleared.

Cron Issues (if enabled):
Check the cron job:
bash

crontab -u root -l

Verify the script:
bash

cat /usr/local/bin/pgbackrest_backup.sh

Inspect logs:
bash

cat /var/log/pgbackrest_backup.log

Apt Issues:
Clean and retry:
bash

sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get update

Notes
Disk Space: Ensure sufficient space in /var/lib/pgbackrest for backups and WAL segments, and in /var/lib/postgresql/17/main for the database.

Configuration Backup: The script modifies /etc/postgresql/17/main/postgresql.conf and /etc/pgbackrest/pgbackrest.conf. Back up these files in production:
bash

cp /etc/postgresql/17/main/postgresql.conf /etc/postgresql/17/main/postgresql.conf.bak
cp /etc/pgbackrest/pgbackrest.conf /etc/pgbackrest/pgbackrest.conf.bak 2>/dev/null || true

Downtime: The script and restore process require stopping PostgreSQL, causing brief downtime.

Security: Set a password for the postgres user in production:
bash

sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'your_secure_password';"

Support
For issues or enhancements (e.g., different backup schedules, additional pgBackRest options), contact your system administrator or refer to the pgBackRest documentation.

