#!/bin/bash

# Configuration
DB_NAME="testdb"
TABLE_NAME="test_data"
NUM_RECORDS=10  # Default number of records to add

# Function to run psql commands with sudo
run_psql() {
    sudo -u postgres psql -c "$1"
}

run_psql_db() {
    sudo -u postgres psql -d "$DB_NAME" -c "$1"
}

# Function to create database and table
setup_database() {
    echo "Setting up database..."
    if ! run_psql "\l" | grep -qw "$DB_NAME"; then
        run_psql "CREATE DATABASE $DB_NAME;"
    else
        echo "Database $DB_NAME already exists."
    fi
    
    run_psql_db "CREATE TABLE IF NOT EXISTS $TABLE_NAME (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100),
        email VARCHAR(100),
        age INT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );"
    echo "Database setup complete."
}

# Function to generate random data
add_data() {
    [ -n "$2" ] && NUM_RECORDS=$2
    
    echo "Adding $NUM_RECORDS random records..."
    
    for ((i=1; i<=$NUM_RECORDS; i++)); do
        name="User_$((RANDOM % 1000))"
        email="user_$((RANDOM % 1000))@example.com"
        age=$((18 + RANDOM % 50))
        
        run_psql_db "INSERT INTO $TABLE_NAME (name, email, age) VALUES ('$name', '$email', $age);"
    done
    
    echo "Added $NUM_RECORDS records."
}

# Function to validate data
validate_data() {
    count=$(run_psql_db "SELECT COUNT(*) FROM $TABLE_NAME;" | grep -o '[0-9]\+' | head -1)
    
    if [ "$count" -gt 0 ]; then
        echo "Validation passed: $count records exist."
        return 0
    else
        echo "Validation failed: No records found."
        return 1
    fi
}

# Function to delete data
delete_data() {
    run_psql_db "TRUNCATE TABLE $TABLE_NAME RESTART IDENTITY;"
    echo "All data deleted from $TABLE_NAME."
}

# Function to clean up (remove database)
cleanup() {
    read -p "Are you sure you want to delete the entire database? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_psql "DROP DATABASE IF EXISTS $DB_NAME;"
        echo "Database $DB_NAME deleted."
    fi
}

# Main execution
case "$1" in
    setup)
        setup_database
        ;;
    add)
        add_data "$@"
        ;;
    validate)
        validate_data
        ;;
    delete)
        delete_data
        ;;
    cleanup)
        cleanup
        ;;
    *)
        echo "Usage: $0 {setup|add [count]|validate|delete|cleanup}"
        echo "  setup     - Create database and table"
        echo "  add [n]   - Add n random records (default 10)"
        echo "  validate  - Check if data exists"
        echo "  delete    - Delete all data (keeps database)"
        echo "  cleanup   - Remove the entire database"
        exit 1
        ;;
esac

exit 0
