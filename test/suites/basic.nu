#!/usr/bin/env nu

# Basic functionality test suite
# Tests core migration discovery, parsing, and execution

use ../test-framework.nu *
use ../../src/migrate.nu [discover-migrations]

export def run_tests [] {
    test-suite "Basic Migration Functionality" {
        [
            (test "Migration file discovery" { test_migration_discovery }),
            (test "Migration filename parsing" { test_migration_parsing }),
            (test "Database connection" { test_database_connection }),
            (test "SQL execution" { test_sql_execution }),
            (test "Migration file execution" { test_migration_execution }),
            (test "Migration tracking table" { test_migration_tracking })
        ]
    }
}

def test_migration_discovery [] {
    # Test that we can discover migration files using src function
    let migrations_dir = "fixtures/migrations/core"
    
    assert-true ($migrations_dir | path exists) "Core migrations directory should exist"
    
    # Test the actual discover-migrations function from src
    let discovered_migrations = (discover-migrations $migrations_dir)
    assert-true (($discovered_migrations | length) > 0) "Should discover migration files in core directory"
    
    # Test that discovered migrations have expected structure
    let first_migration = $discovered_migrations.0
    assert-true ("timestamp" in $first_migration) "Migration should have timestamp field"
    assert-true ("track" in $first_migration) "Migration should have track field"
    assert-true ("description" in $first_migration) "Migration should have description field"
    assert-true ("filename" in $first_migration) "Migration should have filename field"
    
    # Test specific expected files
    let expected_filenames = [
        "20231201120000_core_create_users_table.sql",
        "20231201120001_core_create_roles_table.sql"
    ]
    
    let discovered_filenames = ($discovered_migrations | get filename)
    for expected_file in $expected_filenames {
        assert-true ($expected_file in $discovered_filenames) $"Should discover expected file: ($expected_file)"
    }
}

def test_migration_parsing [] {
    # Test parsing of migration filenames
    let test_filename = "20231201120000_core_create_users_table.sql"
    let parsed = (parse-migration-filename $test_filename)
    
    assert-equal $parsed.timestamp "20231201120000" "Should parse timestamp correctly"
    assert-equal $parsed.track "core" "Should parse track correctly"
    assert-equal $parsed.description "create_users_table" "Should parse description correctly"
    assert-equal $parsed.filename $test_filename "Should preserve original filename"
    
    # Test timestamp validation
    assert-true (validate-migration-timestamp "20231201120000") "Valid timestamp should pass validation"
    assert-false (validate-migration-timestamp "invalid") "Invalid timestamp should fail validation"
    assert-false (validate-migration-timestamp "2023120112") "Short timestamp should fail validation"
}

def test_database_connection [] {
    # Test basic database connectivity
    let result = try {
        db-query "SELECT 'connection_test' as status"
    } catch { |err|
        error make {msg: $"Database query failed: ($err.msg)"}
    }
    assert-equal $result "connection_test" "Should be able to execute basic query"
    
    # Test that we can access current database name (simpler than checking pg_database)
    let current_db = try {
        db-query "SELECT current_database()"
    } catch { |err|
        error make {msg: $"Current database check failed: ($err.msg)"}
    }
    assert-equal $current_db $env.PGDATABASE "Should be connected to correct database"
}

def test_sql_execution [] {
    # Test creating and dropping a test table
    db-execute "CREATE TABLE test_basic_table (id SERIAL PRIMARY KEY, name VARCHAR(50))"
    assert-table-exists "test_basic_table" "Should be able to create table"
    
    # Test inserting data
    db-execute "INSERT INTO test_basic_table (name) VALUES ('test_name')"
    let count = (db-count-rows "test_basic_table")
    assert-equal $count 1 "Should be able to insert data"
    
    # Test querying data
    let result = (db-query "SELECT name FROM test_basic_table WHERE id = 1")
    assert-equal $result "test_name" "Should be able to query data"
    
    # Cleanup
    db-execute "DROP TABLE test_basic_table"
    assert-false (db-table-exists "test_basic_table") "Should be able to drop table"
}

def test_migration_execution [] {
    # Test executing migrations using the actual migrate run command
    let migrations_dir = "fixtures/migrations/core"
    
    if ($migrations_dir | path exists) {
        # Use the actual migrate run command (dry-run first)
        try {
            nu -c $"use ../src/migrate.nu *; migrate run ($migrations_dir) --dry-run"
        } catch { |err|
            assert-true false $"Dry run should not fail: ($err.msg)"
        }
        
        # Test actual execution
        try {
            nu -c $"use ../src/migrate.nu *; migrate run ($migrations_dir) --force"
            
            # Verify tables were created
            assert-table-exists "users" "Users table should be created by migration"
            assert-table-exists "roles" "Roles table should be created by migration"
            
            # Test the structure
            let user_columns = (db-query "SELECT column_name FROM information_schema.columns WHERE table_name = 'users' ORDER BY ordinal_position")
            assert-contains $user_columns "id" "Users table should have id column"
            assert-contains $user_columns "name" "Users table should have name column"
            
            # Cleanup for other tests
            db-execute "DROP TABLE IF EXISTS users"
            db-execute "DROP TABLE IF EXISTS roles"
            db-execute "DROP TABLE IF EXISTS migrations_core"
        } catch { |err|
            assert-true false $"Migration execution should not fail: ($err.msg)"
        }
    } else {
        # Skip if fixture doesn't exist
        print "Skipping migration execution test - fixture not found"
    }
}

def test_migration_tracking [] {
    # Test migration tracking table functionality
    let tracking_table = "migration_tracking"
    
    # Create a simple tracking table for testing
    db-execute $"CREATE TABLE IF NOT EXISTS ($tracking_table) \(
        id SERIAL PRIMARY KEY,
        filename VARCHAR\(255) NOT NULL,
        executed_at TIMESTAMP DEFAULT NOW\(\),
        checksum VARCHAR\(64)
    )"
    
    assert-table-exists $tracking_table "Migration tracking table should be created"
    
    # Test inserting migration record
    db-execute $"INSERT INTO ($tracking_table) \(filename, checksum) VALUES \('test_migration.sql', 'abc123')"
    
    let count = (db-count-rows $tracking_table)
    assert-equal $count 1 "Should be able to track migration execution"
    
    # Test querying migration status
    let result = (db-query $"SELECT filename FROM ($tracking_table) WHERE checksum = 'abc123'")
    assert-equal $result "test_migration.sql" "Should be able to query migration records"
    
    # Cleanup
    db-execute $"DROP TABLE ($tracking_table)"
}