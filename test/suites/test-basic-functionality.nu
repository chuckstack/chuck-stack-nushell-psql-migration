#!/usr/bin/env nu

# Test suite: Basic functionality
# Tests core migration discovery, parsing, and execution

def main [] {
    print "Testing basic migration functionality..."
    
    # Test 1: Migration file discovery
    test_migration_discovery
    
    # Test 2: Migration file parsing
    test_migration_parsing
    
    # Test 3: Basic SQL execution
    test_basic_execution
    
    print $"(ansi green)Basic functionality tests completed(ansi reset)"
}

def test_migration_discovery [] {
    print "Test 1: Migration file discovery"
    
    let test_migrations_dir = "test/fixtures/migrations/core"
    let expected_files = [
        "20231201120000_core_create_users_table.sql",
        "20231201120001_core_create_roles_table.sql"
    ]
    
    let found_files = (ls $test_migrations_dir | where type == file | get name | path basename | sort)
    
    for expected in $expected_files {
        if $expected in $found_files {
            print $"  ✓ Found migration file: ($expected)"
        } else {
            error make { msg: $"Missing expected migration file: ($expected)" }
        }
    }
}

def test_migration_parsing [] {
    print "Test 2: Migration file parsing"
    
    let test_file = "test/fixtures/migrations/core/20231201120000_core_create_users_table.sql"
    
    if not ($test_file | path exists) {
        error make { msg: $"Test migration file not found: ($test_file)" }
    }
    
    let filename = ($test_file | path basename)
    let parts = ($filename | str replace ".sql" "" | split row "_")
    
    if ($parts | length) < 3 {
        error make { msg: $"Invalid migration filename format: ($filename)" }
    }
    
    let timestamp = $parts.0
    let track = $parts.1
    let description = ($parts | skip 2 | str join "_")
    
    print $"  ✓ Parsed timestamp: ($timestamp)"
    print $"  ✓ Parsed track: ($track)"
    print $"  ✓ Parsed description: ($description)"
    
    # Validate timestamp format
    if not ($timestamp | str contains "20231201") {
        error make { msg: $"Invalid timestamp format: ($timestamp)" }
    }
    
    if $track != "core" {
        error make { msg: $"Expected track 'core', got: ($track)" }
    }
}

def test_basic_execution [] {
    print "Test 3: Basic SQL execution"
    
    # Test database connection
    try {
        let result = (psql -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $env.PGUSER -d $env.PGDATABASE -c "SELECT 'connection test' as status;" | str trim)
        print $"  ✓ Database connection successful"
    } catch {
        error make { msg: "Failed to connect to test database" }
    }
    
    # Test simple SQL execution
    try {
        psql -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $env.PGUSER -d $env.PGDATABASE -c "CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, name VARCHAR(50));" | ignore
        print $"  ✓ SQL execution successful"
    } catch {
        error make { msg: "Failed to execute SQL" }
    }
    
    # Clean up test table
    try {
        psql -h $env.TEST_SOCKET_DIR -p $env.PGPORT -U $env.PGUSER -d $env.PGDATABASE -c "DROP TABLE IF EXISTS test_table;" | ignore
        print $"  ✓ Cleanup successful"
    } catch {
        print $"  ⚠ Warning: Failed to clean up test table"
    }
}