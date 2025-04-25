# PSQL Auto Backup

A lightweight utility script for automating PostgreSQL backups and testing database restore functionality.

## 📥 Getting Started

### Clone the Repository
```bash
git clone https://github.com/BottoStm/PSQL-Auto-Backup.git
cd PSQL-Auto-Backup
```

### Prepare the Server
Run the setup script to prepare your system for backup operations:
```bash
./prepare.sh
```

### Mount Google cloud bucket as filesystem 

```bash
sudo gcloud auth application-default login
```
``` bash
mkdir -p /pgbackup
```
```bash
gcsfuse psql-001 /pgbackup
```

## 🔄 Backup Options

### Full Backup
Perform a complete backup of your PostgreSQL database:
```bash
sudo ./utility.sh fullbackup
```

### Incremental Backup
Capture only the changes made since the last full or incremental backup:
```bash
sudo ./utility.sh incrbackup
```

## ♻️ Restore from Backup
Restore your database from the latest incremental backup:
```bash
sudo ./utility.sh restoreincr
```



```bash
sudo crontab -e
```
```bash
# Daily full backup at 2 AM
0 2 * * * sudo -u postgres /home/PSQL/utility.sh fullbackup >/var/log/pg_fullbackup.log 2>&1

# Incremental backup every 5 minutes
*/5 * * * * sudo -u postgres /home/PSQL/utility.sh incrbackup >/var/log/pg_incrbackup.log 2>&1
```


## 🧪 Testing Utilities
Use the built-in test script to simulate database operations.

```bash
./test.sh setup       # Create a test database and table
./test.sh add         # Add 10 sample records
./test.sh add 25      # Add 25 sample records
./test.sh validate    # Verify that data exists
./test.sh delete      # Delete all data from the table
./test.sh cleanup     # Drop the test database (requires confirmation)
```

---

Feel free to fork, contribute, or report any issues. Enjoy safe and automated PostgreSQL backups!

