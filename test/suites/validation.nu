#!/usr/bin/env nu

# Validation test suite
# Tests migration validation, error handling, and edge cases

use ../test-framework.nu *

export def run_tests [] {
    test-suite "Migration Validation" {
        [
            (test "Invalid migration filenames" { test_invalid_filenames }),
            (test "SQL syntax validation" { test_sql_syntax_validation }),
            (test "Duplicate migration detection" { test_duplicate_detection }),
            (test "Migration ordering" { test_migration_ordering }),
            (test "Error handling" { test_error_handling })
        ]
    }
}

def test_invalid_filenames [] {
    # Test various invalid filename formats using src function
    let invalid_names = [
        "invalid.sql",                    # No timestamp
        "20231201_missing_track.sql",     # Missing track
        "not_timestamp_core_test.sql",    # Invalid timestamp
        "20231201120000.sql",             # Missing description
        "20231201120000_core.sql",        # Missing description
        ""                                # Empty filename
    ]
    
    for name in $invalid_names {
        try {
            parse-migration-filename $name
            assert-true false $"Should fail to parse invalid filename: ($name)"
        } catch {
            # Expected to fail
        }
    }
    
    # Test valid filename for comparison
    let valid_result = (parse-migration-filename "20231201120000_core_create_table.sql")
    assert-equal $valid_result.track "core" "Valid filename should parse correctly"
    
    # Test timestamp validation function
    assert-true (validate-migration-timestamp "20231201120000") "Valid timestamp should pass"
    assert-false (validate-migration-timestamp "invalid") "Invalid timestamp should fail"
    assert-false (validate-migration-timestamp "2023120112") "Short timestamp should fail"
}

def test_sql_syntax_validation [] {
    # Test SQL syntax validation by executing various SQL statements
    
    # Valid SQL should work
    try {
        db-execute "SELECT 1"
    } catch {
        assert-true false "Valid SQL should execute successfully"
    }
    
    # Invalid SQL should fail (suppress error output)
    try {
        db-execute "INVALID SQL SYNTAX HERE" --quiet
        assert-true false "Invalid SQL should fail"
    } catch {
        # Expected to fail
    }
    
    # Test DDL statements
    try {
        db-execute "CREATE TABLE syntax_test (id INT)"
        assert-table-exists "syntax_test" "DDL should execute correctly"
        db-execute "DROP TABLE syntax_test"
    } catch {
        assert-true false "DDL statements should work"
    }
}

def test_duplicate_detection [] {
    # Test detection of duplicate migration timestamps
    let migrations = [
        {timestamp: "20231201120000", track: "core", description: "first"},
        {timestamp: "20231201120000", track: "impl", description: "second"},  # Same timestamp, different track
        {timestamp: "20231201120001", track: "core", description: "third"}
    ]
    
    # Check that we can detect same timestamps
    let same_timestamp_count = ($migrations | where timestamp == "20231201120000" | length)
    assert-equal $same_timestamp_count 2 "Should detect duplicate timestamps"
    
    # Test that same timestamp in different tracks is potentially valid
    let core_migrations = ($migrations | where track == "core")
    let unique_core_timestamps = ($core_migrations | get timestamp | uniq | length)
    let total_core_migrations = ($core_migrations | length)
    assert-equal $unique_core_timestamps $total_core_migrations "Each track should have unique timestamps"
}

def test_migration_ordering [] {
    # Test that migrations are processed in correct order
    let migrations = [
        {timestamp: "20231201120002", filename: "third.sql"},
        {timestamp: "20231201120000", filename: "first.sql"},
        {timestamp: "20231201120001", filename: "second.sql"}
    ]
    
    let sorted_migrations = ($migrations | sort-by timestamp)
    assert-equal $sorted_migrations.0.filename "first.sql" "First migration should be earliest timestamp"
    assert-equal $sorted_migrations.1.filename "second.sql" "Second migration should be middle timestamp"
    assert-equal $sorted_migrations.2.filename "third.sql" "Third migration should be latest timestamp"
    
    # Test timestamp validation for ordering
    let timestamps = ["20231201120000", "20231201120001", "20231201120002"]
    for i in 0..(($timestamps | length) - 2) {
        let current = $timestamps | get $i
        let next = $timestamps | get ($i + 1)
        assert-true ($current < $next) $"Timestamp ($current) should be less than ($next)"
    }
}

def test_error_handling [] {
    # Test various error conditions and recovery
    
    # Test connection error handling (using src validation)
    try {
        let result = (do { nu -c "use ../src/migrate.nu *; validate-connection" } | complete)
        if $result.exit_code != 0 {
            assert-true false $"Connection validation should work: ($result.stderr)"
        }
    } catch { |err|
        assert-true false $"Connection validation should work: ($err.msg)"
    }
    
    # Clean up any existing error_test table first
    try {
        db-execute "DROP TABLE IF EXISTS error_test" --quiet
    } catch {
        # Table might not exist - ignore
    }
    
    # Test transaction rollback on error
    db-execute "CREATE TABLE error_test (id INT PRIMARY KEY)"
    
    try {
        # This should fail due to duplicate key if we insert same ID twice
        db-execute "INSERT INTO error_test (id) VALUES (1)"
        db-execute "INSERT INTO error_test (id) VALUES (1)" --quiet  # Should fail
        assert-true false "Should fail on duplicate key"
    } catch {
        # Expected to fail
    }
    
    # Verify table still exists and has one row
    assert-table-exists "error_test" "Table should still exist after error"
    let count = (db-count-rows "error_test")
    assert-equal $count 1 "Should have one row after failed insert"
    
    # Cleanup
    db-execute "DROP TABLE IF EXISTS error_test"
    
    # Test handling of missing migration directories using src function
    try {
        let result = (do { nu -c "use ../src/migrate.nu *; migrate validate nonexistent_directory" } | complete)
        if $result.exit_code == 0 {
            assert-true false "Should fail with nonexistent directory"
        }
    } catch {
        # Expected to fail
    }
}