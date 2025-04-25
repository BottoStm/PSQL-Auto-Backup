# PSQL Auto Backup

A lightweight utility script for automating PostgreSQL full and incremental backups, integrating with Google Cloud Storage, and simulating test database operations.

## 📥 Getting Started

### Clone the Repository
```bash
git clone https://github.com/BottoStm/PSQL-Auto-Backup.git
cd PSQL-Auto-Backup
```

### Prepare the Server
Run the setup script to configure your system:
```bash
./prepare.sh
```

### Mount Google Cloud Bucket as Filesystem
Authenticate with Google Cloud:
```bash
sudo gcloud auth application-default login
```

Create a mount point:
```bash
mkdir -p /pgbackup
```

Mount your bucket:
```bash
gcsfuse psql-001 /pgbackup
```

## 🔄 Backup Options

### Full Backup
Create a full backup of your PostgreSQL database:
```bash
sudo ./utility.sh fullbackup
```

### Incremental Backup
Store only the changes since the last backup:
```bash
sudo ./utility.sh incrbackup
```

### Automate Backups with Cron
Edit the crontab:
```bash
sudo crontab -e
```

Add the following entries:
```bash
# Daily full backup at 2 AM
0 2 * * * sudo -u postgres /home/PSQL-Auto-Backup/utility.sh fullbackup >/var/log/pg_fullbackup.log 2>&1

# Incremental backup every 5 minutes
*/5 * * * * sudo -u postgres /home/PSQL-Auto-Backup/utility.sh incrbackup >/var/log/pg_incrbackup.log 2>&1
```

## ♻️ Restore from Backup
Recover your database using the most recent incremental backups:
```bash
sudo ./utility.sh restoreincr
```

## 🧪 Testing Utilities
Simulate database operations using the test script:
```bash
./test.sh setup       # Create test database and table
./test.sh add         # Add 10 sample records
./test.sh add 25      # Add 25 sample records
./test.sh validate    # Verify inserted data
./test.sh delete      # Remove all data from the table
./test.sh cleanup     # Drop the test database (confirmation required)
```

---

Feel free to fork the project, open issues, or contribute improvements. Stay backed up and in control!

