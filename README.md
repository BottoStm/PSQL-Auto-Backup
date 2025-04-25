# PostgreSQL 17 + pgBackRest Setup & Backup Automation

This guide provides a complete overview of installing and configuring **PostgreSQL 17** and **pgBackRest** on **Ubuntu 22.04**, using the `prepare.sh` script. It sets up local backups, enables Write-Ahead Logging (WAL) for point-in-time recovery (PITR), and optionally schedules automated backups.

---

## 📘 Overview

The `prepare.sh` script performs the following:

- Installs **PostgreSQL 17** and **pgBackRest** from official repositories
- Configures PostgreSQL for WAL archiving:
  - `wal_level = replica`
  - `archive_mode = on`
  - `archive_command = 'pgbackrest --stanza=main archive-push %p'`
- Creates a local pgBackRest repository at `/var/lib/pgbackrest`
- Configures retention, compression (LZ4), and parallel processing
- Adds a cron job for scheduled full and incremental backups (if enabled)
- Verifies installations and prints helpful usage tips

---

## ⚙️ Requirements

- OS: Ubuntu 22.04 (Jammy)
- Root or sudo access
- Sufficient disk space:
  - `/var/lib/postgresql/17/main` (database)
  - `/var/lib/pgbackrest` (backups)
- Internet access for package downloads

---

## 💡 How to Use

### 1. Save and Make Script Executable
```bash
curl -O https://yourdomain.com/prepare.sh
chmod +x prepare.sh
```

### 2. Customize (Optional)
Open the script and edit:
```bash
ENABLE_CRON="yes"
```
To enable automated backups (default is `no`).

### 3. Run the Script
```bash
sudo ./prepare.sh
```

---



### 4. Mount Google cloud bucket as filesystem 

```bash
sudo gcloud auth application-default login
```
``` bash
mkdir -p /pgbackup
```
```bash
gcsfuse psqlbackup /pgbackup
```



## 🔁 Backup Process

### Types of Backups:
- **Full**: Complete snapshot of the database cluster
- **Incremental**: Changes since last backup (requires WAL archiving)

### Sample Commands

**Full Backup**:
```bash
sudo -u postgres pgbackrest --stanza=main backup --type=full
```

**Incremental Backup**:
```bash
sudo -u postgres pgbackrest --stanza=main backup --type=incr
```

**View Backup Info**:
```bash
sudo -u postgres pgbackrest --stanza=main info
```

Example output:
```
stanza: main
status: ok
cipher: none

full backup: 20250424-120000F
incr backup: 20250425-100000F_20250425-100000I
```

---

## 🔄 Restore Process

If your PostgreSQL instance crashes:

### 1. Stop PostgreSQL
```bash
sudo systemctl stop postgresql
```

### 2. Prepare Data Directory
```bash
sudo mv /var/lib/postgresql/17/main /var/lib/postgresql/17/main.bak
sudo mkdir /var/lib/postgresql/17/main
sudo chown postgres:postgres /var/lib/postgresql/17/main
sudo chmod 700 /var/lib/postgresql/17/main
```

### 3. Restore Backups
```bash
sudo -u postgres pgbackrest --stanza=main restore
```

### 4. Optional: Point-In-Time Recovery (PITR)
```bash
sudo -u postgres pgbackrest --stanza=main --type=time --target="2025-04-25 11:59:00" restore
```

### 5. Start PostgreSQL
```bash
sudo systemctl start postgresql
```

### 6. Verify Recovery
```bash
sudo -u postgres psql -c "SELECT now();"
sudo -u postgres psql -c "\dt"
```

### 7. Clean Up
```bash
sudo rm -rf /var/lib/postgresql/17/main.bak
```

---

## 📅 Automated Backups (Cron)

If `ENABLE_CRON="yes"`:
- Full Backup: Sunday at 2:00 AM
- Incremental Backup: Monday–Saturday at 2:00 AM

**View Cron Job**:
```bash
crontab -u root -l
```

**Log Output**:
```bash
cat /var/log/pgbackrest_backup.log
```

---

## 🛠 Troubleshooting

### Backup Issues
```bash
ls -l /var/lib/pgbackrest
ls -ld /var/lib/pgbackrest
sudo -u postgres psql -c "SELECT name, setting FROM pg_settings WHERE name IN ('wal_level', 'archive_mode', 'archive_command');"
```

### Restore Errors
```bash
sudo -u postgres pgbackrest --stanza=main --log-level-console=detail restore
```

### Cron Not Running
```bash
cat /usr/local/bin/pgbackrest_backup.sh
cat /var/log/pgbackrest_backup.log
```

### Apt Problems
```bash
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get update
```

---

## 📝 Notes

- Always back up config files:
```bash
cp /etc/postgresql/17/main/postgresql.conf /etc/postgresql/17/main/postgresql.conf.bak
cp /etc/pgbackrest/pgbackrest.conf /etc/pgbackrest/pgbackrest.conf.bak 2>/dev/null || true
```
- Set password for `postgres` in production:
```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'your_secure_password';"
```
- Ensure security, especially if automating backups in production environments.

---

## 📚 References
- [PostgreSQL Official Docs](https://www.postgresql.org/docs/)
- [pgBackRest Documentation](https://pgbackrest.org/)

---

Happy backing up! For custom setups like hybrid deployments or external FTP storage, consider integrating with workflows like `n8n` for automation or alerts.

